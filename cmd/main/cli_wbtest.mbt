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
  let passing = @frontierlab.diagnose_trace(
    expected,
    contract=@frontierlab.insertion_sort_int_contract(object_id="values"),
    expected~,
  )
  assert_true(passing.passed())
  assert_eq(passing.focus_step, -1)
  assert_true(passing.focused_slice is None)
  assert_true(diagnosis_text(passing).contains("First divergence: none"))
  assert_true(diagnosis_text(passing).contains("Actual transition: none"))
  assert_true(diagnosis_json(passing).contains("\"counterexample\":null"))
  assert_true(diagnosis_json(passing).contains("\"reference_changes\":null"))
  assert_true(diagnosis_report_artifact("", passing) is None)
  assert_true(
    debug_result("diagnose", "json", "ok", "null").contains("diagnose"),
  )
  assert_eq(debug_result("diagnose", "text", "ok", "null"), "ok")
  try debug_result("diagnose", "xml", "ok", "null") catch {
    _ => ()
  } noraise {
    _ => fail("unknown diagnosis output format must fail")
  }
  let actual = @frontierlab.faulty_insertion_sort_demo_trace()
  let contract_only = @frontierlab.diagnose_trace(
    actual,
    contract=@frontierlab.insertion_sort_int_contract(object_id="values"),
  )
  assert_true(contract_only.divergence is None)
  assert_true(contract_only.focus_step >= 0)
  let failing = @frontierlab.diagnose_trace(
    actual,
    contract=@frontierlab.insertion_sort_int_contract(object_id="values"),
    expected~,
  )
  assert_true(!failing.passed())
  assert_true(failing.focus_step >= 0)
  assert_true(failing.divergence is Some(_))
  assert_true(failing.focused_slice is Some(_))
  assert_true(failing.reference_diff is Some(_))
  assert_true(diagnosis_json(failing).contains("\"contract\""))
  assert_true(diagnosis_json(failing).contains("\"divergence\""))
  assert_true(
    diagnosis_json(failing).contains(
      "\"counterexample_kind\":\"focused-window\"",
    ),
  )
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
  assert_true(usage().contains("sorted-int-sequence"))
  assert_true(
    json_envelope("verify", true, "null").contains(
      "\"report_version\":\"frontierlab-debug-report/1.0\"",
    ),
  )
  assert_true(
    json_error_envelope("verify", "bad\ninput").contains("bad\\ninput"),
  )
  assert_true(render_content(demo("insertion-sort"), "svg", 0).contains("<svg"))
  assert_eq(cli_input_paths([]), [])
  let no_inputs : Map[String, String] = Map([])
  try input_trace(no_inputs, "missing.json") catch {
    _ => ()
  } noraise {
    _ => fail("missing pure CLI input must fail")
  }
  assert_eq(
    contract_by_name("sorted-int-sequence", "values").name,
    "sorted-int-sequence",
  )
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

///|
fn assert_cli_failure(args : Array[String]) -> Unit raise {
  try run_cli(args) catch {
    _ => ()
  } noraise {
    _ => fail("CLI command should fail")
  }
}

