///|
fn sequence_scene(
  values : Array[String],
  highlights~ : Array[@frontierlab.Highlight] = [],
) -> @frontierlab.Scene raise {
  @frontierlab.Scene::new(
    objects=[
      @frontierlab.Sequence(
        @frontierlab.SequenceState::new(
          id="sequence",
          label="Values",
          items=values.mapi(fn(index, value) {
            @frontierlab.SequenceItem::new(id="item-\{index}", value~)
          }),
        ),
      ),
    ],
    highlights~,
  )
}

///|
test "TraceBuilder stores deep snapshots and deterministic JSON" {
  let scene = sequence_scene(["3", "1"])
  let builder = @frontierlab.TraceBuilder::new(
    title="Sort",
    algorithm="test-sort",
    initial_scene=scene,
  )
  builder.record(
    event=@frontierlab.Compare([
      @frontierlab.TargetRef::entity("sequence", "item-0"),
      @frontierlab.TargetRef::entity("sequence", "item-1"),
    ]),
    scene~,
    annotation=@frontierlab.Annotation::new(title="Compare", body="3 > 1"),
  )
  scene.objects.clear()
  let trace = builder.finish(summary=[
    @frontierlab.TraceAttribute::new(key="comparisons", value="1"),
  ])
  assert_eq(trace.schema_version, "1.0")
  assert_eq(trace.steps.length(), 1)
  assert_eq(trace.steps[0].scene.objects.length(), 1)
  let first = trace.to_json_string()
  assert_eq(first, trace.to_json_string())
  assert_true(first.contains("test-sort"))
  assert_true(first.contains("Compare"))
}

///|
test "Scene rejects duplicate ids and dangling highlights" {
  try
    @frontierlab.Scene::new(objects=[
      @frontierlab.Sequence(
        @frontierlab.SequenceState::new(id="same", label="A", items=[]),
      ),
      @frontierlab.Sets(
        @frontierlab.SetState::new(id="same", label="B", groups=[]),
      ),
    ])
  catch {
    _ => ()
  } noraise {
    _ => fail("expected duplicate scene ids to fail")
  }
  try
    @frontierlab.Scene::new(
      objects=[
        @frontierlab.Sequence(
          @frontierlab.SequenceState::new(id="seq", label="A", items=[]),
        ),
      ],
      highlights=[
        @frontierlab.Highlight::new(
          target=@frontierlab.TargetRef::entity("seq", "missing"),
          role=@frontierlab.Error,
        ),
      ],
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expected dangling highlight to fail")
  }
}

///|
test "Graph and grid validate references and dimensions" {
  let nodes = [
    @frontierlab.GraphNode::new(id="a", label="A"),
    @frontierlab.GraphNode::new(id="b", label="B"),
  ]
  let graph = @frontierlab.GraphState::new(id="g", label="Graph", nodes~, edges=[
    @frontierlab.GraphEdge::new(id="ab", from="a", to="b", directed=true),
  ])
  assert_eq(graph.edges.length(), 1)
  try
    @frontierlab.GraphState::new(id="bad", label="Bad", nodes~, edges=[
      @frontierlab.GraphEdge::new(id="ac", from="a", to="c"),
    ])
  catch {
    _ => ()
  } noraise {
    _ => fail("expected missing graph endpoint to fail")
  }
  try
    @frontierlab.GridState::new(id="grid", label="Grid", width=1, height=1, cells=[
      @frontierlab.GridCellState::new(id="outside", x=2, y=0),
    ])
  catch {
    _ => ()
  } noraise {
    _ => fail("expected outside grid cell to fail")
  }
}

