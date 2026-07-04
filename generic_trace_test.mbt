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
    event=@frontierlab.Compare(["item-0", "item-1"]),
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
        @frontierlab.Highlight::new(target="missing", role=@frontierlab.Error),
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
      @frontierlab.Highlight::new(target="v", role=@frontierlab.Compared),
      @frontierlab.Highlight::new(target="a", role=@frontierlab.Current),
      @frontierlab.Highlight::new(target="c0", role=@frontierlab.Result),
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
    @frontierlab.Highlight::new(target="item-\{index}", role~)
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
  assert_true(sort.to_json_string().contains("Swap"))
  assert_true(union.to_json_string().contains("Union"))
  assert_true(path.to_json_string().contains("Relax"))
}
