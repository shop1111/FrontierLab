///|
/// One operation of the data structure under test.
///
/// `run` receives the current state and an integer argument and returns the
/// next state. Persistent structures return a new value; mutable structures
/// can update the value in place and return it. An error raised by `run` is
/// reported as a failure of that step.
pub struct Op[S] {
  name : String
  takes_arg : Bool
  run : (S, Int32) -> S raise
}

///|
/// An operation that takes an integer argument, such as `insert` or `delete`.
pub fn[S] Op::new(name : String, run : (S, Int32) -> S raise?) -> Op[S] {
  { name, takes_arg: true, run: (state, arg) => run(state, arg), }
}

///|
/// An operation without an argument, such as `pop` or `clear`.
pub fn[S] Op::without_arg(name : String, run : (S) -> S raise?) -> Op[S] {
  { name, takes_arg: false, run: (state, _) => run(state), }
}

///|
/// One applied operation, for example `insert 5` or `pop`.
#derive(Eq, Debug, ToJson)
pub struct Step {
  op : String
  arg : Int32?
}

///|
pub fn Step::new(op : String, arg? : Int32) -> Step {
  { op, arg, }
}

///|
pub impl Show for Step with fn output(self, logger) {
  match self.arg {
    Some(arg) => logger.write_string("\{self.op} \{arg}")
    None => logger.write_string(self.op)
  }
}

///|
/// Parses a script such as `"insert 5, insert 3; delete 5"`. Steps are
/// separated by commas, semicolons, or newlines; each step is an operation
/// name optionally followed by one integer.
pub fn Step::parse(
  script : String,
) -> Array[Step] raise @frontierlab.TraceError {
  let steps : Array[Step] = []
  let normalized = script
    .replace_all(old=";", new=",")
    .replace_all(old="\n", new=",")
  for part in normalized.split(",") {
    let words = part
      .split(" ")
      .filter(fn(word) { word.length() > 0 })
      .map(fn(word) { word.to_owned() })
      .collect()
    match words {
      [] => ()
      [op] => steps.push({ op, arg: None, })
      [op, number] => {
        let arg = @strconv.parse_int(number) catch {
          _ =>
            raise @frontierlab.InvalidStep(
              "Step '\{part}' has a non-integer argument '\{number}'.",
            )
        }
        steps.push({ op, arg: Some(arg), })
      }
      _ =>
        raise @frontierlab.InvalidStep(
          "Step '\{part}' must be an operation name and at most one integer.",
        )
    }
  }
  steps
}

///|
/// The first step after which the state was rejected.
#derive(Eq, Debug, ToJson)
pub struct Failure {
  /// Zero-based position of the failing step.
  index : Int32
  step : Step
  message : String
}

///|
/// The result of applying a sequence of steps: the step-by-step trace, and the
/// first failure if a check rejected the state.
pub struct Replay {
  steps : Array[Step]
  failure : Failure?
  trace : @frontierlab.AlgorithmTrace
}

///|
pub fn Replay::passed(self : Replay) -> Bool {
  self.failure is None
}

///|
/// A short plain-text summary that names the failing step.
pub fn Replay::report(self : Replay) -> String {
  let script = self.steps.map(fn(step) { step.to_string() }).join(", ")
  match self.failure {
    None => "All \{self.steps.length()} steps passed: \{script}"
    Some(failure) =>
      "Step \{failure.index + 1} of \{self.steps.length()} (\{failure.step}) failed: \{failure.message}\nSteps: \{script}"
  }
}

///|
/// A standalone offline HTML player for the replay.
pub fn Replay::to_html(self : Replay) -> String {
  @frontierlab.render_trace_html(self.trace)
}

///|
/// Writes the offline HTML player to `path`.
pub fn Replay::save_html(self : Replay, path : String) -> Unit raise {
  @fs.write_string_to_file(path, self.to_html())
}

///|
/// A failing step sequence found by `explore`, already shrunk and replayed.
pub struct Exploration {
  /// The smallest failing sequence, with its trace.
  replay : Replay
  /// The random sequence that failed first, before shrinking.
  original : Array[Step]
  cases_tried : Int32
  shrink_steps : Int32
  seed : UInt64
}

