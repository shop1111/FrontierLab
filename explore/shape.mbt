///|
/// Converts any `ToJson` value into FrontierLab scene objects.
///
/// `derive(ToJson)` encodes values in a small set of shapes, so the
/// conversion does not need to know the user's types:
///
/// - tuple constructors: `["Node", left, 5, right]`
/// - labeled constructors: `["Cons", {"head": 1, "tail": "Nil"}]`
/// - constant constructors: `"Leaf"`
/// - structs and maps: `{"key": 1, "left": {...}}` (`None` fields are omitted)
/// - arrays: `[1, 2, 3]`
priv enum Shape {
  Scalar(String)
  Ctor(String, ArrayView[Json])
  Fields(String?, Map[String, Json])
  Items(Array[Json])
  Missing
}

///|
let no_args : Array[Json] = []

///|
/// Constant constructors with these names are drawn as empty subtrees even
/// when no sibling value in the snapshot is a subtree.
let empty_names : Array[String] = [
  "Leaf", "Nil", "Empty", "E", "Tip", "Null", "Nothing", "Emp",
]

///|
fn is_tag(s : String) -> Bool {
  let mut first = true
  for c in s {
    if first {
      if c < 'A' || c > 'Z' {
        return false
      }
      first = false
    } else if !(c.is_ascii_alphabetic() || c.is_ascii_digit() || c == '_') {
      return false
    }
  }
  !first
}

///|
fn number_text(n : Double) -> String {
  let i = n.to_int64()
  if i.to_double() == n {
    i.to_string()
  } else {
    n.to_string()
  }
}

///|
fn shape(j : Json) -> Shape {
  match j {
    Null => Missing
    True => Scalar("true")
    False => Scalar("false")
    Number(n, ..) => Scalar(number_text(n))
    String(s) => if is_tag(s) { Ctor(s, no_args[:]) } else { Scalar(s) }
    Array(xs) =>
      if xs.length() >= 2 && xs[0] is String(tag) && is_tag(tag) {
        if xs.length() == 2 && xs[1] is Object(fields) {
          Fields(Some(tag), fields)
        } else {
          Ctor(tag, xs[1:])
        }
      } else {
        Items(xs)
      }
    Object(m) => Fields(None, m)
  }
}

///|
fn is_composite(j : Json) -> Bool {
  // Same answer as matching on `shape(j)`, without building the shape: a
  // tagged array is a constructor with arguments or a labeled constructor.
  match j {
    Object(_) => true
    Array(xs) =>
      (xs.length() >= 2 && xs[0] is String(tag) && is_tag(tag)) ||
      xs.iter().any(is_composite)
    _ => false
  }
}

///|
/// Short text for a value that is drawn inside a node rather than as a child.
fn inline_text(j : Json) -> String {
  match shape(j) {
    Scalar(s) => s
    Ctor(tag, _) => tag
    Missing => "None"
    Items(xs) => "[" + xs.map(inline_text).join(", ") + "]"
    Fields(_, _) => "{...}"
  }
}

///|
/// Records every constructor position or field that holds a subtree somewhere
/// in the snapshot, so that constant constructors in the same position (such
/// as `Leaf`) become empty children instead of labels.
fn collect_slots(j : Json, slots : Map[String, Bool]) -> Unit {
  match shape(j) {
    Ctor(tag, args) =>
      for i, arg in args {
        if is_composite(arg) {
          slots["\{tag}#\{i}"] = true
        }
        collect_slots(arg, slots)
      }
    Fields(tag, fields) => {
      let owner = tag.unwrap_or("")
      for name, value in fields {
        if is_composite(value) {
          slots["\{owner}.\{name}"] = true
        }
        collect_slots(value, slots)
      }
    }
    Items(xs) =>
      for x in xs {
        collect_slots(x, slots)
      }
    Scalar(_) | Missing => ()
  }
}

///|
priv struct RawNode {
  label : String
  parent : Int32
  edge : String
}

