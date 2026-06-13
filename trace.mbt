///|
pub struct CostEntry {
  position : Position
  cost : Int
} derive(Debug, Eq, ToJson)

///|
pub struct ParentLink {
  child : Position
  parent : Position
} derive(Debug, Eq, ToJson)

///|
pub struct PathResult {
  reachable : Bool
  path : Array[Position]
  cost : Int
  visited_count : Int
} derive(Debug, Eq, ToJson)

///|
pub fn PathResult::found(
  path~ : Array[Position],
  cost~ : Int,
  visited_count~ : Int,
) -> PathResult {
  { reachable: true, path, cost, visited_count }
}

///|
pub fn PathResult::not_found(visited_count~ : Int) -> PathResult {
  { reachable: false, path: [], cost: 0, visited_count }
}

///|
pub struct TraceStep {
  current : Position?
  frontier : Array[Position]
  visited : Array[Position]
  cost : Array[CostEntry]
  parent : Array[ParentLink]
} derive(Debug, Eq, ToJson)

///|
pub fn TraceStep::new(
  current~ : Position?,
  frontier~ : Array[Position],
  visited~ : Array[Position],
  cost~ : Array[CostEntry],
  parent~ : Array[ParentLink],
) -> TraceStep {
  {
    current,
    frontier: frontier.copy(),
    visited: visited.copy(),
    cost: cost.copy(),
    parent: parent.copy(),
  }
}

///|
pub struct SearchTrace {
  result : PathResult
  steps : Array[TraceStep]
} derive(Debug, Eq, ToJson)

///|
pub fn SearchTrace::new(
  result~ : PathResult,
  steps~ : Array[TraceStep],
) -> SearchTrace {
  { result, steps }
}

///|
pub fn CostEntry::new(position~ : Position, cost~ : Int) -> CostEntry {
  { position, cost }
}

///|
pub fn ParentLink::new(child~ : Position, parent~ : Position) -> ParentLink {
  { child, parent }
}

///|
fn cost_lookup(entries : Array[CostEntry], position : Position) -> Int? {
  match entries.search_by(fn(entry) { entry.position == position }) {
    Some(index) => Some(entries[index].cost)
    None => None
  }
}

///|
fn cost_put(
  entries : Array[CostEntry],
  position : Position,
  cost : Int,
) -> Unit {
  match entries.search_by(fn(entry) { entry.position == position }) {
    Some(index) => entries[index] = { position, cost }
    None => entries.push({ position, cost })
  }
}

///|
fn parent_put(
  entries : Array[ParentLink],
  child : Position,
  parent : Position,
) -> Unit {
  match entries.search_by(fn(entry) { entry.child == child }) {
    Some(index) => entries[index] = { child, parent }
    None => entries.push({ child, parent })
  }
}

///|
fn reconstruct_path(
  start : Position,
  goal : Position,
  parents : Array[ParentLink],
) -> Array[Position] {
  let reversed : Array[Position] = [goal]
  for current = goal; current != start; {
    match parents.search_by(fn(link) { link.child == current }) {
      Some(index) => {
        let parent = parents[index].parent
        reversed.push(parent)
        continue parent
      }
      None => {
        reversed.clear()
        continue start
      }
    }
  }
  reversed.rev()
}
