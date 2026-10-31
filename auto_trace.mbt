///|
/// How much an automatic tracer records while the algorithm runs.
pub(all) enum TraceLevel {
  /// Run without counting or recording; the baseline for overhead measurement.
  Off
  /// Count operations only; no replayable trace is built.
  Count
  /// Count operations and record a full replayable trace.
  Full
} derive(Debug, Eq, ToJson)

///|
pub extend TraceLevel with Debug::{to_repr}

///|
pub extend TraceLevel with Eq::{not_equal, equal}

///|
pub extend TraceLevel with ToJson::{to_json}

///|
/// Operation counters collected by `TracedArray` and `SequenceProbe`.
///
/// `TracedArray` counts the operations the algorithm performs. `SequenceProbe`
/// infers them from snapshots, so a shift of k elements counts as k writes.
pub struct OperationCounts {
  compares : Int32
  swaps : Int32
  reads : Int32
  writes : Int32
  snapshots : Int32
} derive(Debug, Eq, ToJson)

///|
pub extend OperationCounts with Debug::{to_repr}

///|
pub extend OperationCounts with Eq::{not_equal, equal}

///|
pub extend OperationCounts with ToJson::{to_json}

///|
/// Shared state of the automatic sequence tracers: stable ids, displayed
/// values, counters, and the builder that exists only at `TraceLevel::Full`.
/// Recording errors are kept until `finish` so traced code needs no `raise`.
priv struct SequenceTracker {
  object_id : String
  label : String
  level : TraceLevel
  mut ids : Array[String]
  mut values : Array[String]
  mut next_id : Int32
  builder : TraceBuilder?
  mut error : TraceError?
  mut compares : Int32
  mut swaps : Int32
  mut reads : Int32
  mut writes : Int32
  mut snapshots : Int32
}

///|
fn SequenceTracker::new(
  title~ : String,
  algorithm~ : String,
  description~ : String,
  object_id~ : String,
  label~ : String,
  values~ : Array[String],
  level~ : TraceLevel,
  options~ : TraceOptions,
) -> SequenceTracker {
  let ids = Array::makei(values.length(), fn(i) { "item-\{i}" })
  let mut error : TraceError? = None
  let builder = if level == Full {
    try {
      let initial_scene = tracker_scene(object_id, label, ids, values, [])
      Some(
        TraceBuilder::new(
          title~,
          algorithm~,
          description~,
          initial_scene~,
          options~,
        ),
      )
    } catch {
      err => {
        error = Some(err)
        None
      }
    }
  } else {
    None
  }
  {
    object_id,
    label,
    level,
    ids,
    values: values.copy(),
    next_id: values.length(),
    builder,
    error,
    compares: 0,
    swaps: 0,
    reads: 0,
    writes: 0,
    snapshots: 0,
  }
}

///|
fn tracker_scene(
  object_id : String,
  label : String,
  ids : Array[String],
  values : Array[String],
  highlights : Array[Highlight],
) -> Scene raise TraceError {
  Scene::new(
    objects=[
      Sequence(
        SequenceState::new(
          id=object_id,
          label~,
          items=ids.mapi(fn(i, id) { SequenceItem::new(id~, value=values[i]) }),
        ),
      ),
    ],
    highlights~,
  )
}

///|
fn SequenceTracker::target(self : SequenceTracker, index : Int32) -> TargetRef {
  TargetRef::entity(self.object_id, self.ids[index])
}

///|
fn SequenceTracker::fresh_id(self : SequenceTracker) -> String {
  let id = "item-\{self.next_id}"
  self.next_id += 1
  id
}

///|
fn SequenceTracker::highlight(
  self : SequenceTracker,
  indices : Array[Int32],
  role : HighlightRole,
) -> Array[Highlight] {
  indices.map(fn(i) { Highlight::new(target=self.target(i), role~) })
}

///|
fn SequenceTracker::record(
  self : SequenceTracker,
  event : TraceEvent,
  highlights : Array[Highlight],
  annotation : Annotation,
) -> Unit {
  match (self.builder, self.error) {
    (Some(builder), None) =>
      try {
        let scene = tracker_scene(
          self.object_id,
          self.label,
          self.ids,
          self.values,
          highlights,
        )
        builder.record(event~, scene~, annotation~)
      } catch {
        err => self.error = Some(err)
      }
    _ => ()
  }
}

///|
fn SequenceTracker::counts(self : SequenceTracker) -> OperationCounts {
  {
    compares: self.compares,
    swaps: self.swaps,
    reads: self.reads,
    writes: self.writes,
    snapshots: self.snapshots,
  }
}

