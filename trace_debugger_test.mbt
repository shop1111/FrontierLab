///|
fn sequence_scene_for_debugger(
  values : Array[@frontierlab.SequenceItem],
  highlights? : Array[@frontierlab.Highlight] = [],
) -> @frontierlab.Scene raise {
  @frontierlab.Scene::new(
    objects=[
      @frontierlab.Sequence(
        @frontierlab.SequenceState::new(
          id="values",
          label="Values",
          items=values,
        ),
      ),
    ],
    highlights~,
  )
}

///|
test "time travel diff breakpoints and counterexample preserve stable ids" {
  let trace = @frontierlab.insertion_sort_trace([3, 1, 2])
  let first = trace.diff(from_step=-1, to_step=0)
  assert_true(
    first.changes.any(fn(change) { change.kind is @frontierlab.HighlightAdded }),
  )
  let swap = trace.diff(from_step=0, to_step=1)
  assert_true(
    swap.changes.any(fn(change) {
      change.kind is @frontierlab.Moved &&
      change.target.entity_id == Some("item-0")
    }),
  )
  let hits = trace.breakpoint_hits(
    @frontierlab.TraceBreakpoint::new(
      event_kind="swap",
      target=@frontierlab.TargetRef::entity("values", "item-0"),
      changed_only=true,
    ),
  )
  assert_true(!hits.is_empty())
  assert_eq(hits[0].step, 1)
  let counterexample = trace.slice(center=hits[0].step, before=1, after=1)
  assert_eq(counterexample.original_start, 0)
  assert_eq(counterexample.focus_step, 1)
  assert_eq(counterexample.trace.steps.length(), 3)
  assert_true(counterexample.to_json_string().contains("original_focus"))
}

///|
test "scene diff covers set graph grid and identical scenes" {
  let before = @frontierlab.Scene::new(objects=[
    @frontierlab.Sets(
      @frontierlab.SetState::new(id="sets", label="Sets", groups=[
        @frontierlab.SetGroup::new(id="g", label="G", members=["a"]),
      ]),
    ),
    @frontierlab.Graph(
      @frontierlab.GraphState::new(
        id="graph",
        label="Graph",
        nodes=[@frontierlab.GraphNode::new(id="a", label="A")],
        edges=[],
      ),
    ),
    @frontierlab.Grid(
      @frontierlab.GridState::new(id="grid", label="Grid", width=1, height=1, cells=[
        @frontierlab.GridCellState::new(id="c", x=0, y=0),
      ]),
    ),
  ])
  let after = @frontierlab.Scene::new(objects=[
    @frontierlab.Sets(
      @frontierlab.SetState::new(id="sets", label="Sets", groups=[
        @frontierlab.SetGroup::new(id="g", label="G", members=["a", "b"]),
      ]),
    ),
    @frontierlab.Graph(
      @frontierlab.GraphState::new(
        id="graph",
        label="Graph",
        nodes=[
          @frontierlab.GraphNode::new(id="a", label="A"),
          @frontierlab.GraphNode::new(id="b", label="B"),
        ],
        edges=[@frontierlab.GraphEdge::new(id="ab", from="a", to="b")],
      ),
    ),
    @frontierlab.Grid(
      @frontierlab.GridState::new(id="grid", label="Grid", width=1, height=1, cells=[
        @frontierlab.GridCellState::new(id="c", x=0, y=0, blocked=true),
      ]),
    ),
  ])
  let builder = @frontierlab.TraceBuilder::new(
    title="Diff all scenes",
    algorithm="diff-test",
    initial_scene=before,
  )
  builder.record(event=@frontierlab.Custom("change", []), scene=after)
  let trace = builder.finish()
  let diff = trace.diff(from_step=-1, to_step=0)
  assert_true(diff.changes.length() >= 4)
  assert_true(!diff.is_empty())
  assert_true(trace.diff(from_step=0, to_step=0).is_empty())
  try trace.diff(from_step=-2, to_step=0) catch {
    @frontierlab.InvalidStep(_) => ()
    _ => fail("expected invalid frame")
  } noraise {
    _ => fail("expected invalid frame")
  }
}

