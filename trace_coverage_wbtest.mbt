///|
fn coverage_sequence(
  entries : Array[(String, String)],
  id? : String = "values",
) -> Scene raise {
  Scene::new(objects=[
    Sequence(
      SequenceState::new(
        id~,
        label="Coverage sequence",
        items=entries.map(fn(entry) {
          let (item_id, value) = entry
          SequenceItem::new(id=item_id, value~)
        }),
      ),
    ),
  ])
}

///|
fn coverage_trace(
  initial_scene : Scene,
  values : Array[(TraceEvent, Scene)],
) -> AlgorithmTrace {
  {
    schema_version: "1.0",
    title: "Coverage trace",
    algorithm: "coverage",
    description: "",
    initial_scene,
    steps: values.mapi(fn(index, value) {
      let (event, scene) = value
      { index, event, scene, annotation: None }
    }),
    summary: [],
  }
}

///|
test "contracts cover missing disappearing and unstable sequences" {
  let empty : Scene = { objects: [], highlights: [] }
  let missing = sequence_transition_contract(object_id="values").check(
    coverage_trace(empty, []),
  )
  assert_eq(missing.violations[0].code, "missing-sequence")
  assert_true(missing.report().contains("at trace"))
  let before = coverage_sequence([("a", "1"), ("b", "2")])
  let disappeared = sequence_transition_contract(object_id="values").check(
    coverage_trace(before, [(Custom("gone", []), empty), (Complete, before)]),
  )
  assert_eq(disappeared.violations[0].code, "sequence-disappeared")
  let changed = coverage_sequence([("a", "9"), ("c", "3")])
  let identity = sequence_transition_contract(object_id="values").check(
    coverage_trace(before, [(Custom("mutate", []), changed)]),
  )
  assert_true(
    identity.violations.any(fn(v) { v.code == "stable-value-changed" }),
  )
  assert_true(
    identity.violations.any(fn(v) { v.code == "stable-entity-removed" }),
  )
  assert_true(
    identity.violations.any(fn(v) { v.code == "stable-entity-added" }),
  )
  let warning : ContractReport = {
    report_version: debug_report_version,
    contract_name: "warning-contract",
    passed: true,
    violations: [
      TraceViolation::new(
        contract="warning-contract",
        code="notice",
        severity=Warning,
        message="warning path",
      ),
    ],
    first_failure: None,
    counterexample: None,
  }
  assert_true(warning.report().contains("[warning]"))
}

///|
test "contracts cover malformed swaps integers and object kinds" {
  let before = coverage_sequence([("a", "1"), ("b", "2"), ("c", "3")])
  let rotated = coverage_sequence([("b", "2"), ("c", "3"), ("a", "1")])
  let bad_swap = sequence_transition_contract(object_id="values").check(
    coverage_trace(before, [
      (
        Swap(TargetRef::entity("values", "a"), TargetRef::entity("values", "b")),
        rotated,
      ),
    ]),
  )
  assert_eq(bad_swap.violations[0].code, "invalid-swap-transition")
  let ignored_swap = sequence_transition_contract(object_id="values").check(
    coverage_trace(before, [
      (Swap(TargetRef::object("values"), TargetRef::object("values")), before),
      (
        Swap(
          TargetRef::entity("values", "missing"),
          TargetRef::entity("values", "b"),
        ),
        before,
      ),
    ]),
  )
  assert_true(ignored_swap.passed)
  let bad_numbers = insertion_sort_int_contract(object_id="values").check(
    coverage_trace(coverage_sequence([("a", "x"), ("b", "y")]), []),
  )
  assert_true(
    bad_numbers.violations
    .filter(fn(v) { v.code == "non-integer-value" })
    .length() >=
    2,
  )
  let inversion = insertion_sort_int_contract(object_id="values").check(
    coverage_trace(coverage_sequence([("a", "2"), ("b", "1")]), []),
  )
  assert_eq(inversion.violations[0].code, "result-not-sorted")
  let grid = Grid(
    GridState::new(id="values", label="Wrong kind", width=1, height=1, cells=[]),
  )
  let wrong_kind : Scene = { objects: [grid], highlights: [] }
  assert_eq(
    insertion_sort_int_contract(object_id="values").check(
      coverage_trace(wrong_kind, []),
    ).violations[0].code,
    "missing-sequence",
  )
  assert_true(contract_sequence(wrong_kind, "values") is None)
  assert_true(contract_sequence(wrong_kind, "absent") is None)
}

