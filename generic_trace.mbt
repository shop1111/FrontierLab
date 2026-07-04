///|
/// A stable key/value attribute used by custom events and summaries.
pub struct TraceAttribute {
  key : String
  value : String
} derive(Debug, Eq, ToJson)

///|
pub fn TraceAttribute::new(key~ : String, value~ : String) -> TraceAttribute {
  { key, value }
}

///|
/// The semantic reason why an algorithm produced a new scene.
pub(all) enum TraceEvent {
  Initialize
  Compare(Array[String])
  Swap(String, String)
  Visit(String)
  Update(String, String)
  Union(String, String)
  Relax(String, String, String)
  Complete
  Custom(String, Array[TraceAttribute])
} derive(Debug, Eq, ToJson)

///|
pub(all) enum HighlightRole {
  Current
  Candidate
  Compared
  Changed
  Visited
  Frontier
  Result
  Error
} derive(Debug, Eq, ToJson)

///|
pub struct Highlight {
  target : String
  role : HighlightRole
} derive(Debug, Eq, ToJson)

///|
pub fn Highlight::new(target~ : String, role~ : HighlightRole) -> Highlight {
  { target, role }
}

///|
pub struct Annotation {
  title : String
  body : String
  pseudocode_line : Int?
} derive(Debug, Eq, ToJson)

///|
pub fn Annotation::new(
  title~ : String,
  body~ : String,
  pseudocode_line? : Int,
) -> Annotation {
  { title, body, pseudocode_line }
}

///|
pub struct SequenceItem {
  id : String
  value : String
} derive(Debug, Eq, ToJson)

///|
pub fn SequenceItem::new(id~ : String, value~ : String) -> SequenceItem {
  { id, value }
}

///|
pub struct SequenceState {
  id : String
  label : String
  items : Array[SequenceItem]
} derive(Debug, Eq, ToJson)

///|
pub fn SequenceState::new(
  id~ : String,
  label~ : String,
  items~ : Array[SequenceItem],
) -> SequenceState {
  { id, label, items: items.copy() }
}

