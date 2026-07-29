///|
test "consumer traces pin the stale-index fault to step 10" {
  let expected = selection_sort_trace(false)
  let actual = selection_sort_trace(true)
  assert_eq(expected.steps.length(), 14)
  assert_eq(actual.steps.length(), 14)
  match @frontierlab.first_divergence(expected, actual) {
    Some(value) => {
      assert_eq(value.step, 10)
      assert_eq(value.expected_event, "swap")
      assert_eq(value.actual_event, "swap")
    }
    None => fail("faulty trace must diverge")
  }
  match expected.steps[10].event {
    @frontierlab.Swap(left, right) => {
      assert_eq(left.entity_id, Some("item-2"))
      assert_eq(right.entity_id, Some("item-4"))
    }
    _ => fail("expected step 10 must be a swap")
  }
  match actual.steps[10].event {
    @frontierlab.Swap(left, right) => {
      assert_eq(left.entity_id, Some("item-2"))
      assert_eq(right.entity_id, Some("item-0"))
    }
    _ => fail("actual step 10 must be a swap")
  }
}

///|
test "consumer proves contract and counterexample exit semantics" {
  let expected = selection_sort_trace(false)
  let actual = selection_sort_trace(true)
  let expected_report = @frontierlab.insertion_sort_int_contract(
    object_id="values",
  ).check(expected)
  let actual_report = @frontierlab.insertion_sort_int_contract(
    object_id="values",
  ).check(actual)
  assert_true(expected_report.passed)
  assert_true(!actual_report.passed)
  assert_eq(actual_report.first_failure.unwrap().step, 13)
  let divergence = @frontierlab.first_divergence(expected, actual).unwrap()
  let counterexample = actual.slice(center=divergence.step)
  assert_eq(counterexample.original_focus, 10)
  assert_eq(counterexample.focus_step, 2)
  assert_eq(counterexample.trace.steps.length(), 5)
}