///|
test "grid contract covers missing blocked discontinuous and endpoint paths" {
  let empty : Scene = { objects: [], highlights: [] }
  assert_eq(
    grid_path_contract(object_id="grid").check(coverage_trace(empty, [])).violations[0].code,
    "missing-grid",
  )
  let cells = [
    GridCellState::new(id="a", x=0, y=0, label="X", blocked=true),
    GridCellState::new(id="b", x=1, y=0, label="Y"),
    GridCellState::new(id="c", x=2, y=0, label="Z"),
  ]
  let object = Grid(
    GridState::new(id="grid", label="Grid", width=3, height=1, cells~),
  )
  let dangling : Scene = {
    objects: [object],
    highlights: [
      Highlight::new(target=TargetRef::entity("grid", "missing"), role=Result),
    ],
  }
  assert_true(
    grid_path_contract(object_id="grid").check(coverage_trace(dangling, [])).passed,
  )
  let discontinuous : Scene = {
    objects: [object],
    highlights: [
      Highlight::new(target=TargetRef::entity("grid", "a"), role=Result),
      Highlight::new(target=TargetRef::entity("grid", "c"), role=Result),
    ],
  }
  let discontinuous_report = grid_path_contract(object_id="grid").check(
    coverage_trace(discontinuous, []),
  )
  assert_true(
    discontinuous_report.violations.any(fn(v) {
      v.code == "path-crosses-blocked-cell"
    }),
  )
  assert_true(
    discontinuous_report.violations.any(fn(v) {
      v.code == "non-contiguous-path"
    }),
  )
  let endpoints : Scene = {
    objects: [object],
    highlights: [
      Highlight::new(target=TargetRef::entity("grid", "a"), role=Result),
      Highlight::new(target=TargetRef::entity("grid", "b"), role=Result),
    ],
  }
  let endpoint_report = grid_path_contract(object_id="grid").check(
    coverage_trace(endpoints, []),
  )
  assert_true(
    endpoint_report.violations.any(fn(v) { v.code == "path-start-mismatch" }),
  )
  assert_true(
    endpoint_report.violations.any(fn(v) { v.code == "path-end-mismatch" }),
  )
  let sequence = coverage_sequence([], id="grid")
  assert_true(contract_grid(sequence, "grid") is None)
  assert_true(contract_grid(sequence, "absent") is None)
}

