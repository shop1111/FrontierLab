///|
/// A textbook bubble sort, used as the reference.
fn bubble_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for end = a.length() - 1; end > 0; end = end - 1 {
    for i in 0..<end {
      if a.less(i + 1, i) {
        a.swap(i, i + 1)
      }
    }
  }
}

///|
/// Bubble sort with an early exit, as an assistant might write it: the
/// "no swaps, so we are done" check sits inside the inner loop instead of
/// after it.
fn generated_bubble_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for end = a.length() - 1; end > 0; end = end - 1 {
    let mut swapped = false
    for i in 0..<end {
      if a.less(i + 1, i) {
        a.swap(i, i + 1)
        swapped = true
      }
      if !swapped {
        return
      }
    }
  }
}

///|
fn main raise {
  match
    @frontierlab.search_sequence_counterexample(
      generated_bubble_sort,
      reference=bubble_sort,
    ) {
    Some(found) => println(found.report())
    None => println("No counterexample found.")
  }
}
