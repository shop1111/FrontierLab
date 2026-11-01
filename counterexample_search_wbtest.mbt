///|
test "search helpers label steps counts and shrink candidates" {
  let array = TracedArray::new([2, 1])
  array.swap(1, 0)
  let trace = array.finish()
  assert_eq(step_label(trace, 0), "swap(item-1, item-0)")
  assert_eq(step_label(trace, 1), "complete")
  assert_eq(step_label(trace, 2), "end of trace")
  assert_eq(step_label(trace, -1), "end of trace")
  assert_eq(count_label(1, "case"), "1 case")
  assert_eq(count_label(0, "step"), "0 steps")
  assert_eq(format_values([]), "[]")
  assert_eq(shrink_candidates([5, 9, 5]), [
    [],
    [9, 5],
    [5, 5],
    [5, 9],
    [0, 1, 0],
    [0, 9, 5],
    [2, 9, 5],
    [4, 9, 5],
    [5, 0, 5],
    [5, 4, 5],
    [5, 8, 5],
    [5, 9, 0],
    [5, 9, 2],
    [5, 9, 4],
  ])
}