///|
fn SequenceTracker::finish(
  self : SequenceTracker,
) -> AlgorithmTrace raise TraceError {
  if self.error is Some(err) {
    raise err
  }
  guard self.builder is Some(builder) else {
    raise InvalidStep(
      "no trace was recorded; create the tracer with TraceLevel::Full",
    )
  }
  self.record(
    Complete,
    self.highlight(Array::makei(self.ids.length(), fn(i) { i }), Result),
    Annotation::new(title="Done", body="The algorithm finished."),
  )
  if self.error is Some(err) {
    raise err
  }
  builder.finish(summary=[
    TraceAttribute::new(key="compares", value=self.compares.to_string()),
    TraceAttribute::new(key="swaps", value=self.swaps.to_string()),
    TraceAttribute::new(key="reads", value=self.reads.to_string()),
    TraceAttribute::new(key="writes", value=self.writes.to_string()),
  ])
}

///|
/// Records a sequence algorithm from snapshots without hand-written events.
///
/// Call `observe` with the current values after each change. FrontierLab
/// keeps element ids stable across moves and infers the semantic event:
/// `Swap`, `Update`, or a `Custom` move, insert, remove, or edit. Comparisons
/// leave no trace in the values, so report them with `compare` if wanted.
pub struct SequenceProbe[T] {
  priv tracker : SequenceTracker
  priv mut current : Array[T]
}

///|
pub fn[T : Show] SequenceProbe::new(
  values : Array[T],
  title~ : String = "Observed sequence",
  algorithm~ : String = "observed-sequence",
  object_id~ : String = "values",
  label~ : String = "Values",
  level~ : TraceLevel = Full,
  options~ : TraceOptions = TraceOptions::default(),
) -> SequenceProbe[T] {
  let tracker = SequenceTracker::new(
    title~,
    algorithm~,
    description="Events inferred from value snapshots.",
    object_id~,
    label~,
    values=values.map(fn(value) { value.to_string() }),
    level~,
    options~,
  )
  { tracker, current: values.copy(), }
}

///|
/// Reports the values after a change; unchanged snapshots record nothing.
pub fn[T : Eq + Show] SequenceProbe::observe(
  self : SequenceProbe[T],
  values : Array[T],
  note? : String,
) -> Unit {
  let tracker = self.tracker
  if tracker.level == Off {
    return
  }
  tracker.snapshots += 1
  let ids = align_sequence_ids(tracker.ids, self.current, values, fn() {
    tracker.fresh_id()
  })
  let change = classify_sequence_change(tracker.ids, self.current, ids, values)
  let old_values = tracker.values
  self.current = values.copy()
  tracker.ids = ids
  tracker.values = values.map(fn(value) { Show::to_string(value) })
  match change {
    NoChange => ()
    SwapChange(i, j) => {
      tracker.swaps += 1
      tracker.record(
        Swap(tracker.target(i), tracker.target(j)),
        tracker.highlight([i, j], Changed),
        Annotation::new(
          title="Swap",
          body=note.unwrap_or(
            "Positions \{i} and \{j} exchange \{tracker.values[j]} and \{tracker.values[i]}.",
          ),
        ),
      )
    }
    UpdateChange(i, old_index) => {
      tracker.writes += 1
      tracker.record(
        Update(tracker.target(i), tracker.values[i]),
        tracker.highlight([i], Changed),
        Annotation::new(
          title="Update",
          body=note.unwrap_or(
            "Position \{i} changes from \{old_values[old_index]} to \{tracker.values[i]}.",
          ),
        ),
      )
    }
    EditChange(kind~, touched~, moved~, updated~, inserted~, removed~) => {
      tracker.writes += moved + updated + inserted
      let attributes = []
      for
        entry in [
          ("moved", moved),
          ("updated", updated),
          ("inserted", inserted),
          ("removed", removed),
        ] {
        if entry.1 > 0 {
          attributes.push(
            TraceAttribute::new(key=entry.0, value=entry.1.to_string()),
          )
        }
      }
      let summary = attributes
        .map(fn(attribute) { "\{attribute.value} \{attribute.key}" })
        .join(", ")
      tracker.record(
        Custom(kind, attributes),
        tracker.highlight(touched, Changed),
        Annotation::new(
          title=edit_title(kind),
          body=note.unwrap_or("Elements changed: \{summary}."),
        ),
      )
    }
  }
}

