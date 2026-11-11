///|
/// A persistent binary search tree, written the way a user would write it.
#derive(ToJson)
enum Tree {
  Leaf
  Node(Tree, Int32, Tree)
}

///|
fn insert(t : Tree, k : Int32) -> Tree {
  match t {
    Leaf => Node(Leaf, k, Leaf)
    Node(l, v, r) =>
      if k < v {
        Node(insert(l, k), v, r)
      } else if k > v {
        Node(l, v, insert(r, k))
      } else {
        t
      }
  }
}

///|
fn min_key(t : Tree) -> Int32 {
  match t {
    Node(Leaf, v, _) => v
    Node(l, _, _) => min_key(l)
    Leaf => abort("empty tree")
  }
}

///|
/// Deletes a node with two children incorrectly: the successor is removed
/// from the left subtree instead of the right one, so it stays duplicated.
fn buggy_delete(t : Tree, k : Int32) -> Tree {
  match t {
    Leaf => Leaf
    Node(l, v, r) =>
      if k < v {
        Node(buggy_delete(l, k), v, r)
      } else if k > v {
        Node(l, v, buggy_delete(r, k))
      } else {
        match (l, r) {
          (Leaf, _) => r
          (_, Leaf) => l
          _ => {
            let m = min_key(r)
            Node(buggy_delete(l, m), m, r)
          }
        }
      }
  }
}

///|
fn delete(t : Tree, k : Int32) -> Tree {
  match t {
    Leaf => Leaf
    Node(l, v, r) =>
      if k < v {
        Node(delete(l, k), v, r)
      } else if k > v {
        Node(l, v, delete(r, k))
      } else {
        match (l, r) {
          (Leaf, _) => r
          (_, Leaf) => l
          _ => {
            let m = min_key(r)
            Node(l, m, delete(r, m))
          }
        }
      }
  }
}

///|
fn keys(t : Tree) -> Array[Int32] {
  match t {
    Leaf => []
    Node(l, v, r) => keys(l) + [v] + keys(r)
  }
}

///|
fn is_bst(t : Tree) -> String? {
  let ks = keys(t)
  for i in 1..<ks.length() {
    if ks[i - 1] >= ks[i] {
      return Some("in-order keys \{ks[i - 1]} and \{ks[i]} are not increasing")
    }
  }
  None
}

///|
fn buggy_ops() -> Array[@explore.Op[Tree]] {
  [@explore.Op::new("insert", insert), @explore.Op::new("delete", buggy_delete)]
}

///|
fn graph_of(
  trace : @frontierlab.AlgorithmTrace,
  step : Int32,
) -> @frontierlab.GraphState {
  match trace.steps[step].scene.objects[0] {
    Graph(graph) => graph
    _ => abort("expected a graph")
  }
}

///|
test "explore finds and shrinks the duplicated successor bug" {
  let found = @explore.explore(fn() { Leaf }, buggy_ops(), invariant=is_bst)
  guard found is Some(found) else { fail("expected a failing sequence") }
  let replay = found.replay
  assert_false(replay.passed())
  // Deleting a node with two children needs at least three inserts first.
  assert_eq(replay.steps.length(), 4)
  assert_eq(replay.steps[3].op, "delete")
  guard replay.failure is Some(failure) else { fail("expected a failure") }
  assert_eq(failure.index, 3)
  assert_true(failure.message.contains("not increasing"))
  assert_true(found.original.length() >= replay.steps.length())
  assert_true(found.report().contains("Step 4 of 4"))
  replay.trace.validate()
  // One snapshot per step; replay stops at the failing step.
  assert_eq(replay.trace.steps.length(), 4)
  let last = replay.trace.steps[3]
  assert_true(last.scene.highlights.iter().all(fn(h) { h.role == Error }))
  assert_true(replay.to_html().contains("<!doctype html>"))
}

///|
test "explore is deterministic for a seed" {
  let first = @explore.explore(
    fn() { Leaf },
    buggy_ops(),
    invariant=is_bst,
    seed=7,
  )
  let second = @explore.explore(
    fn() { Leaf },
    buggy_ops(),
    invariant=is_bst,
    seed=7,
  )
  guard first is Some(first) && second is Some(second) else {
    fail("expected failures")
  }
  assert_eq(first.replay.steps, second.replay.steps)
  assert_eq(first.original, second.original)
}