///|
pub fn Exploration::report(self : Exploration) -> String {
  let original = self.original.map(fn(step) { step.to_string() }).join(", ")
  "Found after \{self.cases_tried} random sequences (seed \{self.seed}); shrunk from \{self.original.length()} to \{self.replay.steps.length()} steps in \{self.shrink_steps} rounds.\n" +
  self.replay.report() +
  "\nOriginal: \{original}"
}

///|
pub fn Exploration::save_html(self : Exploration, path : String) -> Unit raise {
  self.replay.save_html(path)
}

///|
/// Operations by name, after checking that there is at least one operation and
/// that no name is used twice.
fn[S] op_table(
  ops : Array[Op[S]],
) -> Map[String, Op[S]] raise @frontierlab.TraceError {
  if ops.is_empty() {
    raise @frontierlab.InvalidStep("At least one operation is required.")
  }
  let table : Map[String, Op[S]] = Map([])
  for op in ops {
    if table.contains(op.name) {
      raise @frontierlab.DuplicateId("Operation '\{op.name}' is defined twice.")
    }
    table[op.name] = op
  }
  table
}

///|
fn[S] check_steps(
  table : Map[String, Op[S]],
  steps : Array[Step],
) -> Unit raise @frontierlab.TraceError {
  for step in steps {
    match table.get(step.op) {
      None => {
        let known = table.keys().collect().join(", ")
        raise @frontierlab.InvalidStep(
          "Unknown operation '\{step.op}'; expected one of: \{known}.",
        )
      }
      Some(op) =>
        if op.takes_arg && step.arg is None {
          raise @frontierlab.InvalidStep(
            "Operation '\{step.op}' needs an integer argument.",
          )
        }
    }
  }
}

///|
priv enum Outcome[S] {
  /// The step ran and every check accepted the new state.
  Applied(S)
  /// The step ran, but a check rejected the new state.
  Rejected(S, String)
  /// The operation raised an error, so there is no new state.
  Raised(String)
}

///|
fn[S] apply_step(
  table : Map[String, Op[S]],
  state : S,
  step : Step,
  invariant : ((S) -> String?)?,
  check : ((S, Step) -> String?)?,
) -> Outcome[S] {
  let next = (table[step.op].run)(state, step.arg.unwrap_or(0)) catch {
    error => return Raised("raised \{error}")
  }
  if invariant is Some(invariant) && invariant(next) is Some(message) {
    return Rejected(next, message)
  }
  if check is Some(check) && check(next, step) is Some(message) {
    return Rejected(next, message)
  }
  Applied(next)
}

///|
/// Runs the steps without recording anything and returns the first failure.
fn[S] first_failure(
  init : () -> S,
  table : Map[String, Op[S]],
  steps : Array[Step],
  invariant : ((S) -> String?)?,
  check : ((S, Step) -> String?)?,
) -> Failure? {
  let mut state = init()
  for index, step in steps {
    match apply_step(table, state, step, invariant, check) {
      Applied(next) => state = next
      Rejected(_, message) | Raised(message) =>
        return Some({ index, step, message, })
    }
  }
  None
}

