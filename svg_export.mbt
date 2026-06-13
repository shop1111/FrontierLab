///|
pub fn export_svg(
  grid : GridMap,
  start~ : Position,
  goal~ : Position,
  trace? : SearchTrace,
  cell_size? : Int = 32
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
  let width = grid.width * cell_size
  let height = grid.height * cell_size
  let out = StringBuilder()
  out.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \{width} \{height}\" width=\"\{width}\" height=\"\{height}\">\n",
  )
  out.write_string("<rect width=\"100%\" height=\"100%\" fill=\"#f8fafc\"/>\n")
  for y in 0..<grid.height {
    for x in 0..<grid.width {
      let pos = Position::new(x~, y~)
      svg_rect(out, pos, cell_size, svg_cell_color(grid, pos, path, visited, frontier))
    }
  }
  svg_rect(out, start, cell_size, "#22c55e")
  svg_rect(out, goal, cell_size, "#ef4444")
  svg_label(out, start, cell_size, "S")
  svg_label(out, goal, cell_size, "E")
  out.write_string("</svg>\n")
  out.to_string()
}

///|
fn svg_cell_color(
  grid : GridMap,
  position : Position,
  path : Array[Position],
  visited : Array[Position],
  frontier : Array[Position]
) -> String {
  if grid.is_obstacle(position) {
    "#111827"
  } else if path.contains(position) {
    "#facc15"
  } else if frontier.contains(position) {
    "#38bdf8"
  } else if visited.contains(position) {
    "#bfdbfe"
  } else {
    "#ffffff"
  }
}

///|
fn svg_rect(out : StringBuilder, position : Position, cell_size : Int, fill : String) -> Unit {
  let x = position.x * cell_size
  let y = position.y * cell_size
  out.write_string(
    "<rect x=\"\{x}\" y=\"\{y}\" width=\"\{cell_size}\" height=\"\{cell_size}\" fill=\"\{fill}\" stroke=\"#cbd5e1\" stroke-width=\"1\"/>\n",
  )
}

///|
fn svg_label(out : StringBuilder, position : Position, cell_size : Int, label : String) -> Unit {
  let x = position.x * cell_size + cell_size / 2
  let y = position.y * cell_size + cell_size / 2 + 5
  out.write_string(
    "<text x=\"\{x}\" y=\"\{y}\" text-anchor=\"middle\" font-family=\"monospace\" font-size=\"14\" font-weight=\"700\" fill=\"#0f172a\">\{label}</text>\n",
  )
}