///|
test "a correct tree survives exploration and replays to completion" {
  let ops = [
    @explore.Op::new("insert", insert),
    @explore.Op::new("delete", delete),
  ]
  let removed = fn(t : Tree, step : @explore.Step) -> String? {
    match step {
      { op: "delete", arg: Some(k), } if keys(t).contains(k) =>
        Some("\{k} is still present")
      _ => None
    }
  }
  assert_true(
    @explore.explore(fn() { Leaf }, ops, invariant=is_bst, check=removed)
    is None,
  )
  let replay = @explore.replay(
    fn() { Leaf },
    ops,
    @explore.Step::parse("insert 50, insert 30, insert 70, delete 50"),
    invariant=is_bst,
    check=removed,
  )
  assert_true(replay.passed())
  replay.trace.validate()
  // Four operations plus the closing Complete step.
  assert_eq(replay.trace.steps.length(), 5)
  assert_true(replay.trace.steps[4].event is Complete)
  assert_true(replay.report().contains("All 4 steps passed"))
}

///|
test "replay draws a binary tree with left and right edges" {
  let replay = @explore.replay(
    fn() { Leaf },
    buggy_ops(),
    @explore.Step::parse("insert 2; insert 1; insert 3"),
  )
  let graph = graph_of(replay.trace, 2)
  assert_eq(graph.nodes.map(fn(n) { n.label }), ["2", "1", "3"])
  assert_eq(graph.edges.map(fn(e) { e.label }), ["left", "right"])
  // Inserting 3 adds exactly one node, and it is highlighted.
  let highlighted = replay.trace.steps[2].scene.highlights.map(fn(h) {
    h.target.entity_id.unwrap_or("")
  })
  assert_eq(highlighted, ["n:3"])
  // The empty tree has no nodes; its constructor names the graph instead.
  let empty = match replay.trace.initial_scene.objects[0] {
    Graph(graph) => graph
    _ => fail("expected a graph")
  }
  assert_eq(empty.label, "State: Leaf")
  assert_eq(empty.nodes.length(), 0)
  assert_true(
    replay.trace.steps[0].annotation is Some({ body: "Added or moved: 2.", .. }),
  )
}

///|
test "a hand-written script reaches the same bug" {
  let replay = @explore.replay(
    fn() { Leaf },
    buggy_ops(),
    @explore.Step::parse(
      "insert 50, insert 30, insert 70, insert 20, insert 40, delete 30",
    ),
    invariant=is_bst,
  )
  guard replay.failure is Some(failure) else { fail("expected a failure") }
  assert_eq(failure.index, 5)
  assert_eq(failure.step, @explore.Step::new("delete", arg=30))
  // The duplicated key 40 gets a numbered id.
  let ids = graph_of(replay.trace, 5).nodes.map(fn(n) { n.id })
  assert_eq(ids, ["n:50", "n:40", "n:20", "n:40#2", "n:70"])
}

///|
/// A mutable stack whose push silently drops values once it holds three.
#derive(ToJson)
struct Stack {
  items : Array[Int32]
}

///|
fn push(s : Stack, x : Int32) -> Stack {
  if s.items.length() < 3 {
    s.items.push(x)
  }
  s
}

///|
#derive(Debug)
suberror EmptyStack

///|
fn pop(s : Stack) -> Stack raise EmptyStack {
  match s.items.pop() {
    Some(_) => s
    None => raise EmptyStack
  }
}

///|
test "mutable structures use a fresh state and the check sees each step" {
  let ops = [
    @explore.Op::new("push", push),
    @explore.Op::without_arg("pop", pop),
  ]
  let top_is_pushed = fn(s : Stack, step : @explore.Step) -> String? {
    match step {
      { op: "push", arg: Some(x), } if s.items.last() != Some(x) =>
        Some("push \{x} did not put \{x} on top")
      _ => None
    }
  }
  let replay = @explore.replay(
    fn() { { items: [], } },
    ops,
    @explore.Step::parse("push 1, push 2, push 3, pop, push 4, push 5, push 6"),
    check=top_is_pushed,
  )
  guard replay.failure is Some(failure) else { fail("expected a failure") }
  assert_eq(failure.step, @explore.Step::new("push", arg=5))
  // A flat struct of arrays is drawn as a sequence, not a graph.
  assert_true(replay.trace.steps[0].scene.objects[0] is Sequence(_))
  // Popping an empty stack raises, which is the smallest failure of all.
  let found = @explore.explore(
    fn() { { items: [], } },
    ops,
    check=top_is_pushed,
  )
  guard found is Some(found) else { fail("expected a failing sequence") }
  assert_eq(found.replay.steps, [@explore.Step::new("pop")])
  // With push alone, the fourth push is the first one that is dropped.
  let pushes = @explore.explore(
    fn() { { items: [], } },
    [@explore.Op::new("push", push)],
    check=top_is_pushed,
  )
  guard pushes is Some(pushes) else { fail("expected a failing sequence") }
  assert_eq(pushes.replay.steps.map(fn(step) { step.op }), [
    "push", "push", "push", "push",
  ])
}