///|
test "all scene kinds round trip through JSON" {
  let graph = @frontierlab.GraphState::new(
    id="graph",
    label="Graph <safe>",
    nodes=[
      @frontierlab.GraphNode::new(id="a", label="A"),
      @frontierlab.GraphNode::new(id="b", label="B"),
    ],
    edges=[
      @frontierlab.GraphEdge::new(
        id="ab",
        from="a",
        to="b",
        label="7",
        directed=true,
      ),
    ],
  )
  let grid = @frontierlab.GridState::new(
    id="grid",
    label="Grid",
    width=2,
    height=1,
    cells=[
      @frontierlab.GridCellState::new(id="c0", x=0, y=0, label="S"),
      @frontierlab.GridCellState::new(id="c1", x=1, y=0, blocked=true),
    ],
  )
  let scene = @frontierlab.Scene::new(
    objects=[
      @frontierlab.Sequence(
        @frontierlab.SequenceState::new(id="seq", label="Seq", items=[
          @frontierlab.SequenceItem::new(id="v", value="1"),
        ]),
      ),
      @frontierlab.Sets(
        @frontierlab.SetState::new(id="sets", label="Sets", groups=[
          @frontierlab.SetGroup::new(id="one", label="One", members=["v"]),
        ]),
      ),
      @frontierlab.Graph(graph),
      @frontierlab.Grid(grid),
    ],
    highlights=[
      @frontierlab.Highlight::new(
        target=@frontierlab.TargetRef::entity("seq", "v"),
        role=@frontierlab.Compared,
      ),
      @frontierlab.Highlight::new(
        target=@frontierlab.TargetRef::entity("graph", "a"),
        role=@frontierlab.Current,
      ),
      @frontierlab.Highlight::new(
        target=@frontierlab.TargetRef::entity("grid", "c0"),
        role=@frontierlab.Result,
      ),
    ],
  )
  let builder = @frontierlab.TraceBuilder::new(
    title="All",
    algorithm="all",
    initial_scene=scene,
  )
  builder.record(
    event=@frontierlab.Complete,
    scene~,
    annotation=@frontierlab.Annotation::new(title="Done", body="Safe & sound"),
  )
  let trace = builder.finish()
  assert_true(
    @frontierlab.AlgorithmTrace::decode_json(trace.encode_json()) == trace,
  )
}

///|
test "HTML renderer is standalone interactive and script-safe" {
  let scene = sequence_scene(["</script><b>unsafe</b>"])
  let builder = @frontierlab.TraceBuilder::new(
    title="中文 <trace>",
    algorithm="safe",
    initial_scene=scene,
  )
  builder.record(event=@frontierlab.Custom("demo", []), scene~)
  let html = @frontierlab.render_trace_html(builder.finish())
  assert_true(html.contains("<!doctype html>"))
  assert_true(html.contains("lang=\"zh-CN\""))
  assert_true(html.contains("id=\"timeline\""))
  assert_true(html.contains("id=\"guide\""))
  assert_true(html.contains("id=\"language\""))
  assert_true(html.contains("FrontierLabPlayerCore"))
  assert_true(html.contains("function eventGuide"))
  assert_true(html.contains("data-entity-key"))
  assert_true(html.contains("node.animate"))
  assert_true(html.contains("--current-bg:#ffedd5"))
  assert_true(html.contains("--current-fg:#7c2d12"))
  assert_true(html.contains("prefers-reduced-motion"))
  assert_true(html.contains("\\u003c/script>"))
  assert_false(html.contains("https://"))
}

///|
test "empty traces render their initial scene" {
  let scene = sequence_scene(["1"])
  let trace = @frontierlab.TraceBuilder::new(
    title="Empty",
    algorithm="empty",
    initial_scene=scene,
  ).finish()
  assert_true(@frontierlab.render_trace_html(trace).contains("<!doctype html>"))
}

///|
test "graph and grid reject duplicate entity ids and invalid dimensions" {
  try
    @frontierlab.GraphState::new(
      id="g",
      label="G",
      nodes=[
        @frontierlab.GraphNode::new(id="a", label="A"),
        @frontierlab.GraphNode::new(id="a", label="Again"),
      ],
      edges=[],
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expected duplicate graph nodes to fail")
  }
  try
    @frontierlab.GridState::new(id="g", label="G", width=0, height=1, cells=[])
  catch {
    _ => ()
  } noraise {
    _ => fail("expected invalid grid dimensions to fail")
  }
  try
    @frontierlab.GridState::new(id="g", label="G", width=1, height=1, cells=[
      @frontierlab.GridCellState::new(id="same", x=0, y=0),
      @frontierlab.GridCellState::new(id="same", x=0, y=0),
    ])
  catch {
    _ => ()
  } noraise {
    _ => fail("expected duplicate grid cells to fail")
  }
}

///|
test "bundled adapters produce complete portable traces" {
  let sort = @classics.insertion_sort_trace([3, 1, 2])
  let union = @classics.union_find_trace(4, [
    @classics.UnionOperation::new(left=0, right=1),
    @classics.UnionOperation::new(left=1, right=3),
  ])
  assert_true(sort.steps.last().unwrap().event is @frontierlab.Complete)
  assert_true(union.steps.last().unwrap().event is @frontierlab.Complete)
  assert_true(sort.to_json_string().contains("\"type\": \"swap\""))
  assert_true(union.to_json_string().contains("\"type\": \"union\""))
  assert_true(
    @frontierlab.AlgorithmTrace::decode_json(sort.encode_json()) == sort,
  )
  assert_true(
    @frontierlab.AlgorithmTrace::decode_json(union.encode_json()) == union,
  )
}

