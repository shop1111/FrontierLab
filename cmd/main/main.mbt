///|
fn main raise {
  let args = @env.args()
  if args.length() < 3 || args.contains("--help") {
    println(
      "Usage: frontierlab <insertion-sort|union-find|pathfinding> <html|svg|json> [output-file|-]",
    )
    return
  }
  let trace = match args[1] {
    "insertion-sort" => @frontierlab.insertion_sort_demo_trace([5, 2, 4, 1, 3])
    "union-find" => @frontierlab.union_find_demo_trace()
    "pathfinding" => @frontierlab.pathfinding_demo_trace()
    name => fail("Unknown demo: \{name}")
  }
  let content = match args[2] {
    "html" => @frontierlab.render_trace_html(trace)
    "svg" => @frontierlab.render_trace_svg(trace, step=trace.steps.length() - 1)
    "json" => trace.to_json_string()
    format => fail("Unknown format: \{format}")
  }
  let output = if args.length() > 3 { args[3] } else { "-" }
  if output == "-" {
    println(content)
  } else {
    @fs.write_string_to_file(output, content)
    println("Wrote \{output}")
  }
}