///|
fn is_empty_slot(
  value : Json,
  key : () -> String,
  slots : Map[String, Bool],
) -> Bool {
  match shape(value) {
    Missing => true
    Ctor(name, []) => empty_names.contains(name) || slots.contains(key())
    // An empty list where other nodes keep their children, such as `[]`.
    Items([]) => slots.contains(key())
    _ => false
  }
}

///|
fn add_node(
  j : Json,
  parent : Int32,
  edge : String,
  slots : Map[String, Bool],
  out : Array[RawNode],
) -> Unit {
  let labels : Array[(String, String)] = []
  // (edge name, child value or None for an empty slot)
  let children : Array[(String, Json?)] = []
  let mut tag = ""
  match shape(j) {
    Ctor(name, args) => {
      tag = name
      for i, arg in args {
        let key = () => "\{name}#\{i}"
        if is_composite(arg) {
          children.push(("", Some(arg)))
        } else if is_empty_slot(arg, key, slots) {
          children.push(("", None))
        } else {
          labels.push(("", inline_text(arg)))
        }
      }
      let count = children.length()
      for i in 0..<count {
        let name = if count == 2 {
          if i == 0 {
            "left"
          } else {
            "right"
          }
        } else {
          "\{i}"
        }
        children[i] = (name, children[i].1)
      }
    }
    Fields(owner, fields) => {
      tag = owner.unwrap_or("")
      for name, value in fields {
        let key = () => "\{tag}.\{name}"
        match shape(value) {
          Items(xs) if is_composite(value) =>
            for i, x in xs {
              if is_composite(x) {
                children.push(("\{name}[\{i}]", Some(x)))
              }
            }
          Fields(None, entries) if entries.values().all(is_composite) =>
            // A map, or a struct made only of subtrees: draw its entries as
            // children of this node.
            for entry, child in entries {
              children.push(("\{name}.\{entry}", Some(child)))
            }
          _ =>
            if is_composite(value) {
              children.push((name, Some(value)))
            } else if is_empty_slot(value, key, slots) {
              children.push((name, None))
            } else {
              labels.push((name, inline_text(value)))
            }
        }
      }
    }
    Items(xs) => {
      // A list of subtrees, such as a forest: every element is a root.
      for x in xs {
        if is_composite(x) {
          add_node(x, parent, edge, slots, out)
        }
      }
      return
    }
    Scalar(_) | Missing => return
  }
  let label = match labels {
    [] => if tag == "" { "·" } else { tag }
    [(_, text)] => text
    _ =>
      labels
      .map(fn(pair) {
        if pair.0 == "" {
          pair.1
        } else {
          "\{pair.0}=\{pair.1}"
        }
      })
      .join(", ")
  }
  let index = out.length()
  out.push({ label, parent, edge, })
  for child in children {
    match child {
      (name, Some(value)) => add_node(value, index, name, slots, out)
      (_, None) => ()
    }
  }
}

///|
/// One entity of a drawn snapshot, used to compare consecutive snapshots.
priv struct Entity {
  object_id : String
  id : String
  label : String
  place : String
}

///|
priv struct Snapshot {
  objects : Array[@frontierlab.SceneObject]
  entities : Array[Entity]
}

///|
/// Ids follow labels, so the same key keeps its id when it moves; repeated
/// labels are numbered in pre-order.
fn label_ids(labels : Array[String], prefix : String) -> Array[String] {
  let seen : Map[String, Int32] = Map([])
  labels.map(fn(label) {
    let count = seen.get(label).unwrap_or(0) + 1
    seen[label] = count
    if count == 1 {
      "\{prefix}\{label}"
    } else {
      "\{prefix}\{label}#\{count}"
    }
  })
}

///|
fn sequence_object(
  id : String,
  label : String,
  values : Array[String],
  entities : Array[Entity],
) -> @frontierlab.SceneObject {
  let ids = label_ids(values, "v:")
  for i, value in values {
    entities.push({ object_id: id, id: ids[i], label: value, place: "\{i}", })
  }
  @frontierlab.Sequence(
    @frontierlab.SequenceState::new(
      id~,
      label~,
      items=values.mapi(fn(i, value) {
        @frontierlab.SequenceItem::new(id=ids[i], value~)
      }),
    ),
  )
}

