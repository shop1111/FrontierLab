///|
/// One operation of the data structure under test.
///
/// An operation receives the current state and, if it takes one, an argument,
/// and returns the next state. Persistent structures return a new value;
/// mutable structures can update the value in place and return it. An
/// operation that also returns a result, such as `pop` returning the removed
/// key, reports it so that it can be shown in the replay and compared with a
/// `Model`. An error raised by an operation fails that step, unless a model
/// raises on the same step too.
pub struct Op[S] {
  name : String
  takes_arg : Bool
  /// Whether the operation reports a result.
  returns : Bool
  /// Draws an argument; `None` for integer arguments, which are drawn from
  /// `0..<max_arg`.
  priv gen : ((Int32, @splitmix.RandomState) -> Json)?
  /// `None` when the operation accepts the argument, otherwise why not.
  priv accepts : (Json) -> String?
  priv run : (S, Json?) -> (S, String?) raise
}

///|
/// Steps are validated before they run, so the argument is present.
fn[A : @json.FromJson] decode(arg : Json?) -> A raise {
  @json.from_json(arg.unwrap_or(Json::null()))
}

///|
/// What operations without an argument say about any argument.
fn takes_none(_ : Json) -> String? {
  Some("the operation takes no argument")
}

///|
/// `None` for a whole number. Decoding an `Int` from JSON would silently
/// truncate `1.5`.
fn int_problem(json : Json) -> String? {
  match json {
    Number(n, ..) if n.to_int().to_double() == n => None
    _ => Some("expected an integer, got \{json.stringify()}")
  }
}

///|
/// An operation that takes an integer argument, such as `insert` or `delete`.
/// Random arguments are drawn from `0..<max_arg`, so that keys repeat.
pub fn[S] Op::new(name : String, run : (S, Int32) -> S raise?) -> Op[S] {
  {
    name,
    takes_arg: true,
    returns: false,
    gen: None,
    accepts: int_problem,
    run: (state, arg) => (run(state, decode(arg)), None),
  }
}

///|
/// An operation without an argument, such as `pop` or `clear`.
pub fn[S] Op::without_arg(name : String, run : (S) -> S raise?) -> Op[S] {
  {
    name,
    takes_arg: false,
    returns: false,
    gen: None,
    accepts: takes_none,
    run: (state, _) => (run(state), None),
  }
}

///|
/// An operation whose argument is drawn from `gen`, for arguments that are not
/// a single small integer: strings, pairs, records, or integers from another
/// range. For example `@quickcheck.elements(["a", "b", "ab"])`, or
/// `@quickcheck.spawn()` for any type with an `Arbitrary` instance.
///
/// The argument type needs `ToJson` and `FromJson`, so that steps can be
/// shown, written in scripts, and shrunk. Generators receive `max_arg` as
/// their size.
pub fn[S, A : ToJson + @json.FromJson] Op::with_gen(
  name : String,
  gen : @quickcheck.Generator[A],
  run : (S, A) -> S raise?,
) -> Op[S] {
  {
    name,
    takes_arg: true,
    returns: false,
    gen: Some((size, rs) => ToJson::to_json(gen.run(size, rs))),
    accepts: json => {
      let _ : A = @json.from_json(json) catch {
        error => return Some("\{error}")
      }
      None
    },
    run: (state, arg) => (run(state, decode(arg)), None),
  }
}

///|
/// Like `Op::new`, for an operation that also returns a result, such as
/// `find k` returning whether `k` is present. Return the state unchanged for
/// a query.
pub fn[S, R : @debug.Debug] Op::returning(
  name : String,
  run : (S, Int32) -> (S, R) raise?,
) -> Op[S] {
  {
    name,
    takes_arg: true,
    returns: true,
    gen: None,
    accepts: int_problem,
    run: (state, arg) => {
      let (next, result) = run(state, decode(arg))
      (next, Some(@debug.to_string(result)))
    },
  }
}

