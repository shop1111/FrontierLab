///|
fn write_evidence(directory : String) -> Unit raise {
  @fs.create_dir(directory)

  // 1. Let FrontierLab search for the smallest failing sequence.
  match
    @explore.explore(
      Heap::empty,
      heap_ops(pop),
      invariant=heap_violation,
      title="Min-heap pop",
    ) {
    Some(found) => {
      println(found.report())
      found.save_html("\{directory}/heap-explore.html")
      // A step-by-step text account, and a test that keeps the bug fixed.
      @fs.write_string_to_file("\{directory}/heap-explain.txt", found.explain())
      println(
        found.regression_test(
          init="Heap::empty",
          ops="heap_ops(pop_fixed)",
          checks="invariant=heap_violation",
        ),
      )
    }
    None => println("No failing sequence found.")
  }

  // 2. Replay an input written by hand.
  let replay = @explore.replay(
    Heap::empty,
    heap_ops(pop),
    @explore.Step::parse("push 1, push 5, push 2, push 6, push 7, pop"),
    invariant=heap_violation,
    title="Hand-written input",
  )
  println(replay.report())
  replay.save_html("\{directory}/heap-replay.html")

  // 3. After fixing pop, the same search finds nothing.
  match
    @explore.explore(Heap::empty, heap_ops(pop_fixed), invariant=heap_violation) {
    Some(found) => println("pop_fixed still fails:\n\{found.report()}")
    None => println("pop_fixed: no failing sequence found.")
  }
}

///|
fn main raise {
  let args = @env.args()
  let directory = if args.length() > 1 { args[1] } else { "evidence" }
  write_evidence(directory)
}
