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
