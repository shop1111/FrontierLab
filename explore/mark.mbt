///|
/// A value recorded by `mark` while a step ran.
priv struct Mark {
  /// `file.mbt:line` of the `mark` call.
  place : String
  note : String
  /// The marked value; for `auto_mark_vars`, an object from each recorded
  /// variable's name to its value.
  value : Json
  /// Whether `value` holds named variables, each drawn on its own.
  named : Bool
}

///|
priv struct Recorder {
  mut on : Bool
  marks : Array[Mark]
  mut dropped : Int32
}

///|
let recorder : Recorder = { on: false, marks: [], dropped: 0, }

///|
/// At most this many marks are kept for one step, so that a mark inside a
/// long loop cannot flood the replay.
let max_marks : Int32 = 200

///|
/// Records `value` at this line of an operation, so that `replay` also shows
/// the states inside the operation, not only after it.
///
/// Put calls where the intermediate state matters, for example after each
/// rotation of a rebalancing insert. Marks are recorded only while `replay`
/// runs an operation under test, so they cost one check elsewhere, including
/// during the `explore` search. The source line is filled in automatically.
#callsite(autofill(loc))
pub fn[T : ToJson] mark(
  value : T,
  note~ : String = "",
  loc~ : SourceLoc,
) -> Unit {
  if recorder.on {
    keep(line_of(loc), note, false, () => value.to_json())
  }
}

///|
/// Keeps a mark unless the step already has `max_marks`; the value is only
/// converted when it is kept.
fn keep(
  place : String,
  note : String,
  named : Bool,
  value : () -> Json,
) -> Unit {
  if recorder.marks.length() >= max_marks {
    recorder.dropped += 1
  } else {
    recorder.marks.push({ place, note, value: value(), named, })
  }
}

///|
/// The mark that `frontierlab-instrument` inserts before a statement: records
/// `value` before line `line`, whose source text is `code`, runs.
///
/// The line is passed explicitly so that it stays right when the
/// instrumented file is reformatted. Write `mark` by hand; this form is
/// generated, and the tool removes every call to it with `--remove`.
#callsite(autofill(loc))
pub fn[T : ToJson] auto_mark(
  value : T,
  line : Int32,
  code : String,
  loc~ : SourceLoc,
) -> Unit {
  if recorder.on {
    keep(line_at(loc, line), "before: " + code, false, () => value.to_json())
  }
}

///|
/// The mark that `frontierlab-instrument` inserts when it records several
/// variables: records each `(name, value)` that `values` returns before line
/// `line`, whose source text is `code`, runs.
///
/// `values` lists only the variables in scope at that line, and runs only
/// while `replay` records, so converting them costs nothing elsewhere. Each
/// variable is drawn on its own, labeled with its name, and a variable that
/// is the part a view draws is drawn by that view. Write `mark` by hand; this
/// form is generated, and the tool removes every call to it with `--remove`.
#callsite(autofill(loc))
pub fn auto_mark_vars(
  values : () -> Array[(String, Json)],
  line : Int32,
  code : String,
  loc~ : SourceLoc,
) -> Unit {
  if recorder.on {
    keep(line_at(loc, line), "before: " + code, true, () => {
      Json::object(Map::from_array(values()))
    })
  }
}

///|
/// One variable for `auto_mark_vars`: its name and its value as JSON. The
/// tool generates these calls inside the function that `auto_mark_vars`
/// runs only while recording.
pub fn[T : ToJson] watched(name : String, value : T) -> (String, Json) {
  (name, value.to_json())
}

///|
/// `file.mbt:line`, with the file of `loc` and the line given.
fn line_at(loc : SourceLoc, line : Int32) -> String {
  let file = loc.to_string().split(":").next().unwrap().to_owned()
  "\{file}:\{line}"
}

///|
/// `file.mbt:12` from a source location such as `file.mbt:12:3-12:9@pkg`.
fn line_of(loc : SourceLoc) -> String {
  loc
  .to_string()
  .split(":")
  .take(2)
  .map(fn(part) { part.to_owned() })
  .collect()
  .join(":")
}

///|
/// Takes the marks recorded since the last call, and how many were dropped.
fn take_marks() -> (Array[Mark], Int32) {
  let marks = recorder.marks.copy()
  let dropped = recorder.dropped
  recorder.marks.clear()
  recorder.dropped = 0
  (marks, dropped)
}

///|
/// Draws a marked value with the views that fit it. A mark of the whole state
/// gets every view. A mark of the part one view draws, such as the bucket
/// array a resize is building, is drawn by that view. Anything else gets the
/// default drawing, with node identity.
fn mark_snapshot(
  value : Json,
  views : Array[View],
) -> Snapshot raise @frontierlab.TraceError {
  let ids = views.filter(fn(view) { view is NodeId(_) })
  let parts = views.filter(fn(view) { !(view is NodeId(_)) })
  let found = parts.filter(fn(view) {
    match view {
      Graph(path) | Buckets(path) | Matrix(path) | NodeId(path) =>
        lookup(value, path) is Some(_)
    }
  })
  if found.is_empty() {
    for view in parts {
      let whole = match view {
        Graph(_) => Graph("")
        Buckets(_) => Buckets("")
        _ => Matrix("")
      }
      // A value of another shape makes the view raise; try the next one.
      try snapshot(value, ids + [whole]) catch {
        _ => continue
      } noraise {
        shot => return shot
      }
    }
  }
  snapshot(value, ids + found) catch {
    _ => snapshot(value, ids)
  }
}

