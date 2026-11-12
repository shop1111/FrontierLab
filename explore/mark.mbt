///|
/// A value recorded by `mark` while a step ran.
priv struct Mark {
  /// `file.mbt:line` of the `mark` call.
  place : String
  note : String
  value : Json
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
    keep(line_of(loc), note, () => value.to_json())
  }
}

///|
/// Keeps a mark unless the step already has `max_marks`; the value is only
/// converted when it is kept.
fn keep(place : String, note : String, value : () -> Json) -> Unit {
  if recorder.marks.length() >= max_marks {
    recorder.dropped += 1
  } else {
    recorder.marks.push({ place, note, value: value(), })
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
    let file = loc.to_string().split(":").next().unwrap().to_owned()
    keep("\{file}:\{line}", "before: " + code, () => value.to_json())
  }
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
  for mark in marks {
    let shot = mark_snapshot(mark.value, views)
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
