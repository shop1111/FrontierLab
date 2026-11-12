///|
let usage : String =
  #|Usage:
  #|  frontierlab-instrument <file.mbt> --fn NAME [--watch VAR] [--fn ...] [--pkg ALIAS] [--stdout]
  #|  frontierlab-instrument --remove <file.mbt>... [--pkg ALIAS]
  #|
  #|Inserts `@explore.auto_mark(VAR, LINE, "code")` before every statement of each
  #|function NAME (`insert` or `Type::insert`), so that `@explore.replay` shows
  #|VAR before each line runs. VAR defaults to the first parameter. The file
  #|is changed in place unless --stdout is given; --remove takes the marks out.

///|
fn run(args : Array[String]) -> Int32 raise {
  let files : Array[String] = []
  let targets : Array[@lib.Target] = []
  let mut pkg = "explore"
  let mut to_stdout = false
  let mut removing = false
  let mut i = 0
  while i < args.length() {
    match args[i] {
      "--fn" if i + 1 < args.length() => {
        targets.push(@lib.Target::new(args[i + 1]))
        i += 2
      }
      "--watch" if i + 1 < args.length() && !targets.is_empty() => {
        let last = targets.length() - 1
        targets[last] = @lib.Target::new(targets[last].name, watch=args[i + 1])
        i += 2
      }
      "--pkg" if i + 1 < args.length() => {
        pkg = args[i + 1]
        i += 2
      }
      "--stdout" => {
        to_stdout = true
        i += 1
      }
      "--remove" => {
        removing = true
        i += 1
      }
      "--help" | "-h" => {
        println(usage)
        return 0
      }
      arg if arg.has_prefix("--") => {
        println("Unknown option \{arg}.\n\n\{usage}")
        return 2
      }
      file => {
        files.push(file)
        i += 1
      }
    }
  }
  if files.is_empty() || (!removing && targets.is_empty()) {
    println(usage)
    return 2
  }
  for file in files {
    let source = @fs.read_file_to_string(file)
    if removing {
      let (out, count) = @lib.remove(source, pkg~)
      @fs.write_string_to_file(file, out)
      println("Removed \{count} marks from \{file}.")
      continue
    }
    let (out, done) = @lib.instrument(source, targets, pkg~) catch {
      error => {
        println("\{file}: \{error}")
        return 1
      }
    }
    if to_stdout {
      // Only the source, so that the output can be redirected to a file.
      println(out)
      continue
    }
    @fs.write_string_to_file(file, out)
    if !imports_explore(file) {
      println(
        "Note: the package of \{file} must import \"shop1111/frontierlab/explore\" in its moon.pkg.",
      )
    }
    for f in done {
      println(
        "Marked \{f.lines.length()} lines of \{f.name} in \{file}, recording `\{f.watch}`.",
      )
    }
    println(
      "Remove them with: frontierlab-instrument --remove \{file}" +
      (if pkg == "explore" { "" } else { " --pkg \{pkg}" }),
    )
  }
  0
}

///|
fn main {
  let code = run(@env.args()[1:].to_owned()) catch {
    error => {
      println("error: \{error}")
      1
    }
  }
  if code != 0 {
    @sys.exit(code)
  }
}

///|
/// Whether the `moon.pkg` next to `file` imports the explore package that the
/// inserted calls use.
fn imports_explore(file : String) -> Bool {
  let dir = match file.rev_find("/") {
    Some(at) => file.clamped_view(end=at).to_owned()
    None =>
      match file.rev_find("\\") {
        Some(at) => file.clamped_view(end=at).to_owned()
        None => "."
      }
  }
  let config = dir + "/moon.pkg"
  let text = @fs.read_file_to_string(config) catch { _ => return false }
  text.contains("shop1111/frontierlab/explore")
}
