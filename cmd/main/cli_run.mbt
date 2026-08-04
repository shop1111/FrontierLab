///|
fn render_content(
  trace : @frontierlab.AlgorithmTrace,
  format : String,
  step : Int,
) -> String raise {
  match format {
    "html" => @frontierlab.render_trace_html(trace)
    "svg" => @frontierlab.render_trace_svg(trace, step~)
    "json" => trace.encode_json()
    other => fail("Unknown format: \{other}")
  }
}

///|
fn decode_trace(
  content : String,
  validate? : Bool = true,
) -> @frontierlab.AlgorithmTrace raise {
  let trace = @frontierlab.AlgorithmTrace::decode_json(content)
  if validate {
    trace.validate()
  }
  trace
}

///|
fn input_trace(
  inputs : Map[String, String],
  path : String,
  validate? : Bool = true,
) -> @frontierlab.AlgorithmTrace raise {
  match inputs.get(path) {
    Some(content) => decode_trace(content, validate~)
    None => fail("Missing CLI input: \{path}")
  }
}

///|
fn cli_input_paths(args : Array[String]) -> Array[String] {
  if args.length() < 2 {
    return []
  }
  match args[1] {
    "diagnose" | "diverge" =>
      if args.length() >= 4 {
        [args[2], args[3]]
      } else {
        []
      }
    "render" | "analyze" | "validate" | "diff" | "breakpoints" | "verify" =>
      if args.length() >= 3 {
        [args[2]]
      } else {
        []
      }
    _ => []
  }
}

///|
fn read_cli_inputs(args : Array[String]) -> Map[String, String] raise {
  let inputs : Map[String, String] = Map([])
  for path in cli_input_paths(args) {
    inputs[path] = @fs.read_file_to_string(path)
  }
  inputs
}

///|
fn contract_by_name(
  name : String,
  object_id : String,
) -> @frontierlab.TraceContract raise {
  if object_id == "" {
    fail("--object is required")
  }
  match name {
    "sequence-transition" =>
      @frontierlab.sequence_transition_contract(object_id~)
    "insertion-sort-int" => @frontierlab.insertion_sort_int_contract(object_id~)
    "sorted-int-sequence" =>
      @frontierlab.sorted_int_sequence_contract(object_id~)
    "grid-path" => @frontierlab.grid_path_contract(object_id~)
    _ => fail("Unknown contract: \{name}")
  }
}

///|
fn demo(name : String) -> @frontierlab.AlgorithmTrace raise {
  match name {
    "insertion-sort" => @frontierlab.insertion_sort_demo_trace([5, 2, 4, 1, 3])
    "faulty-insertion-sort" => @frontierlab.faulty_insertion_sort_demo_trace()
    "union-find" => @frontierlab.union_find_demo_trace()
    "pathfinding" => @frontierlab.pathfinding_demo_trace()
    other => fail("Unknown demo: \{other}")
  }
}