///|
/// Like `Op::without_arg`, for an operation that also returns a result, such
/// as `pop` returning the removed key or `size` returning the count.
pub fn[S, R : @debug.Debug] Op::returning_without_arg(
  name : String,
  run : (S) -> (S, R) raise?,
) -> Op[S] {
  {
    name,
    takes_arg: false,
    returns: true,
    gen: None,
    accepts: takes_none,
    run: (state, _) => {
      let (next, result) = run(state)
      (next, Some(@debug.to_string(result)))
    },
  }
}

///|
/// Like `Op::with_gen`, for an operation that also returns a result.
pub fn[S, A : ToJson + @json.FromJson, R : @debug.Debug] Op::returning_with_gen(
  name : String,
  gen : @quickcheck.Generator[A],
  run : (S, A) -> (S, R) raise?,
) -> Op[S] {
  {
    name,
    takes_arg: true,
    returns: true,
    gen: Some((size, rs) => ToJson::to_json(gen.run(size, rs))),
    accepts: json => {
      let _ : A = @json.from_json(json) catch {
        error => return Some("\{error}")
      }
      None
    },
    run: (state, arg) => {
      let (next, result) = run(state, decode(arg))
      (next, Some(@debug.to_string(result)))
    },
  }
}

///|
/// A reference implementation to compare against, usually a simple and
/// obviously correct structure: a sorted array for a balanced tree or a heap,
/// a `Map` for a hash table.
///
/// Its operations have the same names as the operations under test. After
/// every step, the results of operations that return one must be equal (as
/// text), and an operation must raise exactly when the model raises. Add a
/// query such as `Op::returning_without_arg("keys", ...)` to both sides to
/// compare the whole contents.
pub struct Model {
  priv ops : Map[String, (Bool, Bool, (Json) -> String?)]
  priv start : () -> (Step) -> Result[String?, String]
}

///|
pub fn[M] Model::new(
  init : () -> M,
  ops : Array[Op[M]],
) -> Model raise @frontierlab.TraceError {
  let table = op_table(ops)
  let shapes : Map[String, (Bool, Bool, (Json) -> String?)] = Map([])
  for name, op in table {
    shapes[name] = (op.takes_arg, op.returns, op.accepts)
  }
  {
    ops: shapes,
    start: () => {
      let mut state = init()
      step => {
        let (next, result) = (table[step.op].run)(state, step.arg) catch {
          error => return Err("raised \{error}")
        }
        state = next
        Ok(result)
      }
    },
  }
}

///|
/// One applied operation, for example `insert 5`, `put ["a", 1]`, or `pop`.
/// The argument is kept as JSON so that one step type fits every argument
/// type.
#derive(Eq, Debug, ToJson)
pub struct Step {
  op : String
  arg : Json?
}

///|
/// A step with an optional integer argument.
pub fn Step::new(op : String, arg? : Int32) -> Step {
  { op, arg: arg.map(fn(n) { Json::number(n.to_double()) }), }
}

///|
/// A step with an argument of any `ToJson` type, for operations made with
/// `Op::with_gen`.
pub fn[A : ToJson] Step::with_arg(op : String, arg : A) -> Step {
  { op, arg: Some(ToJson::to_json(arg)), }
}

///|
/// The argument as an integer, for checks on operations made with `Op::new`.
pub fn Step::int_arg(self : Step) -> Int32? {
  match self.arg {
    Some(Number(n, ..)) if n.to_int().to_double() == n => Some(n.to_int())
    _ => None
  }
}

///|
pub impl Show for Step with fn output(self, logger) {
  match self.arg {
    Some(arg) => logger.write_string("\{self.op} \{arg.stringify()}")
    None => logger.write_string(self.op)
  }
}

