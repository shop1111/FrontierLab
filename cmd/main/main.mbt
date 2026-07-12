///|
fn usage() -> String {
  let text =
    #|FrontierLab 0.6.0 - Semantic Time-Travel Debugger
    #|  frontierlab demo <insertion-sort|faulty-insertion-sort|union-find|pathfinding> --format <html|svg|json> --output <path|->
    #|  frontierlab render <trace.json> --format <html|svg> --output <path|-> [--step N]
    #|  frontierlab analyze <trace.json>
    #|  frontierlab validate <trace.json>
    #|  frontierlab playground --output <path|->
    #|  frontierlab diff <trace.json> --from N --to N --format <text|json>
    #|  frontierlab breakpoints <trace.json> [--event KIND] [--target OBJECT[/ENTITY]] [--role ROLE] [--changed-only] --format <text|json>
    #|  frontierlab verify <trace.json> --contract <sequence-transition|insertion-sort-int|grid-path> --object ID --format <text|json> [--counterexample PATH]
    #|  frontierlab diverge <expected.json> <actual.json> --format <text|json> [--counterexample PATH]
  text
}

///|
fn option(args : Array[String], name : String, default : String) -> String {
  match args.search_by(fn(value) { value == name }) {
    Some(index) if index + 1 < args.length() => args[index + 1]
    _ => default
  }
}

///|
fn write_output(path : String, content : String) -> Unit raise {
  if path == "-" {
    println(content)
  } else {
    @fs.write_string_to_file(path, content)
    println("Wrote \{path}")
  }
}

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
fn json_envelope(command : String, ok : Bool, result : String) -> String {
  let ok_text = if ok { "true" } else { "false" }
  "{\"report_version\":\"frontierlab-debug-report/1.0\",\"ok\":\{ok_text},\"command\":\"\{command}\",\"result\":\{result}}"
}

///|
fn json_error_envelope(command : String, message : String) -> String {
  let escaped = message
    .replace_all(old="\\", new="\\\\")
    .replace_all(old="\"", new="\\\"")
    .replace_all(old="\n", new="\\n")
  "{\"report_version\":\"frontierlab-debug-report/1.0\",\"ok\":false,\"command\":\"\{command}\",\"result\":null,\"diagnostics\":[\"\{escaped}\"]}"
}

///|
fn output_debug(
  command : String,
  format : String,
  text : String,
  json : String,
) -> Unit raise {
  if format == "json" {
    println(json_envelope(command, true, json))
  } else if format == "text" {
    println(text)
  } else {
    fail("Unknown debug report format: \{format}")
  }
}

///|
fn parse_target(value : String) -> @frontierlab.TargetRef? raise {
  if value == "" {
    None
  } else {
    let parts = value.split("/").map(fn(part) { part.to_owned() }).collect()
    if parts.length() == 1 {
      Some(@frontierlab.TargetRef::object(parts[0]))
    } else if parts.length() == 2 && parts[0] != "" && parts[1] != "" {
      Some(@frontierlab.TargetRef::entity(parts[0], parts[1]))
    } else {
      fail("Target must be OBJECT or OBJECT/ENTITY")
    }
  }
}

///|
fn write_counterexample(
  path : String,
  counterexample : @frontierlab.TraceCounterexample?,
) -> Unit raise {
  if path == "" {
    return
  }
  match counterexample {
    Some(value) => {
      let content = if path.has_suffix(".html") {
        @frontierlab.render_trace_html(value.trace)
      } else {
        value.trace.encode_json()
      }
      @fs.write_string_to_file(path, content)
    }
    None => fail("No counterexample is available for this result")
  }
}

///|
fn contract_by_name(
  name : String,
  object_id : String,
) -> @frontierlab.TraceContract raise {
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
fn run(args : Array[String]) -> Unit raise {
  if args.length() < 2 || args.contains("--help") {
    println(usage())
    return
  }
  match args[1] {
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
      let raw_step = option(args, "--step", "-1")
      let step = @strconv.parse_int(raw_step)
      write_output(output, render_content(trace, format, step))
    }
    "analyze" => {
      if args.length() < 3 {
        fail("analyze requires a trace file")
      }
      let trace = @frontierlab.AlgorithmTrace::decode_json(
        @fs.read_file_to_string(args[2]),
      )
      trace.validate()
      println(trace.summary_report())
    }
    "validate" => {
      if args.length() < 3 {
        fail("validate requires a trace file")
      }
      let trace = @frontierlab.AlgorithmTrace::decode_json(
        @fs.read_file_to_string(args[2]),
      )
      trace.validate()
      println("valid: \{args[2]}")
    }
    "playground" => {
      let output = option(args, "--output", "-")
      write_output(output, @frontierlab.render_trace_playground())
    }
    "diff" => {
      if args.length() < 3 {
        fail("diff requires a trace file")
      }
      let trace = read_trace(args[2])
      let from_step = @strconv.parse_int(option(args, "--from", "-1"))
      let to_step = @strconv.parse_int(option(args, "--to", "0"))
      let format = option(args, "--format", "text")
      let diff = trace.diff(from_step~, to_step~)
      output_debug("diff", format, diff.report(), diff.to_json_string())
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
        option(args, "--format", "text"),
        out.to_string(),
        hits.to_json().stringify(indent=2),
      )
    }
    "verify" => {
      if args.length() < 3 {
        fail("verify requires a trace file")
      }
      let trace = read_trace(args[2])
      let contract = contract_by_name(
        option(args, "--contract", ""),
        option(args, "--object", ""),
      )
      let report = contract.check(trace)
      write_counterexample(
        option(args, "--counterexample", ""),
        report.counterexample,
      )
      output_debug(
        "verify",
        option(args, "--format", "text"),
        report.report(),
        report.to_json_string(),
      )
      if !report.passed {
        @sys.exit(2)
      }
    }
    "diverge" => {
      if args.length() < 4 {
        fail("diverge requires expected and actual trace files")
      }
      let expected = read_trace(args[2])
      let actual = read_trace(args[3])
      let format = option(args, "--format", "text")
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
            format,
            divergence.message,
            divergence.to_json_string(),
          )
          @sys.exit(2)
        }
        None => output_debug("diverge", format, "No divergence.", "null")
      }
    }
    other => fail("Unknown command: \{other}\n\{usage()}")
  }
}

///|
fn main {
  let args = @sys.get_cli_args()
  try run(args) catch {
    error => {
      if option(args, "--format", "text") == "json" {
        let command = if args.length() > 1 { args[1] } else { "unknown" }
        println(json_error_envelope(command, "\{error}"))
      } else {
        println("error: \{error}")
      }
      @sys.exit(1)
    }
  } noraise {
    _ => ()
  }
}
