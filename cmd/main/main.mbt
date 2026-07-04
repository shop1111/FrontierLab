///|
fn usage() -> String {
  let text =
    #|FrontierLab 0.3.0
    #|  frontierlab demo <insertion-sort|union-find|pathfinding> --format <html|svg|json> --output <path|->
    #|  frontierlab render <trace.json> --format <html|svg> --output <path|-> [--step N]
    #|  frontierlab validate <trace.json>
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
fn demo(name : String) -> @frontierlab.AlgorithmTrace raise {
  match name {
    "insertion-sort" => @frontierlab.insertion_sort_demo_trace([5, 2, 4, 1, 3])
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
    other => fail("Unknown command: \{other}\n\{usage()}")
  }
}

///|
fn main {
  try run(@sys.get_cli_args()) catch {
    error => {
      println("error: \{error}")
      @sys.exit(1)
    }
  } noraise {
    _ => ()
  }
}
