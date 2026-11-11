///|
/// The inverse of `json_delta`, written like the player's `applyDelta`.
fn apply_json_delta(before : Json, delta : Json) -> Json {
  guard delta is Array(parts) && parts[0] is String(kind) else {
    abort("malformed delta")
  }
  match kind {
    "s" => before
    "v" => parts[1]
    "o" => {
      guard before is Object(old) &&
        parts[1] is Object(changed) &&
        parts[2] is Array(removed) else {
        abort("malformed object delta")
      }
      let out : Map[String, Json] = Map([])
      for key, value in old {
        if !removed.contains(Json::string(key)) {
          out[key] = value
        }
      }
      for key, change in changed {
        out[key] = apply_json_delta(
          old.get(key).unwrap_or(Json::null()),
          change,
        )
      }
      Json::object(out)
    }
    "a" => {
      guard before is Array(old) &&
        parts[1] is Number(prefix, ..) &&
        parts[2] is Number(suffix, ..) &&
        parts[3] is Array(middle) else {
        abort("malformed array delta")
      }
      let prefix = prefix.to_int()
      let suffix = suffix.to_int()
      let old_middle = old[prefix:old.length() - suffix]
      let aligned = old_middle.length() == middle.length()
      let out = old[0:prefix].to_owned()
      for i, change in middle {
        out.push(
          apply_json_delta(
            if aligned {
              old_middle[i]
            } else {
              Json::null()
            },
            change,
          ),
        )
      }
      out.append(old[old.length() - suffix:].to_owned())
      Json::array(out)
    }
    _ => abort("unknown delta kind")
  }
}

///|
test "json deltas restore the next value" {
  let cases : Array[(Json, Json)] = [
    ({ "a": 1 }, { "a": 1 }),
    ({ "a": 1, "b": [1, 2] }, { "a": 2, "c": true }),
    ([1, 2, 3, 4], [1, 2, 9, 3, 4]),
    ([1, 2, 3, 4], [1, 4]),
    ([1, 1], [1, 1, 1]),
    ([1, 1, 1], [1, 1]),
    ([], [1]),
    ([1], []),
    (
      [{ "id": "a", "v": 1 }, { "id": "b" }],
      [{ "id": "a", "v": 2 }, { "id": "b" }],
    ),
    ("text", [1]),
    ({ "x": [[1, 2], [3]] }, { "x": [[1, 2], [3, 4]] }),
  ]
  for pair in cases {
    let (before, after) = pair
    assert_eq(apply_json_delta(before, json_delta(before, after)), after)
  }
  // Unchanged values cost one marker, and a middle insertion only the new
  // element.
  assert_eq(json_delta([1, 2], [1, 2]), ["s"])
  assert_eq(json_delta([1, 2, 3], [1, 9, 2, 3]), ["a", 1, 2, [["v", 9]]])
}

///|
test "the packed player data unpacks to the schema wire format" {
  let scene = fn(values : Array[String]) raise {
    Scene::new(objects=[
      Sequence(
        SequenceState::new(
          id="values",
          label="Values",
          items=values.mapi(fn(i, value) {
            SequenceItem::new(id="item-\{i}", value~)
          }),
        ),
      ),
    ])
  }
  let builder = TraceBuilder::new(
    title="Packed",
    algorithm="packed",
    initial_scene=scene(["3", "1", "2"]),
  )
  builder.record(event=Custom("noop", []), scene=scene(["3", "1", "2"]))
  builder.record(event=Custom("set", []), scene=scene(["1", "1", "2"]))
  builder.record(event=Complete, scene=scene(["1", "2", "3", "4"]))
  let trace = builder.finish()
  let full = @json.parse(trace.encode_json())
  let packed = @json.parse(trace.encode_packed_json())
  guard packed is Object(fields) &&
    fields.get("packing") is Some(String("scene-delta-v1")) &&
    fields.get("initial_scene") is Some(initial) &&
    fields.get("steps") is Some(Array(steps)) &&
    full is Object(full_fields) &&
    full_fields.get("steps") is Some(Array(full_steps)) else {
    fail("unexpected packed shape")
  }
  let mut current = initial
  for i, step in steps {
    guard step is Object(step_fields) &&
      step_fields.get("scene_delta") is Some(delta) &&
      !step_fields.contains("scene") &&
      full_steps[i] is Object(expected) else {
      fail("unexpected packed step")
    }
    current = apply_json_delta(current, delta)
    assert_eq(Some(current), expected.get("scene"))
  }
  // The second step repeats the initial scene, so its delta is one marker.
  guard steps[0] is Object(first) else { fail("unexpected step") }
  assert_eq(first.get("scene_delta"), Some(["s"]))
}
