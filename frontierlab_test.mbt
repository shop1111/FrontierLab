///|
test "GridMap tracks bounds obstacles weights and four-way neighbors" {
  let start = @frontierlab.Position::new(x=1, y=1)
  let blocked = @frontierlab.Position::new(x=1, y=0)
  let weighted = @frontierlab.Position::new(x=2, y=1)
  let grid = @frontierlab.GridMap::new(width=3, height=3)
    .with_obstacle(blocked)
    .with_weight(weighted, 7)
  assert_true(grid.contains(start))
  assert_false(grid.contains(@frontierlab.Position::new(x=3, y=1)))
  assert_true(grid.is_obstacle(blocked))
  assert_false(grid.is_walkable(blocked))
  assert_eq(grid.weight_at(weighted), 7)
  assert_eq(grid.weight_at(start), 1)
  debug_inspect(
    grid.neighbors(start, @frontierlab.FourDirections),
    content=(
      #|[{ x: 2, y: 1 }, { x: 1, y: 2 }, { x: 0, y: 1 }]

    ),
  )
}

///|
test "GridMap supports eight-way neighbors" {
  let grid = @frontierlab.GridMap::new(width=3, height=3)
  debug_inspect(
    grid.neighbors(
      @frontierlab.Position::new(x=1, y=1),
      @frontierlab.EightDirections,
    ),
    content=(
      #|[
      #|  { x: 1, y: 0 },
      #|  { x: 2, y: 1 },
      #|  { x: 1, y: 2 },
      #|  { x: 0, y: 1 },
      #|  { x: 2, y: 0 },
      #|  { x: 2, y: 2 },
      #|  { x: 0, y: 2 },
      #|  { x: 0, y: 0 },
      #|]

    ),
  )
}

///|
test "SearchTrace stores stable step snapshots" {
  let start = @frontierlab.Position::new(x=0, y=0)
  let goal = @frontierlab.Position::new(x=1, y=0)
  let frontier = [goal]
  let visited = [start]
  let costs = [@frontierlab.CostEntry::new(position=start, cost=0)]
  let parents = [@frontierlab.ParentLink::new(child=goal, parent=start)]
  let step = @frontierlab.TraceStep::new(
    current=Some(start),
    frontier~,
    visited~,
    cost=costs,
    parent=parents,
  )
  frontier.clear()
  visited.clear()
  debug_inspect(
    step,
    content=(
      #|{
      #|  current: Some({ x: 0, y: 0 }),
      #|  frontier: [{ x: 1, y: 0 }],
      #|  visited: [{ x: 0, y: 0 }],
      #|  cost: [{ position: { x: 0, y: 0 }, cost: 0 }],
      #|  parent: [{ child: { x: 1, y: 0 }, parent: { x: 0, y: 0 } }],
      #|}


    ),
  )
}

///|
test "BFS finds the shortest unweighted path" {
  let grid = @frontierlab.GridMap::new(width=4, height=3)
    .with_obstacle(@frontierlab.Position::new(x=1, y=0))
    .with_obstacle(@frontierlab.Position::new(x=1, y=1))
  let result = @frontierlab.bfs(
    grid,
    start=@frontierlab.Position::new(x=0, y=0),
    goal=@frontierlab.Position::new(x=3, y=0),
  )
  assert_true(result.reachable)
  assert_eq(result.cost, 7)
  debug_inspect(
    result.path,
    content=(
      #|[
      #|  { x: 0, y: 0 },
      #|  { x: 0, y: 1 },
      #|  { x: 0, y: 2 },
      #|  { x: 1, y: 2 },
      #|  { x: 2, y: 2 },
      #|  { x: 2, y: 1 },
      #|  { x: 2, y: 0 },
      #|  { x: 3, y: 0 },
      #|]


    ),
  )
}

///|
test "BFS handles unreachable and start equals goal" {
  let blocked = @frontierlab.GridMap::new(width=2, height=2)
    .with_obstacle(@frontierlab.Position::new(x=1, y=0))
    .with_obstacle(@frontierlab.Position::new(x=0, y=1))
  let result = @frontierlab.bfs(
    blocked,
    start=@frontierlab.Position::new(x=0, y=0),
    goal=@frontierlab.Position::new(x=1, y=1),
  )
  assert_false(result.reachable)
  let same = @frontierlab.bfs(
    blocked,
    start=@frontierlab.Position::new(x=0, y=0),
    goal=@frontierlab.Position::new(x=0, y=0),
  )
  assert_true(same.reachable)
  assert_eq(same.cost, 0)
}

///|
test "BFS trace result matches normal search" {
  let grid = @frontierlab.GridMap::new(width=3, height=1)
  let start = @frontierlab.Position::new(x=0, y=0)
  let goal = @frontierlab.Position::new(x=2, y=0)
  let result = @frontierlab.bfs(grid, start~, goal~)
  let trace = @frontierlab.bfs_trace(grid, start~, goal~)
  assert_true(trace.result == result)
  assert_true(trace.steps.length() > 0)
}
