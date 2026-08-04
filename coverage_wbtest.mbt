///|
test "render helper branches remain covered" {
  let grid = GridMap::new(width=3, height=1)
  let start = Position::new(x=0, y=0)
  let middle = Position::new(x=1, y=0)
  let goal = Position::new(x=2, y=0)
  assert_eq(ascii_cell(grid, middle, start, goal, [], [], [middle]), 'F')
  assert_eq(ascii_cell(grid, middle, start, goal, [], [middle], []), '.')
  assert_eq(svg_cell_color(grid, middle, [], [], [middle]), "#38bdf8")
  assert_eq(svg_cell_color(grid, middle, [], [middle], []), "#bfdbfe")
}

///|
test "search trace maintenance and fallback branches remain covered" {
  let first = Position::new(x=0, y=0)
  let second = Position::new(x=1, y=0)
  let costs = [CostEntry::new(position=first, cost=1)]
  cost_put(costs, first, 2)
  assert_eq(costs[0].cost, 2)
  let parents = [ParentLink::new(child=second, parent=first)]
  parent_put(parents, second, second)
  assert_eq(parents[0].parent, second)
  assert_eq(reconstruct_path(first, second, []), [])
  assert_eq(search_cost_label([], first), "?")
  let grid = GridMap::new(width=2, height=1)
  let empty = SearchTrace::new(result=PathResult::not_found(visited_count=0), steps=[])
  let converted = search_trace_to_algorithm_trace(
    grid,
    start=first,
    goal=second,
    algorithm="empty-search",
    trace=empty,
  )
  assert_eq(converted.steps.length(), 1)
  let exhausted = SearchTrace::new(
    result=PathResult::not_found(visited_count=0),
    steps=[
      TraceStep::new(current=None, frontier=[], visited=[], cost=[], parent=[]),
    ],
  )
  let exhausted_trace = search_trace_to_algorithm_trace(
    grid,
    start=first,
    goal=second,
    algorithm="exhausted-search",
    trace=exhausted,
  )
  assert_true(exhausted_trace.steps[0].event is Custom("frontier-empty", _))
  assert_eq(
    TraceError::AlreadyCompleted.message(),
    "Cannot record after Complete",
  )
}
