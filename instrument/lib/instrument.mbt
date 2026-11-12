///|
/// A function to instrument, and the variable to record before each of its
/// statements.
pub struct Target {
  /// `name` or `Type::name`.
  name : String
  /// `None` records the function's first parameter.
  watch : String?
}

///|
pub fn Target::new(name : String, watch? : String) -> Target {
  { name, watch, }
}

///|
/// What `instrument` did to one function.
pub struct Instrumented {
  name : String
  watch : String
  /// One-based line numbers that got a mark.
  lines : Array[Int32]
}

///|
pub suberror InstrumentError {
  /// The source does not parse, before or after instrumenting.
  Unparsable(String)
  /// A requested function is not defined in the source.
  NotFound(String)
  /// The function has no parameter to record and no `watch` was given.
  NothingToWatch(String)
  /// The source already holds marks inserted by this tool.
  AlreadyInstrumented
}

///|
pub impl Show for InstrumentError with fn output(self, logger) {
  logger.write_string(
    match self {
      Unparsable(reports) => "The source does not parse:\n" + reports
      NotFound(name) => "No function named `" + name + "` in the source."
      NothingToWatch(name) =>
        "`" + name + "` has no parameter to watch; pass a variable name."
      AlreadyInstrumented =>
        "The source already holds inserted marks; remove them first."
    },
  )
}

///|
/// The call inserted before each statement.
fn call_prefix(pkg : String) -> String {
  "@" + pkg + ".auto_mark("
}