///|
/// Records a comparison between two current positions.
pub fn[T] SequenceProbe::compare(
  self : SequenceProbe[T],
  i : Int32,
  j : Int32,
  note? : String,
) -> Unit {
  let tracker = self.tracker
  if tracker.level == Off {
    return
  }
  tracker.compares += 1
  tracker.record(
    Compare([tracker.target(i), tracker.target(j)]),
    tracker.highlight([i, j], Compared),
    Annotation::new(
      title="Compare",
      body=note.unwrap_or(
        "Compare position \{i} (\{tracker.values[i]}) with position \{j} (\{tracker.values[j]}).",
      ),
    ),
  )
}

///|
pub fn[T] SequenceProbe::counts(self : SequenceProbe[T]) -> OperationCounts {
  self.tracker.counts()
}

///|
/// Completes the trace. Raises the first recording error, or `InvalidStep`
/// when the probe was not created at `TraceLevel::Full`.
pub fn[T] SequenceProbe::finish(
  self : SequenceProbe[T],
) -> AlgorithmTrace raise TraceError {
  self.tracker.finish()
}

///|
/// Assigns stable ids to `next` by matching it against `prev`: unchanged
/// positions keep their id, moved values take the nearest unused equal value,
/// a changed value whose old element is unclaimed is an update, and anything
/// else is a new element.
fn[T : Eq] align_sequence_ids(
  prev_ids : Array[String],
  prev : Array[T],
  next : Array[T],
  fresh_id : () -> String,
) -> Array[String] {
  let used = Array::make(prev.length(), false)
  let result : Array[String?] = Array::make(next.length(), None)
  for p in 0..<next.length() {
    if p < prev.length() && prev[p] == next[p] {
      result[p] = Some(prev_ids[p])
      used[p] = true
    }
  }
  for p in 0..<next.length() {
    if result[p] is None {
      let mut best = -1
      for q in 0..<prev.length() {
        if !used[q] &&
          prev[q] == next[p] &&
          (best < 0 || (q - p).abs() < (best - p).abs()) {
          best = q
        }
      }
      if best >= 0 {
        result[p] = Some(prev_ids[best])
        used[best] = true
      }
    }
  }
  for p in 0..<next.length() {
    if result[p] is None {
      if p < prev.length() && !used[p] {
        result[p] = Some(prev_ids[p])
        used[p] = true
      } else {
        result[p] = Some(fresh_id())
      }
    }
  }
  result.map(fn(id) { id.unwrap() })
}

///|
fn edit_title(kind : String) -> String {
  match kind {
    "move" => "Move"
    "insert" => "Insert"
    "remove" => "Remove"
    _ => "Edit"
  }
}

///|
priv enum SequenceChange {
  NoChange
  SwapChange(Int32, Int32)
  UpdateChange(Int32, Int32)
  EditChange(
    kind~ : String,
    touched~ : Array[Int32],
    moved~ : Int32,
    updated~ : Int32,
    inserted~ : Int32,
    removed~ : Int32
  )
}

///|
/// Classifies the change between two aligned snapshots. Positions in the
/// result refer to `next`.
fn[T : Eq] classify_sequence_change(
  prev_ids : Array[String],
  prev : Array[T],
  next_ids : Array[String],
  next : Array[T],
) -> SequenceChange {
  let prev_index : Map[String, Int32] = Map([])
  for i, id in prev_ids {
    prev_index[id] = i
  }
  let next_count = next_ids.length()
  let touched = []
  let moved_positions = []
  let mut updated = 0
  let mut inserted = 0
  let mut moved = 0
  for p, id in next_ids {
    match prev_index.get(id) {
      None => {
        inserted += 1
        touched.push(p)
      }
      Some(q) => {
        let value_changed = prev[q] != next[p]
        if value_changed {
          updated += 1
        }
        if q != p {
          moved += 1
          moved_positions.push(p)
        }
        if value_changed || q != p {
          touched.push(p)
        }
      }
    }
  }
  let removed = prev_ids.length() - (next_count - inserted)
  if touched.is_empty() && removed == 0 {
    return NoChange
  }
  if inserted == 0 && removed == 0 && updated == 0 && moved == 2 {
    let i = moved_positions[0]
    let j = moved_positions[1]
    if prev_index.get(next_ids[i]) == Some(j) &&
      prev_index.get(next_ids[j]) == Some(i) {
      return SwapChange(i, j)
    }
  }
  if inserted == 0 && removed == 0 && moved == 0 && updated == 1 {
    let i = touched[0]
    return UpdateChange(i, prev_index.get(next_ids[i]).unwrap())
  }
  let kind = if updated == 0 && inserted == 0 && removed == 0 {
    "move"
  } else if updated == 0 && removed == 0 {
    "insert"
  } else if updated == 0 && inserted == 0 {
    "remove"
  } else {
    "edit"
  }
  EditChange(kind~, touched~, moved~, updated~, inserted~, removed~)
}
