///|
fn main raise {
  let grid = @frontierlab.GridMap::new(width=5, height=3)
    .with_weight(@frontierlab.Position::new(x=1, y=0), 8)
    .with_weight(@frontierlab.Position::new(x=2, y=0), 8)
    .with_weight(@frontierlab.Position::new(x=3, y=0), 8)
  let start = @frontierlab.Position::new(x=0, y=0)
  let goal = @frontierlab.Position::new(x=4, y=0)
  let trace = @frontierlab.astar_trace(
    grid,
    start~,
    goal~,
    heuristic=@frontierlab.Manhattan,
  )
  println(@frontierlab.export_ascii(grid, start~, goal~, trace~))
  println("cost: \{trace.result.cost}")
}
