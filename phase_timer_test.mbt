///|
fn ticking_clock(step : Double) -> () -> Double {
  let ticks = Ref(0.0)
  fn() {
    ticks.val += step
    ticks.val
  }
}

///|
test "phase timer records phases in order and skips raising phases" {
  let timer = @frontierlab.PhaseTimer::new(clock=ticking_clock(0.5))
  assert_eq(timer.measure("first", fn() { 41 + 1 }), 42)
  timer.measure("second", fn() { () })
  try timer.measure("fails", fn() -> Unit raise { fail("boom") }) catch {
    _ => ()
  } noraise {
    _ => fail("a raising phase must propagate its error")
  }
  assert_eq(timer.timings().map(fn(timing) { timing.name }), ["first", "second"])
  assert_eq(timer.total_ms(), 1.0)
  inspect(
    timer.report(),
    content=(
      #|| phase | ms | share |
      #||---|---:|---:|
      #|| first | 0.500 | 50.0% |
      #|| second | 0.500 | 50.0% |
      #|| total | 1.000 | |
      #|
    ),
  )
}

///|
test "phase timer clamps a clock that goes backwards" {
  let timer = @frontierlab.PhaseTimer::new(clock=ticking_clock(-1.0))
  timer.measure("backwards", fn() { () })
  assert_eq(timer.total_ms(), 0.0)
  assert_true(timer.report().contains("| backwards | 0.000 | 0.0% |"))
}

///|
test "diagnose_trace records each diagnosis phase when timed" {
  let expected = @frontierlab.insertion_sort_demo_trace([5, 2, 4, 1, 3])
  let timer = @frontierlab.PhaseTimer::new(clock=ticking_clock(1.0))
  let timed = @frontierlab.diagnose_trace(
    @frontierlab.faulty_insertion_sort_demo_trace(),
    contract=@frontierlab.insertion_sort_int_contract(object_id="values"),
    expected~,
    timer~,
  )
  let untimed = @frontierlab.diagnose_trace(
    @frontierlab.faulty_insertion_sort_demo_trace(),
    contract=@frontierlab.insertion_sort_int_contract(object_id="values"),
    expected~,
  )
  assert_eq(timed, untimed)
  assert_eq(timer.timings().map(fn(timing) { timing.name }), [
    "contract check", "first divergence", "state diffs", "counterexample slice",
  ])
}

///|
test "complexity classes parse common spellings" {
  let cases = [
    ("O(1)", Some(@frontierlab.Constant)),
    ("o(log n)", Some(@frontierlab.Logarithmic)),
    ("lg n", Some(@frontierlab.Logarithmic)),
    ("n", Some(@frontierlab.Linear)),
    ("O(n log n)", Some(@frontierlab.Linearithmic)),
    ("n lg n", Some(@frontierlab.Linearithmic)),
    ("n*log(n)", Some(@frontierlab.Linearithmic)),
    ("O(n log(n))", Some(@frontierlab.Linearithmic)),
    ("O(n^2)", Some(@frontierlab.Quadratic)),
    ("n**2", Some(@frontierlab.Quadratic)),
    ("n²", Some(@frontierlab.Quadratic)),
    ("N³", Some(@frontierlab.Cubic)),
    ("O(2^n)", Some(@frontierlab.Exponential)),
    ("n!", None),
  ]
  for case in cases {
    assert_eq(@frontierlab.ComplexityClass::parse(case.0), case.1)
  }
  for
    class in [
      @frontierlab.Constant,
      @frontierlab.Logarithmic,
      @frontierlab.Linear,
      @frontierlab.Linearithmic,
      @frontierlab.Quadratic,
      @frontierlab.Cubic,
      @frontierlab.Exponential,
    ] {
    assert_eq(@frontierlab.ComplexityClass::parse(class.label()), Some(class))
  }
}