///|
test "debugger covers edge reports events roles and structural changes" {
  let same = coverage_sequence([("a", "1")])
  let trace = coverage_trace(same, [(Initialize, same)])
  assert_true(
    trace.diff(from_step=-1, to_step=-1).report().contains("No semantic"),
  )
  for
    event in [
      Initialize,
      Update(TargetRef::entity("values", "a"), "x"),
      Union(TargetRef::object("a"), TargetRef::object("b")),
      Relax(TargetRef::object("a"), TargetRef::object("b"), "1"),
      Custom("agent-event", []),
    ] {
    ignore(debugger_event_name(event))
    ignore(debugger_event_targets(event))
  }
  for role in [Candidate, Visited, Frontier, Error] {
    ignore(debugger_role_name(role))
  }
  assert_true(
    debugger_target_matches(
      TargetRef::object("values"),
      TargetRef::entity("values", "a"),
    ),
  )
  assert_eq(debugger_target_label(TargetRef::object("values")), "values")
  assert_eq(debug_change_name(Added), "added")
  assert_eq(debug_change_name(Removed), "removed")
  assert_eq(debug_change_name(Updated), "updated")
  assert_eq(debug_change_name(HighlightAdded), "highlight-added")
  assert_eq(debug_change_name(HighlightRemoved), "highlight-removed")
  assert_eq(debugger_breakpoint_reason(TraceBreakpoint::new()), "all steps")
  assert_true(
    debugger_breakpoint_reason(TraceBreakpoint::new(role="candidate")).contains(
      "role=candidate",
    ),
  )
  assert_eq(debugger_max(1, 2), 2)
  let role_scene : Scene = {
    objects: same.objects,
    highlights: [
      Highlight::new(target=TargetRef::entity("values", "a"), role=Candidate),
    ],
  }
  let role_trace = coverage_trace(same, [
    (Visit(TargetRef::object("values")), role_scene),
  ])
  assert_eq(
    role_trace
    .breakpoint_hits(
      TraceBreakpoint::new(target=TargetRef::object("values"), role="candidate"),
    )
    .length(),
    1,
  )
  assert_eq(
    role_trace.breakpoint_hits(TraceBreakpoint::new(role="candidate")).length(),
    1,
  )
}

///|
test "debugger covers invalid slices length endings and add remove changes" {
  let one = coverage_sequence([("a", "1")])
  let trace = coverage_trace(one, [(Complete, one)])
  try trace.slice(center=2) catch {
    InvalidStep(_) => ()
    _ => fail("expected invalid slice center")
  } noraise {
    _ => fail("slice center must fail")
  }
  try trace.slice(center=0, before=-1) catch {
    InvalidStep(_) => ()
    _ => fail("expected invalid slice context")
  } noraise {
    _ => fail("negative context must fail")
  }
  let empty = coverage_trace(one, [])
  assert_true(first_divergence(empty, trace).unwrap().kind is ExpectedEnded)
  let changed_kind : Scene = {
    objects: [
      Grid(
        GridState::new(id="values", label="Grid", width=1, height=1, cells=[]),
      ),
    ],
    highlights: [],
  }
  assert_true(
    debugger_scene_diff(one, changed_kind).any(fn(c) { c.kind is Updated }),
  )
  let removed_object : Scene = { objects: [], highlights: [] }
  assert_true(
    debugger_scene_diff(one, removed_object).any(fn(c) { c.kind is Removed }),
  )
  assert_true(
    debugger_scene_diff(removed_object, one).any(fn(c) { c.kind is Added }),
  )
  let removed_entity = coverage_sequence([])
  assert_true(
    debugger_scene_diff(one, removed_entity).any(fn(c) {
      c.kind is Removed && c.target.entity_id == Some("a")
    }),
  )
}

