///|
/// A counted event kind in an `AlgorithmTrace`.
pub struct EventCount {
  name : String
  count : Int
  first_step : Int
  last_step : Int
} derive(Debug, Eq, ToJson)

///|
pub fn EventCount::new(
  name~ : String,
  count? : Int = 0,
  first_step? : Int = -1,
  last_step? : Int = -1,
) -> EventCount {
  { name, count, first_step, last_step }
}

///|
/// Object-level usage collected across the initial scene and every step scene.
pub struct ObjectUsage {
  object_id : String
  object_kind : String
  appearances : Int
  max_entities : Int
  first_step : Int
  last_step : Int
} derive(Debug, Eq, ToJson)

///|
pub fn ObjectUsage::new(
  object_id~ : String,
  object_kind~ : String,
  appearances? : Int = 0,
  max_entities? : Int = 0,
  first_step? : Int = -1,
  last_step? : Int = -1,
) -> ObjectUsage {
  { object_id, object_kind, appearances, max_entities, first_step, last_step }
}

///|
/// Target-level references observed in semantic events and visual highlights.
pub struct TargetUsage {
  object_id : String
  entity_id : String?
  references : Int
  event_references : Int
  highlight_references : Int
  first_step : Int
  last_step : Int
  event_names : Array[String]
  highlight_roles : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub fn TargetUsage::new(
  object_id~ : String,
  entity_id? : String,
  references? : Int = 0,
  event_references? : Int = 0,
  highlight_references? : Int = 0,
  first_step? : Int = -1,
  last_step? : Int = -1,
  event_names? : Array[String] = [],
  highlight_roles? : Array[String] = [],
) -> TargetUsage {
  {
    object_id,
    entity_id,
    references,
    event_references,
    highlight_references,
    first_step,
    last_step,
    event_names: event_names.copy(),
    highlight_roles: highlight_roles.copy(),
  }
}

///|
/// Summary of a full trace document, suitable for docs, CLI output, or CI smoke
/// checks before rendering.
pub struct TraceStats {
  title : String
  algorithm : String
  step_count : Int
  completed : Bool
  event_counts : Array[EventCount]
  object_usage : Array[ObjectUsage]
  target_usage : Array[TargetUsage]
  initial_object_count : Int
  max_objects_per_scene : Int
  max_entities_per_scene : Int
  summary_count : Int
  annotation_count : Int
  custom_event_count : Int
  highlight_count : Int
} derive(Debug, Eq, ToJson)

///|
pub fn TraceStats::summary_report(self : TraceStats) -> String {
  let out = StringBuilder()
  out.write_string("Trace: \{self.title}\n")
  out.write_string("Algorithm: \{self.algorithm}\n")
  out.write_string("Steps: \{self.step_count}\n")
  out.write_string("Completed: \{self.completed}\n")
  out.write_string("Initial objects: \{self.initial_object_count}\n")
  out.write_string("Max objects per scene: \{self.max_objects_per_scene}\n")
  out.write_string("Max entities per scene: \{self.max_entities_per_scene}\n")
  out.write_string("Annotations: \{self.annotation_count}\n")
  out.write_string("Highlights: \{self.highlight_count}\n")
  out.write_string("Summary attributes: \{self.summary_count}\n")
  out.write_string("Events:\n")
  if self.event_counts.is_empty() {
    out.write_string("  none\n")
  } else {
    for item in self.event_counts {
      out.write_string(
        "  \{item.name}: \{item.count} (steps \{item.first_step}..\{item.last_step})\n",
      )
    }
  }
  out.write_string("Objects:\n")
  if self.object_usage.is_empty() {
    out.write_string("  none\n")
  } else {
    for item in self.object_usage {
      out.write_string(
        "  \{item.object_id} [\{item.object_kind}]: \{item.appearances} appearances, max \{item.max_entities} entities\n",
      )
    }
  }
  out.write_string("Top targets:\n")
  let targets = self.top_targets(limit=6)
  if targets.is_empty() {
    out.write_string("  none\n")
  } else {
    for item in targets {
      out.write_string(
        "  \{target_usage_label(item)}: \{item.references} references\n",
      )
    }
  }
  out.to_string()
}

///|
pub fn TraceStats::event_count(self : TraceStats, name : String) -> Int {
  match self.event_counts.search_by(fn(item) { item.name == name }) {
    Some(index) => self.event_counts[index].count
    None => 0
  }
}

///|
pub fn TraceStats::object_count(self : TraceStats, object_id : String) -> Int {
  match self.object_usage.search_by(fn(item) { item.object_id == object_id }) {
    Some(index) => self.object_usage[index].appearances
    None => 0
  }
}

///|
pub fn TraceStats::target_count(
  self : TraceStats,
  object_id : String,
  entity_id? : String,
) -> Int {
  match
    self.target_usage.search_by(fn(item) {
      item.object_id == object_id && item.entity_id == entity_id
    }) {
    Some(index) => self.target_usage[index].references
    None => 0
  }
}

///|
pub fn TraceStats::top_targets(
  self : TraceStats,
  limit? : Int = 10,
) -> Array[TargetUsage] {
  let values = self.target_usage.copy()
  values.sort_by(fn(left, right) {
    if left.references == right.references {
      target_usage_label(left).compare(target_usage_label(right))
    } else {
      right.references.compare(left.references)
    }
  })
  if limit < 0 || limit >= values.length() {
    values
  } else {
    values[:limit].to_owned()
  }
}

///|
pub fn AlgorithmTrace::analyze(self : AlgorithmTrace) -> TraceStats {
  let events : Array[EventCount] = []
  let objects : Array[ObjectUsage] = []
  let targets : Array[TargetUsage] = []
  let mut max_objects = self.initial_scene.objects.length()
  let mut max_entities = self.initial_scene.entity_count()
  let mut annotations = 0
  let mut custom_events = 0
  let mut highlights = 0
  collect_scene_usage(self.initial_scene, -1, objects, targets)
  highlights += self.initial_scene.highlights.length()
  for highlight in self.initial_scene.highlights {
    add_target_usage(
      targets,
      highlight.target,
      -1,
      event_name="",
      highlight_role=Some(highlight_role_name(highlight.role)),
    )
  }
  for step in self.steps {
    let name = trace_event_name(step.event)
    add_event_count(events, name, step.index)
    if step.event is Custom(_, _) {
      custom_events += 1
    }
    if step.annotation is Some(_) {
      annotations += 1
    }
    max_objects = max_int(max_objects, step.scene.objects.length())
    max_entities = max_int(max_entities, step.scene.entity_count())
    collect_scene_usage(step.scene, step.index, objects, targets)
    collect_event_targets(step.event, step.index, targets)
    highlights += step.scene.highlights.length()
    for highlight in step.scene.highlights {
      add_target_usage(
        targets,
        highlight.target,
        step.index,
        event_name="",
        highlight_role=Some(highlight_role_name(highlight.role)),
      )
    }
  }
  {
    title: self.title,
    algorithm: self.algorithm,
    step_count: self.steps.length(),
    completed: self.steps
    .last()
    .map(fn(step) { step.event is Complete })
    .unwrap_or(false),
    event_counts: events,
    object_usage: objects,
    target_usage: targets,
    initial_object_count: self.initial_scene.objects.length(),
    max_objects_per_scene: max_objects,
    max_entities_per_scene: max_entities,
    summary_count: self.summary.length(),
    annotation_count: annotations,
    custom_event_count: custom_events,
    highlight_count: highlights,
  }
}

///|
pub fn AlgorithmTrace::event_counts(self : AlgorithmTrace) -> Array[EventCount] {
  self.analyze().event_counts
}

///|
pub fn AlgorithmTrace::target_usage(
  self : AlgorithmTrace,
) -> Array[TargetUsage] {
  self.analyze().target_usage
}

///|
pub fn AlgorithmTrace::object_usage(
  self : AlgorithmTrace,
) -> Array[ObjectUsage] {
  self.analyze().object_usage
}

///|
pub fn AlgorithmTrace::summary_report(self : AlgorithmTrace) -> String {
  self.analyze().summary_report()
}

///|
fn add_event_count(
  counts : Array[EventCount],
  name : String,
  step : Int,
) -> Unit {
  match counts.search_by(fn(item) { item.name == name }) {
    Some(index) => {
      let current = counts[index]
      counts[index] = {
        name: current.name,
        count: current.count + 1,
        first_step: current.first_step,
        last_step: step,
      }
    }
    None =>
      counts.push(
        EventCount::new(name~, count=1, first_step=step, last_step=step),
      )
  }
}

///|
fn collect_scene_usage(
  scene : Scene,
  step : Int,
  objects : Array[ObjectUsage],
  targets : Array[TargetUsage],
) -> Unit {
  for object in scene.objects {
    add_object_usage(objects, object, step)
    add_scene_object_targets(targets, object, step)
  }
}

///|
fn add_object_usage(
  values : Array[ObjectUsage],
  object : SceneObject,
  step : Int,
) -> Unit {
  let object_id = object.id()
  let kind = scene_object_kind(object)
  let entities = scene_object_entity_count(object)
  match values.search_by(fn(item) { item.object_id == object_id }) {
    Some(index) => {
      let current = values[index]
      values[index] = {
        object_id: current.object_id,
        object_kind: current.object_kind,
        appearances: current.appearances + 1,
        max_entities: max_int(current.max_entities, entities),
        first_step: current.first_step,
        last_step: step,
      }
    }
    None =>
      values.push(
        ObjectUsage::new(
          object_id~,
          object_kind=kind,
          appearances=1,
          max_entities=entities,
          first_step=step,
          last_step=step,
        ),
      )
  }
}

///|
fn add_scene_object_targets(
  values : Array[TargetUsage],
  object : SceneObject,
  step : Int,
) -> Unit {
  add_target_usage(
    values,
    TargetRef::object(object.id()),
    step,
    event_name="scene",
    highlight_role=None,
  )
  match object {
    Sequence(state) =>
      for item in state.items {
        add_target_usage(
          values,
          TargetRef::entity(state.id, item.id),
          step,
          event_name="scene",
          highlight_role=None,
        )
      }
    Sets(state) =>
      for group in state.groups {
        add_target_usage(
          values,
          TargetRef::entity(state.id, group.id),
          step,
          event_name="scene",
          highlight_role=None,
        )
        for set_member in group.members {
          add_target_usage(
            values,
            TargetRef::entity(state.id, set_member),
            step,
            event_name="scene",
            highlight_role=None,
          )
        }
      }
    Graph(state) => {
      for node in state.nodes {
        add_target_usage(
          values,
          TargetRef::entity(state.id, node.id),
          step,
          event_name="scene",
          highlight_role=None,
        )
      }
      for edge in state.edges {
        add_target_usage(
          values,
          TargetRef::entity(state.id, edge.id),
          step,
          event_name="scene",
          highlight_role=None,
        )
      }
    }
    Grid(state) =>
      for cell in state.cells {
        add_target_usage(
          values,
          TargetRef::entity(state.id, cell.id),
          step,
          event_name="scene",
          highlight_role=None,
        )
      }
  }
}

///|
fn collect_event_targets(
  event : TraceEvent,
  step : Int,
  values : Array[TargetUsage],
) -> Unit {
  let name = trace_event_name(event)
  match event {
    Compare(targets) =>
      for target in targets {
        add_target_usage(
          values,
          target,
          step,
          event_name=name,
          highlight_role=None,
        )
      }
    Swap(left, right) => {
      add_target_usage(values, left, step, event_name=name, highlight_role=None)
      add_target_usage(
        values,
        right,
        step,
        event_name=name,
        highlight_role=None,
      )
    }
    Visit(target) =>
      add_target_usage(
        values,
        target,
        step,
        event_name=name,
        highlight_role=None,
      )
    Update(target, _) =>
      add_target_usage(
        values,
        target,
        step,
        event_name=name,
        highlight_role=None,
      )
    Union(left, right) => {
      add_target_usage(values, left, step, event_name=name, highlight_role=None)
      add_target_usage(
        values,
        right,
        step,
        event_name=name,
        highlight_role=None,
      )
    }
    Relax(from, to, _) => {
      add_target_usage(values, from, step, event_name=name, highlight_role=None)
      add_target_usage(values, to, step, event_name=name, highlight_role=None)
    }
    _ => ()
  }
}

///|
fn add_target_usage(
  values : Array[TargetUsage],
  target : TargetRef,
  step : Int,
  event_name~ : String,
  highlight_role~ : String?,
) -> Unit {
  match
    values.search_by(fn(item) {
      item.object_id == target.object_id && item.entity_id == target.entity_id
    }) {
    Some(index) => {
      let current = values[index]
      let event_names = current.event_names.copy()
      if event_name != "" && !event_names.contains(event_name) {
        event_names.push(event_name)
      }
      let roles = current.highlight_roles.copy()
      match highlight_role {
        Some(role) if !roles.contains(role) => roles.push(role)
        _ => ()
      }
      let event_increment = if event_name == "" { 0 } else { 1 }
      let highlight_increment = if highlight_role is Some(_) { 1 } else { 0 }
      values[index] = {
        object_id: current.object_id,
        entity_id: current.entity_id,
        references: current.references + 1,
        event_references: current.event_references + event_increment,
        highlight_references: current.highlight_references + highlight_increment,
        first_step: current.first_step,
        last_step: step,
        event_names,
        highlight_roles: roles,
      }
    }
    None => {
      let event_names : Array[String] = if event_name == "" {
        []
      } else {
        [event_name]
      }
      let roles : Array[String] = match highlight_role {
        Some(role) => [role]
        None => []
      }
      let event_increment = if event_name == "" { 0 } else { 1 }
      let highlight_increment = if highlight_role is Some(_) { 1 } else { 0 }
      values.push({
        object_id: target.object_id,
        entity_id: target.entity_id,
        references: 1,
        event_references: event_increment,
        highlight_references: highlight_increment,
        first_step: step,
        last_step: step,
        event_names,
        highlight_roles: roles,
      })
    }
  }
}

///|
fn trace_event_name(event : TraceEvent) -> String {
  match event {
    Initialize => "initialize"
    Compare(_) => "compare"
    Swap(_, _) => "swap"
    Visit(_) => "visit"
    Update(_, _) => "update"
    Union(_, _) => "union"
    Relax(_, _, _) => "relax"
    Complete => "complete"
    Custom(kind, _) => kind
  }
}

///|
fn highlight_role_name(role : HighlightRole) -> String {
  match role {
    Current => "current"
    Candidate => "candidate"
    Compared => "compared"
    Changed => "changed"
    Visited => "visited"
    Frontier => "frontier"
    Result => "result"
    Error => "error"
  }
}

///|
fn scene_object_kind(object : SceneObject) -> String {
  match object {
    Sequence(_) => "sequence"
    Sets(_) => "sets"
    Graph(_) => "graph"
    Grid(_) => "grid"
  }
}

///|
fn scene_object_entity_count(object : SceneObject) -> Int {
  match object {
    Sequence(state) => state.items.length()
    Sets(state) =>
      state.groups.fold(init=0, fn(total, group) {
        total + 1 + group.members.length()
      })
    Graph(state) => state.nodes.length() + state.edges.length()
    Grid(state) => state.cells.length()
  }
}

///|
fn target_usage_label(value : TargetUsage) -> String {
  match value.entity_id {
    Some(entity) => "\{value.object_id}/\{entity}"
    None => value.object_id
  }
}

///|
fn max_int(left : Int, right : Int) -> Int {
  if left >= right {
    left
  } else {
    right
  }
}