///|
pub struct SetGroup {
  id : String
  label : String
  members : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub fn SetGroup::new(
  id~ : String,
  label~ : String,
  members~ : Array[String],
) -> SetGroup {
  { id, label, members: members.copy() }
}

///|
pub struct SetState {
  id : String
  label : String
  groups : Array[SetGroup]
} derive(Debug, Eq, ToJson)

///|
pub fn SetState::new(
  id~ : String,
  label~ : String,
  groups~ : Array[SetGroup],
) -> SetState {
  { id, label, groups: groups.map(fn(group) { group.deep_copy() }) }
}

///|
pub struct GraphNode {
  id : String
  label : String
} derive(Debug, Eq, ToJson)

///|
pub fn GraphNode::new(id~ : String, label~ : String) -> GraphNode {
  { id, label }
}

///|
pub struct GraphEdge {
  id : String
  from : String
  to : String
  label : String
  directed : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn GraphEdge::new(
  id~ : String,
  from~ : String,
  to~ : String,
  label? : String = "",
  directed? : Bool = false,
) -> GraphEdge {
  { id, from, to, label, directed }
}

///|
pub struct GraphState {
  id : String
  label : String
  nodes : Array[GraphNode]
  edges : Array[GraphEdge]
} derive(Debug, Eq, ToJson)

///|
pub fn GraphState::new(
  id~ : String,
  label~ : String,
  nodes~ : Array[GraphNode],
  edges~ : Array[GraphEdge],
) -> GraphState raise {
  ensure_unique_node_ids(nodes)
  for edge in edges {
    if !nodes.any(fn(node) { node.id == edge.from }) ||
      !nodes.any(fn(node) { node.id == edge.to }) {
      fail("Graph edge endpoints must reference existing node ids")
    }
  }
  { id, label, nodes: nodes.copy(), edges: edges.copy() }
}

///|
pub struct GridCellState {
  id : String
  x : Int
  y : Int
  label : String
  blocked : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn GridCellState::new(
  id~ : String,
  x~ : Int,
  y~ : Int,
  label? : String = "",
  blocked? : Bool = false,
) -> GridCellState {
  { id, x, y, label, blocked }
}

///|
pub struct GridState {
  id : String
  label : String
  width : Int
  height : Int
  cells : Array[GridCellState]
} derive(Debug, Eq, ToJson)

///|
pub fn GridState::new(
  id~ : String,
  label~ : String,
  width~ : Int,
  height~ : Int,
  cells~ : Array[GridCellState],
) -> GridState raise {
  if width <= 0 || height <= 0 {
    fail("Grid scene dimensions must be positive")
  }
  ensure_unique_cell_ids(cells)
  for cell in cells {
    if cell.x < 0 || cell.y < 0 || cell.x >= width || cell.y >= height {
      fail("Grid scene cell is outside its dimensions")
    }
  }
  { id, label, width, height, cells: cells.copy() }
}

///|
pub(all) enum SceneObject {
  Sequence(SequenceState)
  Sets(SetState)
  Graph(GraphState)
  Grid(GridState)
} derive(Debug, Eq, ToJson)

///|
pub struct Scene {
  objects : Array[SceneObject]
  highlights : Array[Highlight]
} derive(Debug, Eq, ToJson)

///|
pub fn Scene::new(
  objects~ : Array[SceneObject],
  highlights? : Array[Highlight] = [],
) -> Scene raise {
  ensure_unique_object_ids(objects)
  let scene = {
    objects: objects.map(fn(object) { object.deep_copy() }),
    highlights: highlights.copy(),
  }
  scene.validate_highlights()
  scene
}

///|
pub struct AlgorithmTraceStep {
  index : Int
  event : TraceEvent
  scene : Scene
  annotation : Annotation?
} derive(Debug, Eq, ToJson)

///|
pub struct AlgorithmTrace {
  schema_version : String
  title : String
  algorithm : String
  description : String
  initial_scene : Scene
  steps : Array[AlgorithmTraceStep]
  summary : Array[TraceAttribute]
} derive(Debug, Eq, ToJson)

///|
/// Mutable recorder that stores immutable scene snapshots.
pub struct TraceBuilder {
  title : String
  algorithm : String
  description : String
  initial_scene : Scene
  steps : Array[AlgorithmTraceStep]
} derive(Debug)

///|
pub fn TraceBuilder::new(
  title~ : String,
  algorithm~ : String,
  description? : String = "",
  initial_scene~ : Scene,
) -> TraceBuilder {
  {
    title,
    algorithm,
    description,
    initial_scene: initial_scene.deep_copy(),
    steps: [],
  }
}

///|
pub fn TraceBuilder::record(
  self : TraceBuilder,
  event~ : TraceEvent,
  scene~ : Scene,
  annotation? : Annotation,
) -> Unit raise {
  scene.validate_highlights()
  self.steps.push({
    index: self.steps.length(),
    event: event.deep_copy(),
    scene: scene.deep_copy(),
    annotation,
  })
}

///|
pub fn TraceBuilder::finish(
  self : TraceBuilder,
  summary? : Array[TraceAttribute] = [],
) -> AlgorithmTrace {
  {
    schema_version: "1.0",
    title: self.title,
    algorithm: self.algorithm,
    description: self.description,
    initial_scene: self.initial_scene.deep_copy(),
    steps: self.steps.map(fn(step) { step.deep_copy() }),
    summary: summary.copy(),
  }
}

///|
pub fn AlgorithmTrace::to_json_string(self : AlgorithmTrace) -> String {
  self.to_json().stringify(indent=2)
}

///|
fn TraceEvent::deep_copy(self : TraceEvent) -> TraceEvent {
  match self {
    Compare(ids) => Compare(ids.copy())
    Custom(kind, attrs) => Custom(kind, attrs.copy())
    other => other
  }
}

///|
fn SetGroup::deep_copy(self : SetGroup) -> SetGroup {
  { id: self.id, label: self.label, members: self.members.copy() }
}

///|
fn SceneObject::id(self : SceneObject) -> String {
  match self {
    Sequence(value) => value.id
    Sets(value) => value.id
    Graph(value) => value.id
    Grid(value) => value.id
  }
}

///|
fn SceneObject::deep_copy(self : SceneObject) -> SceneObject {
  match self {
    Sequence(value) =>
      Sequence({ id: value.id, label: value.label, items: value.items.copy() })
    Sets(value) =>
      Sets({
        id: value.id,
        label: value.label,
        groups: value.groups.map(fn(group) { group.deep_copy() }),
      })
    Graph(value) =>
      Graph({
        id: value.id,
        label: value.label,
        nodes: value.nodes.copy(),
        edges: value.edges.copy(),
      })
    Grid(value) =>
      Grid({
        id: value.id,
        label: value.label,
        width: value.width,
        height: value.height,
        cells: value.cells.copy(),
      })
  }
}

///|
fn Scene::deep_copy(self : Scene) -> Scene {
  {
    objects: self.objects.map(fn(object) { object.deep_copy() }),
    highlights: self.highlights.copy(),
  }
}

///|
fn AlgorithmTraceStep::deep_copy(
  self : AlgorithmTraceStep,
) -> AlgorithmTraceStep {
  {
    index: self.index,
    event: self.event.deep_copy(),
    scene: self.scene.deep_copy(),
    annotation: self.annotation,
  }
}

///|
fn Scene::contains_target(self : Scene, target : String) -> Bool {
  self.objects.any(fn(object) {
    if object.id() == target {
      true
    } else {
      match object {
        Sequence(value) => value.items.any(fn(item) { item.id == target })
        Sets(value) =>
          value.groups.any(fn(group) {
            group.id == target || group.members.contains(target)
          })
        Graph(value) =>
          value.nodes.any(fn(node) { node.id == target }) ||
          value.edges.any(fn(edge) { edge.id == target })
        Grid(value) => value.cells.any(fn(cell) { cell.id == target })
      }
    }
  })
}

///|
fn Scene::validate_highlights(self : Scene) -> Unit raise {
  for highlight in self.highlights {
    if !self.contains_target(highlight.target) {
      fail("Highlight target must reference a scene object or entity id")
    }
  }
}

///|
fn ensure_unique_object_ids(objects : Array[SceneObject]) -> Unit raise {
  for i in 0..<objects.length() {
    for j in (i + 1)..<objects.length() {
      if objects[i].id() == objects[j].id() {
        fail("Scene object ids must be unique")
      }
    }
  }
}

///|
fn ensure_unique_node_ids(nodes : Array[GraphNode]) -> Unit raise {
  for i in 0..<nodes.length() {
    for j in (i + 1)..<nodes.length() {
      if nodes[i].id == nodes[j].id {
        fail("Graph node ids must be unique")
      }
    }
  }
}

///|
fn ensure_unique_cell_ids(cells : Array[GridCellState]) -> Unit raise {
  for i in 0..<cells.length() {
    for j in (i + 1)..<cells.length() {
      if cells[i].id == cells[j].id {
        fail("Grid cell ids must be unique")
      }
    }
  }
}
