///|
/// Stable version marker for machine-readable debugger reports.
pub let debug_report_version : String = "frontierlab-debug-report/1.0"

///|
pub(all) enum TraceChangeKind {
  Added
  Removed
  Updated
  Moved
  HighlightAdded
  HighlightRemoved
} derive(Debug, Eq, ToJson)

///|
pub struct TraceChange {
  kind : TraceChangeKind
  target : TargetRef
  before_value : String
  after_value : String
  before_index : Int
  after_index : Int
} derive(Debug, Eq, ToJson)

///|
pub fn TraceChange::new(
  kind~ : TraceChangeKind,
  target~ : TargetRef,
  before_value? : String = "",
  after_value? : String = "",
  before_index? : Int = -1,
  after_index? : Int = -1,
) -> TraceChange {
  { kind, target, before_value, after_value, before_index, after_index }
}

///|
pub struct TraceFrameDiff {
  from_step : Int
  to_step : Int
  changes : Array[TraceChange]
} derive(Debug, Eq, ToJson)

///|
pub fn TraceFrameDiff::is_empty(self : TraceFrameDiff) -> Bool {
  self.changes.is_empty()
}

///|
pub fn TraceFrameDiff::to_json_string(self : TraceFrameDiff) -> String {
  self.to_json().stringify(indent=2)
}

///|
pub fn TraceFrameDiff::report(self : TraceFrameDiff) -> String {
  let out = StringBuilder()
  out.write_string("Diff frame \{self.from_step} -> \{self.to_step}\n")
  if self.changes.is_empty() {
    out.write_string("No semantic scene changes.\n")
  } else {
    for change in self.changes {
      out.write_string(
        "- \{debug_change_name(change.kind)} \{debugger_target_label(change.target)}",
      )
      if change.before_value != "" || change.after_value != "" {
        out.write_string(": \{change.before_value} -> \{change.after_value}")
      }
      if change.before_index != change.after_index &&
        (change.before_index >= 0 || change.after_index >= 0) {
        out.write_string(" [\{change.before_index} -> \{change.after_index}]")
      }
      out.write_string("\n")
    }
  }
  out.to_string()
}

///|
pub fn AlgorithmTrace::diff(
  self : AlgorithmTrace,
  from_step~ : Int,
  to_step~ : Int,
) -> TraceFrameDiff raise TraceError {
  let before = debugger_scene_at(self, from_step)
  let after = debugger_scene_at(self, to_step)
  { from_step, to_step, changes: debugger_scene_diff(before, after) }
}

