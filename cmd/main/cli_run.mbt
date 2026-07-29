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
fn read_trace(path : String) -> @frontierlab.AlgorithmTrace raise {
  let trace = @frontierlab.AlgorithmTrace::decode_json(
    @fs.read_file_to_string(path),
  )
  trace.validate()
  trace
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
fn run_cli(args : Array[String]) -> Int raise {
  if args.length() < 2 || args.contains("--help") {
    println(usage())
    return 0
  }
  match args[1] {
    "diagnose" => {
      if args.length() < 4 {
        fail("diagnose requires expected and actual trace files")
      }
      let expected = read_trace(args[2])
      let actual = read_trace(args[3])
      let contract = contract_by_name(
        required_option(args, "--contract"),
        required_option(args, "--object"),
      )
      let format = debug_format(args)
      let diagnosis = calculate_diagnosis(expected, actual, contract)
      write_counterexample(
        option(args, "--counterexample", ""),
        diagnosis.counterexample,
      )
      write_diagnosis_report(option(args, "--report", ""), diagnosis)
      output_diagnosis(format, diagnosis)
      if diagnosis.passed() {
        0
      } else {
        2
      }
    }
    "demo" => {
      if args.length() < 3 {
        fail("demo requires a name")
      }
      let trace = demo(args[2])
      let format = option(args, "--format", "html")
      let output = option(args, "--output", "-")
      write_output(
        output,
        render_content(trace, format, trace.steps.length() - 1),
      )
      if output != "-" {
        println(trace.summary_report())
      }
      0
    }
    "render" => {
      if args.length() < 3 {
        fail("render requires a trace file")
      }
      let trace = @frontierlab.AlgorithmTrace::decode_json(
        @fs.read_file_to_string(args[2]),
      )
      let format = option(args, "--format", "html")
      let output = option(args, "--output", "-")
      let step = @strconv.parse_int(option(args, "--step", "-1"))
      write_output(output, render_content(trace, format, step))
      0
    }
    "analyze" => {
      if args.length() < 3 {
        fail("analyze requires a trace file")
      }
      println(read_trace(args[2]).summary_report())
      0
    }
    "validate" => {
      if args.length() < 3 {
        fail("validate requires a trace file")
      }
      ignore(read_trace(args[2]))
      println("valid: \{args[2]}")
      0
    }
    "playground" => {
      write_output(
        option(args, "--output", "-"),
        @frontierlab.render_trace_playground(),
      )
      0
    }
    "diff" => {
      if args.length() < 3 {
        fail("diff requires a trace file")
      }
      let trace = read_trace(args[2])
      let diff = trace.diff(
        from_step=@strconv.parse_int(option(args, "--from", "-1")),
        to_step=@strconv.parse_int(option(args, "--to", "0")),
      )
      output_debug(
        "diff",
        debug_format(args),
        diff.report(),
        diff.to_json_string(),
      )
      0
    }
    "breakpoints" => {
      if args.length() < 3 {
        fail("breakpoints requires a trace file")
      }
      let trace = read_trace(args[2])
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
      output_debug(
        "breakpoints",
        debug_format(args),
        out.to_string(),
        hits.to_json().stringify(indent=2),
      )
      0
    }
    "verify" => {
      if args.length() < 3 {
        fail("verify requires a trace file")
      }
      let trace = read_trace(args[2])
      let contract = contract_by_name(
        required_option(args, "--contract"),
        required_option(args, "--object"),
      )
      let report = contract.check(trace)
      write_counterexample(
        option(args, "--counterexample", ""),
        report.counterexample,
      )
      output_debug(
        "verify",
        debug_format(args),
        report.report(),
        report.to_json_string(),
      )
      if report.passed {
        0
      } else {
        2
      }
    }
    "diverge" => {
      if args.length() < 4 {
        fail("diverge requires expected and actual trace files")
      }
      let expected = read_trace(args[2])
      let actual = read_trace(args[3])
      match @frontierlab.first_divergence(expected, actual) {
        Some(divergence) => {
          let counterexample = if divergence.step < actual.steps.length() {
            Some(actual.slice(center=divergence.step))
          } else {
            None
          }
          write_counterexample(
            option(args, "--counterexample", ""),
            counterexample,
          )
          output_debug(
            "diverge",
            debug_format(args),
            divergence.message,
            divergence.to_json_string(),
          )
          2
        }
        None => {
          output_debug("diverge", debug_format(args), "No divergence.", "null")
          0
        }
      }
    }
    other => fail("Unknown command: \{other}\n\{usage()}")
  }
}
