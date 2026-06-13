///|
pub fn dijkstra(
  grid : GridMap,
  start~ : Position,
  goal~ : Position,
  rule? : MoveRule = FourDirections
) -> PathResult raise {
  dijkstra_trace(grid, start~, goal~, rule~).result
}

///|
pub fn dijkstra_trace(
  grid : GridMap,
  start~ : Position,
  goal~ : Position,
  rule? : MoveRule = FourDirections
) -> SearchTrace raise {
  ensure_search_points(grid, start, goal)
  let frontier : Array[Position] = [start]
  let visited : Array[Position] = []
  let costs : Array[CostEntry] = [CostEntry::new(position=start, cost=0)]
  let parents : Array[ParentLink] = []
  let steps : Array[TraceStep] = [
    TraceStep::new(
      current=Some(start),
      frontier~,
      visited~,
      cost=costs,
      parent=parents,
    ),
  ]
  if start == goal {
    let result = PathResult::found(path=[start], cost=0, visited_count=1)
    return SearchTrace::new(result~, steps~)
  }
  while !frontier.is_empty() {
    let index = cheapest_frontier_index(frontier, costs)
    let current = frontier.remove(index)
    if visited.contains(current) {
      continue
    }
    visited.push(current)
    if current == goal {
      let total = cost_lookup(costs, goal).unwrap()
      let path = reconstruct_path(start, goal, parents)
      let result = PathResult::found(
        path~,
        cost=total,
        visited_count=visited.length(),
      )
      steps.push(
        TraceStep::new(
          current=Some(current),
          frontier~,
          visited~,
          cost=costs,
          parent=parents,
        ),
      )
      return SearchTrace::new(result~, steps~)
    }
    let current_cost = cost_lookup(costs, current).unwrap()
    for next in grid.neighbors(current, rule) {
      if !visited.contains(next) {
        let next_cost = current_cost + grid.weight_at(next)
        match cost_lookup(costs, next) {
          Some(existing) =>
            if next_cost < existing {
              cost_put(costs, next, next_cost)
              parent_put(parents, next, current)
              if !frontier.contains(next) {
                frontier.push(next)
              }
            }
          None => {
            cost_put(costs, next, next_cost)
            parent_put(parents, next, current)
            frontier.push(next)
          }
        }
      }
    }
    steps.push(
      TraceStep::new(
        current=Some(current),
        frontier~,
        visited~,
        cost=costs,
        parent=parents,
      ),
    )
  }
  let result = PathResult::not_found(visited_count=visited.length())
  steps.push(
    TraceStep::new(
      current=None,
      frontier~,
      visited~,
      cost=costs,
      parent=parents,
    ),
  )
  SearchTrace::new(result~, steps~)
}

///|
fn cheapest_frontier_index(frontier : Array[Position], costs : Array[CostEntry]) -> Int {
  let mut best_index = 0
  let mut best_cost = cost_lookup(costs, frontier[0]).unwrap()
  for i in 1..<frontier.length() {
    let cost = cost_lookup(costs, frontier[i]).unwrap()
    if cost < best_cost {
      best_index = i
      best_cost = cost
    }
  }
  best_index
}
