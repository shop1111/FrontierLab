///|
/// Build the insertion-sort trace used by the bundled demo and CLI.
pub fn insertion_sort_demo_trace(values : Array[Int]) -> AlgorithmTrace raise {
  insertion_sort_trace(values)
}

///|
/// Build the Union-Find trace used by the bundled demo and CLI.
pub fn union_find_demo_trace() -> AlgorithmTrace raise {
  union_find_trace(6, [
    UnionOperation::new(left=0, right=1),
    UnionOperation::new(left=2, right=3),
    UnionOperation::new(left=1, right=3),
    UnionOperation::new(left=4, right=5),
    UnionOperation::new(left=3, right=5),
  ])
}

///|
/// Build the A* flagship trace used by the bundled demo and CLI.
pub fn pathfinding_demo_trace() -> AlgorithmTrace raise {
  let grid = GridMap::new(width=7, height=5)
    .with_obstacle(Position::new(x=2, y=0))
    .with_obstacle(Position::new(x=2, y=1))
    .with_obstacle(Position::new(x=2, y=2))
    .with_weight(Position::new(x=4, y=3), 7)
  let start = Position::new(x=0, y=0)
  let goal = Position::new(x=6, y=4)
  let search = astar_trace(grid, start~, goal~)
  search_trace_to_algorithm_trace(
    grid,
    start~,
    goal~,
    algorithm="A*",
    trace=search,
  )
}
