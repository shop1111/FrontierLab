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
/// How to draw one part of the state, for structures whose `derive(ToJson)`
/// output does not show what they are.
///
/// `path` names a field of the state, with dots for nested fields
/// (`"table.buckets"`); `""` is the whole state. Parts drawn by a view are
/// left out of the default drawing of the rest of the state.
pub(all) enum View {
  /// A directed graph from adjacency lists: a map from node to neighbors
  /// (`Map[K, Array[K]]`), an array indexed by node (`Array[Array[Int]]`), or
  /// a map from node to a map of neighbor to weight. A neighbor written as a
  /// pair `(node, weight)`, or as a record with a `to` field, labels its edge
  /// with the rest.
  Graph(String)
  /// A hash table: an array of buckets, each `None`, `Some(entry)`, an array
  /// of entries, or a constructor chain such as `Cons(key, value, rest)`.
  Buckets(String)
  /// A matrix: an array of rows, each an array of values or a string.
  Matrix(String)
  /// Tree nodes take their identity from this field instead of their whole
  /// label, so that a node whose other fields change, such as a recolored
  /// red-black node, stays the same node instead of being replaced. Names a
  /// labeled field (`"key"`) or a constructor position counted from 0
  /// (`"Node#2"`).
  NodeId(String)
}

///|
/// What an entity is, which decides how its changes are described in text.
priv enum Kind {
  Node
  Item
  Member
  Cell
  Vertex
  Link
}

///|
/// The field or constructor position that identifies tree nodes.
priv struct IdRule {
  /// The constructor name, or `""` for a labeled field.
  tag : String
  field : String
  position : Int32
}

///|
fn id_rule(name : String) -> IdRule {
  let field = { tag: "", field: name, position: -1, }
  guard name.find("#") is Some(i) && i + 1 < name.length() else { return field }
  let mut position = 0
  for c in name[i + 1:] {
    if c < '0' || c > '9' {
      return field
    }
    position = position * 10 + (c.to_int() - '0'.to_int())
  }
  { tag: name[:i].to_owned(), field: "", position, }
}

