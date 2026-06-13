///|
pub(all) enum Heuristic {
  Manhattan
  Chebyshev
  Zero
} derive(Debug, Eq, ToJson)

///|
pub fn heuristic_distance(
  kind : Heuristic,
  from : Position,
  to : Position,
) -> Int {
  let dx = abs_int(from.x - to.x)
  let dy = abs_int(from.y - to.y)
  match kind {
    Manhattan => dx + dy
    Chebyshev => if dx > dy { dx } else { dy }
    Zero => 0
  }
}

///|
pub fn astar(
  grid : GridMap,
  start~ : Position,
  goal~ : Position,
  rule? : MoveRule = FourDirections,
  heuristic? : Heuristic = Manhattan,
) -> PathResult raise {
  astar_trace(grid, start~, goal~, rule~, heuristic~).result
}

///|
pub fn astar_trace(
  grid : GridMap,
  start~ : Position,
  goal~ : Position,
  rule? : MoveRule = FourDirections,
  heuristic? : Heuristic = Manhattan,
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
    let index = astar_frontier_index(frontier, costs, goal, heuristic)
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
fn astar_frontier_index(
  frontier : Array[Position],
  costs : Array[CostEntry],
  goal : Position,
  heuristic : Heuristic,
) -> Int {
  let mut best_index = 0
  let mut best_score = astar_score(frontier[0], costs, goal, heuristic)
  for i in 1..<frontier.length() {
    let score = astar_score(frontier[i], costs, goal, heuristic)
    if score < best_score {
      best_index = i
      best_score = score
    }
  }
  best_index
}

///|
fn astar_score(
  position : Position,
  costs : Array[CostEntry],
  goal : Position,
  heuristic : Heuristic,
) -> Int {
  cost_lookup(costs, position).unwrap() +
  heuristic_distance(heuristic, position, goal)
}

///|
fn abs_int(value : Int) -> Int {
  if value < 0 {
    0 - value
  } else {
    value
  }
}