///|
fn flat_fields(fields : Map[String, Json]) -> Bool {
  fields.values().all(fn(value) { !is_composite(value) })
}

///|
fn snapshot(value : Json) -> Snapshot raise @frontierlab.TraceError {
  let entities : Array[Entity] = []
  match shape(value) {
    Items(xs) if !is_composite(value) => {
      let object = sequence_object(
        "state",
        "State",
        xs.map(inline_text),
        entities,
      )
      return { objects: [object], entities, }
    }
    Fields(None, fields) if flat_fields(fields) => {
      let objects : Array[@frontierlab.SceneObject] = []
      let scalars : Array[String] = []
      for name, field in fields {
        match field {
          Array(xs) =>
            objects.push(
              sequence_object(name, name, xs.map(inline_text), entities),
            )
          _ => scalars.push("\{name}=\{inline_text(field)}")
        }
      }
      if scalars.length() > 0 {
        objects.push(sequence_object("fields", "fields", scalars, entities))
      }
      if objects.length() > 0 {
        return { objects, entities, }
      }
    }
    _ => ()
  }
  let slots : Map[String, Bool] = Map([])
  collect_slots(value, slots)
  let raw : Array[RawNode] = []
  if is_composite(value) {
    add_node(value, -1, "", slots, raw)
  }
  let ids = label_ids(raw.map(fn(node) { node.label }), "n:")
  let nodes = raw.mapi(fn(i, node) {
    @frontierlab.GraphNode::new(id=ids[i], label=node.label)
  })
  let edges : Array[@frontierlab.GraphEdge] = []
  for i, node in raw {
    let place = if node.parent < 0 {
      "root"
    } else {
      edges.push(
        @frontierlab.GraphEdge::new(
          id="\{ids[node.parent]}->\{ids[i]}",
          from=ids[node.parent],
          to=ids[i],
          label=node.edge,
          directed=true,
        ),
      )
      "\{ids[node.parent]}/\{node.edge}"
    }
    entities.push({ object_id: "state", id: ids[i], label: node.label, place, })
  }
  // An empty structure such as `Leaf`, or a plain value, has no nodes; its
  // text goes into the title instead.
  let label = if is_composite(value) {
    "State"
  } else {
    "State: \{inline_text(value)}"
  }
  let graph = @frontierlab.GraphState::new(id="state", label~, nodes~, edges~)
  { objects: [@frontierlab.Graph(graph)], entities, }
}

///|
/// Entities that are new in `after` or sit in a different place.
fn changed_entities(before : Snapshot, after : Snapshot) -> Array[Entity] {
  let places : Map[String, String] = Map([])
  for entity in before.entities {
    places["\{entity.object_id}::\{entity.id}"] = entity.place
  }
  after.entities.filter(fn(entity) {
    places.get("\{entity.object_id}::\{entity.id}") != Some(entity.place)
  })
}

///|
/// Labels of entities that disappeared between the two snapshots.
fn removed_labels(before : Snapshot, after : Snapshot) -> Array[String] {
  let present : Map[String, Bool] = Map([])
  for entity in after.entities {
    present["\{entity.object_id}::\{entity.id}"] = true
  }
  before.entities
  .filter(fn(entity) { !present.contains("\{entity.object_id}::\{entity.id}") })
  .map(fn(entity) { entity.label })
}

///|
fn scene(
  snapshot : Snapshot,
  highlighted : Array[Entity],
  role : @frontierlab.HighlightRole,
) -> @frontierlab.Scene raise @frontierlab.TraceError {
  @frontierlab.Scene::new(
    objects=snapshot.objects,
    highlights=highlighted.map(fn(entity) {
      @frontierlab.Highlight::new(
        target=@frontierlab.TargetRef::entity(entity.object_id, entity.id),
        role~,
      )
    }),
  )
}
