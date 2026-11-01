///|
fn profile_bubble_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for end = a.length() - 1; end > 0; end = end - 1 {
    for i in 0..<end {
      if a.less(i + 1, i) {
        a.swap(i, i + 1)
      }
    }
  }
}

///|
fn profile_insertion_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for i in 1..<a.length() {
    let mut j = i
    while j > 0 && a.less(j, j - 1) {
      a.swap(j, j - 1)
      j -= 1
    }
  }
}

///|
fn profile_selection_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for i in 0..<(a.length() - 1) {
    let mut smallest = i
    for j in (i + 1)..<a.length() {
      if a.less(j, smallest) {
        smallest = j
      }
    }
    if smallest != i {
      a.swap(i, smallest)
    }
  }
}

///|
fn profile_sift_down(
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
fn profile_heap_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  let n = a.length()
  for start = n / 2 - 1; start >= 0; start = start - 1 {
    profile_sift_down(a, start, n)
  }
  for end = n - 1; end > 0; end = end - 1 {
    a.swap(0, end)
    profile_sift_down(a, 0, end)
  }
}

///|
/// Lomuto quicksort with the last element as pivot, so sorted input shows the
/// quadratic worst case. It recurses into the smaller part to bound the stack.
fn profile_quick_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  fn sort(lo : Int32, hi : Int32) -> Unit {
    let mut lo = lo
    let mut hi = hi
    while lo < hi {
      let mut store = lo
      for j in lo..<hi {
        if a.less(j, hi) {
          if j != store {
            a.swap(j, store)
          }
          store += 1
        }
      }
      if store != hi {
        a.swap(store, hi)
      }
      if store - lo < hi - store {
        sort(lo, store - 1)
        lo = store + 1
      } else {
        sort(store + 1, hi)
        hi = store - 1
      }
    }
  }

  sort(0, a.length() - 1)
}

///|
fn profile_algorithm(
  name : String,
) -> ((@frontierlab.TracedArray[Int32]) -> Unit) raise {
  match name {
    "bubble-sort" => profile_bubble_sort
    "insertion-sort" => profile_insertion_sort
    "selection-sort" => profile_selection_sort
    "heap-sort" => profile_heap_sort
    "quick-sort" => profile_quick_sort
    other => fail("Unknown profile algorithm: \{other}")
  }
}

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
fn profile_metric(name : String) -> @frontierlab.CostMetric raise {
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
  let algorithm = profile_algorithm(algorithm_name)
  let input_name = option(args, "--input", "random")
  let input = profile_input(input_name)
  let format = debug_format(args)
  let profile = @frontierlab.profile_traced_array(
    profile_sizes(option(args, "--sizes", "64,128,256,512,1024")),
    input,
    algorithm,
    metric=profile_metric(option(args, "--metric", "compares")),
  )
  let bound_text = option(args, "--bound", "")
  let bound = if bound_text == "" {
    None
  } else {
    match @frontierlab.ComplexityClass::parse(bound_text) {
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
      @frontierlab.measure_tracing_overhead(
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
