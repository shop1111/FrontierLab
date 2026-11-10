///|
fn main raise {
  let trace = @frontierlab.union_find_trace(6, [
    @frontierlab.UnionOperation::new(left=0, right=1),
    @frontierlab.UnionOperation::new(left=2, right=3),
    @frontierlab.UnionOperation::new(left=1, right=3),
    @frontierlab.UnionOperation::new(left=4, right=5),
    @frontierlab.UnionOperation::new(left=3, right=5),
  ])
  println(@frontierlab.render_trace_html(trace))
}