///|
/// Splits a script at commas, semicolons, and newlines that are outside
/// brackets, braces, and strings.
fn split_script(script : String) -> Array[String] {
  let parts : Array[String] = []
  let current = StringBuilder()
  let mut depth = 0
  let mut in_string = false
  let mut escaped = false
  for c in script {
    if in_string {
      current.write_char(c)
      if escaped {
        escaped = false
      } else if c == '\\' {
        escaped = true
      } else if c == '"' {
        in_string = false
      }
      continue
    }
    match c {
      '"' => {
        in_string = true
        current.write_char(c)
      }
      '[' | '{' => {
        depth += 1
        current.write_char(c)
      }
      ']' | '}' => {
        depth -= 1
        current.write_char(c)
      }
      ',' | ';' | '\n' if depth <= 0 => {
        parts.push(current.to_string())
        current.reset()
      }
      _ => current.write_char(c)
    }
  }
  parts.push(current.to_string())
  parts
}

///|
/// Parses a script such as `"insert 5, insert 3; delete 5"`. Steps are
/// separated by commas, semicolons, or newlines; each step is an operation
/// name optionally followed by an argument written as JSON: `insert 5`,
/// `add "abc"`, `put ["a", 1]`.
pub fn Step::parse(
  script : String,
) -> Array[Step] raise @frontierlab.TraceError {
  let steps : Array[Step] = []
  for part in split_script(script) {
    let text = part.trim(chars=" \t\r").to_owned()
    if text.is_empty() {
      continue
    }
    let (op, rest) = match text.find(" ") {
      Some(i) =>
        (
          text.clamped_view(start=0, end=i).to_owned(),
          text
          .clamped_view(start=i, end=text.length())
          .trim(chars=" \t")
          .to_owned(),
        )
      None => (text, "")
    }
    if rest.is_empty() {
      steps.push({ op, arg: None, })
      continue
    }
    let arg = @json.parse(rest) catch {
      _ =>
        raise @frontierlab.InvalidStep(
          "Step '\{text}' has an argument that is not JSON: '\{rest}'. Write strings in double quotes.",
        )
    }
    steps.push({ op, arg: Some(arg), })
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
  /// What each step that ran returned, for operations that return a result;
  /// `raised ...` when the operation raised. Steps after a failure did not
  /// run and have no entry.
  outputs : Array[String?]
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
/// Every operation under test needs a model operation of the same name that
/// takes an argument and returns a result exactly when it does.
fn[S] check_model(
  table : Map[String, Op[S]],
  model : Model?,
) -> Unit raise @frontierlab.TraceError {
  guard model is Some(model) else { return }
  for name, op in table {
    match model.ops.get(name) {
      None =>
        raise @frontierlab.InvalidStep("The model has no operation '\{name}'.")
      Some((takes_arg, returns, _)) => {
        if takes_arg != op.takes_arg {
          raise @frontierlab.InvalidStep(
            "Operation '\{name}' and its model disagree on taking an argument.",
          )
        }
        if returns != op.returns {
          raise @frontierlab.InvalidStep(
            "Operation '\{name}' and its model disagree on returning a result.",
          )
        }
      }
    }
  }
}

///|
/// Why `step` cannot run: an unknown operation, a missing or extra argument,
/// or an argument that the operation or its model cannot read.
fn[S] step_problem(
  table : Map[String, Op[S]],
  model : Model?,
  step : Step,
) -> String? {
  guard table.get(step.op) is Some(op) else {
    let known = table.keys().collect().join(", ")
    return Some("Unknown operation '\{step.op}'; expected one of: \{known}.")
  }
  match (op.takes_arg, step.arg) {
    (true, None) => Some("Operation '\{step.op}' needs an argument.")
    (false, None) => None
    (_, Some(arg)) => {
      if (op.accepts)(arg) is Some(reason) {
        return Some(
          "Step '\{step}' has an argument that does not fit: \{reason}",
        )
      }
      if model is Some(model) &&
        model.ops.get(step.op) is Some((_, _, model_accepts)) &&
        model_accepts(arg) is Some(reason) {
        return Some(
          "Step '\{step}' has an argument that the model cannot read: \{reason}",
        )
      }
      None
    }
  }
}

///|
fn[S] check_steps(
  table : Map[String, Op[S]],
  model : Model?,
  steps : Array[Step],
) -> Unit raise @frontierlab.TraceError {
  for step in steps {
    if step_problem(table, model, step) is Some(problem) {
      raise @frontierlab.InvalidStep(problem)
    }
  }
}

///|
priv enum Outcome[S] {
  /// The step ran and every check accepted the new state.
  Applied(S, String?)
  /// The step ran, but a check rejected the new state.
  Rejected(S, String?, String)
  /// The operation raised an error and the model did not, so there is no new
  /// state.
  Raised(String)
}

///|
priv struct Checks[S] {
  invariant : ((S) -> String?)?
  check : ((S, Step) -> String?)?
  model : Model?
}

///|
fn[S] Checks::any(self : Checks[S]) -> Bool {
  self.invariant is Some(_) || self.check is Some(_) || self.model is Some(_)
}

///|
fn result_text(result : String?) -> String {
  match result {
    Some(text) => "returned \{text}"
    None => "returned normally"
  }
}

///|
/// Runs one step, and the model's step when there is a model, then checks
/// the new state. `model_step` must be the same model run for every step of
/// a sequence.
fn[S] apply_step(
  table : Map[String, Op[S]],
  state : S,
  step : Step,
  checks : Checks[S],
  model_step : ((Step) -> Result[String?, String])?,
) -> Outcome[S] {
  let ran : Result[(S, String?), Error] = Ok(
    (table[step.op].run)(state, step.arg),
  ) catch {
    error => Err(error)
  }
  let expected = match model_step {
    Some(f) => Some(f(step))
    None => None
  }
  let (next, result) = match (ran, expected) {
    (Err(error), None) => return Raised("raised \{error}")
    // Both raised, for example popping an empty heap: that is the expected
    // behavior, and the state stays as it was.
    (Err(error), Some(Err(_))) => return Applied(state, Some("raised \{error}"))
    (Err(error), Some(Ok(model_result))) =>
      return Raised(
        "raised \{error}, but the model \{result_text(model_result)}",
      )
    (Ok((next, result)), Some(Err(model_error))) =>
      return Rejected(
        next,
        result,
        "\{result_text(result)}, but the model \{model_error}",
      )
    (Ok((next, result)), Some(Ok(model_result))) =>
      if result != model_result {
        return Rejected(
          next,
          result,
          "\{result_text(result)}, but the model \{result_text(model_result)}",
        )
      } else {
        (next, result)
      }
    (Ok((next, result)), None) => (next, result)
  }
  if checks.invariant is Some(invariant) && invariant(next) is Some(message) {
    return Rejected(next, result, message)
  }
  if checks.check is Some(check) && check(next, step) is Some(message) {
    return Rejected(next, result, message)
  }
  Applied(next, result)
}

///|
fn start_model(model : Model?) -> ((Step) -> Result[String?, String])? {
  match model {
    Some(model) => Some((model.start)())
    None => None
  }
}

///|
/// Runs the steps without recording anything and returns the first failure.
fn[S] first_failure(
  init : () -> S,
  table : Map[String, Op[S]],
  steps : Array[Step],
  checks : Checks[S],
) -> Failure? {
  let mut state = init()
  let model_step = start_model(checks.model)
  for index, step in steps {
    match apply_step(table, state, step, checks, model_step) {
      Applied(next, _) => state = next
      Rejected(_, _, message) | Raised(message) =>
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
/// - `model` runs a reference implementation alongside and requires the same
///   results; see `Model`.
///
/// Replay stops at the first failing step. Every step of the returned trace
/// shows the structure, highlights the nodes that were added or moved, and
/// names removed nodes and returned results, so the player shows where the
/// structure went wrong.
pub fn[S : ToJson] replay(
  init : () -> S,
  ops : Array[Op[S]],
  steps : Array[Step],
  invariant? : (S) -> String?,
  check? : (S, Step) -> String?,
  model? : Model,
  window? : Int32,
  title~ : String = "Data structure replay",
  options~ : @frontierlab.TraceOptions = @frontierlab.TraceOptions::default(),
) -> Replay raise @frontierlab.TraceError {
  let table = op_table(ops)
  check_model(table, model)
  check_steps(table, model, steps)
  let checks = { invariant, check, model, }
  // With a window, a first pass without snapshots finds where the run stops,
  // and only the last `window` steps before that point are drawn.
  let start = match window {
    None => 0
    Some(size) => {
      if size < 1 {
        raise @frontierlab.LimitExceeded("window must be at least 1.")
      }
      let stop = match first_failure(init, table, steps, checks) {
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
  let model_step = start_model(model)
  let outputs : Array[String?] = []
  let unchecked = { invariant: None, check: None, model, }
  for step in steps[0:start] {
    // These steps passed in the first pass, so they apply cleanly.
    if apply_step(table, state, step, unchecked, model_step)
      is Applied(next, result) {
      state = next
      outputs.push(result)
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
    let (after, result, problem) = match
      apply_step(table, state, step, checks, model_step) {
      Applied(next, result) => {
        state = next
        (snapshot(state.to_json()), result, None)
      }
      Rejected(next, result, message) => {
        state = next
        (snapshot(state.to_json()), result, Some(message))
      }
      // A step that raised leaves no new state; show the last good one.
      Raised(message) => (before, None, Some(message))
    }
    outputs.push(result)
    let changed = changed_entities(before, after)
    let removed = removed_labels(before, after)
    let removed_text = if removed.is_empty() {
      ""
    } else {
      " Removed: \{removed.join(", ")}."
    }
    let result_note = match (result, problem) {
      (Some(text), None) => " Returned: \{text}."
      _ => ""
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
        (Changed, changed, summary + removed_text + result_note)
      }
      Some(message) => {
        failure = Some({ index, step, message, })
        let marked = if changed.is_empty() { after.entities } else { changed }
        (Error, marked, "Check failed: \{message}.\{removed_text}")
      }
    }
    let attributes = []
    if step.arg is Some(arg) {
      attributes.push(
        @frontierlab.TraceAttribute::new(key="arg", value=arg.stringify()),
      )
    }
    if result is Some(text) {
      attributes.push(
        @frontierlab.TraceAttribute::new(key="result", value=text),
      )
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
  { steps, outputs, failure, trace: builder.finish(summary~), }
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
fn shrink_number(n : Double) -> Array[Json] {
  if n == 0.0 {
    return []
  }
  let whole = n.to_int64().to_double()
  if whole != n {
    return [Json::number(0.0), Json::number(whole)]
  }
  let i = n.to_int64()
  let toward_zero = if i > 0L { i - 1L } else { i + 1L }
  [0L, i / 2L, toward_zero].map(fn(k) { Json::number(k.to_double()) })
}

///|
/// Smaller variants of an argument: numbers toward zero, shorter strings and
/// arrays, and smaller elements and fields. Candidates that the operation
/// cannot read are skipped by the caller.
fn shrink_json(value : Json) -> Array[Json] {
  match value {
    Number(n, ..) => shrink_number(n)
    True => [Json::boolean(false)]
    String(s) => {
      let chars = s.to_array()
      if chars.is_empty() {
        return []
      }
      let half = chars.length() / 2
      [
        "",
        String::from_array(chars[0:half]),
        String::from_array(chars[1:]),
        String::from_array(chars[0:chars.length() - 1]),
      ].map(Json::string)
    }
    Array(xs) => {
      let out : Array[Json] = []
      for i in 0..<xs.length() {
        out.push(Json::array(xs[0:i].to_owned() + xs[i + 1:].to_owned()))
      }
      for i, x in xs {
        for smaller in shrink_json(x) {
          let copy = xs.copy()
          copy[i] = smaller
          out.push(Json::array(copy))
        }
      }
      out
    }
    Object(fields) => {
      let out : Array[Json] = []
      for key, field in fields {
        for smaller in shrink_json(field) {
          let copy = Map::from_iter(fields.iter())
          copy[key] = smaller
          out.push(Json::object(copy))
        }
      }
      out
    }
    _ => []
  }
}

///|
/// Shrinks a failing sequence: first removes runs of steps, then makes each
/// argument smaller. Every candidate must still fail, and candidate arguments
/// must still fit their operation (`valid`).
fn shrink(
  steps : Array[Step],
  fails : (Array[Step]) -> Bool,
  valid : (Step) -> Bool,
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
      // Shrink every occurrence of an argument together first: in
      // `insert 4, contains 4`, neither 4 can change alone.
      let seen : Array[Json] = []
      for step in best {
        guard step.arg is Some(arg) else { continue }
        if seen.contains(arg) {
          continue
        }
        seen.push(arg)
        for smaller in shrink_json(arg) {
          let candidate = best.map(fn(other) {
            if other.arg == Some(arg) {
              { op: other.op, arg: Some(smaller), }
            } else {
              other
            }
          })
          if candidate.iter().all(valid) && fails(candidate) {
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
    if !progress {
      for i, step in best {
        guard step.arg is Some(arg) else { continue }
        for smaller in shrink_json(arg) {
          let changed = { op: step.op, arg: Some(smaller), }
          if !valid(changed) {
            continue
          }
          let candidate = best.copy()
          candidate[i] = changed
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
    if progress {
      rounds += 1
    }
  }
  (best, rounds)
}

///|
/// Searches random operation sequences for one that breaks `invariant`,
/// `check`, or agreement with `model`, shrinks it to a small failing
/// sequence, and replays only that sequence with full snapshots.
///
/// The search itself takes no snapshots: each candidate only runs the
/// operations and the checks. Use `replay` to run a sequence you wrote by
/// hand.
///
/// `init` must return a fresh state on every call, because each candidate
/// starts from scratch. Arguments of `Op::new` operations are drawn from
/// `0..<max_arg`; generators of `Op::with_gen` operations receive `max_arg`
/// as their size. Returns `None` when no failure is found in `cases`
/// sequences or when there is nothing to check.
pub fn[S : ToJson] explore(
  init : () -> S,
  ops : Array[Op[S]],
  invariant? : (S) -> String?,
  check? : (S, Step) -> String?,
  model? : Model,
  cases~ : Int32 = 300,
  max_steps~ : Int32 = 12,
  max_arg~ : Int32 = 10,
  max_shrinks~ : Int32 = 200,
  seed~ : UInt64 = 1,
  title~ : String = "Smallest failing sequence",
  options~ : @frontierlab.TraceOptions = @frontierlab.TraceOptions::default(),
) -> Exploration? raise @frontierlab.TraceError {
  let table = op_table(ops)
  check_model(table, model)
  if cases < 1 || max_steps < 1 || max_arg < 1 || max_shrinks < 0 {
    raise @frontierlab.LimitExceeded(
      "cases, max_steps and max_arg must be positive and max_shrinks non-negative.",
    )
  }
  let checks = { invariant, check, model, }
  if !checks.any() {
    return None
  }
  let rng : Rng = { state: seed, }
  // Generators get their own stream, so that integer operations draw the same
  // sequences whether or not other operations use generators.
  let rs = @splitmix.RandomState(seed~)
  let fails = fn(steps) { first_failure(init, table, steps, checks) is Some(_) }
  let valid = fn(step) { step_problem(table, model, step) is None }
  for case in 0..<cases {
    let length = 1 + rng.next(max_steps)
    let steps = Array::makei(length, fn(_) {
      let op = ops[rng.next(ops.length())]
      let arg = if !op.takes_arg {
        None
      } else if op.gen is Some(gen) {
        Some(gen(max_arg, rs))
      } else {
        Some(Json::number(rng.next(max_arg).to_double()))
      }
      { op: op.name, arg, }
    })
    // A model may not read every generated argument; such a sequence is not
    // a failure of the structure under test.
    if !steps.iter().all(valid) {
      continue
    }
    if first_failure(init, table, steps, checks) is Some(failure) {
      // Steps after the first failure never run, so drop them before shrinking.
      let prefix = steps[0:failure.index + 1].to_owned()
      let (smallest, rounds) = shrink(prefix, fails, valid, max_shrinks)
      let replayed = replay(
        init,
        ops,
        smallest,
        invariant?,
        check?,
        model?,
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
