///|
pub struct AlgorithmReport {
  algorithm : String
  reachable : Bool
  visited_count : Int32
  path_length : Int32
  total_cost : Int32
} derive(Debug, Eq, ToJson)

///|
pub extend AlgorithmReport with Debug::{to_repr}

///|
pub extend AlgorithmReport with Eq::{not_equal, equal}

///|
pub extend AlgorithmReport with ToJson::{to_json}

///|
pub struct CompareReport {
  entries : Array[AlgorithmReport]
} derive(Debug, Eq, ToJson)

///|
pub extend CompareReport with Debug::{to_repr}

///|
pub extend CompareReport with Eq::{not_equal, equal}

///|
pub extend CompareReport with ToJson::{to_json}

///|
pub fn compare_algorithms(
  grid : GridMap,
  start~ : Position,
  goal~ : Position,
  rule~ : MoveRule = FourDirections,
  heuristic~ : Heuristic = Manhattan,
) -> CompareReport raise {
  {
    entries: [
      AlgorithmReport::from_result("BFS", bfs(grid, start~, goal~, rule~)),
      AlgorithmReport::from_result(
        "Dijkstra",
        dijkstra(grid, start~, goal~, rule~),
      ),
      AlgorithmReport::from_result(
        "A*",
        astar(grid, start~, goal~, rule~, heuristic~),
      ),
    ],
  }
}

///|
pub fn AlgorithmReport::from_result(
  algorithm : String,
  result : PathResult,
) -> AlgorithmReport {
  {
    algorithm,
    reachable: result.reachable,
    visited_count: result.visited_count,
    path_length: if result.reachable {
      result.path.length() - 1
    } else {
      0
    },
    total_cost: result.cost,
  }
}