///|
/// Draws each variable of a named mark the way `mark_snapshot` draws a
/// marked value, and labels its parts with the variable's name, so that the
/// variables sit side by side in one scene.
fn named_snapshot(
  value : Json,
  views : Array[View],
) -> Snapshot raise @frontierlab.TraceError {
  guard value is Object(vars) else { return mark_snapshot(value, views) }
  let objects : Array[@frontierlab.SceneObject] = []
  let entities : Array[Entity] = []
  for name, part in vars {
    let shot = mark_snapshot(part, views)
    for object in shot.objects {
      objects.push(renamed(object, name))
    }
    for entity in shot.entities {
      let object_id = var_object_id(name, entity.object_id)
      entities.push({ ..entity, object_id, key: object_id + "::" + entity.id, })
    }
  }
  { objects, entities, }
}

///|
/// The id of a part of variable `name`, so that the parts of different
/// variables stay apart.
fn var_object_id(name : String, id : String) -> String {
  "var:\{name}/\{id}"
}

///|
/// Whether `id` is the default drawing of a state or of one variable, which
/// is always a forest.
fn is_default_drawing(id : String) -> Bool {
  id == "state" || (id.has_prefix("var:") && id.has_suffix("/state"))
}

///|
/// A part's label with the variable's name: `wider` for the whole value,
/// `self.buckets` for a field drawn by a view.
fn var_label(name : String, id : String, label : String) -> String {
  if label == "State" || id == "fields" {
    name
  } else if label.has_prefix("State: ") {
    name + label[5:].to_owned()
  } else {
    name + "." + label
  }
}

///|
fn renamed(
  object : @frontierlab.SceneObject,
  name : String,
) -> @frontierlab.SceneObject raise @frontierlab.TraceError {
  match object {
    Sequence(s) =>
      Sequence(
        @frontierlab.SequenceState::new(
          id=var_object_id(name, s.id),
          label=var_label(name, s.id, s.label),
          items=s.items,
        ),
      )
    Sets(s) =>
      Sets(
        @frontierlab.SetState::new(
          id=var_object_id(name, s.id),
          label=var_label(name, s.id, s.label),
          groups=s.groups,
        ),
      )
    Graph(s) =>
      Graph(
        @frontierlab.GraphState::new(
          id=var_object_id(name, s.id),
          label=var_label(name, s.id, s.label),
          nodes=s.nodes,
          edges=s.edges,
        ),
      )
    Grid(s) =>
      Grid(
        @frontierlab.GridState::new(
          id=var_object_id(name, s.id),
          label=var_label(name, s.id, s.label),
          width=s.width,
          height=s.height,
          cells=s.cells,
        ),
      )
  }
}

///|
/// Adds a trace step for every mark of one step, and the same in text: the
/// first mark as an outline, later marks as changes from the one before.
fn record_marks(
  builder : @frontierlab.TraceBuilder,
  log : Array[String],
  title : String,
  marks : Array[Mark],
  dropped : Int32,
  views : Array[View],
) -> Unit raise @frontierlab.TraceError {
  let mut previous : Snapshot? = None
  let mut was_named = false
  for mark in marks {
    // A hand-written mark after inserted ones of several variables, or the
    // other way round, draws other parts: start again from an outline.
    if mark.named != was_named {
      previous = None
    }
    was_named = mark.named
    let shot = if mark.named {
      named_snapshot(mark.value, views)
    } else {
      mark_snapshot(mark.value, views)
    }
    let note = if mark.note == "" { "" } else { " (" + mark.note + ")" }
    log.push("  at " + mark.place + note + ":")
    let (lines, highlighted) = match previous {
      None => (outline(shot.objects), [])
      Some(earlier) => {
        let d = diff(earlier, shot)
        let lines = change_lines(earlier, shot, d)
        (
          if lines.is_empty() {
            ["(no change)"]
          } else {
            lines
          },
          d.changed.map(fn(pair) { pair.1 }),
        )
      }
    }
    for line in lines {
      log.push("    " + line)
    }
    let attributes = [
      @frontierlab.TraceAttribute::new(key="line", value=mark.place),
    ]
    if mark.note != "" {
      attributes.push(
        @frontierlab.TraceAttribute::new(key="note", value=mark.note),
      )
    }
    builder.record(
      event=@frontierlab.Custom("mark", attributes),
      scene=scene(shot, highlighted, Current),
      annotation=@frontierlab.Annotation::new(
        title=title + " at " + mark.place,
        body=if mark.note == "" {
          "Inside the operation."
        } else {
          "Inside the operation: " + mark.note + "."
        },
      ),
    )
    previous = Some(shot)
  }
  if dropped > 0 {
    log.push("  (\{dropped} more marks were not recorded)")
  }
}