///|
test "an operation that raises fails its step" {
  let ops = [
    @explore.Op::new("push", push),
    @explore.Op::without_arg("pop", pop),
  ]
  let replay = @explore.replay(
    fn() { { items: [], } },
    ops,
    @explore.Step::parse("push 1, pop, pop"),
    check=fn(_, _) { None },
  )
  guard replay.failure is Some(failure) else { fail("expected a failure") }
  assert_eq(failure.index, 2)
  assert_true(failure.message.contains("raised"))
  replay.trace.validate()
}

///|
#derive(ToJson)
enum Color {
  Red
  Black
}

///|
#derive(ToJson)
enum Rb {
  E
  N(Color, Rb, Int32, Rb)
}

///|
#derive(ToJson)
enum Chain {
  End
  Link(head~ : Int32, tail~ : Chain)
}

///|
#derive(ToJson)
struct Trie {
  word : Bool
  kids : Map[String, Trie]
}

///|
fn[T] noop() -> Array[@explore.Op[T]] {
  [@explore.Op::new("noop", fn(x, _) { x })]
}

///|
test "constant constructors become labels or empty children by position" {
  let tree = N(Black, N(Red, E, 1, E), 2, E)
  let replay = @explore.replay(fn() { tree }, noop(), [])
  let graph = match replay.trace.initial_scene.objects[0] {
    Graph(graph) => graph
    _ => fail("expected a graph")
  }
  assert_eq(graph.nodes.map(fn(n) { n.label }), ["Black, 2", "Red, 1"])
  assert_eq(graph.edges.map(fn(e) { e.label }), ["left"])
}

///|
test "labeled constructors and maps become edges named after fields" {
  let chain = Link(head=1, tail=Link(head=2, tail=End))
  let chain_graph = match
    @explore.replay(fn() { chain }, noop(), []).trace.initial_scene.objects[0] {
    Graph(graph) => graph
    _ => fail("expected a graph")
  }
  assert_eq(chain_graph.nodes.map(fn(n) { n.label }), ["1", "2"])
  assert_eq(chain_graph.edges.map(fn(e) { e.label }), ["tail"])
  let trie : Trie = { word: false, kids: { "a": { word: true, kids: {}, } }, }
  let trie_graph = match
    @explore.replay(fn() { trie }, noop(), []).trace.initial_scene.objects[0] {
    Graph(graph) => graph
    _ => fail("expected a graph")
  }
  assert_eq(trie_graph.edges.map(fn(e) { e.label }), ["kids.a"])
}

///|
fn error_of(
  f : () -> Unit raise @frontierlab.TraceError,
) -> @frontierlab.TraceError? {
  f() catch {
    error => return Some(error)
  }
  None
}

///|
test "scripts and operation tables are validated" {
  assert_eq(@explore.Step::parse(" pop ;\n\npush 3,"), [
    @explore.Step::new("pop"),
    @explore.Step::new("push", arg=3),
  ])
  assert_eq(@explore.Step::new("push", arg=3).to_string(), "push 3")
  for script in ["push x", "push 1 2"] {
    assert_true(
      error_of(() => ignore(@explore.Step::parse(script)))
      is Some(InvalidStep(_)),
    )
  }
  let ops = [@explore.Op::new("insert", insert)]
  let unknown = error_of(() => {
    ignore(
      @explore.replay(fn() { Leaf }, ops, [@explore.Step::new("remove", arg=1)]),
    )
  })
  assert_true(unknown is Some(InvalidStep(_)))
  let missing = error_of(() => {
    ignore(@explore.replay(fn() { Leaf }, ops, [@explore.Step::new("insert")]))
  })
  assert_true(missing is Some(InvalidStep(_)))
  let twice = error_of(() => {
    ignore(@explore.replay(fn() { Leaf }, ops + ops, []))
  })
  assert_true(twice is Some(DuplicateId(_)))
  let none = error_of(() => ignore(@explore.replay(fn() { Leaf }, [], [])))
  assert_true(none is Some(InvalidStep(_)))
  let limits = error_of(() => {
    ignore(@explore.explore(fn() { Leaf }, ops, invariant=is_bst, cases=0))
  })
  assert_true(limits is Some(LimitExceeded(_)))
  // Without any check there is nothing to find.
  assert_true(@explore.explore(fn() { Leaf }, ops) is None)
}

