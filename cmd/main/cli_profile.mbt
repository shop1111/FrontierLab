///|
/// A deterministic Fisher-Yates shuffle of 0..<n.
fn shuffled_input(n : Int32) -> Array[Int32] {
  let values = Array::makei(n, fn(i) { i })
  let mut state = 0x2545F491U
  for i = n - 1; i > 0; i = i - 1 {
    state = state * 1664525U + 1013904223U
    let j = ((state >> 8) % (i + 1).reinterpret_as_uint()).reinterpret_as_int()
    let value = values[i]
    values[i] = values[j]
    values[j] = value
  }
  values
}

///|
fn profile_input(name : String) -> ((Int32) -> Array[Int32]) raise {
  match name {
    "random" => shuffled_input
    "sorted" => fn(n) { Array::makei(n, fn(i) { i }) }
    "reversed" => fn(n) { Array::makei(n, fn(i) { n - 1 - i }) }
    other => fail("Unknown profile input: \{other}")
  }
}

///|
fn profile_metric(name : String) -> @profile.CostMetric raise {
  match name {
    "compares" => Compares
    "swaps" => Swaps
    "reads" => Reads
    "writes" => Writes
    "total" => Total
    other => fail("Unknown profile metric: \{other}")
  }
}

///|
fn profile_sizes(value : String) -> Array[Int32] raise {
  let sizes = []
  for part in value.split(",") {
    sizes.push(@strconv.parse_int(part.trim(chars=" ")))
  }
  sizes
}

///|
fn parse_factor(value : String) -> Double raise {
  let factor = @strconv.parse_double(value)
  if !(factor > 0.0) {
    fail("--factor must be positive")
  }
  factor
}

///|
fn profile_execution(
  args : Array[String],
  now~ : () -> UInt64,
) -> Diagnosis raise {
  if args.length() < 3 || args[2].has_prefix("--") {
    fail("profile requires an algorithm name")
  }
  let algorithm_name = args[2]
  let algorithm = sort_algorithm(algorithm_name)
  let input_name = option(args, "--input", "random")
  let input = profile_input(input_name)
  let format = debug_format(args)
  let profile = @profile.profile_traced_array(
    profile_sizes(option(args, "--sizes", "64,128,256,512,1024")),
    input,
    algorithm,
    metric=profile_metric(option(args, "--metric", "compares")),
  )
  let bound_text = option(args, "--bound", "")
  let bound = if bound_text == "" {
    None
  } else {
    match @profile.ComplexityClass::parse(bound_text) {
      Some(value) => Some(value)
      None => fail("Unknown complexity bound: \{bound_text}")
    }
  }
  let factor = parse_factor(option(args, "--factor", "1"))
  let violations = match bound {
    Some(value) => profile.check_bound(value, factor~)
    None => []
  }
  let overhead_size = @strconv.parse_int(option(args, "--overhead", "0"))
  let overhead = if overhead_size > 0 {
    Some(
      @profile.measure_tracing_overhead(
        input(overhead_size),
        algorithm,
        clock=now,
      ),
    )
  } else if overhead_size < 0 {
    fail("--overhead must be a positive size")
  } else {
    None
  }
  let text = StringBuilder()
  text.write_string("# \{algorithm_name} on \{input_name} input\n\n")
  text.write_string(profile.report())
  match bound {
    Some(value) => {
      let limit = "\{value.label()} with factor \{factor}"
      if violations.is_empty() {
        text.write_string("\nBound \{limit}: PASS\n")
      } else {
        text.write_string("\nBound \{limit}: FAIL\n")
        for sample in violations {
          text.write_string(
            "- n = \{sample.size}: cost \{sample.cost} exceeds \{factor * value.evaluate(sample.size)}\n",
          )
        }
      }
    }
    None => ()
  }
  match overhead {
    Some(value) => {
      text.write_string(
        "\n## Tracing overhead (n = \{overhead_size}, wall clock)\n\n",
      )
      text.write_string(value.report())
    }
    None => ()
  }
  let bound_json : Json = match bound {
    Some(value) =>
      {
        "class": Json(value),
        "label": Json(value.label()),
        "factor": Json(factor),
        "passed": Json(violations.is_empty()),
        "violations": Json(violations),
      }
    None => Json::null()
  }
  let result : Json = {
    "algorithm": Json(algorithm_name),
    "input": Json(input_name),
    "profile": Json(profile),
    "bound": bound_json,
    "overhead": match overhead {
      Some(value) => Json(value)
      None => Json::null()
    },
  }
  let passed = violations.is_empty()
  Diagnosis::new(
    exit_code=if passed { 0 } else { 2 },
    stdout=debug_result("profile", format, text.to_string(), result.stringify()),
  )
}
