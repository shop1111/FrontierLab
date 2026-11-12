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
  if !recorder.on {
    return
  }
  if recorder.marks.length() >= max_marks {
    recorder.dropped += 1
    return
  }
  recorder.marks.push({ place: line_of(loc), note, value: value.to_json(), })
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
/// The views that fit a marked value: a mark of the whole state gets every
/// view, a mark of a part only the node identity.
fn views_for(views : Array[View], value : Json) -> Array[View] {
  views.filter(fn(view) {
    match view {
      NodeId(_) => true
      Graph(path) | Buckets(path) | Matrix(path) =>
        lookup(value, path) is Some(_)
    }
  })
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
    // A marked part may not have the shape the views expect.
    let shot = snapshot(mark.value, views_for(views, mark.value)) catch {
      _ => snapshot(mark.value, [])
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
