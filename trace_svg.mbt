///|
/// Render one trace frame as a deterministic, standalone SVG document.
pub fn render_trace_svg(
  trace : AlgorithmTrace,
  step? : Int = -1,
  width? : Int = 900,
) -> String raise {
  let scene = trace_scene_at(trace, step)
  let height = scene_height(scene)
  let out = StringBuilder()
  out.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \{width} \{height}\" width=\"\{width}\" height=\"\{height}\" role=\"img\">\n",
  )
  out.write_string("<rect width=\"100%\" height=\"100%\" fill=\"#0f172a\"/>\n")
  svg_text(out, 28, 38, trace.title, 24, "#f8fafc")
  svg_text(out, 28, 64, trace.algorithm, 14, "#94a3b8")
  let mut y = 92
  for object in scene.objects {
    match object {
      Sequence(value) => y = render_sequence_svg(out, value, scene, y)
      Sets(value) => y = render_sets_svg(out, value, scene, y)
      Graph(value) => y = render_graph_svg(out, value, scene, y)
      Grid(value) => y = render_grid_svg(out, value, scene, y)
    }
  }
  let annotation = trace_annotation_at(trace, step)
  match annotation {
    Some(note) => {
      svg_text(out, 28, height - 48, note.title, 16, "#f8fafc")
      svg_text(out, 28, height - 24, note.body, 13, "#cbd5e1")
    }
    None => ()
  }
  out.write_string("</svg>\n")
  out.to_string()
}

///|
/// Render every recorded step. An empty trace yields its initial scene.
pub fn render_trace_svg_frames(
  trace : AlgorithmTrace,
  width? : Int = 900,
) -> Array[String] raise {
  if trace.steps.is_empty() {
    [render_trace_svg(trace, step=-1, width~)]
  } else {
    trace.steps.map(fn(step) raise {
      render_trace_svg(trace, step=step.index, width~)
    })
  }
}

///|
fn trace_scene_at(trace : AlgorithmTrace, step : Int) -> Scene raise {
  if trace.steps.is_empty() || step < 0 {
    trace.initial_scene
  } else if step >= trace.steps.length() {
    fail("Trace step is outside the recorded range")
  } else {
    trace.steps[step].scene
  }
}

///|
fn trace_annotation_at(trace : AlgorithmTrace, step : Int) -> Annotation? {
  if step < 0 || step >= trace.steps.length() {
    None
  } else {
    trace.steps[step].annotation
  }
}

///|
fn scene_height(scene : Scene) -> Int {
  let mut height = 150
  for object in scene.objects {
    height += match object {
      Sequence(_) => 120
      Sets(value) => 86 + value.groups.length() * 46
      Graph(_) => 190
      Grid(value) => 56 + value.height * 44
    }
  }
  height
}

///|
fn render_sequence_svg(
  out : StringBuilder,
  value : SequenceState,
  scene : Scene,
  y : Int,
) -> Int {
  svg_text(out, 28, y + 20, value.label, 16, "#e2e8f0")
  for i, item in value.items {
    let x = 28 + i * 72
    svg_box(out, x, y + 34, 58, 48, highlight_color(scene, item.id))
    svg_text(out, x + 29, y + 64, item.value, 15, "#0f172a", anchor="middle")
    svg_text(out, x + 29, y + 100, item.id, 10, "#94a3b8", anchor="middle")
  }
  y + 120
}

///|
fn render_sets_svg(
  out : StringBuilder,
  value : SetState,
  scene : Scene,
  y : Int,
) -> Int {
  svg_text(out, 28, y + 20, value.label, 16, "#e2e8f0")
  let mut row = y + 36
  for group in value.groups {
    let members = group.members.join(", ")
    svg_box(out, 28, row, 820, 34, highlight_color(scene, group.id))
    svg_text(out, 42, row + 22, "\{group.label}: \{members}", 13, "#0f172a")
    row += 46
  }
  row + 24
}

