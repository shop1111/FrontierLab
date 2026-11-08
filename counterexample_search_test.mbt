///|
fn search_insertion_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for i in 1..<a.length() {
    let mut j = i
    while j > 0 && a.less(j, j - 1) {
      a.swap(j, j - 1)
      j -= 1
    }
  }
}

///|
/// Never compares with position 0.
fn off_by_one_insertion_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for i in 1..<a.length() {
    let mut j = i
    while j > 1 && a.less(j, j - 1) {
      a.swap(j, j - 1)
      j -= 1
    }
  }
}

///|
fn shift_insertion_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for i in 1..<a.length() {
    let key = a[i]
    let mut j = i
    while j > 0 && a[j - 1] > key {
      a[j] = a[j - 1]
      j -= 1
    }
    if j != i {
      a[j] = key
    }
  }
}

///|
/// Forgets to store the key when it belongs at position 0.
fn lossy_shift_insertion_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for i in 1..<a.length() {
    let key = a[i]
    let mut j = i
    while j > 0 && a[j - 1] > key {
      a[j] = a[j - 1]
      j -= 1
    }
    if j != i && j > 0 {
      a[j] = key
    }
  }
}

///|
fn search_bubble_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for end = a.length() - 1; end > 0; end = end - 1 {
    for i in 0..<end {
      if a.less(i + 1, i) {
        a.swap(i, i + 1)
      }
    }
  }
}

///|
/// Correct only when no value repeats.
fn duplicate_blind_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  search_insertion_sort(a)
  for i in 1..<a.length() {
    if a[i] == a[i - 1] {
      a[i] = a[i] + 1
    }
  }
}

///|
test "search shrinks an off-by-one sort to a two-element input" {
  let found = @frontierlab.search_sequence_counterexample(
    off_by_one_insertion_sort,
  ).unwrap()
  assert_eq(found.input, [1, 0])
  assert_eq(found.actual_output, [1, 0])
  assert_true(found.expected_output is None)
  assert_true(found.expected_trace is None)
  assert_true(found.original_input.length() >= found.input.length())
  assert_true(found.cases_tried >= 1)
  assert_eq(
    found.diagnosis.contract_report.contract_name,
    "sorted-int-sequence",
  )
  assert_eq(
    found.diagnosis.contract_report.first_failure.unwrap().code,
    "result-not-sorted",
  )
  inspect(
    found.report(),
    content=(
      #|## Counterexample
      #|
      #|Found after 1 case (seed 1) and shrunk from [9, 0] to [1, 0] in 1 step.
      #|
      #|- Input: [1, 0]
      #|- Actual output: [1, 0]
      #|- Failure: output [1, 0] is not sorted
      #|- Contract sorted-int-sequence: result-not-sorted at step 0: Final sequence contains inversion 1 > 0.
      #|- Focus step 0: complete (The algorithm finished.)
      #|
    ),
  )
}

///|
test "search with a reference locates the first divergent step" {
  let found = @frontierlab.search_sequence_counterexample(
    off_by_one_insertion_sort,
    reference=search_insertion_sort,
  ).unwrap()
  assert_eq(found.input, [1, 0])
  assert_eq(found.expected_output, Some([0, 1]))
  let divergence = found.diagnosis.divergence.unwrap()
  assert_eq(divergence.step, 0)
  assert_eq(found.diagnosis.focus_step, 0)
  inspect(
    found.report(),
    content=(
      #|## Counterexample
      #|
      #|Found after 1 case (seed 1) and shrunk from [9, 0] to [1, 0] in 1 step.
      #|
      #|- Input: [1, 0]
      #|- Actual output: [1, 0]
      #|- Reference output: [0, 1]
      #|- Failure: output [1, 0] differs from reference [0, 1]
      #|- First divergence: step 0, expected compare(item-1, item-0), actual complete
      #|- Contract sequence-transition: PASS
      #|- Focus step 0: complete (The algorithm finished.)
      #|
    ),
  )
}