///|
test "CLI dispatch covers commands artifacts and exit semantics" {
  let expected = "fixtures/agent-traces/selection-sort-expected.json"
  let actual = "fixtures/agent-traces/selection-sort-actual.json"
  assert_eq(run_cli(["frontierlab", "--version"]), 0)
  assert_eq(run_cli(["frontierlab", "--help"]), 0)
  assert_eq(
    run_cli([
      "frontierlab", "demo", "insertion-sort", "--format", "html", "--output", "_build/cli-test-demo.html",
    ]),
    0,
  )
  assert_eq(
    run_cli([
      "frontierlab", "render", expected, "--format", "json", "--output", "_build/cli-test-render.json",
      "--step", "0",
    ]),
    0,
  )
  assert_eq(run_cli(["frontierlab", "analyze", expected]), 0)
  assert_eq(run_cli(["frontierlab", "validate", expected]), 0)
  assert_eq(
    run_cli([
      "frontierlab", "playground", "--output", "_build/cli-test-playground.html",
    ]),
    0,
  )
  assert_eq(
    run_cli([
      "frontierlab", "diff", expected, "--from", "9", "--to", "10", "--format", "json",
    ]),
    0,
  )
  assert_eq(
    run_cli([
      "frontierlab", "breakpoints", expected, "--event", "swap", "--target", "values/item-4",
      "--role", "changed", "--changed-only", "--format", "text",
    ]),
    0,
  )
  assert_eq(
    run_cli([
      "frontierlab", "breakpoints", expected, "--event", "swap", "--format", "json",
    ]),
    0,
  )
  assert_eq(
    run_cli([
      "frontierlab", "verify", expected, "--contract", "sorted-int-sequence", "--object",
      "values", "--format", "text",
    ]),
    0,
  )
  assert_eq(
    run_cli([
      "frontierlab", "verify", actual, "--contract", "sorted-int-sequence", "--object",
      "values", "--format", "json", "--counterexample", "_build/cli-test-verify-counterexample.json",
    ]),
    2,
  )
  assert_eq(
    run_cli([
      "frontierlab", "diagnose", expected, expected, "--contract", "sorted-int-sequence",
      "--object", "values", "--format", "text",
    ]),
    0,
  )
  assert_eq(
    run_cli([
      "frontierlab", "diagnose", expected, actual, "--contract", "sorted-int-sequence",
      "--object", "values", "--format", "json", "--counterexample", "_build/cli-test-diagnose-counterexample.json",
      "--report", "_build/cli-test-diagnosis.html",
    ]),
    2,
  )
  assert_eq(
    run_cli([
      "frontierlab", "diagnose", expected, actual, "--contract", "sorted-int-sequence",
      "--object", "values", "--report", "_build/cli-test-diagnosis.json",
    ]),
    2,
  )
  assert_eq(
    run_cli([
      "frontierlab", "diagnose", expected, actual, "--contract", "sorted-int-sequence",
      "--object", "values", "--report", "_build/cli-test-diagnosis.txt",
    ]),
    2,
  )
  assert_eq(
    run_cli(["frontierlab", "diverge", expected, expected, "--format", "text"]),
    0,
  )
  assert_eq(
    run_cli([
      "frontierlab", "diverge", expected, "fixtures/schema-v1/minimal-valid.json",
      "--format", "text",
    ]),
    2,
  )
  assert_eq(
    run_cli([
      "frontierlab", "diverge", expected, actual, "--format", "json", "--counterexample",
      "_build/cli-test-diverge-counterexample.html",
    ]),
    2,
  )
  assert_eq(
    output_execution("-", "stdout boundary smoke").stdout,
    "stdout boundary smoke",
  )
  assert_true(counterexample_artifact("", None) is None)
  try counterexample_artifact("_build/cli-test-missing.json", None) catch {
    _ => ()
  } noraise {
    _ => fail("missing counterexample must fail")
  }
  try debug_result("test", "xml", "text", "null") catch {
    _ => ()
  } noraise {
    _ => fail("unknown debug format must fail")
  }
}

///|
test "CLI dispatch reports malformed invocations" {
  assert_cli_failure(["frontierlab", "diagnose"])
  assert_cli_failure(["frontierlab", "demo"])
  assert_cli_failure(["frontierlab", "render"])
  assert_cli_failure(["frontierlab", "analyze"])
  assert_cli_failure(["frontierlab", "validate"])
  assert_cli_failure(["frontierlab", "diff"])
  assert_cli_failure(["frontierlab", "breakpoints"])
  assert_cli_failure(["frontierlab", "verify"])
  assert_cli_failure(["frontierlab", "diverge"])
  assert_cli_failure(["frontierlab", "unknown"])
  try render_content(demo("faulty-insertion-sort"), "yaml", 0) catch {
    _ => ()
  } noraise {
    _ => fail("unknown render format must fail")
  }
  ignore(demo("union-find"))
  ignore(demo("pathfinding"))
  try demo("unknown") catch {
    _ => ()
  } noraise {
    _ => fail("unknown demo must fail")
  }
  assert_eq(
    contract_by_name("sequence-transition", "values").name,
    "sequence-transition",
  )
  assert_eq(
    contract_by_name("insertion-sort-int", "values").name,
    "insertion-sort-int",
  )
  assert_eq(contract_by_name("grid-path", "grid").name, "grid-path")
}
