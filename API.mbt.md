# FrontierLab checked API examples

This file is executed by `moon check` and `moon test`. The human-facing guide remains in `README.md`.

```mbt check
///|
test "build encode and decode a trace" {
  let scene = @frontierlab.Scene::new(objects=[
    @frontierlab.Sequence(
      @frontierlab.SequenceState::new(id="values", label="Values", items=[
        @frontierlab.SequenceItem::new(id="a", value="2"),
        @frontierlab.SequenceItem::new(id="b", value="1"),
      ]),
    ),
  ])
  let builder = @frontierlab.TraceBuilder::new(
    title="Checked example",
    algorithm="example",
    initial_scene=scene,
  )
  builder.record(
    event=@frontierlab.Compare([
      @frontierlab.TargetRef::entity("values", "a"),
      @frontierlab.TargetRef::entity("values", "b"),
    ]),
    scene~,
  )
  let trace = builder.finish()
  let decoded = @frontierlab.AlgorithmTrace::decode_json(trace.encode_json())
  assert_true(decoded == trace)
}
```

```mbt check
///|
test "generate an offline trace playground" {
  let html = @frontierlab.render_trace_playground()
  assert_true(html.contains("AI Trace Clinic"))
  assert_true(!html.contains("<script src="))
}
```

```mbt check
///|
test "diagnose a trace through the unified facade" {
  let expected = @frontierlab.insertion_sort_trace([3, 1, 2])
  let diagnosis = @frontierlab.diagnose_trace(
    expected,
    contract=@frontierlab.sorted_int_sequence_contract(object_id="values"),
    expected~,
  )
  assert_true(diagnosis.passed())
  assert_eq(diagnosis.focus_step, -1)
  assert_true(diagnosis.transition_diff is None)
  assert_true(diagnosis.reference_diff is None)
  assert_true(diagnosis.focused_slice is None)
}
```

```mbt check
///|
test "debug and verify an algorithm trace" {
  let trace = @frontierlab.insertion_sort_trace([3, 1, 2])
  let diff = trace.diff(from_step=0, to_step=1)
  assert_true(!diff.is_empty())
  let hits = trace.breakpoint_hits(
    @frontierlab.TraceBreakpoint::new(event_kind="swap", changed_only=true),
  )
  assert_true(!hits.is_empty())
  let report = @frontierlab.insertion_sort_int_contract(object_id="values").check(
    trace,
  )
  assert_true(report.passed)
}
```
