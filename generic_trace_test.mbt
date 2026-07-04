///|
fn sequence_scene(
  values : Array[String],
  highlights? : Array[@frontierlab.Highlight] = [],
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
test "SVG renderer covers sequence sets graph and grid" {
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
  let svg = @frontierlab.render_trace_svg(trace, step=0)
  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("Graph &lt;safe&gt;"))
  assert_true(svg.contains("#c084fc"))
  assert_eq(@frontierlab.render_trace_svg_frames(trace).length(), 1)
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
  assert_true(html.contains("id=\"timeline\""))
  assert_true(html.contains("prefers-reduced-motion"))
  assert_true(html.contains("\\u003c/script>"))
  assert_false(html.contains("https://"))
}

///|
test "search adapter preserves final search result metadata" {
  let grid = @frontierlab.GridMap::new(width=3, height=1)
  let start = @frontierlab.Position::new(x=0, y=0)
  let goal = @frontierlab.Position::new(x=2, y=0)
  let search = @frontierlab.bfs_trace(grid, start~, goal~)
  let trace = @frontierlab.search_trace_to_algorithm_trace(
    grid,
    start~,
    goal~,
    algorithm="BFS",
    trace=search,
  )
  assert_eq(trace.steps.length(), search.steps.length() + 1)
  assert_true(trace.steps.last().unwrap().event is @frontierlab.Complete)
  assert_eq(trace.summary[1].value, search.result.cost.to_string())
}

///|
test "empty traces render their initial scene and reject invalid steps" {
  let scene = sequence_scene(["1"])
  let trace = @frontierlab.TraceBuilder::new(
    title="Empty",
    algorithm="empty",
    initial_scene=scene,
  ).finish()
  assert_eq(@frontierlab.render_trace_svg_frames(trace).length(), 1)
  assert_true(@frontierlab.render_trace_svg(trace).contains("Empty"))
  let builder = @frontierlab.TraceBuilder::new(
    title="One",
    algorithm="one",
    initial_scene=scene,
  )
  builder.record(event=@frontierlab.Complete, scene~)
  let one = builder.finish()
  try @frontierlab.render_trace_svg(one, step=1) catch {
    _ => ()
  } noraise {
    _ => fail("expected out-of-range frame to fail")
  }
}

///|
test "all highlight roles have deterministic SVG colors" {
  let roles = [
    @frontierlab.Current,
    @frontierlab.Candidate,
    @frontierlab.Compared,
    @frontierlab.Changed,
    @frontierlab.Visited,
    @frontierlab.Frontier,
    @frontierlab.Result,
    @frontierlab.Error,
  ]
  let values = roles.mapi(fn(index, _) { index.to_string() })
  let highlights = roles.mapi(fn(index, role) {
    @frontierlab.Highlight::new(
      target=@frontierlab.TargetRef::entity("sequence", "item-\{index}"),
      role~,
    )
  })
  let scene = sequence_scene(values, highlights~)
  let trace = @frontierlab.TraceBuilder::new(
    title="Roles \" ' & < >",
    algorithm="roles",
    initial_scene=scene,
  ).finish()
  let svg = @frontierlab.render_trace_svg(trace)
  for
    color in [
      "#f59e0b", "#38bdf8", "#c084fc", "#fb7185", "#93c5fd", "#22d3ee", "#4ade80",
      "#ef4444",
    ] {
    assert_true(svg.contains(color))
  }
  assert_true(svg.contains("&quot;"))
  assert_true(svg.contains("&#39;"))
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
test "bundled demo factories produce complete portable traces" {
  let sort = @frontierlab.insertion_sort_demo_trace([3, 1, 2])
  let union = @frontierlab.union_find_demo_trace()
  let path = @frontierlab.pathfinding_demo_trace()
  assert_true(sort.steps.last().unwrap().event is @frontierlab.Complete)
  assert_true(union.steps.last().unwrap().event is @frontierlab.Complete)
  assert_true(path.steps.last().unwrap().event is @frontierlab.Complete)
  assert_true(sort.to_json_string().contains("\"type\": \"swap\""))
  assert_true(union.to_json_string().contains("\"type\": \"union\""))
  assert_true(path.to_json_string().contains("\"type\": \"relax\""))
  assert_true(
    @frontierlab.AlgorithmTrace::decode_json(sort.encode_json()) == sort,
  )
  assert_true(
    @frontierlab.AlgorithmTrace::decode_json(union.encode_json()) == union,
  )
  assert_true(
    @frontierlab.AlgorithmTrace::decode_json(path.encode_json()) == path,
  )
}

///|
test "schema v1 ignores unknown fields and preserves unknown events" {
  let trace = @frontierlab.insertion_sort_demo_trace([2, 1])
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
  let json = @frontierlab.insertion_sort_demo_trace([1])
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
test "cyclic graph layout renders self loops parallel edges and arrows" {
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
  let svg = @frontierlab.render_trace_svg(trace)
  assert_true(svg.contains("frontierlab-arrow"))
  assert_true(svg.contains("marker-end"))
  assert_true(svg.contains(">loop<"))
  assert_true(svg.contains("<path d="))
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
  let bad_role = @frontierlab.insertion_sort_demo_trace([1])
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
