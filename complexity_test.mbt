///|
fn traced_sift_down(
  a : @frontierlab.TracedArray[Int32],
  start : Int32,
  end : Int32,
) -> Unit {
  let mut root = start
  while 2 * root + 1 < end {
    let mut child = 2 * root + 1
    if child + 1 < end && a.less(child, child + 1) {
      child += 1
    }
    if !a.less(root, child) {
      return
    }
    a.swap(root, child)
    root = child
  }
}

///|
fn traced_heap_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  let n = a.length()
  for start = n / 2 - 1; start >= 0; start = start - 1 {
    traced_sift_down(a, start, n)
  }
  for end = n - 1; end > 0; end = end - 1 {
    a.swap(0, end)
    traced_sift_down(a, 0, end)
  }
}

///|
fn traced_minimum_index(a : @frontierlab.TracedArray[Int32]) -> Unit {
  let mut best = 0
  for i in 1..<a.length() {
    if a.less(i, best) {
      best = i
    }
  }
}

///|
/// Searches for a key above every element, so each probe moves right.
fn traced_binary_search_past_end(a : @frontierlab.TracedArray[Int32]) -> Unit {
  let key = a.length()
  let mut low = 0
  let mut high = a.length()
  while low < high {
    let mid = (low + high) / 2
    if a[mid] < key {
      low = mid + 1
    } else {
      high = mid
    }
  }
}

///|
fn ascending(n : Int32) -> Array[Int32] {
  Array::makei(n, fn(i) { i })
}

///|
fn descending(n : Int32) -> Array[Int32] {
  Array::makei(n, fn(i) { n - i })
}

///|
/// A deterministic permutation of 0..<n for sizes coprime with 7919.
fn scrambled(n : Int32) -> Array[Int32] {
  Array::makei(n, fn(i) { i * 7919 % n })
}

///|
test "bubble sort profiles as quadratic with an exact bound" {
  let profile = @frontierlab.profile_traced_array(
    [16, 32, 64, 128, 256],
    descending,
    traced_bubble_sort,
    metric=Compares,
  )
  assert_eq(profile.best.class, @frontierlab.Quadratic)
  assert_eq(profile.samples[4].cost, 256 * 255 / 2)
  assert_true(profile.exponent > 1.9 && profile.exponent < 2.05)
  assert_true(profile.best.coefficient > 0.45 && profile.best.coefficient < 0.5)
  assert_true(profile.check_bound(Quadratic, factor=0.5).is_empty())
  assert_eq(profile.check_bound(Linearithmic, factor=1.0).length(), 5)
}

///|
test "heap sort profiles as linearithmic" {
  let profile = @frontierlab.profile_traced_array(
    [64, 128, 256, 512, 1024, 2048],
    scrambled,
    traced_heap_sort,
    metric=Compares,
  )
  assert_eq(profile.best.class, @frontierlab.Linearithmic)
  assert_true(profile.report().contains("Best fit: O(n log n), cost ≈ "))
  assert_true(profile.check_bound(Linearithmic, factor=3.0).is_empty())
  assert_true(profile.check_bound(Linear, factor=3.0).length() > 0)
  // 2^n overflows at these sizes, so the exponential class is not fitted.
  assert_eq(profile.fits.length(), 6)
  assert_true(
    profile.fits.all(fn(fit) { fit.class != @frontierlab.Exponential }),
  )
}

///|
test "scans, binary search, and single reads fit linear, log, and constant" {
  let scan = @frontierlab.profile_traced_array(
    [10, 100, 1000, 10000],
    scrambled,
    traced_minimum_index,
  )
  assert_eq(scan.best.class, @frontierlab.Linear)
  assert_true(scan.report().contains("Best fit: O(n), cost ≈ "))
  assert_eq(scan.samples[3].counts.compares, 9999)
  let search = @frontierlab.profile_traced_array(
    [16, 64, 256, 1024, 4096],
    ascending,
    traced_binary_search_past_end,
    metric=Reads,
  )
  assert_eq(search.best.class, @frontierlab.Logarithmic)
  assert_eq(search.samples.map(fn(sample) { sample.cost }), [4, 6, 8, 10, 12])
  let first = @frontierlab.profile_traced_array([1, 10, 100], ascending, fn(a) {
    ignore(a[0])
  })
  assert_eq(first.best.class, @frontierlab.Constant)
  assert_eq(first.best.error, 0.0)
}

///|
test "profiles with no measured cost report a zero constant" {
  let profile = @frontierlab.profile_traced_array(
    [8, 16, 32],
    ascending,
    traced_bubble_sort,
    metric=Swaps,
  )
  assert_eq(profile.best.class, @frontierlab.Constant)
  assert_eq(profile.best.coefficient, 0.0)
  assert_eq(profile.best.error, 0.0)
  assert_eq(profile.fits.length(), 1)
  assert_eq(profile.exponent, 0.0)
}

///|
test "profile_complexity validates sizes" {
  let run = fn(n : Int32) { @frontierlab.OperationCounts::new(compares=n) }
  for sizes in [[10], [0, 10], [10, 10], [20, 10]] {
    try @frontierlab.profile_complexity(sizes, run) catch {
      InvalidStep(_) => ()
      _ => fail("expected InvalidStep")
    } noraise {
      _ => fail("invalid sizes must be rejected")
    }
  }
  let ok = @frontierlab.profile_complexity([10, 20, 40], run, metric=Compares)
  assert_eq(ok.best.class, @frontierlab.Linear)
  assert_eq(ok.best.coefficient, 1.0)
  assert_eq(ok.metric.name(), "compares")
}