///|
test "a window draws only the last steps before the failure" {
  let steps = @explore.Step::parse(
    "insert 50, insert 30, insert 70, insert 20, insert 40, delete 30",
  )
  let replay = @explore.replay(
    () => Leaf,
    buggy_ops(),
    steps,
    invariant=is_bst,
    window=2,
  )
  guard replay.failure is Some(failure) else { fail("expected a failure") }
  // Failure positions stay absolute even though only two steps are drawn.
  assert_eq(failure.index, 5)
  assert_eq(replay.trace.steps.length(), 2)
  assert_true(
    replay.trace.steps[0].annotation is Some({ title: "Step 5: insert 40", .. }),
  )
  // The initial scene already holds the four earlier inserts.
  let initial = match replay.trace.initial_scene.objects[0] {
    Graph(graph) => graph
    _ => fail("expected a graph")
  }
  assert_eq(initial.nodes.length(), 4)
  replay.trace.validate()
  // Without a failure, the window covers the last steps of the script.
  let passing = @explore.replay(
    () => Leaf,
    buggy_ops(),
    steps[0:5].to_owned(),
    invariant=is_bst,
    window=3,
  )
  assert_true(passing.passed())
  // Three operations plus Complete.
  assert_eq(passing.trace.steps.length(), 4)
  let bad = error_of(() => {
    ignore(@explore.replay(() => Leaf, buggy_ops(), steps, window=0))
  })
  assert_true(bad is Some(LimitExceeded(_)))
}

///|
#derive(ToJson)
struct Note {
  key : Int32
  weight : Double
  text : String
  children : Array[Note]
}

///|
#derive(ToJson)
enum Ternary {
  Nil
  T3(Int32, Ternary, Ternary, Ternary)
}

///|
#derive(ToJson)
enum Opt {
  Cell(Int32, Opt?)
}

///|
#derive(ToJson)
struct Counter {
  values : Array[Int32]
  size : Int32
  label : String
}

///|
fn initial_objects(value : Json) -> Array[@frontierlab.SceneObject] raise {
  // Every value is drawn through the same snapshot path that replay uses.
  let replay = @explore.replay(() => value, noop(), [])
  replay.trace.initial_scene.objects
}

///|
fn initial_graph(value : Json) -> @frontierlab.GraphState raise {
  match initial_objects(value)[0] {
    Graph(graph) => graph
    _ => abort("expected a graph")
  }
}

///|
test "struct nodes show several fields and list children" {
  let note : Note = {
    key: 1,
    weight: 0.5,
    text: "two words",
    children: [{ key: 2, weight: 1, text: "Leaf-x", children: [], }],
  }
  let graph = initial_graph(ToJson::to_json(note))
  assert_eq(graph.nodes.map(fn(n) { n.label }), [
    "key=1, weight=0.5, text=two words", "key=2, weight=1, text=Leaf-x",
  ])
  assert_eq(graph.edges.map(fn(e) { e.label }), ["children[0]"])
}

///|
test "constructors with three subtrees and optional children" {
  let ternary = T3(1, T3(2, Nil, Nil, Nil), Nil, T3(3, Nil, Nil, Nil))
  assert_eq(
    initial_graph(ToJson::to_json(ternary)).edges.map(fn(e) { e.label }),
    ["0", "2"],
  )
  let cells = Cell(1, Some(Cell(2, None)))
  assert_eq(
    initial_graph(ToJson::to_json(cells)).nodes.map(fn(n) { n.label }),
    ["1", "2"],
  )
  // A list of subtrees is drawn as a forest with one root per element.
  let forest : Array[Tree] = [Node(Leaf, 1, Leaf), Node(Leaf, 2, Leaf)]
  let graph = initial_graph(ToJson::to_json(forest))
  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.edges.length(), 0)
}

///|
test "flat values are drawn as sequences" {
  let counter : Counter = { values: [3, 1, 2], size: 3, label: "c", }
  let objects = initial_objects(ToJson::to_json(counter))
  let ids = objects.map(fn(o) {
    match o {
      Sequence(sequence) => sequence.id
      _ => "?"
    }
  })
  assert_eq(ids, ["values", "fields"])
  match objects[1] {
    Sequence(fields) =>
      assert_eq(fields.items.map(fn(item) { item.value }), ["size=3", "label=c"])
    _ => fail("expected a sequence")
  }
  let optional : Array[Int32?] = [Some(1), None]
  match initial_objects(ToJson::to_json(optional))[0] {
    Sequence(values) =>
      assert_eq(values.items.map(fn(item) { item.value }), ["[1]", "None"])
    _ => fail("expected a sequence")
  }
}

///|
test "a window larger than the run draws every step" {
  let replay = @explore.replay(
    () => Leaf,
    buggy_ops(),
    @explore.Step::parse("insert 2, insert 1, insert 3, delete 2"),
    invariant=is_bst,
    window=10,
  )
  assert_eq(replay.trace.steps.length(), 4)
}
