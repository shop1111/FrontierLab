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
/// A scoped reference to either a scene object or one entity inside it.
pub struct TargetRef {
  object_id : String
  entity_id : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn TargetRef::object(object_id : String) -> TargetRef {
  { object_id, entity_id: None }
}

///|
pub fn TargetRef::entity(object_id : String, entity_id : String) -> TargetRef {
  { object_id, entity_id: Some(entity_id) }
}

///|
pub(all) suberror TraceError {
  JsonSyntax(String)
  UnsupportedSchema(String)
  DuplicateId(String)
  DanglingReference(TargetRef)
  InvalidGraph(String)
  InvalidGrid(String)
  InvalidStep(String)
  DuplicateSummaryKey(String)
  AlreadyCompleted
  LimitExceeded(String)
} derive(Debug, Eq)

///|
pub fn TraceError::message(self : TraceError) -> String {
  match self {
    JsonSyntax(message) => "Invalid trace JSON: \{message}"
    UnsupportedSchema(version) => "Unsupported trace schema version: \{version}"
    DuplicateId(message) => message
    DanglingReference(target) =>
      match target.entity_id {
        Some(id) => "Dangling reference: \{target.object_id}/\{id}"
        None => "Dangling object reference: \{target.object_id}"
      }
    InvalidGraph(message) => "Invalid graph: \{message}"
    InvalidGrid(message) => "Invalid grid: \{message}"
    InvalidStep(message) => "Invalid trace step: \{message}"
    DuplicateSummaryKey(key) => "Duplicate summary key: \{key}"
    AlreadyCompleted => "Cannot record after Complete"
    LimitExceeded(message) => message
  }
}

///|
pub impl Show for TraceError with fn output(self : TraceError, logger : &Logger) -> Unit {
  logger.write_string(self.message())
}

///|
pub struct TraceOptions {
  max_steps : Int
  max_entities_per_scene : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn TraceOptions::default() -> TraceOptions {
  { max_steps: 10000, max_entities_per_scene: 10000 }
}

///|
pub fn TraceOptions::new(
  max_steps? : Int = 10000,
  max_entities_per_scene? : Int = 10000,
) -> TraceOptions raise TraceError {
  if max_steps <= 0 || max_entities_per_scene <= 0 {
    raise LimitExceeded("Trace limits must be positive")
  }
  { max_steps, max_entities_per_scene }
}

///|
/// The semantic reason why an algorithm produced a new scene.
pub(all) enum TraceEvent {
  Initialize
  Compare(Array[TargetRef])
  Swap(TargetRef, TargetRef)
  Visit(TargetRef)
  Update(TargetRef, String)
  Union(TargetRef, TargetRef)
  Relax(TargetRef, TargetRef, String)
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
  target : TargetRef
  role : HighlightRole
} derive(Debug, Eq, ToJson)

///|
pub fn Highlight::new(target~ : TargetRef, role~ : HighlightRole) -> Highlight {
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
) -> GraphState raise TraceError {
  ensure_unique_node_ids(nodes)
  for edge in edges {
    if !nodes.any(fn(node) { node.id == edge.from }) ||
      !nodes.any(fn(node) { node.id == edge.to }) {
      raise InvalidGraph(
        "Graph edge endpoints must reference existing node ids",
      )
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
) -> GridState raise TraceError {
  if width <= 0 || height <= 0 {
    raise InvalidGrid("Grid scene dimensions must be positive")
  }
  ensure_unique_cell_ids(cells)
  for cell in cells {
    if cell.x < 0 || cell.y < 0 || cell.x >= width || cell.y >= height {
      raise InvalidGrid("Grid scene cell is outside its dimensions")
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
) -> Scene raise TraceError {
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
  options : TraceOptions
  mut completed : Bool
} derive(Debug)

///|
pub fn TraceBuilder::new(
  title~ : String,
  algorithm~ : String,
  description? : String = "",
  initial_scene~ : Scene,
  options? : TraceOptions = TraceOptions::default(),
) -> TraceBuilder raise TraceError {
  initial_scene.validate(options)
  {
    title,
    algorithm,
    description,
    initial_scene: initial_scene.deep_copy(),
    steps: [],
    options,
    completed: false,
  }
}

///|
pub fn TraceBuilder::record(
  self : TraceBuilder,
  event~ : TraceEvent,
  scene~ : Scene,
  annotation? : Annotation,
) -> Unit raise TraceError {
  if self.completed {
    raise AlreadyCompleted
  }
  if self.steps.length() >= self.options.max_steps {
    raise LimitExceeded("Trace step limit exceeded")
  }
  scene.validate(self.options)
  validate_event(event, scene)
  self.steps.push({
    index: self.steps.length(),
    event: event.deep_copy(),
    scene: scene.deep_copy(),
    annotation,
  })
  if event is Complete {
    self.completed = true
  }
}

///|
pub fn TraceBuilder::finish(
  self : TraceBuilder,
  summary? : Array[TraceAttribute] = [],
) -> AlgorithmTrace raise TraceError {
  ensure_unique_summary_keys(summary)
  let trace = {
    schema_version: "1.0",
    title: self.title,
    algorithm: self.algorithm,
    description: self.description,
    initial_scene: self.initial_scene.deep_copy(),
    steps: self.steps.map(fn(step) { step.deep_copy() }),
    summary: summary.copy(),
  }
  trace.validate(options=self.options)
  trace
}

///|
pub fn AlgorithmTrace::to_json_string(self : AlgorithmTrace) -> String {
  self.encode_json()
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
fn Scene::contains_target(self : Scene, target : TargetRef) -> Bool {
  match self.objects.search_by(fn(object) { object.id() == target.object_id }) {
    None => false
    Some(index) =>
      match target.entity_id {
        None => true
        Some(id) =>
          match self.objects[index] {
            Sequence(value) => value.items.any(fn(item) { item.id == id })
            Sets(value) =>
              value.groups.any(fn(group) {
                group.id == id || group.members.contains(id)
              })
            Graph(value) =>
              value.nodes.any(fn(node) { node.id == id }) ||
              value.edges.any(fn(edge) { edge.id == id })
            Grid(value) => value.cells.any(fn(cell) { cell.id == id })
          }
      }
  }
}

///|
fn Scene::validate_highlights(self : Scene) -> Unit raise TraceError {
  for highlight in self.highlights {
    if !self.contains_target(highlight.target) {
      raise DanglingReference(highlight.target)
    }
  }
}

///|
fn Scene::entity_count(self : Scene) -> Int {
  self.objects.fold(init=0, fn(total, object) {
    let count = match object {
      Sequence(value) => value.items.length()
      Sets(value) =>
        value.groups.fold(init=0, fn(n, group) {
          n + 1 + group.members.length()
        })
      Graph(value) => value.nodes.length() + value.edges.length()
      Grid(value) => value.cells.length()
    }
    total + 1 + count
  })
}

///|
fn Scene::validate(
  self : Scene,
  options : TraceOptions,
) -> Unit raise TraceError {
  ensure_unique_object_ids(self.objects)
  for object in self.objects {
    validate_object_entities(object)
  }
  self.validate_highlights()
  if self.entity_count() > options.max_entities_per_scene {
    raise LimitExceeded("Scene entity limit exceeded")
  }
}

///|
fn validate_event(event : TraceEvent, scene : Scene) -> Unit raise TraceError {
  let targets = match event {
    Compare(values) => values
    Swap(left, right) => [left, right]
    Visit(target) => [target]
    Update(target, _) => [target]
    Union(left, right) => [left, right]
    Relax(from, to, _) => [from, to]
    _ => []
  }
  for target in targets {
    if !scene.contains_target(target) {
      raise DanglingReference(target)
    }
  }
}

///|
fn validate_object_entities(object : SceneObject) -> Unit raise TraceError {
  match object {
    Sequence(value) =>
      ensure_unique_strings(
        value.items.map(fn(item) { item.id }),
        "sequence entity",
      )
    Sets(value) => {
      ensure_unique_strings(
        value.groups.map(fn(group) { group.id }),
        "set group",
      )
      let members : Array[String] = []
      for group in value.groups {
        for value in group.members {
          members.push(value)
        }
      }
      ensure_unique_strings(members, "set member")
    }
    Graph(value) => {
      ensure_unique_strings(value.nodes.map(fn(node) { node.id }), "graph node")
      ensure_unique_strings(value.edges.map(fn(edge) { edge.id }), "graph edge")
    }
    Grid(value) =>
      ensure_unique_strings(value.cells.map(fn(cell) { cell.id }), "grid cell")
  }
}

///|
fn ensure_unique_strings(
  values : Array[String],
  kind : String,
) -> Unit raise TraceError {
  for i in 0..<values.length() {
    for j in (i + 1)..<values.length() {
      if values[i] == values[j] {
        raise DuplicateId("Duplicate \{kind} id: \{values[i]}")
      }
    }
  }
}

///|
fn ensure_unique_summary_keys(
  values : Array[TraceAttribute],
) -> Unit raise TraceError {
  for i in 0..<values.length() {
    for j in (i + 1)..<values.length() {
      if values[i].key == values[j].key {
        raise DuplicateSummaryKey(values[i].key)
      }
    }
  }
}

///|
pub fn AlgorithmTrace::validate(
  self : AlgorithmTrace,
  options? : TraceOptions = TraceOptions::default(),
) -> Unit raise TraceError {
  if self.schema_version != "1.0" {
    raise UnsupportedSchema(self.schema_version)
  }
  self.initial_scene.validate(options)
  if self.steps.length() > options.max_steps {
    raise LimitExceeded("Trace step limit exceeded")
  }
  let mut completed = false
  for index, step in self.steps {
    if step.index != index {
      raise InvalidStep("Step indices must be contiguous from zero")
    }
    if completed {
      raise InvalidStep("Complete must be the final step")
    }
    step.scene.validate(options)
    validate_event(step.event, step.scene)
    if step.event is Complete {
      completed = true
    }
  }
  ensure_unique_summary_keys(self.summary)
}

///|
fn ensure_unique_object_ids(
  objects : Array[SceneObject],
) -> Unit raise TraceError {
  for i in 0..<objects.length() {
    for j in (i + 1)..<objects.length() {
      if objects[i].id() == objects[j].id() {
        raise DuplicateId("Duplicate scene object id: \{objects[i].id()}")
      }
    }
  }
}

///|
fn ensure_unique_node_ids(nodes : Array[GraphNode]) -> Unit raise TraceError {
  for i in 0..<nodes.length() {
    for j in (i + 1)..<nodes.length() {
      if nodes[i].id == nodes[j].id {
        raise DuplicateId("Duplicate graph node id: \{nodes[i].id}")
      }
    }
  }
}

///|
fn ensure_unique_cell_ids(
  cells : Array[GridCellState],
) -> Unit raise TraceError {
  for i in 0..<cells.length() {
    for j in (i + 1)..<cells.length() {
      if cells[i].id == cells[j].id {
        raise DuplicateId("Duplicate grid cell id: \{cells[i].id}")
      }
    }
  }
}
