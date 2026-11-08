///|
fn values_json(values : Array[Int32]) -> Json {
  Json(values.map(fn(value) { Json(value) }))
}

///|
fn counterexample_json(
  found : @frontierlab.SequenceCounterexample,
) -> Json raise {
  {
    "cases_tried": Json(found.cases_tried),
    "original_input": values_json(found.original_input),
    "input": values_json(found.input),
    "shrink_steps": Json(found.shrink_steps),
    "reason": Json(found.reason),
    "actual_output": values_json(found.actual_output),
    "expected_output": match found.expected_output {
      Some(values) => values_json(values)
      None => Json::null()
    },
    "diagnosis": @json.parse(diagnosis_json(found.diagnosis)),
  }
}

///|
fn search_execution(args : Array[String]) -> Diagnosis raise {
  if args.length() < 3 || args[2].has_prefix("--") {
    fail("search requires an algorithm name")
  }
  let name = args[2]
  let algorithm = sort_algorithm(name)
  let reference_name = option(args, "--reference", "")
  let reference = if reference_name == "" {
    None
  } else {
    Some(sort_algorithm(reference_name))
  }
  let format = debug_format(args)
  let cases = @strconv.parse_int(option(args, "--cases", "500"))
  let seed = @strconv.parse_uint64(option(args, "--seed", "1"))
  let found = @frontierlab.search_sequence_counterexample(
    algorithm,
    reference?,
    match_events=args.contains("--match-events"),
    cases~,
    max_length=@strconv.parse_int(option(args, "--max-length", "8")),
    max_value=@strconv.parse_int(option(args, "--max-value", "9")),
    seed~,
  )
  let against = if reference_name == "" {
    "sorted output"
  } else {
    reference_name
  }
  let text = StringBuilder()
  text.write_string("# Counterexample search: \{name} against \{against}\n\n")
  let artifacts : Array[(String, String)] = []
  match found {
    Some(value) => {
      text.write_string(value.report())
      let trace_path = option(args, "--counterexample", "")
      if trace_path != "" {
        artifacts.push(
          (
            trace_path,
            if trace_path.has_suffix(".html") {
              @frontierlab.render_trace_html(value.actual_trace)
            } else {
              value.actual_trace.encode_json()
            },
          ),
        )
      }
      collect_artifact(
        artifacts,
        diagnosis_report_artifact(option(args, "--report", ""), value.diagnosis),
      )
    }
    None =>
      text.write_string("No counterexample in \{cases} cases (seed \{seed}).\n")
  }
  let result : Json = {
    "algorithm": Json(name),
    "reference": if reference_name == "" {
      Json::null()
    } else {
      Json(reference_name)
    },
    "seed": Json(seed.to_string()),
    "cases": Json(cases),
    "found": Json(found is Some(_)),
    "counterexample": match found {
      Some(value) => counterexample_json(value)
      None => Json::null()
    },
  }
  Diagnosis::new(
    exit_code=if found is Some(_) { 2 } else { 0 },
    stdout=debug_result("search", format, text.to_string(), result.stringify()),
    artifacts~,
  )
}
