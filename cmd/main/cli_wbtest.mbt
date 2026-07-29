///|
test "CLI parsing validates required values formats and targets" {
  assert_eq(option(["frontierlab"], "--format", "text"), "text")
  assert_eq(
    required_option(["frontierlab", "x", "--object", "values"], "--object"),
    "values",
  )
  assert_eq(debug_format(["frontierlab", "x", "--format", "json"]), "json")
  assert_eq(command_name(["frontierlab", "diagnose"]), "diagnose")
  assert_eq(command_name(["frontierlab"]), "unknown")
  assert_true(parse_target("values") is Some(_))
  assert_true(parse_target("values/item-2") is Some(_))
  assert_true(parse_target("") is None)
  try option(["frontierlab", "x", "--format"], "--format", "text") catch {
    _ => ()
  } noraise {
    _ => fail("missing option value must fail")
  }
  try required_option(["frontierlab", "x"], "--object") catch {
    _ => ()
  } noraise {
    _ => fail("missing required option must fail")
  }
  try debug_format(["frontierlab", "x", "--format", "xml"]) catch {
    _ => ()
  } noraise {
    _ => fail("unknown debug format must fail")
  }
  try parse_target("a/b/c") catch {
    _ => ()
  } noraise {
    _ => fail("malformed target must fail")
  }
}

///|
test "diagnosis combines contract divergence focus and counterexample" {
  let expected = @frontierlab.insertion_sort_demo_trace([5, 2, 4, 1, 3])
  let passing = calculate_diagnosis(
    expected,
    expected,
    @frontierlab.insertion_sort_int_contract(object_id="values"),
  )
  assert_true(passing.passed())
  assert_eq(passing.focus_step, -1)
  assert_true(passing.counterexample is None)
  assert_true(diagnosis_text(passing).contains("First divergence: none"))
  assert_true(diagnosis_text(passing).contains("State changes: none"))
  assert_true(diagnosis_json(passing).contains("\"counterexample\":null"))
  write_diagnosis_report("", passing)
  output_diagnosis("json", passing)
  output_diagnosis("text", passing)
  try output_diagnosis("xml", passing) catch {
    _ => ()
  } noraise {
    _ => fail("unknown diagnosis output format must fail")
  }
  let actual = @frontierlab.faulty_insertion_sort_demo_trace()
  let contract_only = calculate_diagnosis(
    actual,
    actual,
    @frontierlab.insertion_sort_int_contract(object_id="values"),
  )
  assert_true(contract_only.divergence is None)
  assert_true(contract_only.focus_step >= 0)
  let failing = calculate_diagnosis(
    expected,
    actual,
    @frontierlab.insertion_sort_int_contract(object_id="values"),
  )
  assert_true(!failing.passed())
  assert_true(failing.focus_step >= 0)
  assert_true(failing.divergence is Some(_))
  assert_true(failing.counterexample is Some(_))
  assert_true(diagnosis_json(failing).contains("\"contract\""))
  assert_true(diagnosis_json(failing).contains("\"divergence\""))
  assert_true(diagnosis_text(failing).contains("Diagnosis: FAIL"))
  assert_true(diagnosis_html(failing).contains("frontierlab-diagnosis"))
  assert_true(
    json_envelope("diagnose", failing.passed(), diagnosis_json(failing)).contains(
      "\"ok\":false",
    ),
  )
}

///|
test "CLI helpers keep report version and command compatibility" {
  assert_true(usage().contains("frontierlab diagnose"))
  assert_true(
    json_envelope("verify", true, "null").contains(
      "\"report_version\":\"frontierlab-debug-report/1.0\"",
    ),
  )
  assert_true(
    json_error_envelope("verify", "bad\ninput").contains("bad\\ninput"),
  )
  assert_true(render_content(demo("insertion-sort"), "svg", 0).contains("<svg"))
  try contract_by_name("unknown", "values") catch {
    _ => ()
  } noraise {
    _ => fail("unknown contract must fail")
  }
  try contract_by_name("sequence-transition", "") catch {
    _ => ()
  } noraise {
    _ => fail("empty object id must fail")
  }
}