///|
test "search accepts Update traces and catches lost values" {
  assert_true(
    @frontierlab.search_sequence_counterexample(shift_insertion_sort) is None,
  )
  let found = @frontierlab.search_sequence_counterexample(
    lossy_shift_insertion_sort,
    reference=shift_insertion_sort,
  ).unwrap()
  assert_eq(found.input, [1, 0])
  assert_eq(found.actual_output, [1, 1])
  inspect(
    found.report(),
    content=(
      #|## Counterexample
      #|
      #|Found after 1 case (seed 1) and shrunk from [9, 0] to [1, 0] in 1 step.
      #|
      #|- Input: [1, 0]
      #|- Actual output: [1, 1]
      #|- Reference output: [0, 1]
      #|- Failure: output [1, 1] differs from reference [0, 1]
      #|- First divergence: step 1, expected update(item-0), actual complete
      #|- Contract sequence-transition: PASS
      #|- Focus step 1: complete (The algorithm finished.)
      #|
    ),
  )
  let alone = @frontierlab.search_sequence_counterexample(
    lossy_shift_insertion_sort,
  ).unwrap()
  assert_eq(
    alone.diagnosis.contract_report.first_failure.unwrap().code,
    "result-not-permutation",
  )
}

///|
test "search finds bugs that need repeated values" {
  let found = @frontierlab.search_sequence_counterexample(duplicate_blind_sort).unwrap()
  assert_eq(found.input, [0, 0])
  assert_eq(found.actual_output, [0, 1])
}

///|
test "match_events separates algorithms with equal outputs" {
  assert_true(
    @frontierlab.search_sequence_counterexample(
      search_bubble_sort,
      reference=search_insertion_sort,
    )
    is None,
  )
  let found = @frontierlab.search_sequence_counterexample(
    search_bubble_sort,
    reference=search_insertion_sort,
    match_events=true,
  ).unwrap()
  debug_inspect(
    found.input,
    content=(
      #|[0, 0, 0]
    ),
  )
  inspect(
    found.reason,
    content=(
      #|operations diverge at step 2: expected complete, actual compare(item-1, item-0)
    ),
  )
}

///|
test "search uses a custom property and contract" {
  let found = @frontierlab.search_sequence_counterexample(
    search_insertion_sort,
    check=fn(input, output) {
      if output.length() == input.length() && output.length() < 3 {
        None
      } else {
        Some("length \{output.length()} is too long")
      }
    },
    contract=@frontierlab.sequence_transition_contract(object_id="values"),
  ).unwrap()
  assert_eq(found.input, [0, 0, 0])
  assert_eq(found.reason, "length 3 is too long")
  assert_true(found.diagnosis.passed())
}

///|
test "search is deterministic per seed and validates options" {
  let first = @frontierlab.search_sequence_counterexample(
    off_by_one_insertion_sort,
    seed=42,
  ).unwrap()
  let again = @frontierlab.search_sequence_counterexample(
    off_by_one_insertion_sort,
    seed=42,
  ).unwrap()
  assert_eq(first, again)
  assert_eq(first.seed, 42)
  let unshrunk = @frontierlab.search_sequence_counterexample(
    off_by_one_insertion_sort,
    max_shrinks=0,
  ).unwrap()
  assert_eq(unshrunk.input, unshrunk.original_input)
  assert_eq(unshrunk.shrink_steps, 0)
  let one_attempt = @frontierlab.search_sequence_counterexample(
    off_by_one_insertion_sort,
    max_shrinks=1,
  ).unwrap()
  assert_eq(one_attempt.input, one_attempt.original_input)
  for
    bad in [
      fn() raise @frontierlab.TraceError {
        ignore(
          @frontierlab.search_sequence_counterexample(
            search_bubble_sort,
            cases=0,
          ),
        )
      },
      fn() raise @frontierlab.TraceError {
        ignore(
          @frontierlab.search_sequence_counterexample(
            search_bubble_sort,
            max_length=-1,
          ),
        )
      },
      fn() raise @frontierlab.TraceError {
        ignore(
          @frontierlab.search_sequence_counterexample(
            search_bubble_sort,
            match_events=true,
          ),
        )
      },
    ] {
    try bad() catch {
      InvalidStep(_) => ()
      _ => fail("expected InvalidStep")
    } noraise {
      _ => fail("invalid search options must raise")
    }
  }
}