///|
test "schema v1 ignores unknown fields and preserves unknown events" {
  let trace = @classics.insertion_sort_trace([2, 1])
  let json = trace
    .encode_json()
    .replace(
      old="\"format\": \"frontierlab-trace\"",
      new="\"format\": \"frontierlab-trace\", \"future\": true",
    )
    .replace(old="\"type\": \"compare\"", new="\"type\": \"future-compare\"")
  let decoded = @frontierlab.AlgorithmTrace::decode_json(json)
  assert_true(
    decoded.steps[0].event is @frontierlab.Custom("future-compare", _),
  )
}

///|
test "schema v1 rejects unsupported major versions" {
  let json = @classics.insertion_sort_trace([1])
    .encode_json()
    .replace(
      old="\"schema_version\": \"1.0\"",
      new="\"schema_version\": \"2.0\"",
    )
  try @frontierlab.AlgorithmTrace::decode_json(json) catch {
    @frontierlab.UnsupportedSchema(_) => ()
    _ => fail("expected UnsupportedSchema")
  } noraise {
    _ => fail("expected schema rejection")
  }
}

///|
test "TargetRef scopes duplicate entity ids across scene objects" {
  let scene = @frontierlab.Scene::new(
    objects=[
      @frontierlab.Sequence(
        @frontierlab.SequenceState::new(id="left", label="Left", items=[
          @frontierlab.SequenceItem::new(id="same", value="1"),
        ]),
      ),
      @frontierlab.Sequence(
        @frontierlab.SequenceState::new(id="right", label="Right", items=[
          @frontierlab.SequenceItem::new(id="same", value="2"),
        ]),
      ),
    ],
    highlights=[
      @frontierlab.Highlight::new(
        target=@frontierlab.TargetRef::entity("left", "same"),
        role=@frontierlab.Current,
      ),
      @frontierlab.Highlight::new(
        target=@frontierlab.TargetRef::entity("right", "same"),
        role=@frontierlab.Candidate,
      ),
    ],
  )
  let builder = @frontierlab.TraceBuilder::new(
    title="Scoped",
    algorithm="scoped",
    initial_scene=scene,
  )
  builder.record(
    event=@frontierlab.Compare([
      @frontierlab.TargetRef::entity("left", "same"),
      @frontierlab.TargetRef::entity("right", "same"),
    ]),
    scene~,
  )
  assert_true(
    @frontierlab.AlgorithmTrace::decode_json(builder.finish().encode_json()) ==
    builder.finish(),
  )
}

///|
test "builder rejects dangling events completion reuse and limits" {
  let scene = sequence_scene(["1"])
  let builder = @frontierlab.TraceBuilder::new(
    title="Validation",
    algorithm="validation",
    initial_scene=scene,
  )
  try
    builder.record(
      event=@frontierlab.Visit(
        @frontierlab.TargetRef::entity("sequence", "missing"),
      ),
      scene~,
    )
  catch {
    @frontierlab.DanglingReference(_) => ()
    _ => fail("expected dangling reference")
  } noraise {
    _ => fail("expected dangling event failure")
  }
  builder.record(event=@frontierlab.Complete, scene~)
  try builder.record(event=@frontierlab.Complete, scene~) catch {
    @frontierlab.AlreadyCompleted => ()
    _ => fail("expected AlreadyCompleted")
  } noraise {
    _ => fail("expected completion reuse failure")
  }
  let limited = @frontierlab.TraceBuilder::new(
    title="Limited",
    algorithm="limited",
    initial_scene=scene,
    options=@frontierlab.TraceOptions::new(max_steps=1),
  )
  limited.record(event=@frontierlab.Initialize, scene~)
  try limited.record(event=@frontierlab.Complete, scene~) catch {
    @frontierlab.LimitExceeded(_) => ()
    _ => fail("expected LimitExceeded")
  } noraise {
    _ => fail("expected step limit failure")
  }
}