///|
/// A MoonBit string literal for `text`.
fn quoted(text : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  for c in text {
    match c {
      '\\' => out.write_string("\\\\")
      '"' => out.write_string("\\\"")
      '\n' => out.write_string("\\n")
      '\t' => out.write_string("\\t")
      '\r' => out.write_string("\\r")
      _ => out.write_char(c)
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
/// Finds where statements start inside one function body.
priv struct Finder {
  source : String
  watch : String
  /// Whether `watch` is in scope at the current statement: always for a
  /// parameter, and after its `let` for a local.
  mut active : Bool
  /// Character offsets, at most one per line.
  starts : Array[Int32]
  lines : Map[Int32, Bool]
}

///|
/// Whether `pattern` binds `name`, as in `let name = ...` or
/// `let (name, other) = ...`.
fn binds(pattern : @syntax.Pattern, name : String) -> Bool {
  match pattern {
    Var(binder) => binder.name == name
    Alias(pat~, alias_~, ..) => alias_.name == name || binds(pat, name)
    Constraint(pat~, ..) => binds(pat, name)
    Tuple(pats~, ..) => pats.iter().any(fn(p) { binds(p, name) })
    _ => false
  }
}

///|
/// Runs `f` with `watch` in scope when `bound`, and restores the scope after.
fn Finder::scoped(self : Finder, bound : Bool, f : () -> Unit) -> Unit {
  let saved = self.active
  if bound {
    self.active = true
  }
  f()
  self.active = saved
}

///|
fn Finder::statement(self : Finder, e : @syntax.Expr) -> Unit {
  let start = e.loc().start
  if self.active && !self.lines.contains(start.lnum) {
    self.lines[start.lnum] = true
    self.starts.push(start.cnum)
  }
}

///|
/// Whether `e` sits directly inside braces, so that statements can be put
/// before it: `if c { e }` but not `match x { A => e }`.
fn Finder::braced(self : Finder, e : @syntax.Expr) -> Bool {
  let mut i = e.loc().start.cnum - 1
  while i >= 0 {
    let c = self.source[i]
    if c == ' ' || c == '\n' || c == '\r' || c == '\t' {
      i -= 1
      continue
    }
    return c == '{'
  }
  false
}

///|
/// A block in a nested position, such as an `if` branch or a loop body.
fn Finder::nested(self : Finder, e : @syntax.Expr) -> Unit {
  match e {
    Group(expr~, group=Brace, ..) => self.block(expr)
    _ => if self.braced(e) { self.block(e) } else { self.inner(e) }
  }
}

///|
/// The statements of a block: `let` chains and sequences.
fn Finder::block(self : Finder, e : @syntax.Expr) -> Unit {
  match e {
    Let(pattern~, expr~, body~, ..) => {
      self.statement(e)
      self.inner(expr)
      self.scoped(binds(pattern, self.watch), () => self.block(body))
    }
    LetMut(binder~, expr~, body~, ..) => {
      self.statement(e)
      self.inner(expr)
      self.scoped(binder.name == self.watch, () => self.block(body))
    }
    // Local functions run later, with their own variables; skip their bodies.
    LetFn(body~, ..) | LetAnd(body~, ..) => {
      self.statement(e)
      self.block(body)
    }
    Guard(cond~, otherwise~, body~, ..) => {
      self.statement(e)
      self.inner(cond)
      if otherwise is Some(otherwise) {
        self.nested(otherwise)
      }
      self.block(body)
    }
    Defer(expr~, body~, ..) | ErrDefer(expr~, body~, ..) => {
      self.statement(e)
      self.nested(expr)
      self.block(body)
    }
    Sequence(exprs~, last_expr~, ..) => {
      for x in exprs {
        self.block(x)
      }
      self.block(last_expr)
    }
    StaticAssert(body~, ..) => self.block(body)
    Unit(faked=true, ..) => ()
    other => {
      self.statement(other)
      self.inner(other)
    }
  }
}

///|
/// Blocks nested inside one statement or expression.
fn Finder::inner(self : Finder, e : @syntax.Expr) -> Unit {
  match e {
    If(cond~, ifso~, ifnot~, ..) => {
      self.inner(cond)
      self.nested(ifso)
      match ifnot {
        Some(If(..) as next) => self.inner(next)
        Some(other) => self.nested(other)
        None => ()
      }
    }
    While(loop_cond~, loop_body~, while_else~, ..) => {
      self.inner(loop_cond)
      self.nested(loop_body)
      if while_else is Some(other) {
        self.nested(other)
      }
    }
    For(binders~, body~, for_else~, ..) => {
      let bound = binders.iter().any(fn(pair) { pair.0.name == self.watch })
      self.scoped(bound, () => self.nested(body))
      if for_else is Some(other) {
        self.nested(other)
      }
    }
    ForEach(patterns~, expr~, body~, else_block~, ..) => {
      self.inner(expr)
      let bound = patterns.iter().any(fn(p) { binds(p, self.watch) })
      self.scoped(bound, () => self.nested(body))
      if else_block is Some(other) {
        self.nested(other)
      }
    }
    Match(expr~, cases~, ..) => {
      self.inner(expr)
      for case in cases {
        self.nested(case.body)
      }
    }
    Try(body~, catch_~, try_else~, ..) => {
      self.nested(body)
      for case in catch_ {
        self.nested(case.body)
      }
      if try_else is Some(cases) {
        for case in cases {
          self.nested(case.body)
        }
      }
    }
    LabelledBlock(body~, ..) => self.nested(body)
    Group(expr~, group=Brace, ..) => self.block(expr)
    Group(expr~, group=Paren, ..) => self.inner(expr)
    Assign(expr~, ..) | Return(return_value=Some(expr), ..) => self.inner(expr)
    Mutate(field~, ..) => self.inner(field)
    Constraint(expr~, ..) | TryOperator(body=expr, ..) => self.inner(expr)
    _ => ()
  }
}

///|
fn function_name(decl : @syntax.FunDecl) -> String {
  match decl.type_name {
    Some(type_name) =>
      match type_name.name {
        Ident(name~) => name + "::" + decl.name.name
        Dot(id~, ..) => id + "::" + decl.name.name
      }
    None => decl.name.name
  }
}

///|
fn parameters(decl : @syntax.FunDecl) -> Array[String] {
  guard decl.decl_params is Some(params) else { return [] }
  params
  .iter()
  .filter_map(fn(param) {
    match param {
      Positional(binder~, ..)
      | Labelled(binder~, ..)
      | Optional(binder~, ..)
      | QuestionOptional(binder~, ..) => Some(binder.name)
      DiscardPositional(..) => None
    }
  })
  .collect()
}

///|
fn first_parameter(decl : @syntax.FunDecl) -> String? {
  parameters(decl).get(0)
}

///|
/// The code of a line for a note: without indentation or a trailing `//`
/// comment, and at most 60 characters.
fn line_code(line : String) -> String {
  let code = match line.find(" //") {
    Some(at) => line.clamped_view(end=at).to_owned()
    None => line
  }
  let code = code.trim(chars=" \t\r").to_owned()
  if code.length() > 60 {
    code.clamped_view(end=57).to_owned() + "..."
  } else {
    code
  }
}

///|
fn parse(source : String) -> @list.List[@syntax.Impl] raise InstrumentError {
  let (impls, reports) = @parser.parse_string(source)
  if reports.length() > 0 {
    raise Unparsable(reports.map(fn(r) { "\{r}" }).join("\n"))
  }
  impls
}

///|
/// Inserts `@explore.auto_mark(watch, line, "source line")` before every statement
/// of each target function, at most once per line, so that `replay` shows the
/// watched value before each line runs.
///
/// Marks go on the line of the statement they precede, so line numbers do not
/// change and the player shows the original ones. Bodies of local functions
/// and closures are left alone. `pkg` is the name under which the file's
/// package imports `shop1111/frontierlab/explore`.
pub fn instrument(
  source : String,
  targets : Array[Target],
  pkg~ : String = "explore",
) -> (String, Array[Instrumented]) raise InstrumentError {
  if source.contains(call_prefix(pkg)) {
    raise AlreadyInstrumented
  }
  let impls = parse(source)
  let lines = source.split("\n").map(fn(line) { line.to_owned() }).collect()
  // (offset, inserted text)
  let inserts : Array[(Int32, String)] = []
  let done : Array[Instrumented] = []
  for target in targets {
    let mut found = false
    for impl_ in impls {
      guard impl_ is TopFuncDef(fun_decl~, decl_body=DeclBody(expr~), ..) &&
        (
          function_name(fun_decl) == target.name ||
          fun_decl.name.name == target.name
        ) else {
        continue
      }
      found = true
      let watch = match target.watch {
        Some(name) => name
        None =>
          match first_parameter(fun_decl) {
            Some(name) => name
            None => raise NothingToWatch(function_name(fun_decl))
          }
      }
      let finder = {
        source,
        watch,
        active: parameters(fun_decl).contains(watch),
        starts: [],
        lines: {},
      }
      finder.block(expr)
      let marked = []
      for start in finder.starts {
        // The statement's line, from its offset.
        let mut line = 0
        let mut seen = 0
        while line < lines.length() && seen + lines[line].length() < start {
          seen += lines[line].length() + 1
          line += 1
        }
        inserts.push(
          (
            start,
            call_prefix(pkg) +
            watch +
            ", \{line + 1}, " +
            quoted(line_code(lines[line])) +
            "); ",
          ),
        )
        marked.push(line + 1)
      }
      done.push({ name: function_name(fun_decl), watch, lines: marked, })
    }
    if !found {
      raise NotFound(target.name)
    }
  }
  inserts.sort_by_key(fn(pair) { pair.0 })
  let out = StringBuilder()
  let mut last = 0
  for pair in inserts {
    let (at, text) = pair
    out.write_string(source.clamped_view(start=last, end=at).to_owned())
    out.write_string(text)
    last = at
  }
  out.write_string(source.clamped_view(start=last).to_owned())
  let result = out.to_string()
  // The inserted calls must leave the file parseable.
  ignore(parse(result))
  (result, done)
}

///|
/// Removes every call inserted by `instrument`, restoring the source.
pub fn remove(source : String, pkg~ : String = "explore") -> (String, Int32) {
  let prefix = call_prefix(pkg)
  let out = StringBuilder()
  let mut i = 0
  let mut removed = 0
  let unit = fn(j : Int32) { source.code_unit_at(j).to_int() }
  let blank = fn(c : Int32) { c == ' '.to_int() || c == '\t'.to_int() }
  while source.clamped_view(start=i).find(prefix) is Some(k) {
    let at = i + k
    // Skip to the closing parenthesis, stepping over string literals.
    let mut j = at + prefix.length()
    let mut depth = 1
    let mut in_string = false
    while j < source.length() && depth > 0 {
      let c = source.code_unit_at(j).to_int().unsafe_to_char()
      if in_string {
        if c == '\\' {
          j += 1
        } else if c == '"' {
          in_string = false
        }
      } else if c == '"' {
        in_string = true
      } else if c == '(' {
        depth += 1
      } else if c == ')' {
        depth -= 1
      }
      j += 1
    }
    if j < source.length() && unit(j) == ';'.to_int() {
      j += 1
    }
    if j < source.length() && unit(j) == ' '.to_int() {
      j += 1
    }
    // After `moon fmt` a mark sits alone on its line: remove the whole line.
    let mut start = at
    while start > i && blank(unit(start - 1)) {
      start -= 1
    }
    let mut end = j
    while end < source.length() && blank(unit(end)) {
      end += 1
    }
    if end < source.length() && unit(end) == '\r'.to_int() {
      end += 1
    }
    let alone = (start == 0 || unit(start - 1) == '\n'.to_int()) &&
      end < source.length() &&
      unit(end) == '\n'.to_int()
    if alone {
      out.write_string(source.clamped_view(start=i, end=start).to_owned())
      i = end + 1
    } else {
      out.write_string(source.clamped_view(start=i, end=at).to_owned())
      i = j
    }
    removed += 1
  }
  out.write_string(source.clamped_view(start=i).to_owned())
  (out.to_string(), removed)
}

///|
pub extend InstrumentError with Show::{to_string, output}
