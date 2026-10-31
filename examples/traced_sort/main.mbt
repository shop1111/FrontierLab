///|
/// An ordinary bubble sort. The only FrontierLab-specific part is the
/// parameter type: `TracedArray` records every comparison and swap.
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
fn main raise {
  let a = @frontierlab.TracedArray::new(
    [5, 2, 4, 1, 3],
    title="Bubble sort",
    algorithm="bubble-sort",
  )
  bubble_sort(a)
  println(@frontierlab.render_trace_html(a.finish()))
}
