///|
test "marks go before every statement, once per line" {
  let source =
    #|fn insert(t : Tree, k : Int) -> Tree {
    #|  let x = k + 1
    #|  if x > 3 { g(x) } else {
    #|    h(x)
    #|    x
    #|  }
    #|  match t {
    #|    Leaf => { a(); b }
    #|    Node(l, v, r) => c
    #|  }
    #|  for i in 0..<3 {
    #|    p(i)
    #|  }
    #|  let f = fn(y) { q(y) }
    #|  guard x > 0 else { return t }
    #|  t
    #|}
  let (out, done) = @lib.instrument(source, [@lib.Target::new("insert")])
  inspect(
    out,
    content=(
      #|fn insert(t : Tree, k : Int) -> Tree {
      #|  @explore.auto_mark(t, 2, "let x = k + 1"); let x = k + 1
      #|  @explore.auto_mark(t, 3, "if x > 3 { g(x) } else {"); if x > 3 { g(x) } else {
      #|    @explore.auto_mark(t, 4, "h(x)"); h(x)
      #|    @explore.auto_mark(t, 5, "x"); x
      #|  }
      #|  @explore.auto_mark(t, 7, "match t {"); match t {
      #|    Leaf => { @explore.auto_mark(t, 8, "Leaf => { a(); b }"); a(); b }
      #|    Node(l, v, r) => c
      #|  }
      #|  @explore.auto_mark(t, 11, "for i in 0..<3 {"); for i in 0..<3 {
      #|    @explore.auto_mark(t, 12, "p(i)"); p(i)
      #|  }
      #|  @explore.auto_mark(t, 14, "let f = fn(y) { q(y) }"); let f = fn(y) { q(y) }
      #|  @explore.auto_mark(t, 15, "guard x > 0 else { return t }"); guard x > 0 else { return t }
      #|  @explore.auto_mark(t, 16, "t"); t
      #|}
    ),
  )
  assert_eq(done[0].name, "insert")
  assert_eq(done[0].watch, "t")
  assert_eq(done[0].lines, [2, 3, 4, 5, 7, 8, 11, 12, 14, 15, 16])
  // Removing the marks restores the source exactly.
  assert_eq(@lib.remove(out), (source, 11))
}

///|
test "a local is watched only where it is in scope" {
  let source =
    #|fn HashMap::grow(self : HashMap) -> Unit {
    #|  let n = self.buckets.length()
    #|  let wider = Array::makei(n * 2, _ => []) // twice as many
    #|  for i, bucket in self.buckets {
    #|    for entry in bucket {
    #|      wider[i].push(entry)
    #|    }
    #|  }
    #|  self.buckets = wider
    #|}
    #|
    #|fn other(x : Int) -> Int {
    #|  x
    #|}
  let (out, done) = @lib.instrument(
    source,
    [
      @lib.Target::new("HashMap::grow", watch="wider"),
      @lib.Target::new("other"),
    ],
    pkg="ex",
  )
  inspect(
    out,
    content=(
      #|fn HashMap::grow(self : HashMap) -> Unit {
      #|  let n = self.buckets.length()
      #|  let wider = Array::makei(n * 2, _ => []) // twice as many
      #|  @ex.auto_mark(wider, 4, "for i, bucket in self.buckets {"); for i, bucket in self.buckets {
      #|    @ex.auto_mark(wider, 5, "for entry in bucket {"); for entry in bucket {
      #|      @ex.auto_mark(wider, 6, "wider[i].push(entry)"); wider[i].push(entry)
      #|    }
      #|  }
      #|  @ex.auto_mark(wider, 9, "self.buckets = wider"); self.buckets = wider
      #|}
      #|
      #|fn other(x : Int) -> Int {
      #|  @ex.auto_mark(x, 13, "x"); x
      #|}
    ),
  )
  assert_eq(done.map(f => (f.name, f.watch)), [
    ("HashMap::grow", "wider"),
    ("other", "x"),
  ])
  // A method can also be named without its type, and loop variables can be
  // watched inside their loop.
  let (looped, _) = @lib.instrument(source, [
    @lib.Target::new("grow", watch="entry"),
  ])
  let marked = looped
    .split("\n")
    .filter(line => line.contains("auto_mark"))
    .map(line => line.to_owned())
    .collect()
  assert_eq(marked, [
    "      @explore.auto_mark(entry, 6, \"wider[i].push(entry)\"); wider[i].push(entry)",
  ])
}

///|
test "notes are quoted, shortened and survive removal" {
  let source =
    #|fn f(s : String) -> String {
    #|  let t = s + "a \"quoted\" (paren) \\ \{s} 中文"
    #|  let long = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    #|  t
    #|}
  let (out, _) = @lib.instrument(source, [@lib.Target::new("f")])
  inspect(
    out,
    content=(
      #|fn f(s : String) -> String {
      #|  @explore.auto_mark(s, 2, "let t = s + \"a \\\"quoted\\\" (paren) \\\\ \\{s} 中文\""); let t = s + "a \"quoted\" (paren) \\ \{s} 中文"
      #|  @explore.auto_mark(s, 3, "let long = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..."); let long = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      #|  @explore.auto_mark(s, 4, "t"); t
      #|}
    ),
  )
  assert_eq(@lib.remove(out).0, source)
  let crlf = "fn g(x : Int) -> Int {\r\n  let y = x\r\n  y\r\n}\r\n"
  let (marked, _) = @lib.instrument(crlf, [@lib.Target::new("g")])
  assert_true(
    marked.contains("@explore.auto_mark(x, 2, \"let y = x\"); let y = x\r\n"),
  )
  assert_eq(@lib.remove(marked).0, crlf)
}

///|
test "problems are reported instead of writing a broken file" {
  let errors = [
    ("fn f(x : Int) -> Int {\n  x\n}", "g", None),
    ("fn f() -> Int {\n  1\n}", "f", None),
    ("fn f(x : Int) -> Int {\n  @explore.auto_mark(x, \"x\"); x\n}", "f", None),
    ("fn f(x : Int) -> Int {\n  x +\n}", "f", None),
  ].map(case => {
    let (source, name, watch) = case
    try @lib.instrument(source, [@lib.Target::new(name, watch?)]) catch {
      error => error.to_string()
    } noraise {
      _ => "instrumented"
    }
  })
  assert_eq(errors[0], "No function named `g` in the source.")
  assert_eq(errors[1], "`f` has no parameter to watch; pass a variable name.")
  assert_eq(
    errors[2],
    "The source already holds inserted marks; remove them first.",
  )
  assert_true(errors[3].has_prefix("The source does not parse:"))
  assert_eq(@lib.remove("no marks here"), ("no marks here", 0))
}

///|
test "marks moved onto their own lines by moon fmt are removed whole" {
  let source = "fn g(x : Int) -> Int {\n  let y = x\n  y\n}\n"
  let formatted =
    #|fn g(x : Int) -> Int {
    #|  @explore.auto_mark(x, 2, "let y = x")
    #|  let y = x
    #|  @explore.auto_mark(x, 3, "y")
    #|  y
    #|}
    #|
  assert_eq(@lib.remove(formatted), (source, 2))
  let crlf = formatted.replace_all(old="\n", new="\r\n")
  assert_eq(@lib.remove(crlf).0, source.replace_all(old="\n", new="\r\n"))
}
