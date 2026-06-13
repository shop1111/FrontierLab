///|
pub fn export_ascii(
  grid : GridMap,
  start~ : Position,
  goal~ : Position,
  trace? : SearchTrace
) -> String {
  let path = match trace {
    Some(t) => t.result.path
    None => []
  }
  let last_step = match trace {
    Some(t) => t.steps.last()
    None => None
  }
  let visited = match last_step {
    Some(step) => step.visited
    None => []
  }
  let frontier = match last_step {
    Some(step) => step.frontier
    None => []
  }
  let out = StringBuilder()
  for y in 0..<grid.height {
    for x in 0..<grid.width {
      let pos = Position::new(x~, y~)
      out.write_char(ascii_cell(grid, pos, start, goal, path, visited, frontier))
    }
    if y + 1 < grid.height {
      out.write_char('\n')
    }
  }
  out.to_string()
}

///|
fn ascii_cell(
  grid : GridMap,
  position : Position,
  start : Position,
  goal : Position,
  path : Array[Position],
  visited : Array[Position],
  frontier : Array[Position]
) -> Char {
  if position == start {
    'S'
  } else if position == goal {
    'E'
  } else if grid.is_obstacle(position) {
    '#'
  } else if path.contains(position) {
    '*'
  } else if frontier.contains(position) {
    'F'
  } else if visited.contains(position) {
    '.'
  } else {
    ' '
  }
}
