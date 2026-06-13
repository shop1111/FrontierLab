///|
fn main raise {
  let grid = @frontierlab.GridMap::new(width=4, height=3)
    .with_obstacle(@frontierlab.Position::new(x=1, y=1))
    .with_weight(@frontierlab.Position::new(x=2, y=0), 6)
  let report = @frontierlab.compare_algorithms(
    grid,
    start=@frontierlab.Position::new(x=0, y=0),
    goal=@frontierlab.Position::new(x=3, y=0),
  )
  for entry in report.entries {
    println(
      "\{entry.algorithm}: visited=\{entry.visited_count}, length=\{entry.path_length}, cost=\{entry.total_cost}",
    )
  }
}
