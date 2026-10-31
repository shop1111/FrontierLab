///|
pub struct Position {
  x : Int32
  y : Int32
} derive(Debug, Eq, ToJson)

///|
pub extend Position with Debug::{to_repr}

///|
pub extend Position with Eq::{not_equal, equal}

///|
pub extend Position with ToJson::{to_json}

///|
pub fn Position::new(x~ : Int32, y~ : Int32) -> Position {
  { x, y, }
}

///|
pub(all) enum MoveRule {
  FourDirections
  EightDirections
} derive(Debug, Eq, ToJson)

///|
pub extend MoveRule with Debug::{to_repr}

///|
pub extend MoveRule with Eq::{not_equal, equal}

///|
pub extend MoveRule with ToJson::{to_json}

///|
struct WeightedCell {
  position : Position
  weight : Int32
} derive(Debug, Eq, ToJson)

///|
pub extend WeightedCell with Debug::{to_repr}

///|
pub extend WeightedCell with Eq::{not_equal, equal}

///|
pub extend WeightedCell with ToJson::{to_json}

///|
pub struct GridMap {
  width : Int32
  height : Int32
  obstacles : Array[Position]
  weights : Array[WeightedCell]
} derive(Debug, Eq, ToJson)

///|
pub extend GridMap with Debug::{to_repr}

///|
pub extend GridMap with Eq::{not_equal, equal}

///|
pub extend GridMap with ToJson::{to_json}

///|
pub fn GridMap::new(width~ : Int32, height~ : Int32) -> GridMap raise {
  if width <= 0 || height <= 0 {
    fail("GridMap dimensions must be positive")
  }
  { width, height, obstacles: [], weights: [], }
}

///|
pub fn GridMap::contains(self : GridMap, position : Position) -> Bool {
  position.x >= 0 &&
  position.y >= 0 &&
  position.x < self.width &&
  position.y < self.height
}

///|
pub fn GridMap::is_obstacle(self : GridMap, position : Position) -> Bool {
  self.obstacles.contains(position)
}

///|
pub fn GridMap::is_walkable(self : GridMap, position : Position) -> Bool {
  self.contains(position) && !self.is_obstacle(position)
}

///|
pub fn GridMap::with_obstacle(
  self : GridMap,
  position : Position,
) -> GridMap raise {
  if !self.contains(position) {
    fail("Obstacle position is outside the grid")
  }
  let next = self.copy()
  if !next.obstacles.contains(position) {
    next.obstacles.push(position)
  }
  next
}

///|
pub fn GridMap::with_weight(
  self : GridMap,
  position : Position,
  weight : Int32,
) -> GridMap raise {
  if !self.contains(position) {
    fail("Weighted position is outside the grid")
  }
  if weight < 0 {
    fail("GridMap weights must be non-negative")
  }
  let next = self.copy()
  let existing = next.weights.search_by(fn(cell) { cell.position == position })
  match existing {
    Some(index) => next.weights[index] = { position, weight, }
    None => next.weights.push({ position, weight, })
  }
  next
}

///|
pub fn GridMap::weight_at(self : GridMap, position : Position) -> Int32 {
  match self.weights.search_by(fn(cell) { cell.position == position }) {
    Some(index) => self.weights[index].weight
    None => 1
  }
}

///|
pub fn GridMap::neighbors(
  self : GridMap,
  position : Position,
  rule : MoveRule,
) -> Array[Position] {
  let deltas = match rule {
    FourDirections => [(0, -1), (1, 0), (0, 1), (-1, 0)]
    EightDirections =>
      [(0, -1), (1, 0), (0, 1), (-1, 0), (1, -1), (1, 1), (-1, 1), (-1, -1)]
  }
  let out : Array[Position] = []
  for delta in deltas {
    let (dx, dy) = delta
    let next = Position::new(x=position.x + dx, y=position.y + dy)
    if self.is_walkable(next) {
      out.push(next)
    }
  }
  out
}

///|
fn GridMap::copy(self : GridMap) -> GridMap {
  {
    width: self.width,
    height: self.height,
    obstacles: self.obstacles.copy(),
    weights: self.weights.copy(),
  }
}