///|
priv struct RawNode {
  label : String
  /// The value of the identifying field, when there is one.
  key : String?
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
  rule : IdRule?,
  out : Array[RawNode],
) -> Unit {
  let labels : Array[(String, String)] = []
  // (edge name, child value or None for an empty slot)
  let children : Array[(String, Json?)] = []
  let mut tag = ""
  let mut key : String? = None
  match shape(j) {
    Ctor(name, args) => {
      tag = name
      for i, arg in args {
        let slot = () => "\{name}#\{i}"
        if is_composite(arg) {
          children.push(("", Some(arg)))
        } else if is_empty_slot(arg, slot, slots) {
          children.push(("", None))
        } else {
          labels.push(("", inline_text(arg)))
        }
        if rule is Some(rule) && rule.tag == name && rule.position == i {
          key = Some(inline_text(arg))
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
        let slot = () => "\{tag}.\{name}"
        if rule is Some(rule) && rule.tag == "" && rule.field == name {
          key = Some(inline_text(value))
        }
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
            } else if is_empty_slot(value, slot, slots) {
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
          add_node(x, parent, edge, slots, rule, out)
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
  out.push({ label, key, parent, edge, })
  for child in children {
    match child {
      (name, Some(value)) => add_node(value, index, name, slots, rule, out)
      (_, None) => ()
    }
  }
}

///|
/// One entity of a drawn snapshot, used to compare consecutive snapshots.
priv struct Entity {
  object_id : String
  id : String
  /// `object_id::id`, built once for comparing snapshots.
  key : String
  label : String
  /// Where the entity is; an entity whose place changes counts as moved.
  place : String
  kind : Kind
  /// For tree nodes, the parent's label and the edge from it.
  parent : String
  edge : String
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
fn entity(
  object_id : String,
  id : String,
  label : String,
  place : String,
  kind : Kind,
) -> Entity {
  {
    object_id,
    id,
    key: object_id + "::" + id,
    label,
    place,
    kind,
    parent: "",
    edge: "",
  }
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
    entities.push(entity(id, ids[i], value, "\{i}", Item))
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
/// The default drawing: a sequence for a flat array, sequences for a record
/// of flat fields, and a tree of nodes for anything else.
fn draw_value(
  value : Json,
  rule : IdRule?,
  entities : Array[Entity],
) -> Array[@frontierlab.SceneObject] raise @frontierlab.TraceError {
  match shape(value) {
    Items(xs) if !is_composite(value) =>
      return [sequence_object("state", "State", xs.map(inline_text), entities)]
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
        return objects
      }
    }
    _ => ()
  }
  let slots : Map[String, Bool] = Map([])
  collect_slots(value, slots)
  let raw : Array[RawNode] = []
  if is_composite(value) {
    add_node(value, -1, "", slots, rule, raw)
  }
  let ids = label_ids(
    raw.map(fn(node) {
      match node.key {
        Some(key) => "#\{key}"
        None => node.label
      }
    }),
    "n:",
  )
  let nodes = raw.mapi(fn(i, node) {
    @frontierlab.GraphNode::new(id=ids[i], label=node.label)
  })
  let edges : Array[@frontierlab.GraphEdge] = []
  for i, node in raw {
    if node.parent < 0 {
      entities.push(entity("state", ids[i], node.label, "root", Node))
      continue
    }
    edges.push(
      @frontierlab.GraphEdge::new(
        id="\{ids[node.parent]}->\{ids[i]}",
        from=ids[node.parent],
        to=ids[i],
        label=node.edge,
        directed=true,
      ),
    )
    entities.push({
      object_id: "state",
      id: ids[i],
      key: "state::" + ids[i],
      label: node.label,
      place: "\{ids[node.parent]}/\{node.edge}",
      kind: Node,
      parent: raw[node.parent].label,
      edge: node.edge,
    })
  }
  // An empty structure such as `Leaf`, or a plain value, has no nodes; its
  // text goes into the title instead.
  let label = if is_composite(value) {
    "State"
  } else {
    "State: \{inline_text(value)}"
  }
  [
    @frontierlab.Graph(
      @frontierlab.GraphState::new(id="state", label~, nodes~, edges~),
    ),
  ]
}

///|
/// The value at a dotted field path, or `None` when a field is missing, for
/// example an omitted `None` field.
fn lookup(value : Json, path : String) -> Json? {
  let mut current = value
  for part in field_path(path) {
    let fields = match current {
      Object(fields) => fields
      Array([String(tag), Object(fields)]) if is_tag(tag) => fields
      _ => return None
    }
    match fields.get(part) {
      Some(next) => current = next
      None => return None
    }
  }
  Some(current)
}

///|
/// The field names of a dotted path; none for `""`, the whole state.
fn field_path(path : String) -> Array[String] {
  if path == "" {
    []
  } else {
    path.split(".").map(fn(part) { part.to_owned() }).collect()
  }
}

///|
/// `value` without the field at `parts`; `null` when the path is the whole
/// value.
fn without(value : Json, parts : ArrayView[String]) -> Json {
  guard parts is [first, .. rest] else { return Json::null() }
  match value {
    Object(fields) => {
      let copy = Map::from_iter(fields.iter())
      if rest is [] {
        copy.remove(first)
      } else if fields.get(first) is Some(child) {
        // A record left empty by the view goes too.
        match without(child, rest) {
          Object(left) if left.is_empty() => copy.remove(first)
          left => copy[first] = left
        }
      }
      Json::object(copy)
    }
    Array([String(tag) as name, Object(_) as fields]) if is_tag(tag) =>
      Json::array([name, without(fields, parts)])
    _ => value
  }
}

///|
/// Text for an entry of a bucket: `key: value` for a pair, `k=v, ...` for a
/// record.
fn entry_text(j : Json) -> String {
  match j {
    Array([key, value]) if !is_composite(j) =>
      "\{shown(inline_text(key))}: \{shown(inline_text(value))}"
    Object(fields) if flat_fields(fields) =>
      fields
      .iter()
      .map(fn(pair) { "\{pair.0}=\{inline_text(pair.1)}" })
      .collect()
      .join(", ")
    _ => inline_text(j)
  }
}

///|
fn bucket_entries(bucket : Json) -> Array[String] {
  match shape(bucket) {
    Missing => []
    // A chain of constructors: plain arguments form the entry and the
    // composite argument is the rest of the chain.
    Ctor(_, args) => {
      let parts : Array[String] = []
      let mut rest : Json? = None
      for arg in args {
        if is_composite(arg) {
          rest = Some(arg)
        } else if !(shape(arg) is Ctor(_, []) || arg is Null) {
          parts.push(inline_text(arg))
        }
      }
      chain_entry(parts, rest)
    }
    Fields(Some(_), fields) => {
      let parts : Array[String] = []
      let mut rest : Json? = None
      for name, value in fields {
        if is_composite(value) {
          rest = Some(value)
        } else if !(shape(value) is Ctor(_, []) || value is Null) {
          parts.push("\{name}=\{inline_text(value)}")
        }
      }
      chain_entry([parts.join(", ")], rest)
    }
    Items(xs) => xs.map(entry_text)
    Scalar(_) | Fields(None, _) => [entry_text(bucket)]
  }
}

///|
fn chain_entry(parts : Array[String], rest : Json?) -> Array[String] {
  let head = match parts {
    [] => []
    [one] => [one]
    [key, value] => ["\{key}: \{value}"]
    _ => [parts.join(", ")]
  }
  match rest {
    Some(next) => head + bucket_entries(next)
    None => head
  }
}

///|
fn view_problem(kind : String, path : String, value : Json) -> String {
  "View \{kind}(\"\{path}\") cannot draw \{value.stringify()}"
}

///|
fn draw_graph(
  id : String,
  label : String,
  path : String,
  value : Json?,
  entities : Array[Entity],
) -> @frontierlab.SceneObject raise @frontierlab.TraceError {
  let lists : Array[(String, Json)] = []
  match value {
    Some(Object(fields)) =>
      for key, neighbors in fields {
        lists.push((key, neighbors))
      }
    Some(Array(xs)) =>
      for i, neighbors in xs {
        lists.push(("\{i}", neighbors))
      }
    None | Some(Null) => ()
    Some(other) =>
      raise @frontierlab.InvalidGraph(view_problem("Graph", path, other))
  }
  let names : Array[String] = []
  let known : Map[String, Bool] = Map([])
  let add = fn(name : String) {
    if !known.contains(name) {
      known[name] = true
      names.push(name)
    }
  }
  // (from, to, weight)
  let links : Array[(String, String, String)] = []
  for list in lists {
    let (from, neighbors) = list
    add(from)
    let targets : Array[(String, String)] = match neighbors {
      Null => []
      Array(xs) => xs.map(neighbor)
      Object(weights) =>
        weights.iter().map(fn(pair) { (pair.0, inline_text(pair.1)) }).collect()
      other =>
        raise @frontierlab.InvalidGraph(view_problem("Graph", path, other))
    }
    for target in targets {
      add(target.0)
      links.push((from, target.0, target.1))
    }
  }
  let nodes = names.map(fn(name) {
    entities.push(entity(id, "n:\{name}", name, "", Vertex))
    @frontierlab.GraphNode::new(id="n:\{name}", label=name)
  })
  let edge_ids = label_ids(links.map(fn(link) { "\{link.0}->\{link.1}" }), "e:")
  let edges = links.mapi(fn(i, link) {
    let (from, to, weight) = link
    entities.push(entity(id, edge_ids[i], "\{from} -> \{to}", weight, Link))
    @frontierlab.GraphEdge::new(
      id=edge_ids[i],
      from="n:\{from}",
      to="n:\{to}",
      label=weight,
      directed=true,
    )
  })
  @frontierlab.Graph(@frontierlab.GraphState::new(id~, label~, nodes~, edges~))
}

///|
/// A neighbor and the label of the edge to it.
fn neighbor(j : Json) -> (String, String) {
  match j {
    Array([target, .. rest]) if !is_composite(target) =>
      (inline_text(target), rest.iter().map(inline_text).collect().join(", "))
    Object(fields) =>
      match
        ["to", "target", "node", "dst"].search_by(fn(name) {
          fields.contains(name)
        }) {
        Some(i) => {
          let name = ["to", "target", "node", "dst"][i]
          let rest = fields
            .iter()
            .filter(fn(pair) { pair.0 != name })
            .map(fn(pair) { "\{pair.0}=\{inline_text(pair.1)}" })
            .collect()
          (inline_text(fields[name]), rest.join(", "))
        }
        None => (inline_text(j), "")
      }
    _ => (inline_text(j), "")
  }
}

///|
fn draw_buckets(
  id : String,
  label : String,
  path : String,
  value : Json?,
  entities : Array[Entity],
) -> @frontierlab.SceneObject raise @frontierlab.TraceError {
  let buckets = match value {
    Some(Array(xs)) => xs
    None | Some(Null) => []
    Some(other) =>
      raise @frontierlab.InvalidStep(view_problem("Buckets", path, other))
  }
  let seen : Map[String, Int32] = Map([])
  let groups = buckets.mapi(fn(i, bucket) {
    let members = bucket_entries(bucket).map(fn(text) {
      // Set members are their own ids, so a repeated entry gets a number.
      let count = seen.get(text).unwrap_or(0) + 1
      seen[text] = count
      let entry = if count == 1 { text } else { "\{text} (\{count})" }
      entities.push(entity(id, entry, entry, "\{i}", Member))
      entry
    })
    @frontierlab.SetGroup::new(id="bucket-\{i}", label="\{i}", members~)
  })
  @frontierlab.Sets(@frontierlab.SetState::new(id~, label~, groups~))
}

///|
fn draw_matrix(
  id : String,
  label : String,
  path : String,
  value : Json?,
  entities : Array[Entity],
) -> @frontierlab.SceneObject raise @frontierlab.TraceError {
  let rows : Array[Array[String]] = []
  match value {
    Some(Array(xs)) =>
      for row in xs {
        rows.push(
          match row {
            Array(cells) => cells.map(inline_text)
            String(text) => text.iter().map(fn(c) { c.to_string() }).collect()
            Null => []
            other =>
              raise @frontierlab.InvalidGrid(
                view_problem("Matrix", path, other),
              )
          },
        )
      }
    None | Some(Null) => ()
    Some(other) =>
      raise @frontierlab.InvalidGrid(view_problem("Matrix", path, other))
  }
  let mut width = 1
  for row in rows {
    if row.length() > width {
      width = row.length()
    }
  }
  let cells : Array[@frontierlab.GridCellState] = []
  for y, row in rows {
    for x, text in row {
      let cell = "c:\{x},\{y}"
      entities.push(entity(id, cell, "(\{x}, \{y})", text, Cell))
      cells.push(@frontierlab.GridCellState::new(id=cell, x~, y~, label=text))
    }
  }
  @frontierlab.Grid(
    @frontierlab.GridState::new(
      id~,
      label~,
      width~,
      height=if rows.is_empty() { 1 } else { rows.length() },
      cells~,
    ),
  )
}

///|
fn snapshot(
  value : Json,
  views : Array[View],
) -> Snapshot raise @frontierlab.TraceError {
  let entities : Array[Entity] = []
  let objects : Array[@frontierlab.SceneObject] = []
  let mut rest = value
  let mut rule : IdRule? = None
  for view in views {
    match view {
      NodeId(name) => rule = Some(id_rule(name))
      Graph(path) | Buckets(path) | Matrix(path) => {
        let (id, label) = if path == "" {
          ("view", "State")
        } else {
          ("view:\{path}", path)
        }
        let part = lookup(value, path)
        objects.push(
          match view {
            Graph(_) => draw_graph(id, label, path, part, entities)
            Buckets(_) => draw_buckets(id, label, path, part, entities)
            _ => draw_matrix(id, label, path, part, entities)
          },
        )
        rest = without(rest, field_path(path))
      }
    }
  }
  // Unless views drew everything, the rest gets the default drawing.
  if objects.is_empty() || !rest_is_empty(rest) {
    objects.append(draw_value(rest, rule, entities))
  }
  { objects, entities, }
}

///|
fn rest_is_empty(rest : Json) -> Bool {
  match rest {
    Null => true
    Object(fields) => fields.is_empty()
    _ => false
  }
}

///|
/// How a snapshot differs from the one before.
priv struct Diff {
  /// Added entities, without an old entity, and moved or changed ones.
  changed : Array[(Entity?, Entity)]
  removed : Array[Entity]
}

///|
/// Compares two snapshots with one map over the old entities: matched ones
/// are taken out, so what is left was removed.
fn diff(before : Snapshot, after : Snapshot) -> Diff {
  let old : Map[String, Entity] = Map([])
  for entity in before.entities {
    old[entity.key] = entity
  }
  let changed : Array[(Entity?, Entity)] = []
  for entity in after.entities {
    match old.get(entity.key) {
      None => changed.push((None, entity))
      Some(was) => {
        // A node identified by `NodeId` can keep its id and change its label.
        if was.place != entity.place || was.label != entity.label {
          changed.push((Some(was), entity))
        }
        old.remove(entity.key)
      }
    }
  }
  { changed, removed: old.values().collect(), }
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
