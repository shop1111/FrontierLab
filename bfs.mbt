///|
pub fn bfs(
  grid : GridMap,
  start~ : Position,
  goal~ : Position,
  rule? : MoveRule = FourDirections,
) -> PathResult raise {
  bfs_trace(grid, start~, goal~, rule~).result
}

///|
pub fn bfs_trace(
  grid : GridMap,
  start~ : Position,
  goal~ : Position,
  rule? : MoveRule = FourDirections,
) -> SearchTrace raise {
  ensure_search_points(grid, start, goal)
  let queue : Array[Position] = [start]
  let visited : Array[Position] = [start]
  let costs : Array[CostEntry] = [CostEntry::new(position=start, cost=0)]
  let parents : Array[ParentLink] = []
  let steps : Array[TraceStep] = [
    TraceStep::new(
      current=Some(start),
      frontier=queue_frontier(queue, 0),
      visited~,
      cost=costs,
      parent=parents,
    ),
  ]
  if start == goal {
    let result = PathResult::found(path=[start], cost=0, visited_count=1)
    return SearchTrace::new(result~, steps~)
  }
  for head = 0; head < queue.length(); {
    let current = queue[head]
    for next in grid.neighbors(current, rule) {
      if !visited.contains(next) {
        visited.push(next)
        queue.push(next)
        let next_cost = match cost_lookup(costs, current) {
          Some(cost) => cost + 1
          None => 1
        }
        cost_put(costs, next, next_cost)
        parent_put(parents, next, current)
        steps.push(
          TraceStep::new(
            current=Some(current),
            frontier=queue_frontier(queue, head + 1),
            visited~,
            cost=costs,
            parent=parents,
          ),
        )
        if next == goal {
          let path = reconstruct_path(start, goal, parents)
          let result = PathResult::found(
            path~,
            cost=next_cost,
            visited_count=visited.length(),
          )
          return SearchTrace::new(result~, steps~)
        }
      }
    }
    continue head + 1
  }
  let result = PathResult::not_found(visited_count=visited.length())
  steps.push(
    TraceStep::new(
      current=None,
      frontier=[],
      visited~,
      cost=costs,
      parent=parents,
    ),
  )
  SearchTrace::new(result~, steps~)
}

///|
fn ensure_search_points(
  grid : GridMap,
  start : Position,
  goal : Position,
) -> Unit raise {
  if !grid.is_walkable(start) {
    fail("Search start must be inside the grid and walkable")
  }
  if !grid.is_walkable(goal) {
    fail("Search goal must be inside the grid and walkable")
  }
}

///|
fn queue_frontier(queue : Array[Position], head : Int) -> Array[Position] {
  let out : Array[Position] = []
  for i in head..<queue.length() {
    out.push(queue[i])
  }
  out
}