///|
/// Applies `steps` to a fresh state from `init`, takes a snapshot of the whole
/// structure after every step, and checks it.
///
/// - `invariant` returns `Some(reason)` when a state is invalid, for example
///   when a binary search tree is no longer ordered.
/// - `check` sees the state together with the step that produced it, for
///   example to require that `delete k` really removed `k`.
///
/// Replay stops at the first failing step. Every step of the returned trace
/// shows the structure, highlights the nodes that were added or moved, and
/// names removed nodes, so the player shows where the structure went wrong.
pub fn[S : ToJson] replay(
  init : () -> S,
  ops : Array[Op[S]],
  steps : Array[Step],
  invariant? : (S) -> String?,
  check? : (S, Step) -> String?,
  window? : Int32,
  title~ : String = "Data structure replay",
  options~ : @frontierlab.TraceOptions = @frontierlab.TraceOptions::default(),
) -> Replay raise @frontierlab.TraceError {
  let table = op_table(ops)
  check_steps(table, steps)
  // With a window, a first pass without snapshots finds where the run stops,
  // and only the last `window` steps before that point are drawn.
  let start = match window {
    None => 0
    Some(size) => {
      if size < 1 {
        raise @frontierlab.LimitExceeded("window must be at least 1.")
      }
      let stop = match first_failure(init, table, steps, invariant, check) {
        Some(failure) => failure.index + 1
        None => steps.length()
      }
      if stop > size {
        stop - size
      } else {
        0
      }
    }
  }
  let mut state = init()
  for step in steps[0:start] {
    // These steps passed in the first pass, so they apply cleanly.
    if apply_step(table, state, step, None, None) is Applied(next) {
      state = next
    }
  }
  let mut before = snapshot(state.to_json())
  let description = if start == 0 {
    "Snapshots of the structure after each operation."
  } else {
    "The first \{start} operations ran without snapshots; the initial scene is the state after them."
  }
  let builder = @frontierlab.TraceBuilder::new(
    title~,
    algorithm="explore",
    description~,
    initial_scene=scene(before, [], Changed),
    options~,
  )
  let mut failure : Failure? = None
  for offset, step in steps[start:] {
    let index = start + offset
    let (after, problem) = match
      apply_step(table, state, step, invariant, check) {
      Applied(next) => {
        state = next
        (snapshot(state.to_json()), None)
      }
      Rejected(next, message) => {
        state = next
        (snapshot(state.to_json()), Some(message))
      }
      // A step that raised leaves no new state; show the last good one.
      Raised(message) => (before, Some(message))
    }
    let changed = changed_entities(before, after)
    let removed = removed_labels(before, after)
    let removed_text = if removed.is_empty() {
      ""
    } else {
      " Removed: \{removed.join(", ")}."
    }
    let (role, highlighted, body) : (
      @frontierlab.HighlightRole,
      Array[Entity],
      String,
    ) = match problem {
      None => {
        let summary = if changed.is_empty() {
          "No node was added or moved."
        } else {
          "Added or moved: \{changed.map(fn(entity) { entity.label }).join(", ")}."
        }
        (Changed, changed, summary + removed_text)
      }
      Some(message) => {
        failure = Some({ index, step, message, })
        let marked = if changed.is_empty() { after.entities } else { changed }
        (Error, marked, "Check failed: \{message}.\{removed_text}")
      }
    }
    let attributes = match step.arg {
      Some(arg) => [@frontierlab.TraceAttribute::new(key="arg", value="\{arg}")]
      None => []
    }
    builder.record(
      event=@frontierlab.Custom(step.op, attributes),
      scene=scene(after, highlighted, role),
      annotation=@frontierlab.Annotation::new(
        title="Step \{index + 1}: \{step}",
        body~,
      ),
    )
    before = after
    if failure is Some(_) {
      break
    }
  }
  if failure is None {
    builder.record(
      event=Complete,
      scene=scene(before, [], Changed),
      annotation=@frontierlab.Annotation::new(
        title="Done",
        body="All \{steps.length()} steps passed every check.",
      ),
    )
  }
  let summary = [
    @frontierlab.TraceAttribute::new(key="steps", value="\{steps.length()}"),
    @frontierlab.TraceAttribute::new(
      key="result",
      value=if failure is None { "passed" } else { "failed" },
    ),
  ]
  { steps, failure, trace: builder.finish(summary~), }
}

///|
/// A small deterministic generator, so a seed reproduces the same search on
/// every target.
priv struct Rng {
  mut state : UInt64
}

///|
fn Rng::next(self : Rng, bound : Int32) -> Int32 {
  self.state = self.state + 0x9E3779B97F4A7C15UL
  let mut z = self.state
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
  z = z ^ (z >> 31)
  (z % bound.to_uint64()).to_int()
}

