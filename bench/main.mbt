///|
fn make_scene(value : Int) -> @frontierlab.Scene raise {
  @frontierlab.Scene::new(objects=[
    @frontierlab.Sequence(
      @frontierlab.SequenceState::new(id="benchmark", label="Benchmark", items=[
        @frontierlab.SequenceItem::new(id="value", value=value.to_string()),
      ]),
    ),
  ])
}

///|
fn run_case(step_count : Int) -> Unit raise {
  let started = @env.now()
  let builder = @frontierlab.TraceBuilder::new(
    title="Benchmark",
    algorithm="benchmark",
    initial_scene=make_scene(0),
  )
  for i in 0..<(step_count - 1) {
    ignore(i)
    builder.record(event=@frontierlab.Custom("tick", []), scene=make_scene(0))
  }
  builder.record(event=@frontierlab.Complete, scene=make_scene(0))
  let trace = builder.finish()
  let built = @env.now()
  let json = trace.encode_json()
  let encoded = @env.now()
  let decoded = @frontierlab.AlgorithmTrace::decode_json(json)
  let parsed = @env.now()
  let html = @frontierlab.render_trace_html(decoded)
  let rendered = @env.now()
  let _ = decoded.diff(from_step=step_count - 2, to_step=step_count - 1)
  let diffed = @env.now()
  let _ = @frontierlab.sequence_transition_contract(object_id="benchmark").check(
    decoded,
  )
  let verified = @env.now()
  let _ = @frontierlab.first_divergence(decoded, decoded)
  let diverged = @env.now()
  println(
    "\{step_count},\{built - started},\{encoded - built},\{parsed - encoded},\{rendered - parsed},\{diffed - rendered},\{verified - diffed},\{diverged - verified},\{json.length()},\{html.length()}",
  )
}

///|
fn main raise {
  println(
    "steps,build_ms,encode_ms,decode_ms,html_ms,diff_ms,contract_ms,divergence_ms,json_bytes,html_bytes",
  )
  for count in [100, 1000, 10000] {
    run_case(count)
  }
}
