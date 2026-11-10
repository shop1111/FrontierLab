///|
fn main raise {
  let trace = @frontierlab.insertion_sort_trace([5, 2, 4, 1, 3])
  println(@frontierlab.render_trace_html(trace))
}