///|
/// Shrinks a failing sequence: first removes runs of steps, then moves each
/// argument toward zero. Every candidate must still fail.
fn shrink(
  steps : Array[Step],
  fails : (Array[Step]) -> Bool,
  max_rounds : Int32,
) -> (Array[Step], Int32) {
  let mut best = steps
  let mut rounds = 0
  let mut progress = true
  while progress && rounds < max_rounds {
    progress = false
    let mut size = best.length() / 2
    while size >= 1 && !progress {
      let mut start = 0
      while start + size <= best.length() {
        let candidate = best[0:start].to_owned() +
          best[start + size:].to_owned()
        if fails(candidate) {
          best = candidate
          progress = true
          break
        }
        start += 1
      }
      size /= 2
    }
    if !progress {
      for i, step in best {
        if step.arg is Some(arg) && arg != 0 {
          let options = [0, arg / 2, if arg > 0 { arg - 1 } else { arg + 1 }]
          for smaller in options {
            let candidate = best.copy()
            candidate[i] = { op: step.op, arg: Some(smaller), }
            if fails(candidate) {
              best = candidate
              progress = true
              break
            }
          }
          if progress {
            break
          }
        }
      }
    }
    if progress {
      rounds += 1
    }
  }
  (best, rounds)
}

///|
/// Searches random operation sequences for one that breaks `invariant` or
/// `check`, shrinks it to a small failing sequence, and replays only that
/// sequence with full snapshots.
///
/// The search itself takes no snapshots: each candidate only runs the
/// operations and the checks. Use `replay` to run a sequence you wrote by
/// hand.
///
/// `init` must return a fresh state on every call, because each candidate
/// starts from scratch. Arguments are drawn from `0..<max_arg`. Returns `None`
/// when no failure is found in `cases` sequences or when no check is given.
pub fn[S : ToJson] explore(
  init : () -> S,
  ops : Array[Op[S]],
  invariant? : (S) -> String?,
  check? : (S, Step) -> String?,
  cases~ : Int32 = 300,
  max_steps~ : Int32 = 12,
  max_arg~ : Int32 = 10,
  max_shrinks~ : Int32 = 200,
  seed~ : UInt64 = 1,
  title~ : String = "Smallest failing sequence",
  options~ : @frontierlab.TraceOptions = @frontierlab.TraceOptions::default(),
) -> Exploration? raise @frontierlab.TraceError {
  let table = op_table(ops)
  if cases < 1 || max_steps < 1 || max_arg < 1 || max_shrinks < 0 {
    raise @frontierlab.LimitExceeded(
      "cases, max_steps and max_arg must be positive and max_shrinks non-negative.",
    )
  }
  if invariant is None && check is None {
    return None
  }
  let rng : Rng = { state: seed, }
  let fails = fn(steps) {
    first_failure(init, table, steps, invariant, check) is Some(_)
  }
  for case in 0..<cases {
    let length = 1 + rng.next(max_steps)
    let steps = Array::makei(length, fn(_) {
      let op = ops[rng.next(ops.length())]
      let arg = if op.takes_arg { Some(rng.next(max_arg)) } else { None }
      { op: op.name, arg, }
    })
    if fails(steps) {
      // Steps after the first failure never run, so drop them before shrinking.
      let failure = first_failure(init, table, steps, invariant, check).unwrap()
      let prefix = steps[0:failure.index + 1].to_owned()
      let (smallest, rounds) = shrink(prefix, fails, max_shrinks)
      let replayed = replay(
        init,
        ops,
        smallest,
        invariant?,
        check?,
        title~,
        options~,
      )
      return Some({
        replay: replayed,
        original: steps,
        cases_tried: case + 1,
        shrink_steps: rounds,
        seed,
      })
    }
  }
  None
}

///|
pub extend Step with Debug::{to_repr}

///|
pub extend Step with Eq::{not_equal, equal}

///|
pub extend Step with ToJson::{to_json}

///|
pub extend Step with Show::{to_string, output}

///|
pub extend Failure with Debug::{to_repr}

///|
pub extend Failure with Eq::{not_equal, equal}

///|
pub extend Failure with ToJson::{to_json}