///|
test "contracts locate first semantic failure and valid builtins pass" {
  let valid = @frontierlab.insertion_sort_trace([3, 1, 2])
  let valid_report = @frontierlab.insertion_sort_int_contract(
    object_id="values",
  ).check(valid)
  assert_true(valid_report.passed)
  let generic_report = @frontierlab.sorted_int_sequence_contract(
    object_id="values",
  ).check(valid)
  assert_true(generic_report.passed)
  assert_eq(generic_report.contract_name, "sorted-int-sequence")
  assert_true(
    valid_report.to_json_string().contains("frontierlab-debug-report/1.0"),
  )
  let initial = sequence_scene_for_debugger([
    @frontierlab.SequenceItem::new(id="a", value="2"),
    @frontierlab.SequenceItem::new(id="b", value="1"),
  ])
  let changed = sequence_scene_for_debugger([
    @frontierlab.SequenceItem::new(id="b", value="1"),
    @frontierlab.SequenceItem::new(id="a", value="2"),
  ])
  let builder = @frontierlab.TraceBuilder::new(
    title="Faulty compare",
    algorithm="faulty-sort",
    initial_scene=initial,
  )
  builder.record(
    event=@frontierlab.Compare([
      @frontierlab.TargetRef::entity("values", "a"),
      @frontierlab.TargetRef::entity("values", "b"),
    ]),
    scene=changed,
  )
  let faulty = builder.finish()
  let report = @frontierlab.sequence_transition_contract(object_id="values").check(
    faulty,
  )
  assert_false(report.passed)
  assert_eq(report.first_failure.unwrap().code, "compare-mutated-order")
  assert_eq(report.first_failure.unwrap().step, 0)
  assert_true(report.counterexample is Some(_))
  assert_true(report.to_markdown().contains("compare-mutated-order"))
}

///|
test "unified diagnosis separates transition and reference evidence" {
  let expected = @frontierlab.insertion_sort_demo_trace([5, 2, 4, 1, 3])
  let actual = @frontierlab.faulty_insertion_sort_demo_trace()
  let diagnosis = @frontierlab.diagnose_trace(
    actual,
    contract=@frontierlab.sorted_int_sequence_contract(object_id="values"),
    expected~,
  )
  assert_false(diagnosis.passed())
  assert_true(diagnosis.divergence is Some(_))
  assert_true(diagnosis.transition_diff is Some(_))
  assert_true(diagnosis.reference_diff is Some(_))
  assert_true(diagnosis.focused_slice is Some(_))
  let focus = diagnosis.focus_step
  let slice = diagnosis.focused_slice.unwrap()
  assert_eq(focus, 0)
  assert_eq(slice.original_start, 0)
  assert_eq(slice.original_end, 0)
  let no_reference = @frontierlab.diagnose_trace(
    actual,
    contract=@frontierlab.sorted_int_sequence_contract(object_id="values"),
  )
  assert_true(no_reference.divergence is None)
  assert_true(no_reference.reference_diff is None)
  assert_false(no_reference.passed())
}

///|
test "grid path contract and first divergence cover success and failure" {
  let path = @frontierlab.pathfinding_demo_trace()
  let path_report = @frontierlab.grid_path_contract(object_id="search-grid").check(
    path,
  )
  assert_true(path_report.passed)
  assert_true(@frontierlab.first_divergence(path, path) is None)
  let sort = @frontierlab.insertion_sort_trace([2, 1])
  let other = @frontierlab.insertion_sort_trace([3, 1])
  let divergence = @frontierlab.first_divergence(sort, other)
  assert_true(divergence is Some(_))
  assert_eq(divergence.unwrap().step, 0)
  assert_true(divergence.unwrap().kind is @frontierlab.SceneMismatch)
  let short_builder = @frontierlab.TraceBuilder::new(
    title="Short reference",
    algorithm=sort.algorithm,
    initial_scene=sort.initial_scene,
  )
  short_builder.record(
    event=sort.steps[0].event,
    scene=sort.steps[0].scene,
    annotation=sort.steps[0].annotation.unwrap(),
  )
  let short = short_builder.finish()
  let length_divergence = @frontierlab.first_divergence(sort, short)
  assert_true(length_divergence is Some(_))
  assert_true(length_divergence.unwrap().kind is @frontierlab.ActualEnded)
}

///|
test "grid path contract reports blocked and discontinuous result cells" {
  let scene = @frontierlab.Scene::new(
    objects=[
      @frontierlab.Grid(
        @frontierlab.GridState::new(
          id="grid",
          label="Faulty path",
          width=3,
          height=1,
          cells=[
            @frontierlab.GridCellState::new(id="s", x=0, y=0, label="S"),
            @frontierlab.GridCellState::new(
              id="blocked",
              x=1,
              y=0,
              blocked=true,
            ),
            @frontierlab.GridCellState::new(id="e", x=2, y=0, label="E"),
          ],
        ),
      ),
    ],
    highlights=[
      @frontierlab.Highlight::new(
        target=@frontierlab.TargetRef::entity("grid", "s"),
        role=@frontierlab.Result,
      ),
      @frontierlab.Highlight::new(
        target=@frontierlab.TargetRef::entity("grid", "blocked"),
        role=@frontierlab.Result,
      ),
      @frontierlab.Highlight::new(
        target=@frontierlab.TargetRef::entity("grid", "e"),
        role=@frontierlab.Result,
      ),
    ],
  )
  let builder = @frontierlab.TraceBuilder::new(
    title="Faulty grid path",
    algorithm="path",
    initial_scene=scene,
  )
  builder.record(event=@frontierlab.Complete, scene~)
  let report = @frontierlab.grid_path_contract(object_id="grid").check(
    builder.finish(),
  )
  assert_false(report.passed)
  assert_eq(report.first_failure.unwrap().code, "path-crosses-blocked-cell")
}