///|
pub struct TraceBreakpoint {
  event_kind : String
  target : TargetRef?
  role : String
  changed_only : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn TraceBreakpoint::new(
  event_kind? : String = "",
  target? : TargetRef,
  role? : String = "",
  changed_only? : Bool = false,
) -> TraceBreakpoint {
  { event_kind, target, role, changed_only }
}

///|
pub struct TraceBreakpointHit {
  step : Int
  event_kind : String
  targets : Array[TargetRef]
  changes : Array[TraceChange]
  reason : String
} derive(Debug, Eq, ToJson)

///|
pub fn AlgorithmTrace::breakpoint_hits(
  self : AlgorithmTrace,
  breakpoint : TraceBreakpoint,
) -> Array[TraceBreakpointHit] {
  let hits : Array[TraceBreakpointHit] = []
  for step in self.steps {
    let event_kind = debugger_event_name(step.event)
    let targets = debugger_event_targets(step.event)
    let diff = try! self.diff(from_step=step.index - 1, to_step=step.index)
    let event_matches = breakpoint.event_kind == "" ||
      breakpoint.event_kind == event_kind
    let target_matches = match breakpoint.target {
      Some(target) =>
        targets.any(fn(value) { debugger_target_matches(target, value) }) ||
        diff.changes.any(fn(change) {
          debugger_target_matches(target, change.target)
        })
      None => true
    }
    let role_matches = breakpoint.role == "" ||
      step.scene.highlights.any(fn(highlight) {
        let target_matches_role = match breakpoint.target {
          Some(target) => debugger_target_matches(target, highlight.target)
          None => true
        }
        debugger_role_name(highlight.role) == breakpoint.role &&
        target_matches_role
      })
    let change_matches = !breakpoint.changed_only || !diff.changes.is_empty()
    if event_matches && target_matches && role_matches && change_matches {
      hits.push({
        step: step.index,
        event_kind,
        targets,
        changes: diff.changes,
        reason: debugger_breakpoint_reason(breakpoint),
      })
    }
  }
  hits
}

///|
pub struct TraceCounterexample {
  original_title : String
  original_start : Int
  original_focus : Int
  original_end : Int
  focus_step : Int
  trace : AlgorithmTrace
} derive(Debug, Eq, ToJson)

///|
pub fn TraceCounterexample::to_json_string(
  self : TraceCounterexample,
) -> String {
  self.to_json().stringify(indent=2)
}

///|
pub fn AlgorithmTrace::slice(
  self : AlgorithmTrace,
  center~ : Int,
  before? : Int = 2,
  after? : Int = 2,
) -> TraceCounterexample raise TraceError {
  if center < 0 || center >= self.steps.length() {
    raise InvalidStep("Slice center \{center} is outside the trace.")
  }
  if before < 0 || after < 0 {
    raise InvalidStep("Slice context must be non-negative.")
  }
  let start = debugger_max(0, center - before)
  let end = debugger_min(self.steps.length() - 1, center + after)
  let initial_scene = debugger_scene_at(self, start - 1).deep_copy()
  let steps : Array[AlgorithmTraceStep] = []
  for original_index in start..<=end {
    let source = self.steps[original_index]
    steps.push({
      index: original_index - start,
      event: source.event.deep_copy(),
      scene: source.scene.deep_copy(),
      annotation: source.annotation,
    })
  }
  let trace : AlgorithmTrace = {
    schema_version: self.schema_version,
    title: "\{self.title} counterexample",
    algorithm: self.algorithm,
    description: "Steps \{start}..\{end} from \{self.title}.",
    initial_scene,
    steps,
    summary: [
      TraceAttribute::new(key="original_start", value=start.to_string()),
      TraceAttribute::new(key="original_focus", value=center.to_string()),
      TraceAttribute::new(key="original_end", value=end.to_string()),
    ],
  }
  trace.validate()
  {
    original_title: self.title,
    original_start: start,
    original_focus: center,
    original_end: end,
    focus_step: center - start,
    trace,
  }
}

///|
pub(all) enum TraceDivergenceKind {
  EventMismatch
  SceneMismatch
  ExpectedEnded
  ActualEnded
} derive(Debug, Eq, ToJson)

///|
pub struct TraceDivergence {
  step : Int
  kind : TraceDivergenceKind
  message : String
  expected_event : String
  actual_event : String
  scene_diff : TraceFrameDiff?
} derive(Debug, Eq, ToJson)

///|
pub fn TraceDivergence::to_json_string(self : TraceDivergence) -> String {
  self.to_json().stringify(indent=2)
}

///|
pub fn first_divergence(
  expected : AlgorithmTrace,
  actual : AlgorithmTrace,
) -> TraceDivergence? {
  let shared = debugger_min(expected.steps.length(), actual.steps.length())
  for index in 0..<shared {
    let expected_event = debugger_event_name(expected.steps[index].event)
    let actual_event = debugger_event_name(actual.steps[index].event)
    if expected.steps[index].event != actual.steps[index].event {
      return Some({
        step: index,
        kind: EventMismatch,
        message: "Events first diverge at step \{index}.",
        expected_event,
        actual_event,
        scene_diff: None,
      })
    }
    if expected.steps[index].scene != actual.steps[index].scene {
      let changes = debugger_scene_diff(
        expected.steps[index].scene,
        actual.steps[index].scene,
      )
      return Some({
        step: index,
        kind: SceneMismatch,
        message: "Scenes first diverge at step \{index}.",
        expected_event,
        actual_event,
        scene_diff: Some({ from_step: index, to_step: index, changes }),
      })
    }
  }
  if expected.steps.length() < actual.steps.length() {
    Some({
      step: shared,
      kind: ExpectedEnded,
      message: "Expected trace ended before actual trace at step \{shared}.",
      expected_event: "",
      actual_event: debugger_event_name(actual.steps[shared].event),
      scene_diff: None,
    })
  } else if actual.steps.length() < expected.steps.length() {
    Some({
      step: shared,
      kind: ActualEnded,
      message: "Actual trace ended before expected trace at step \{shared}.",
      expected_event: debugger_event_name(expected.steps[shared].event),
      actual_event: "",
      scene_diff: None,
    })
  } else {
    None
  }
}

///|
fn debugger_scene_at(
  trace : AlgorithmTrace,
  step : Int,
) -> Scene raise TraceError {
  if step == -1 {
    trace.initial_scene
  } else if step >= 0 && step < trace.steps.length() {
    trace.steps[step].scene
  } else {
    raise InvalidStep(
      "Frame \{step} is outside -1..\{trace.steps.length() - 1}.",
    )
  }
}

///|
struct DebugEntity {
  id : String
  value : String
  index : Int
} derive(Debug, Eq)

///|
fn debugger_scene_diff(before : Scene, after : Scene) -> Array[TraceChange] {
  let changes : Array[TraceChange] = []
  for object in before.objects {
    let id = object.id()
    match after.objects.search_by(fn(value) { value.id() == id }) {
      None =>
        changes.push(
          TraceChange::new(kind=Removed, target=TargetRef::object(id)),
        )
      Some(index) => {
        let next = after.objects[index]
        let before_entities = debugger_entities(object)
        let after_entities = debugger_entities(next)
        if debugger_object_kind(object) != debugger_object_kind(next) {
          changes.push(
            TraceChange::new(
              kind=Updated,
              target=TargetRef::object(id),
              before_value=debugger_object_kind(object),
              after_value=debugger_object_kind(next),
            ),
          )
        } else {
          debugger_diff_entities(id, before_entities, after_entities, changes)
        }
      }
    }
  }
  for object in after.objects {
    if !before.objects.any(fn(value) { value.id() == object.id() }) {
      changes.push(
        TraceChange::new(kind=Added, target=TargetRef::object(object.id())),
      )
    }
  }
  for highlight in before.highlights {
    if !after.highlights.any(fn(value) { value == highlight }) {
      changes.push(
        TraceChange::new(
          kind=HighlightRemoved,
          target=highlight.target,
          before_value=debugger_role_name(highlight.role),
        ),
      )
    }
  }
  for highlight in after.highlights {
    if !before.highlights.any(fn(value) { value == highlight }) {
      changes.push(
        TraceChange::new(
          kind=HighlightAdded,
          target=highlight.target,
          after_value=debugger_role_name(highlight.role),
        ),
      )
    }
  }
  changes
}

///|
fn debugger_diff_entities(
  object_id : String,
  before : Array[DebugEntity],
  after : Array[DebugEntity],
  changes : Array[TraceChange],
) -> Unit {
  for entity in before {
    match after.search_by(fn(value) { value.id == entity.id }) {
      None =>
        changes.push(
          TraceChange::new(
            kind=Removed,
            target=TargetRef::entity(object_id, entity.id),
            before_value=entity.value,
            before_index=entity.index,
          ),
        )
      Some(index) => {
        let next = after[index]
        if entity.value != next.value {
          changes.push(
            TraceChange::new(
              kind=Updated,
              target=TargetRef::entity(object_id, entity.id),
              before_value=entity.value,
              after_value=next.value,
              before_index=entity.index,
              after_index=next.index,
            ),
          )
        } else if entity.index != next.index {
          changes.push(
            TraceChange::new(
              kind=Moved,
              target=TargetRef::entity(object_id, entity.id),
              before_value=entity.value,
              after_value=next.value,
              before_index=entity.index,
              after_index=next.index,
            ),
          )
        }
      }
    }
  }
  for entity in after {
    if !before.any(fn(value) { value.id == entity.id }) {
      changes.push(
        TraceChange::new(
          kind=Added,
          target=TargetRef::entity(object_id, entity.id),
          after_value=entity.value,
          after_index=entity.index,
        ),
      )
    }
  }
}

///|
fn debugger_entities(object : SceneObject) -> Array[DebugEntity] {
  match object {
    Sequence(state) => {
      let values : Array[DebugEntity] = []
      for index, item in state.items {
        values.push({ id: item.id, value: item.value, index })
      }
      values
    }
    Sets(state) => {
      let values : Array[DebugEntity] = []
      for index, group in state.groups {
        values.push({
          id: group.id,
          value: "\{group.label}:\{group.members.join(",")}",
          index,
        })
      }
      values
    }
    Graph(state) => {
      let values : Array[DebugEntity] = []
      for index, node in state.nodes {
        values.push({ id: node.id, value: node.label, index })
      }
      for index, edge in state.edges {
        values.push({
          id: "edge:\{edge.id}",
          value: "\{edge.from}->\{edge.to}:\{edge.label}:\{edge.directed}",
          index: state.nodes.length() + index,
        })
      }
      values
    }
    Grid(state) => {
      let values : Array[DebugEntity] = []
      for index, cell in state.cells {
        values.push({
          id: cell.id,
          value: "\{cell.x},\{cell.y}:\{cell.label}:\{cell.blocked}",
          index,
        })
      }
      values
    }
  }
}

///|
fn debugger_event_name(event : TraceEvent) -> String {
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
fn debugger_event_targets(event : TraceEvent) -> Array[TargetRef] {
  match event {
    Compare(targets) => targets
    Swap(left, right) | Union(left, right) => [left, right]
    Visit(target) | Update(target, _) => [target]
    Relax(from, to, _) => [from, to]
    _ => []
  }
}

///|
fn debugger_target_matches(filter : TargetRef, value : TargetRef) -> Bool {
  let entity_matches = match filter.entity_id {
    Some(entity) => value.entity_id == Some(entity)
    None => true
  }
  filter.object_id == value.object_id && entity_matches
}

///|
fn debugger_object_kind(object : SceneObject) -> String {
  match object {
    Sequence(_) => "sequence"
    Sets(_) => "sets"
    Graph(_) => "graph"
    Grid(_) => "grid"
  }
}

///|
fn debugger_role_name(role : HighlightRole) -> String {
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
fn debugger_target_label(target : TargetRef) -> String {
  match target.entity_id {
    Some(entity) => "\{target.object_id}/\{entity}"
    None => target.object_id
  }
}

///|
fn debug_change_name(kind : TraceChangeKind) -> String {
  match kind {
    Added => "added"
    Removed => "removed"
    Updated => "updated"
    Moved => "moved"
    HighlightAdded => "highlight-added"
    HighlightRemoved => "highlight-removed"
  }
}

///|
fn debugger_breakpoint_reason(value : TraceBreakpoint) -> String {
  let parts : Array[String] = []
  if value.event_kind != "" {
    parts.push("event=\{value.event_kind}")
  }
  match value.target {
    Some(target) => parts.push("target=\{debugger_target_label(target)}")
    None => ()
  }
  if value.role != "" {
    parts.push("role=\{value.role}")
  }
  if value.changed_only {
    parts.push("changed-only")
  }
  if parts.is_empty() {
    "all steps"
  } else {
    parts.join(", ")
  }
}

///|
fn debugger_max(left : Int, right : Int) -> Int {
  if left >= right {
    left
  } else {
    right
  }
}

///|
fn debugger_min(left : Int, right : Int) -> Int {
  if left <= right {
    left
  } else {
    right
  }
}