///|
fn execute_cli(
  args : Array[String],
  inputs : Map[String, String],
) -> Diagnosis raise {
  if args.contains("--version") {
    return Diagnosis::new(stdout="FrontierLab 0.7.0 candidate")
  }
  if args.length() < 2 || args.contains("--help") {
    return Diagnosis::new(stdout=usage())
  }
  match args[1] {
    "diagnose" => {
      if args.length() < 4 {
        fail("diagnose requires expected and actual trace files")
      }
      let expected = input_trace(inputs, args[2])
      let actual = input_trace(inputs, args[3])
      let contract = contract_by_name(
        required_option(args, "--contract"),
        required_option(args, "--object"),
      )
      let format = debug_format(args)
      let diagnosis = @frontierlab.diagnose_trace(actual, contract~, expected~)
      let artifacts : Array[(String, String)] = []
      collect_artifact(
        artifacts,
        counterexample_artifact(
          option(args, "--counterexample", ""),
          diagnosis.focused_slice,
        ),
      )
      collect_artifact(
        artifacts,
        diagnosis_report_artifact(option(args, "--report", ""), diagnosis),
      )
      Diagnosis::new(
        exit_code=if diagnosis.passed() { 0 } else { 2 },
        stdout=debug_result(
          "diagnose",
          format,
          diagnosis_text(diagnosis),
          diagnosis_json(diagnosis),
        ),
        artifacts~,
      )
    }
    "demo" => {
      if args.length() < 3 {
        fail("demo requires a name")
      }
      let trace = demo(args[2])
      output_execution(
        option(args, "--output", "-"),
        render_content(
          trace,
          option(args, "--format", "html"),
          trace.steps.length() - 1,
        ),
        summary=trace.summary_report(),
      )
    }
    "render" => {
      if args.length() < 3 {
        fail("render requires a trace file")
      }
      let trace = input_trace(inputs, args[2], validate=false)
      output_execution(
        option(args, "--output", "-"),
        render_content(
          trace,
          option(args, "--format", "html"),
          @strconv.parse_int(option(args, "--step", "-1")),
        ),
      )
    }
    "analyze" => {
      if args.length() < 3 {
        fail("analyze requires a trace file")
      }
      Diagnosis::new(stdout=input_trace(inputs, args[2]).summary_report())
    }
    "validate" => {
      if args.length() < 3 {
        fail("validate requires a trace file")
      }
      ignore(input_trace(inputs, args[2]))
      Diagnosis::new(stdout="valid: \{args[2]}")
    }
    "playground" =>
      output_execution(
        option(args, "--output", "-"),
        @frontierlab.render_trace_playground(),
      )
    "diff" => {
      if args.length() < 3 {
        fail("diff requires a trace file")
      }
      let diff = input_trace(inputs, args[2]).diff(
        from_step=@strconv.parse_int(option(args, "--from", "-1")),
        to_step=@strconv.parse_int(option(args, "--to", "0")),
      )
      Diagnosis::new(
        stdout=debug_result(
          "diff",
          debug_format(args),
          diff.report(),
          diff.to_json_string(),
        ),
      )
    }
    "breakpoints" => {
      if args.length() < 3 {
        fail("breakpoints requires a trace file")
      }
      let trace = input_trace(inputs, args[2])
      let target = parse_target(option(args, "--target", ""))
      let breakpoint = match target {
        Some(value) =>
          @frontierlab.TraceBreakpoint::new(
            event_kind=option(args, "--event", ""),
            target=value,
            role=option(args, "--role", ""),
            changed_only=args.contains("--changed-only"),
          )
        None =>
          @frontierlab.TraceBreakpoint::new(
            event_kind=option(args, "--event", ""),
            role=option(args, "--role", ""),
            changed_only=args.contains("--changed-only"),
          )
      }
      let hits = trace.breakpoint_hits(breakpoint)
      let out = StringBuilder()
      out.write_string("Breakpoint hits: \{hits.length()}\n")
      for hit in hits {
        out.write_string(
          "- step \{hit.step}: \{hit.event_kind} (\{hit.reason})\n",
        )
      }
      Diagnosis::new(
        stdout=debug_result(
          "breakpoints",
          debug_format(args),
          out.to_string(),
          hits.to_json().stringify(indent=2),
        ),
      )
    }
    "verify" => {
      if args.length() < 3 {
        fail("verify requires a trace file")
      }
      let trace = input_trace(inputs, args[2])
      let contract = contract_by_name(
        required_option(args, "--contract"),
        required_option(args, "--object"),
      )
      let report = contract.check(trace)
      let artifacts : Array[(String, String)] = []
      collect_artifact(
        artifacts,
        counterexample_artifact(
          option(args, "--counterexample", ""),
          report.counterexample,
        ),
      )
      Diagnosis::new(
        exit_code=if report.passed { 0 } else { 2 },
        stdout=debug_result(
          "verify",
          debug_format(args),
          report.report(),
          report.to_json_string(),
        ),
        artifacts~,
      )
    }
    "diverge" => {
      if args.length() < 4 {
        fail("diverge requires expected and actual trace files")
      }
      let expected = input_trace(inputs, args[2])
      let actual = input_trace(inputs, args[3])
      match @frontierlab.first_divergence(expected, actual) {
        Some(divergence) => {
          let counterexample = if divergence.step < actual.steps.length() {
            Some(actual.slice(center=divergence.step))
          } else {
            None
          }
          let artifacts : Array[(String, String)] = []
          collect_artifact(
            artifacts,
            counterexample_artifact(
              option(args, "--counterexample", ""),
              counterexample,
            ),
          )
          Diagnosis::new(
            exit_code=2,
            stdout=debug_result(
              "diverge",
              debug_format(args),
              divergence.message,
              divergence.to_json_string(),
            ),
            artifacts~,
          )
        }
        None =>
          Diagnosis::new(
            stdout=debug_result(
              "diverge",
              debug_format(args),
              "No divergence.",
              "null",
            ),
          )
      }
    }
    other => fail("Unknown command: \{other}\n\{usage()}")
  }
}

///|
fn run_cli(args : Array[String]) -> Int raise {
  apply_execution(execute_cli(args, read_cli_inputs(args)))
}