///|
test "quality diagnostics cover empty malformed growing and clean traces" {
  let empty : Scene = { objects: [], highlights: [] }
  let malformed : AlgorithmTrace = {
    schema_version: "1.0",
    title: " ",
    algorithm: " ",
    description: "",
    initial_scene: empty,
    steps: [],
    summary: [],
  }
  let malformed_issues = malformed.lint()
  assert_true(malformed_issues.any(fn(v) { v.code == "empty-title" }))
  assert_true(malformed_issues.any(fn(v) { v.code == "empty-algorithm" }))
  assert_true(malformed_issues.any(fn(v) { v.code == "empty-initial-scene" }))
  assert_true(malformed_issues.any(fn(v) { v.code == "empty-timeline" }))
  assert_true(malformed.lint_report().contains("at trace"))
  assert_true(malformed.has_lint_warnings())
  let info = TraceLintIssue::new(severity=Info, code="info", message="message")
  let warning = TraceLintIssue::new(
    severity=Warning,
    code="warning",
    message="message",
    step=1,
  )
  assert_true(info.is_info())
  assert_true(warning.is_warning())
  assert_eq(warning.severity_name(), "warning")
  assert_true(warning.line().contains("step 1"))
  let initial = coverage_sequence([("a", "1")])
  let large = coverage_sequence([
    ("a", "1"),
    ("b", "2"),
    ("c", "3"),
    ("d", "4"),
    ("e", "5"),
    ("f", "6"),
    ("g", "7"),
    ("h", "8"),
    ("i", "9"),
  ])
  let shaped = coverage_trace(initial, [
    (Compare([]), empty),
    (Swap(TargetRef::object("values"), TargetRef::object("values")), large),
  ])
  let shaped_issues = shaped.lint()
  assert_true(shaped_issues.any(fn(v) { v.code == "missing-complete" }))
  assert_true(shaped_issues.any(fn(v) { v.code == "empty-step-scene" }))
  assert_true(shaped_issues.any(fn(v) { v.code == "event-without-target" }))
  assert_true(shaped_issues.any(fn(v) { v.code == "large-scene-growth" }))
  assert_true(shaped.lint_report().contains("missing-complete"))
  for
    event in [
      Initialize,
      Visit(TargetRef::object("a")),
      Update(TargetRef::object("a"), "value"),
      Union(TargetRef::object("a"), TargetRef::object("b")),
      Swap(TargetRef::object("a"), TargetRef::object("b")),
      Relax(TargetRef::object("a"), TargetRef::object("b"), "1"),
    ] {
    ignore(timeline_event_name(event))
    ignore(timeline_event_target_count(event))
  }
  let clean = insertion_sort_trace([2, 1])
  assert_true(clean.lint_report().contains("No trace lint issues."))
  assert_true(clean.lint_markdown().contains("| info | clean |"))
}

///|
test "empty analysis report tables are explicit" {
  let empty : Scene = { objects: [], highlights: [] }
  let stats = coverage_trace(empty, []).analyze()
  assert_true(stats.event_table().contains("| none |"))
  assert_true(stats.object_table().contains("| none |"))
  assert_true(stats.target_table().contains("| none |"))
  assert_true(stats.summary_report().contains("Objects:\n  none"))
  assert_eq(stats.event_count("missing"), 0)
  assert_eq(stats.object_count("missing"), 0)
  assert_eq(stats.target_count("missing"), 0)
  ignore(coverage_trace(empty, []).event_counts())
  ignore(coverage_trace(empty, []).target_usage())
  ignore(coverage_trace(empty, []).object_usage())
  let usage = TargetUsage::new(
    object_id="object",
    entity_id="entity",
    event_names=["visit"],
    highlight_roles=["candidate"],
  )
  assert_eq(usage.event_names, ["visit"])
  let values : Array[TargetUsage] = []
  add_target_usage(
    values,
    TargetRef::object("object"),
    -1,
    event_name="",
    highlight_role=Some("candidate"),
  )
  assert_eq(values[0].highlight_roles, ["candidate"])
  assert_eq(max_int(1, 2), 2)
}

///|
test "analysis covers graph grid events targets and highlight roles" {
  let graph = Graph(
    GraphState::new(
      id="graph",
      label="Graph",
      nodes=[
        GraphNode::new(id="n1", label="N1"),
        GraphNode::new(id="n2", label="N2"),
      ],
      edges=[
        GraphEdge::new(id="e", from="n1", to="n2", label="1", directed=true),
      ],
    ),
  )
  let grid = Grid(
    GridState::new(id="grid", label="Grid", width=1, height=1, cells=[
      GridCellState::new(id="c", x=0, y=0, label="S"),
    ]),
  )
  let scene : Scene = {
    objects: [graph, grid],
    highlights: [
      Highlight::new(target=TargetRef::entity("graph", "n1"), role=Candidate),
      Highlight::new(target=TargetRef::entity("graph", "n2"), role=Visited),
      Highlight::new(target=TargetRef::entity("grid", "c"), role=Error),
    ],
  }
  let trace = coverage_trace(scene, [
    (Initialize, scene),
    (Visit(TargetRef::entity("graph", "n1")), scene),
    (
      Relax(
        TargetRef::entity("graph", "n1"),
        TargetRef::entity("graph", "n2"),
        "1",
      ),
      scene,
    ),
    (Complete, scene),
  ])
  let stats = trace.analyze()
  assert_eq(stats.event_count("initialize"), 1)
  assert_eq(stats.event_count("visit"), 1)
  assert_eq(stats.event_count("relax"), 1)
  assert_true(stats.object_count("graph") > 0)
  assert_true(stats.target_count("grid", entity_id="c") > 0)
  assert_true(scene_object_kind(graph) == "graph")
  assert_eq(scene_object_entity_count(graph), 3)
  for role in [Candidate, Visited, Frontier, Error] {
    ignore(highlight_role_name(role))
  }
}