///|
test "trace validation rejects duplicate summary keys and step gaps" {
  let scene = sequence_scene(["1"])
  let builder = @frontierlab.TraceBuilder::new(
    title="Summary",
    algorithm="summary",
    initial_scene=scene,
  )
  try
    builder.finish(summary=[
      @frontierlab.TraceAttribute::new(key="same", value="1"),
      @frontierlab.TraceAttribute::new(key="same", value="2"),
    ])
  catch {
    @frontierlab.DuplicateSummaryKey("same") => ()
    _ => fail("expected duplicate summary error")
  } noraise {
    _ => fail("expected duplicate summary failure")
  }
  builder.record(event=@frontierlab.Initialize, scene~)
  let invalid = builder
    .finish()
    .encode_json()
    .replace(old="\"index\": 0", new="\"index\": 3")
  try @frontierlab.AlgorithmTrace::decode_json(invalid) catch {
    @frontierlab.InvalidStep(_) => ()
    _ => fail("expected InvalidStep")
  } noraise {
    _ => fail("expected non-contiguous step failure")
  }
}

///|
test "cyclic graphs with self loops and parallel edges round trip" {
  let graph = @frontierlab.GraphState::new(
    id="cyclic",
    label="Cyclic graph",
    nodes=[
      @frontierlab.GraphNode::new(id="a", label="A"),
      @frontierlab.GraphNode::new(id="b", label="B"),
    ],
    edges=[
      @frontierlab.GraphEdge::new(
        id="ab1",
        from="a",
        to="b",
        label="one",
        directed=true,
      ),
      @frontierlab.GraphEdge::new(
        id="ab2",
        from="a",
        to="b",
        label="two",
        directed=true,
      ),
      @frontierlab.GraphEdge::new(id="ba", from="b", to="a", directed=true),
      @frontierlab.GraphEdge::new(
        id="aa",
        from="a",
        to="a",
        label="loop",
        directed=true,
      ),
    ],
  )
  let scene = @frontierlab.Scene::new(objects=[@frontierlab.Graph(graph)])
  let trace = @frontierlab.TraceBuilder::new(
    title="Cycle",
    algorithm="cycle",
    initial_scene=scene,
  ).finish()
  trace.validate()
  assert_true(
    @frontierlab.AlgorithmTrace::decode_json(trace.encode_json()) == trace,
  )
}

///|
test "schema v1 covers initialize visit custom attributes and object targets" {
  let scene = sequence_scene(["1"], highlights=[
    @frontierlab.Highlight::new(
      target=@frontierlab.TargetRef::object("sequence"),
      role=@frontierlab.Error,
    ),
  ])
  let builder = @frontierlab.TraceBuilder::new(
    title="All events 中文",
    algorithm="events",
    initial_scene=scene,
  )
  builder.record(event=@frontierlab.Initialize, scene~)
  builder.record(
    event=@frontierlab.Visit(
      @frontierlab.TargetRef::entity("sequence", "item-0"),
    ),
    scene~,
    annotation=@frontierlab.Annotation::new(title="Visit", body="Body"),
  )
  builder.record(
    event=@frontierlab.Custom("domain", [
      @frontierlab.TraceAttribute::new(key="k", value="v"),
    ]),
    scene~,
  )
  builder.record(event=@frontierlab.Complete, scene~)
  let trace = builder.finish()
  assert_true(
    @frontierlab.AlgorithmTrace::decode_json(trace.encode_json()) == trace,
  )
}

///|
test "schema v1 reports malformed JSON fields and roles" {
  for
    json in [
      "not-json",
      "{}",
      (
        #|{"format":"wrong","schema_version":"1.0"},
      ),
    ] {
    try @frontierlab.AlgorithmTrace::decode_json(json) catch {
      @frontierlab.JsonSyntax(_) => ()
      _ => fail("expected JsonSyntax")
    } noraise {
      _ => fail("expected malformed JSON failure")
    }
  }
  let bad_role = @classics.insertion_sort_trace([1])
    .encode_json()
    .replace(
      old="\"highlights\": []",
      new=(
        #|"highlights": [{"target":{"object_id":"values","entity_id":"item-0"},"role":"unknown"}]
      ),
    )
  try @frontierlab.AlgorithmTrace::decode_json(bad_role) catch {
    @frontierlab.JsonSyntax(_) => ()
    _ => fail("expected bad role JsonSyntax")
  } noraise {
    _ => fail("expected bad role failure")
  }
}

