///|
fn usage() -> String {
  (
    #|FrontierLab 0.13.1 - HTML Trace Player
    #|  frontierlab diagnose <expected.json> <actual.json> --contract <name> --object <id> --format <text|json> [--counterexample <path>] [--report <path>] [--timings]
    #|  frontierlab profile <algorithm> [--input <random|sorted|reversed>] [--sizes N,N,...] [--metric <compares|swaps|reads|writes|total>] [--bound <O(...)>] [--factor K] [--overhead N] --format <text|json>
    #|  frontierlab search <algorithm> [--reference <algorithm>] [--match-events] [--cases N] [--max-length N] [--max-value N] [--seed N] --format <text|json> [--counterexample <path>] [--report <path>]
    #|  Algorithms: bubble-sort, insertion-sort, shift-insertion-sort, selection-sort, heap-sort, quick-sort; faulty-insertion-sort, lossy-insertion-sort, and faulty-quick-sort contain deliberate bugs.
    #|  frontierlab demo <insertion-sort|faulty-insertion-sort|union-find|pathfinding|fibonacci|coin-change|knapsack|lcs|red-black-tree> --format <html|json> --output <path|->
    #|  frontierlab render <trace.json> --format <html|json> --output <path|->
    #|  frontierlab analyze <trace.json>
    #|  frontierlab validate <trace.json>
    #|  frontierlab diff <trace.json> --from N --to N --format <text|json>
    #|  frontierlab breakpoints <trace.json> [--event KIND] [--target OBJECT[/ENTITY]] [--role ROLE] [--changed-only] --format <text|json>
    #|  frontierlab verify <trace.json> --contract <sequence-transition|sorted-int-sequence|grid-path> --object ID --format <text|json> [--counterexample PATH]
    #|  frontierlab diverge <expected.json> <actual.json> --format <text|json> [--counterexample PATH]
    #|  frontierlab --version
  )
}

///|
fn option(
  args : Array[String],
  name : String,
  default : String,
) -> String raise {
  match args.search_by(fn(value) { value == name }) {
    Some(index) if index + 1 < args.length() &&
      !args[index + 1].has_prefix("--") => args[index + 1]
    Some(_) => fail("\{name} requires a value")
    None => default
  }
}

///|
fn required_option(args : Array[String], name : String) -> String raise {
  let value = option(args, name, "")
  if value == "" {
    fail("\{name} is required")
  }
  value
}

///|
fn debug_format(args : Array[String]) -> String raise {
  let format = option(args, "--format", "text")
  if format != "text" && format != "json" {
    fail("Unknown debug report format: \{format}")
  }
  format
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
fn command_name(args : Array[String]) -> String {
  if args.length() > 1 {
    args[1]
  } else {
    "unknown"
  }
}
