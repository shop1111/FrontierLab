///|
fn main raise {
  let grid = @frontierlab.GridMap::new(width=6, height=4)
    .with_obstacle(@frontierlab.Position::new(x=1, y=0))
    .with_obstacle(@frontierlab.Position::new(x=1, y=1))
    .with_obstacle(@frontierlab.Position::new(x=3, y=1))
    .with_obstacle(@frontierlab.Position::new(x=3, y=2))
  let start = @frontierlab.Position::new(x=0, y=0)
  let goal = @frontierlab.Position::new(x=5, y=3)
  let trace = @frontierlab.bfs_trace(grid, start~, goal~)
  println(@frontierlab.export_ascii(grid, start~, goal~, trace~))
}