///|
test "complexity report lists samples and fits" {
  let profile = @frontierlab.profile_traced_array(
    [8, 16, 32],
    descending,
    traced_bubble_sort,
  )
  let report = profile.report()
  assert_true(report.contains("## Complexity profile (total)"))
  assert_true(report.contains("| 32 | 496 | 496 | 0 | 0 | 992 |"))
  assert_true(report.contains("Best fit: O(n^2)"))
  assert_true(report.contains("| O(n log n) |"))
  assert_eq(@frontierlab.Cubic.label(), "O(n^3)")
  assert_eq(@frontierlab.Exponential.evaluate(10), 1024.0)
  assert_eq(@frontierlab.Logarithmic.evaluate(1), 1.0)
}

///|
test "tracing overhead calibrates runs against the clock" {
  let ticks = Ref(0UL)
  let clock = fn() {
    ticks.val += 1UL
    ticks.val
  }
  let overhead = @frontierlab.measure_tracing_overhead(
    [3, 1, 2],
    traced_bubble_sort,
    clock~,
    min_ms=5,
    max_runs=4,
  )
  // Every timed section spans one tick, so each level stops at max_runs.
  assert_eq(overhead.off_runs, 4)
  assert_eq(overhead.count_runs, 4)
  assert_eq(overhead.full_runs, 4)
  assert_eq(overhead.off_ms, 0.25)
  assert_eq(overhead.count_ratio, 1.0)
  assert_eq(overhead.full_ratio, 1.0)
  assert_eq(overhead.steps, 6)
  assert_true(overhead.json_length > 0)
  assert_eq(overhead.full_us_per_step, 0.0)
  let report = overhead.report()
  assert_true(report.contains("## Tracing overhead"))
  assert_true(report.contains("| Full | 4 | 0.2500 | 1.00x |"))
  assert_true(report.contains("Full trace: 6 steps"))
}

///|
test "tracing overhead reports a zero ratio below clock resolution" {
  let overhead = @frontierlab.measure_tracing_overhead(
    [2, 1],
    traced_bubble_sort,
    clock=fn() { 7UL },
    max_runs=2,
  )
  assert_eq(overhead.off_runs, 2)
  assert_eq(overhead.count_ratio, 0.0)
  assert_eq(overhead.full_ratio, 0.0)
}

///|
test "tracing overhead surfaces trace errors" {
  try
    @frontierlab.measure_tracing_overhead(
      [5, 4, 3, 2, 1],
      traced_bubble_sort,
      clock=fn() { 0UL },
      max_runs=1,
      options=@frontierlab.TraceOptions::new(max_steps=3),
    )
  catch {
    LimitExceeded(_) => ()
    _ => fail("expected LimitExceeded")
  } noraise {
    _ => fail("the step limit must surface")
  }
}

///|
test "indistinguishable fits prefer the slower growth class" {
  // log2(1) is clamped to 1 and log2(2) is 1, so O(1) and O(log n) tie.
  let profile = @frontierlab.profile_complexity([1, 2], fn(_) {
    @frontierlab.OperationCounts::new(reads=3)
  })
  assert_eq(profile.best.class, @frontierlab.Constant)
  assert_eq(profile.fits[1].class, @frontierlab.Logarithmic)
  assert_true(profile.report().contains("cost ≈ 3.000 · 1 "))
}

///|
test "zero costs at small sizes still fit and skip the exponent" {
  let profile = @frontierlab.profile_complexity(
    [1, 2, 4],
    fn(n) {
      @frontierlab.OperationCounts::new(writes=if n == 4 { 5 } else { 0 })
    },
    metric=Writes,
  )
  assert_eq(profile.samples.map(fn(sample) { sample.cost }), [0, 0, 5])
  assert_eq(profile.exponent, 0.0)
  let cubic = @frontierlab.profile_complexity([2, 4, 8], fn(n) {
    @frontierlab.OperationCounts::new(swaps=n * n * n)
  })
  assert_eq(cubic.best.class, @frontierlab.Cubic)
  assert_true(cubic.report().contains("· n^3 (relative error 0.0%)"))
}

///|
test "cost metrics select the matching counter" {
  let counts = @frontierlab.OperationCounts::new(
    compares=1,
    swaps=2,
    reads=3,
    writes=4,
    snapshots=5,
  )
  let metrics : Array[@frontierlab.CostMetric] = [
    Compares,
    Swaps,
    Reads,
    Writes,
    Total,
  ]
  assert_eq(metrics.map(fn(metric) { metric.cost(counts) }), [1, 2, 3, 4, 10])
  assert_eq(metrics.map(fn(metric) { metric.name() }), [
    "compares", "swaps", "reads", "writes", "total",
  ])
}

///|
test "reports name logarithmic and exponential growth" {
  let logarithmic = @frontierlab.profile_complexity([2, 8, 64], fn(n) {
    @frontierlab.OperationCounts::new(
      reads=@frontierlab.Logarithmic.evaluate(n).to_int(),
    )
  })
  assert_true(
    logarithmic
    .report()
    .contains("Best fit: O(log n), cost ≈ 1.000 · log n "),
  )
  let exponential = @frontierlab.profile_complexity([2, 4, 8, 16], fn(n) {
    @frontierlab.OperationCounts::new(compares=1 << n)
  })
  assert_true(
    exponential.report().contains("Best fit: O(2^n), cost ≈ 1.000 · 2^n "),
  )
}