///|
test "adapter and model defensive branches remain explicit" {
  try union_find_trace(0, []) catch {
    LimitExceeded(_) => ()
    _ => fail("expected union-find size failure")
  } noraise {
    _ => fail("zero-sized union-find must fail")
  }
  try insertion_sort_items_trace([SortTraceItem::new(id="", value=1)]) catch {
    DuplicateId(_) => ()
    _ => fail("expected empty stable id failure")
  } noraise {
    _ => fail("empty stable id must fail")
  }
  let parent = [0, 1]
  let rank = [0, 1]
  assert_eq(union_find_attach(parent, rank, 0, 1), (1, 0))
  assert_eq(parent[0], 1)
  assert_true(
    TraceError::message(InvalidGraph("bad")).contains("Invalid graph"),
  )
  assert_true(
    TraceError::message(JsonSyntax("bad")).contains("Invalid trace JSON"),
  )
  assert_true(TraceError::message(InvalidGrid("bad")).contains("Invalid grid"))
  assert_true(
    TraceError::message(UnsupportedSchema("2.0")).contains("Unsupported"),
  )
  assert_true(
    TraceError::message(InvalidStep("bad")).contains("Invalid trace step"),
  )
  assert_eq(TraceError::message(DuplicateId("duplicate")), "duplicate")
  assert_true(
    TraceError::message(DuplicateSummaryKey("key")).contains(
      "Duplicate summary",
    ),
  )
  assert_true(
    TraceError::message(DanglingReference(TargetRef::object("missing"))).contains(
      "Dangling object",
    ),
  )
  assert_true(
    TraceError::message(
      DanglingReference(TargetRef::entity("object", "entity")),
    ).contains("object/entity"),
  )
  assert_true("\{InvalidGraph("bad")}".contains("Invalid graph"))
  try TraceOptions::new(max_steps=0) catch {
    LimitExceeded(_) => ()
    _ => fail("expected invalid trace limit")
  } noraise {
    _ => fail("invalid trace limit must fail")
  }
}

///|
test "grid weights and SVG renderer cover replacement and visual variants" {
  let grid_map = GridMap::new(width=2, height=1)
  let weighted = grid_map
    .with_weight(Position::new(x=0, y=0), 2)
    .with_weight(Position::new(x=0, y=0), 3)
  assert_eq(weighted.weight_at(Position::new(x=0, y=0)), 3)
  try grid_map.with_weight(Position::new(x=2, y=0), 1) catch {
    _ => ()
  } noraise {
    _ => fail("out-of-range weighted cells must fail")
  }
  let graph = Graph(
    GraphState::new(
      id="graph",
      label="Undirected graph",
      nodes=[
        GraphNode::new(id="a", label="A"),
        GraphNode::new(id="b", label="B"),
      ],
      edges=[
        GraphEdge::new(
          id="edge",
          from="a",
          to="b",
          label="edge",
          directed=false,
        ),
      ],
    ),
  )
  let grid = Grid(
    GridState::new(id="grid", label="Blocked grid", width=1, height=1, cells=[
      GridCellState::new(id="wall", x=0, y=0, label="#", blocked=true),
    ]),
  )
  let scene = Scene::new(objects=[graph, grid])
  let svg = render_trace_svg(coverage_trace(scene, [(Complete, scene)]), step=0)
  assert_true(svg.contains("Undirected graph"))
  assert_true(svg.contains("#f8fafc"))
}