///|
fn render_graph_svg(
  out : StringBuilder,
  value : GraphState,
  scene : Scene,
  y : Int,
) -> Int {
  svg_text(out, 28, y + 20, value.label, 16, "#e2e8f0")
  for edge in value.edges {
    let from_index = graph_node_index(value.nodes, edge.from)
    let to_index = graph_node_index(value.nodes, edge.to)
    let x1 = 70 + from_index * 110
    let x2 = 70 + to_index * 110
    out.write_string(
      "<line x1=\"\{x1}\" y1=\"\{y + 94}\" x2=\"\{x2}\" y2=\"\{y + 94}\" stroke=\"#64748b\" stroke-width=\"3\"/>\n",
    )
    if edge.label != "" {
      svg_text(
        out,
        (x1 + x2) / 2,
        y + 80,
        edge.label,
        11,
        "#cbd5e1",
        anchor="middle",
      )
    }
  }
  for i, node in value.nodes {
    let x = 70 + i * 110
    out.write_string(
      "<circle cx=\"\{x}\" cy=\"\{y + 94}\" r=\"27\" fill=\"\{highlight_color(scene, node.id)}\" stroke=\"#e2e8f0\" stroke-width=\"2\"/>\n",
    )
    svg_text(out, x, y + 100, node.label, 13, "#0f172a", anchor="middle")
  }
  y + 170
}

///|
fn render_grid_svg(
  out : StringBuilder,
  value : GridState,
  scene : Scene,
  y : Int,
) -> Int {
  svg_text(out, 28, y + 20, value.label, 16, "#e2e8f0")
  for cell in value.cells {
    let x = 28 + cell.x * 44
    let cy = y + 34 + cell.y * 44
    let fill = if cell.blocked {
      "#1e293b"
    } else {
      highlight_color(scene, cell.id)
    }
    svg_box(out, x, cy, 40, 40, fill)
    if cell.label != "" {
      svg_text(
        out,
        x + 20,
        cy + 25,
        cell.label,
        11,
        if cell.blocked {
          "#f8fafc"
        } else {
          "#0f172a"
        },
        anchor="middle",
      )
    }
  }
  y + 56 + value.height * 44
}

///|
fn graph_node_index(nodes : Array[GraphNode], id : String) -> Int {
  match nodes.search_by(fn(node) { node.id == id }) {
    Some(index) => index
    None => 0
  }
}

///|
fn highlight_color(scene : Scene, target : String) -> String {
  match scene.highlights.search_by(fn(item) { item.target == target }) {
    None => "#f8fafc"
    Some(index) =>
      match scene.highlights[index].role {
        Current => "#f59e0b"
        Candidate => "#38bdf8"
        Compared => "#c084fc"
        Changed => "#fb7185"
        Visited => "#93c5fd"
        Frontier => "#22d3ee"
        Result => "#4ade80"
        Error => "#ef4444"
      }
  }
}

///|
fn svg_box(
  out : StringBuilder,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  fill : String,
) -> Unit {
  out.write_string(
    "<rect x=\"\{x}\" y=\"\{y}\" width=\"\{width}\" height=\"\{height}\" rx=\"7\" fill=\"\{fill}\" stroke=\"#94a3b8\"/>\n",
  )
}

///|
fn svg_text(
  out : StringBuilder,
  x : Int,
  y : Int,
  text : String,
  size : Int,
  color : String,
  anchor? : String = "start",
) -> Unit {
  out.write_string(
    "<text x=\"\{x}\" y=\"\{y}\" text-anchor=\"\{anchor}\" font-family=\"ui-monospace, monospace\" font-size=\"\{size}\" fill=\"\{color}\">\{escape_markup(text)}</text>\n",
  )
}

///|
fn escape_markup(text : String) -> String {
  let out = StringBuilder()
  for char in text {
    match char {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' => out.write_string("&quot;")
      '\'' => out.write_string("&#39;")
      _ => out.write_char(char)
    }
  }
  out.to_string()
}