///|
test "trace analysis summarizes empty and custom multi-object traces" {
  let left = @frontierlab.Sequence(
    @frontierlab.SequenceState::new(id="left", label="Left", items=[
      @frontierlab.SequenceItem::new(id="same", value="1"),
    ]),
  )
  let right = @frontierlab.Sequence(
    @frontierlab.SequenceState::new(id="right", label="Right", items=[
      @frontierlab.SequenceItem::new(id="same", value="2"),
    ]),
  )
  let scene = @frontierlab.Scene::new(objects=[left, right], highlights=[
    @frontierlab.Highlight::new(
      target=@frontierlab.TargetRef::entity("left", "same"),
      role=@frontierlab.Current,
    ),
  ])
  let empty = @frontierlab.TraceBuilder::new(
    title="Empty analysis",
    algorithm="empty",
    initial_scene=scene,
  ).finish()
  let empty_stats = empty.analyze()
  assert_eq(empty_stats.step_count, 0)
  assert_false(empty_stats.completed)
  assert_eq(empty_stats.initial_object_count, 2)
  assert_eq(empty_stats.max_entities_per_scene, 4)
  assert_true(empty.summary_report().contains("Events:\n  none"))
  let builder = @frontierlab.TraceBuilder::new(
    title="Custom analysis",
    algorithm="custom",
    initial_scene=scene,
  )
  builder.record(
    event=@frontierlab.Custom("domain-event", [
      @frontierlab.TraceAttribute::new(key="phase", value="demo"),
    ]),
    scene~,
    annotation=@frontierlab.Annotation::new(title="Domain", body="custom"),
  )
  builder.record(
    event=@frontierlab.Compare([
      @frontierlab.TargetRef::entity("left", "same"),
      @frontierlab.TargetRef::entity("right", "same"),
    ]),
    scene~,
  )
  builder.record(event=@frontierlab.Complete, scene~)
  let trace = builder.finish()
  let stats = trace.analyze()
  assert_true(stats.completed)
  assert_eq(stats.event_count("domain-event"), 1)
  assert_eq(stats.event_count("compare"), 1)
  assert_eq(stats.custom_event_count, 1)
  assert_eq(stats.annotation_count, 1)
  assert_true(stats.object_count("left") > 0)
  assert_true(stats.target_count("left", entity_id="same") > 0)
  assert_true(stats.summary_report().contains("domain-event: 1"))
}

///|
test "insertion sort adapter records reusable sorted traces" {
  let trace = @classics.insertion_sort_trace([3, 1, 2])
  let stats = trace.analyze()
  assert_true(trace.steps.last().unwrap().event is @frontierlab.Complete)
  assert_eq(stats.event_count("compare"), 3)
  assert_eq(stats.event_count("swap"), 2)
  assert_eq(stats.event_count("complete"), 1)
  assert_eq(trace.summary[0].value, "3")
  assert_eq(trace.summary[3].value, "1,2,3")
  assert_true(trace.summary_report().contains("swap: 2"))
  assert_true(
    @frontierlab.AlgorithmTrace::decode_json(trace.encode_json()) == trace,
  )
  let custom = @classics.insertion_sort_items_trace([
    @classics.SortTraceItem::new(id="x", value=2, label="two"),
    @classics.SortTraceItem::new(id="y", value=1, label="one"),
  ])
  assert_eq(custom.summary[3].value, "one,two")
  try
    @classics.insertion_sort_items_trace([
      @classics.SortTraceItem::new(id="same", value=2),
      @classics.SortTraceItem::new(id="same", value=1),
    ])
  catch {
    @frontierlab.DuplicateId(_) => ()
    _ => fail("expected duplicate sort item ids")
  } noraise {
    _ => fail("expected duplicate sort item failure")
  }
}

///|
test "union find adapter records merges compression and validation" {
  let trace = @classics.union_find_trace(4, [
    @classics.UnionOperation::new(left=0, right=1),
    @classics.UnionOperation::new(left=2, right=3),
    @classics.UnionOperation::new(left=1, right=3),
  ])
  let stats = trace.analyze()
  assert_true(trace.steps.last().unwrap().event is @frontierlab.Complete)
  assert_eq(stats.event_count("compare"), 3)
  assert_eq(stats.event_count("union"), 3)
  assert_eq(stats.event_count("update"), 1)
  assert_eq(trace.summary[3].value, "3")
  assert_eq(trace.summary[5].value, "1")
  assert_true(trace.summary_report().contains("union: 3"))
  assert_true(
    @frontierlab.AlgorithmTrace::decode_json(trace.encode_json()) == trace,
  )
  try
    @classics.union_find_trace(2, [
      @classics.UnionOperation::new(left=0, right=3),
    ])
  catch {
    @frontierlab.InvalidStep(_) => ()
    _ => fail("expected invalid union operation")
  } noraise {
    _ => fail("expected invalid union operation failure")
  }
}