///|
test "model validation covers limits references schema and completion order" {
  let graph = Graph(
    GraphState::new(
      id="graph",
      label="Graph",
      nodes=[GraphNode::new(id="n", label="N")],
      edges=[GraphEdge::new(id="edge", from="n", to="n", directed=false)],
    ),
  )
  let scene = Scene::new(objects=[graph])
  assert_true(!scene.contains_target(TargetRef::object("missing")))
  assert_true(scene.contains_target(TargetRef::entity("graph", "edge")))
  try scene.validate(TraceOptions::new(max_entities_per_scene=1)) catch {
    LimitExceeded(_) => ()
    _ => fail("expected scene entity limit")
  } noraise {
    _ => fail("scene entity limit must fail")
  }
  try ensure_unique_strings(["duplicate", "duplicate"], "fixture") catch {
    DuplicateId(_) => ()
    _ => fail("expected duplicate strings")
  } noraise {
    _ => fail("duplicate strings must fail")
  }
  let base = coverage_trace(scene, [])
  let unsupported : AlgorithmTrace = { ..base, schema_version: "2.0" }
  try unsupported.validate() catch {
    UnsupportedSchema(_) => ()
    _ => fail("expected unsupported schema")
  } noraise {
    _ => fail("unsupported schema must fail")
  }
  let many = coverage_trace(scene, [
    (Custom("one", []), scene),
    (Complete, scene),
  ])
  try many.validate(options=TraceOptions::new(max_steps=1)) catch {
    LimitExceeded(_) => ()
    _ => fail("expected trace step limit")
  } noraise {
    _ => fail("trace step limit must fail")
  }
  let after_complete = coverage_trace(scene, [
    (Complete, scene),
    (Custom("after", []), scene),
  ])
  try after_complete.validate() catch {
    InvalidStep(_) => ()
    _ => fail("expected Complete finality failure")
  } noraise {
    _ => fail("events after Complete must fail")
  }
}

///|
test "codec primitive guards and unknown wire kinds are explicit" {
  let actions : Array[() -> Unit raise TraceError] = [
    fn() raise TraceError { ignore(expect_object(Json::string("x"), "object")) },
    fn() raise TraceError { ignore(expect_array(Json::string("x"), "array")) },
    fn() raise TraceError {
      ignore(expect_string(Json::number(1.0, repr="1"), "string"))
    },
    fn() raise TraceError { ignore(expect_int(Json::string("x"), "integer")) },
    fn() raise TraceError { ignore(expect_bool(Json::string("x"), "boolean")) },
  ]
  for action in actions {
    try action() catch {
      JsonSyntax(_) => ()
      _ => fail("expected JSON shape error")
    } noraise {
      _ => fail("JSON shape guard must fail")
    }
  }
  let unknown_object =
    #|{"type":"mystery","id":"x","label":"X"}
  try decode_scene_object(@json.parse(unknown_object), "object") catch {
    JsonSyntax(_) => ()
    _ => fail("expected unknown scene object")
  } noraise {
    _ => fail("unknown scene object must fail")
  }
  let wrong_format =
    #|{"format":"other","schema_version":"1.0","metadata":{"title":"x","algorithm":"x","description":""},"initial_scene":{"objects":[],"highlights":[]},"steps":[],"summary":[]}
  try AlgorithmTrace::decode_json(wrong_format) catch {
    JsonSyntax(_) => ()
    _ => fail("expected unknown trace format")
  } noraise {
    _ => fail("unknown trace format must fail")
  }
}
