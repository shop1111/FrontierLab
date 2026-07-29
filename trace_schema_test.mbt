///|
fn schema_roundtrip(json : String) -> @frontierlab.AlgorithmTrace raise {
  let first = @frontierlab.AlgorithmTrace::decode_json(json)
  first.validate()
  let second = @frontierlab.AlgorithmTrace::decode_json(first.encode_json())
  second.validate()
  assert_eq(second, first)
  second
}

///|
test "schema v1 minimal and empty timelines round trip semantically" {
  let minimal =
    #|{"format":"frontierlab-trace","schema_version":"1.0","metadata":{"title":"Minimal valid trace","algorithm":"fixture","description":"Smallest legal schema-v1 trace."},"initial_scene":{"objects":[],"highlights":[]},"steps":[],"summary":[]}
  let empty =
    #|{"format":"frontierlab-trace","schema_version":"1.0","metadata":{"title":"Empty timeline","algorithm":"fixture","description":"A legal trace with initial state and no events."},"initial_scene":{"objects":[{"type":"sequence","id":"values","label":"Values","items":[]}],"highlights":[]},"steps":[],"summary":[{"key":"purpose","value":"empty-timeline"}]}
  assert_eq(schema_roundtrip(minimal).steps.length(), 0)
  assert_eq(schema_roundtrip(empty).initial_scene.objects.length(), 1)
}

///|
test "schema v1 preserves unknown events and rejects dangling references" {
  let unknown =
    #|{"format":"frontierlab-trace","schema_version":"1.0","metadata":{"title":"Unknown event compatibility","algorithm":"fixture","description":"Unknown schema-v1 event kinds decode as Custom."},"initial_scene":{"objects":[],"highlights":[]},"steps":[{"index":0,"event":{"type":"agent-observation","attributes":[{"key":"model","value":"demo"}]},"scene":{"objects":[],"highlights":[]}}],"summary":[]}
  let trace = schema_roundtrip(unknown)
  assert_true(
    trace.steps[0].event is @frontierlab.Custom("agent-observation", _),
  )
  let invalid =
    #|{"format":"frontierlab-trace","schema_version":"1.0","metadata":{"title":"Invalid object reference","algorithm":"fixture","description":"Compare points to a missing entity."},"initial_scene":{"objects":[{"type":"sequence","id":"values","label":"Values","items":[{"id":"item-0","value":"1"}]}],"highlights":[]},"steps":[{"index":0,"event":{"type":"compare","targets":[{"object_id":"values","entity_id":"missing"}]},"scene":{"objects":[{"type":"sequence","id":"values","label":"Values","items":[{"id":"item-0","value":"1"}]}],"highlights":[]}}],"summary":[]}
  try @frontierlab.AlgorithmTrace::decode_json(invalid).validate() catch {
    @frontierlab.DanglingReference(_) => ()
    _ => fail("expected dangling reference")
  } noraise {
    _ => fail("invalid object reference must fail")
  }
}
