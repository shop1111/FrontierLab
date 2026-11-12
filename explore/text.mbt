///|
/// Text for a label in plain-text output, where an empty label would vanish.
fn shown(label : String) -> String {
  if label == "" {
    "\"\""
  } else {
    label
  }
}

///|
fn list_text(state : @frontierlab.SequenceState) -> String {
  "[" + state.items.map(fn(item) { item.value }).join(", ") + "]"
}

///|
fn where_text(entity : Entity) -> String {
  match entity.kind {
    Node =>
      if entity.place == "root" {
        "root"
      } else {
        "\{entity.edge} of \{shown(entity.parent)}"
      }
    Member => "bucket \{entity.place}"
    _ => entity.place
  }
}

///|
fn added_line(entity : Entity) -> String {
  match entity.kind {
    // Sequence items are described as whole lists, so only nodes get here.
    Node | Item => "+ \{shown(entity.label)} at \{where_text(entity)}"
    Member => "+ \{entity.label} in \{where_text(entity)}"
    Cell => "+ \{entity.label} = \{shown(entity.place)}"
    Vertex => "+ node \{shown(entity.label)}"
    Link =>
      if entity.place == "" {
        "+ edge \{entity.label}"
      } else {
        "+ edge \{entity.label} (\{entity.place})"
      }
  }
}

///|
fn removed_line(entity : Entity) -> String {
  match entity.kind {
    Vertex => "- node \{shown(entity.label)}"
    Link => "- edge \{entity.label}"
    _ => "- \{shown(entity.label)}"
  }
}

///|
fn moved_line(old : Entity, new : Entity) -> String {
  let label = match new.kind {
    Link => "edge \{new.label}"
    _ => shown(new.label)
  }
  let place = "\{shown(where_text(old))} -> \{shown(where_text(new))}"
  if old.label == new.label {
    "~ \{label}: \{place}"
  } else if old.place == new.place {
    "~ \{shown(old.label)} -> \{label}"
  } else {
    "~ \{shown(old.label)} -> \{label}: \{place}"
  }
}

///|
/// What changed between two snapshots, one line per change: `+` for added,
/// `-` for removed, `~` for moved or changed entities, and whole lists for
/// sequences, whose items shift together.
fn change_lines(before : Snapshot, after : Snapshot, d : Diff) -> Array[String] {
  let lines : Array[String] = []
  let lists : Map[String, @frontierlab.SequenceState] = Map([])
  // Empty buckets hold no entities, so a resize shows as a new bucket count.
  let buckets : Map[String, Int32] = Map([])
  for object in before.objects {
    match object {
      Sequence(state) => lists[state.id] = state
      Sets(state) => buckets[state.id] = state.groups.length()
      _ => ()
    }
  }
  for object in after.objects {
    if object is Sets(state) &&
      buckets.get(state.id) is Some(was) &&
      was != state.groups.length() {
      lines.push("\{state.label}: \{was} -> \{state.groups.length()} buckets")
    }
    guard object is Sequence(state) else { continue }
    match lists.get(state.id) {
      Some(was) =>
        if was.items != state.items {
          lines.push("\{state.label}: \{list_text(was)} -> \{list_text(state)}")
        }
      None => lines.push("+ \{state.label}: \{list_text(state)}")
    }
    lists.remove(state.id)
  }
  for _, list in lists {
    lines.push("- \{list.label}: \{list_text(list)}")
  }
  for pair in d.changed {
    match pair {
      (_, { kind: Item, .. }) => ()
      (None, entity) => lines.push(added_line(entity))
      (Some(was), entity) => lines.push(moved_line(was, entity))
    }
  }
  for entity in d.removed {
    if !(entity.kind is Item) {
      lines.push(removed_line(entity))
    }
  }
  lines
}

///|
/// The drawn state as indented text: trees as an outline, graphs as
/// adjacency lists, buckets and matrices row by row, sequences as lists.
fn outline(objects : Array[@frontierlab.SceneObject]) -> Array[String] {
  let lines : Array[String] = []
  for object in objects {
    match object {
      Sequence(state) => lines.push("\{state.label}: \{list_text(state)}")
      Sets(state) => {
        lines.push("\{state.label}:")
        for group in state.groups {
          let members = if group.members.is_empty() {
            "-"
          } else {
            group.members.join(", ")
          }
          lines.push("  \{group.label}: \{members}")
        }
      }
      Grid(state) => {
        lines.push("\{state.label}:")
        let rows : Array[Array[String]] = Array::makei(state.height, fn(_) {
          Array::make(state.width, ".")
        })
        for cell in state.cells {
          rows[cell.y][cell.x] = shown(cell.label)
        }
        for row in rows {
          lines.push("  " + row.join(" "))
        }
      }
      Graph(state) =>
        // The default drawing is always a forest; views draw any graph.
        if state.id == "state" {
          tree_outline(state, lines)
        } else {
          adjacency_outline(state, lines)
        }
    }
  }
  lines
}

///|
fn tree_outline(state : @frontierlab.GraphState, lines : Array[String]) -> Unit {
  // An empty structure already has its text in the label, as in `State: Leaf`.
  if state.nodes.is_empty() {
    lines.push(state.label)
    return
  }
  lines.push("\{state.label}:")
  let labels : Map[String, String] = Map([])
  for node in state.nodes {
    labels[node.id] = node.label
  }
  let children : Map[String, Array[@frontierlab.GraphEdge]] = Map([])
  let has_parent : Map[String, Bool] = Map([])
  for edge in state.edges {
    match children.get(edge.from) {
      Some(list) => list.push(edge)
      None => children[edge.from] = [edge]
    }
    has_parent[edge.to] = true
  }
  fn walk(id : String, edge : String, depth : Int32) -> Unit {
    let indent = "  ".repeat(depth)
    let label = shown(labels.get(id).unwrap_or(id))
    lines.push(
      if edge == "" {
        indent + label
      } else {
        "\{indent}\{edge}: \{label}"
      },
    )
    for child in children.get(id).unwrap_or([]) {
      walk(child.to, child.label, depth + 1)
    }
  }
  for node in state.nodes {
    if !has_parent.contains(node.id) {
      walk(node.id, "", 1)
    }
  }
}

///|
fn adjacency_outline(
  state : @frontierlab.GraphState,
  lines : Array[String],
) -> Unit {
  lines.push("\{state.label}:")
  let labels : Map[String, String] = Map([])
  for node in state.nodes {
    labels[node.id] = node.label
  }
  for node in state.nodes {
    let targets = state.edges
      .filter(fn(edge) { edge.from == node.id })
      .map(fn(edge) {
        let to = shown(labels.get(edge.to).unwrap_or(edge.to))
        if edge.label == "" {
          to
        } else {
          "\{to} (\{edge.label})"
        }
      })
    let list = if targets.is_empty() { "-" } else { targets.join(", ") }
    lines.push("  \{shown(node.label)} -> \{list}")
  }
}
