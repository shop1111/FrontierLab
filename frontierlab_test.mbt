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
