///|
/// A directed graph kept as adjacency lists.
#derive(ToJson)
struct Digraph {
  adj : Map[Int32, Array[Int32]]
}

///|
fn pairs() -> @quickcheck.Generator[(Int32, Int32)] {
  @quickcheck.int_range(0, 3).flat_map(a => {
    @quickcheck.int_range(0, 3).map(b => (a, b))
  })
}

///|
fn graph_ops() -> Array[@explore.Op[Digraph]] {
  [
    @explore.Op::with_gen("link", pairs(), (g : Digraph, pair : (Int32, Int32)) => {
      let (a, b) = pair
      match g.adj.get(a) {
        Some(list) => list.push(b)
        None => g.adj[a] = [b]
      }
      if !g.adj.contains(b) {
        g.adj[b] = []
      }
      g
    }),
    @explore.Op::with_gen("unlink", pairs(), (
      g : Digraph,
      pair : (Int32, Int32),
    ) => {
      let (a, b) = pair
      // Bug: drops every edge out of `a`, not only the one to `b`.
      if g.adj.contains(a) {
        g.adj[a] = []
      }
      ignore(b)
      g
    }),
  ]
}

///|
test "a graph view draws adjacency lists and explains each step" {
  let replay = @explore.replay(
    () => { adj: {}, },
    graph_ops(),
    @explore.Step::parse("link [0, 1], link [1, 2], link [0, 2], unlink [0, 1]"),
    check=(g, step) => {
      if step.op == "unlink" && !g.adj.get(0).unwrap_or([]).contains(2) {
        Some("the edge to 2 is gone too")
      } else {
        None
      }
    },
    views=[Graph("adj")],
  )
  inspect(
    replay.explain(),
    content=(
      #|Initial state:
      #|  adj:
      #|Step 1: link [0,1]
      #|  + node 0
      #|  + node 1
      #|  + edge 0 -> 1
      #|Step 2: link [1,2]
      #|  + node 2
      #|  + edge 1 -> 2
      #|Step 3: link [0,2]
      #|  + edge 0 -> 2
      #|Step 4: unlink [0,1]
      #|  - edge 0 -> 1
      #|  - edge 0 -> 2
      #|  FAILED: the edge to 2 is gone too
      #|State after the failing step:
      #|  adj:
      #|    0 -> -
      #|    1 -> 2
      #|    2 -> -
    ),
  )
  let last = replay.trace.steps[replay.trace.steps.length() - 1]
  guard last.scene.objects is [Graph(graph)] else { fail("expected a graph") }
  assert_eq(graph.id, "view:adj")
  assert_eq(graph.nodes.length(), 3)
  assert_eq(graph.edges.map(edge => edge.id), ["e:1->2"])
}

///|
/// A hash table with separate chaining and a broken resize.
#derive(ToJson)
struct Table {
  buckets : Array[Array[(String, Int32)]]
  mut size : Int32
}

///|
fn slot(key : String, count : Int32) -> Int32 {
  key.length() % count
}

///|
fn table_put(t : Table, entry : (String, Int32)) -> Table {
  let (key, value) = entry
  let bucket = t.buckets[slot(key, t.buckets.length())]
  match bucket.search_by(pair => pair.0 == key) {
    Some(i) => bucket[i] = (key, value)
    None => {
      bucket.push((key, value))
      t.size += 1
    }
  }
  if t.size > t.buckets.length() {
    let wider : Array[Array[(String, Int32)]] = Array::makei(
      t.buckets.length() * 2,
      _ => [],
    )
    for i, old in t.buckets {
      // Bug: keeps every entry at its old index instead of rehashing.
      for pair in old {
        wider[i].push(pair)
      }
    }
    return { buckets: wider, size: t.size, }
  }
  t
}

///|
fn table_get(t : Table, key : String) -> (Table, Int32?) {
  let bucket = t.buckets[slot(key, t.buckets.length())]
  (t, bucket.search_by(pair => pair.0 == key).map(i => bucket[i].1))
}

///|
test "a buckets view draws a hash table and its resize" {
  let ops = [
    @explore.Op::with_gen(
      "put",
      @quickcheck.elements(["a", "bb", "ccc"]).map(key => (key, 1)),
      table_put,
    ),
    @explore.Op::returning_with_gen(
      "get",
      @quickcheck.elements(["a", "bb", "ccc"]),
      table_get,
    ),
  ]
  let model = @explore.Model::new(() => ([] : Array[String]), [
    @explore.Op::with_gen(
      "put",
      @quickcheck.elements(["a"]).map(key => (key, 1)),
      (keys : Array[String], entry : (String, Int32)) => {
        if !keys.contains(entry.0) {
          keys.push(entry.0)
        }
        keys
      },
    ),
    @explore.Op::returning_with_gen("get", @quickcheck.elements(["a"]), (
      keys : Array[String],
      key : String,
    ) => (keys, if keys.contains(key) { Some(1) } else { None })),
  ])
  let replay = @explore.replay(
    () => { buckets: [[], []], size: 0, },
    ops,
    @explore.Step::parse(
      "put [\"a\", 1], put [\"bb\", 2], put [\"ccc\", 3], get \"ccc\"",
    ),
    model~,
    views=[Buckets("buckets")],
  )
  inspect(
    replay.explain(),
    content=(
      #|Initial state:
      #|  buckets:
      #|    0: -
      #|    1: -
      #|  fields: [size=0]
      #|Step 1: put ["a",1]
      #|  fields: [size=0] -> [size=1]
      #|  + a: 1 in bucket 1
      #|Step 2: put ["bb",2]
      #|  fields: [size=1] -> [size=2]
      #|  + bb: 2 in bucket 0
      #|Step 3: put ["ccc",3]
      #|  fields: [size=2] -> [size=3]
      #|  + ccc: 3 in bucket 1
      #|Step 4: get "ccc" -> None
      #|  (no change)
      #|  FAILED: returned None, but the model returned Some(1)
      #|State after the failing step:
      #|  buckets:
      #|    0: bb: 2
      #|    1: a: 1, ccc: 3
      #|    2: -
      #|    3: -
      #|  fields: [size=3]
    ),
  )
}

///|
test "a matrix view draws rows as a grid and names changed cells" {
  let ops : Array[@explore.Op[Array[Array[Int32]]]] = [
    @explore.Op::with_gen(
      "set",
      @quickcheck.int_range(0, 2).map(x => [x, 0, 1]),
      (m : Array[Array[Int32]], args : Array[Int32]) => {
        m[args[1]][args[0]] = args[2]
        m
      },
    ),
    @explore.Op::without_arg("grow", (m : Array[Array[Int32]]) => {
      m.push(Array::make(m[0].length(), 0))
      m
    }),
    @explore.Op::without_arg("shrink", (m : Array[Array[Int32]]) => {
      ignore(m.pop())
      m
    }),
  ]
  let replay = @explore.replay(
    () => [[0, 0], [0, 0]],
    ops,
    @explore.Step::parse("set [1, 0, 7], grow, shrink"),
    views=[Matrix("")],
  )
  inspect(
    replay.explain(),
    content=(
      #|Initial state:
      #|  State:
      #|    0 0
      #|    0 0
      #|Step 1: set [1,0,7]
      #|  ~ (1, 0): 0 -> 7
      #|Step 2: grow
      #|  + (0, 2) = 0
      #|  + (1, 2) = 0
      #|Step 3: shrink
      #|  - (0, 2)
      #|  - (1, 2)
      #|All 3 steps passed. Final state:
      #|  State:
      #|    0 7
      #|    0 0
    ),
  )
  guard replay.trace.steps[0].scene.objects is [Grid(grid)] else {
    fail("expected a grid")
  }
  assert_eq((grid.width, grid.height), (2, 2))
}

///|
/// A binary tree that allows equal keys, each node with its own id.
#derive(ToJson)
enum Bag {
  Tip
  Node(left~ : Bag, key~ : Int32, id~ : Int32, right~ : Bag)
}

///|
fn bag_add(bag : Bag, key : Int32, id : Int32) -> Bag {
  match bag {
    Tip => Node(left=Tip, key~, id~, right=Tip)
    Node(left~, key=k, id=i, right~) =>
      if key <= k {
        Node(left=bag_add(left, key, id), key=k, id=i, right~)
      } else {
        Node(left~, key=k, id=i, right=bag_add(right, key, id))
      }
  }
}

///|
fn bag_size(bag : Bag) -> Int32 {
  match bag {
    Tip => 0
    Node(left~, right~, ..) => bag_size(left) + 1 + bag_size(right)
  }
}

///|
fn rb_insert(tree : Rb, key : Int32) -> Rb {
  match tree {
    E => N(Red, E, key, E)
    N(c, l, k, r) =>
      if key < k {
        N(c, rb_insert(l, key), k, r)
      } else if key > k {
        N(c, l, k, rb_insert(r, key))
      } else {
        tree
      }
  }
}

///|
fn rb_blacken(tree : Rb) -> Rb {
  match tree {
    N(_, l, k, r) => N(Black, l, k, r)
    E => E
  }
}

///|
test "a node id view keeps a recolored node the same node" {
  let ops = [
    @explore.Op::new("insert", rb_insert),
    @explore.Op::without_arg("blacken", rb_blacken),
  ]
  let steps = @explore.Step::parse("insert 5, insert 3, blacken")
  let by_label = @explore.replay(() => E, ops, steps)
  let by_key = @explore.replay(() => E, ops, steps, views=[NodeId("N#2")])
  // By label, recoloring replaces the root with a new node and moves its
  // child under it; by key, the root just changes color.
  inspect(
    by_label.explain(),
    content=(
      #|Initial state:
      #|  State: E
      #|Step 1: insert 5
      #|  + Red, 5 at root
      #|Step 2: insert 3
      #|  + Red, 3 at left of Red, 5
      #|Step 3: blacken
      #|  + Black, 5 at root
      #|  ~ Red, 3: left of Red, 5 -> left of Black, 5
      #|  - Red, 5
      #|All 3 steps passed. Final state:
      #|  State:
      #|    Black, 5
      #|      left: Red, 3
    ),
  )
  inspect(
    by_key.explain(),
    content=(
      #|Initial state:
      #|  State: E
      #|Step 1: insert 5
      #|  + Red, 5 at root
      #|Step 2: insert 3
      #|  + Red, 3 at left of Red, 5
      #|Step 3: blacken
      #|  ~ Red, 5 -> Black, 5
      #|All 3 steps passed. Final state:
      #|  State:
      #|    Black, 5
      #|      left: Red, 3
    ),
  )
  let marked = by_key.trace.steps[2].scene.highlights.map(h => {
    h.target.entity_id
  })
  assert_eq(marked, [Some("n:#5")])
}

///|
test "regression tests replay the found steps" {
  let source = @explore.replay(
    () => Tip,
    [@explore.Op::new("add", (bag : Bag, key : Int32) => bag_add(bag, key, 0))],
    @explore.Step::parse("add 1, add 2"),
    invariant=bag => if bag_size(bag) > 1 { Some("too big") } else { None },
  ).regression_test(init="() => Tip", ops="bag_ops()")
  inspect(
    source,
    content=(
      #|///|
      #|/// Found by FrontierLab: step 2 failed with "too big".
      #|test "add keeps working after the fix" {
      #|  let script =
      #|    #|add 1, add 2
      #|  let replay = @explore.replay(
      #|    () => Tip,
      #|    bag_ops(),
      #|    @explore.Step::parse(script),
      #|    invariant=invariant,
      #|  )
      #|  if replay.failure is Some(_) {
      #|    fail(replay.report())
      #|  }
      #|}
      #|
    ),
  )
  let passing = @explore.replay(
    () => Tip,
    [@explore.Op::new("add", (bag : Bag, key : Int32) => bag_add(bag, key, 0))],
    @explore.Step::parse("add 1"),
  )
  assert_true(
    passing
    .regression_test(name="one \"add\"", checks="")
    .contains("test \"one \\\"add\\\"\" {"),
  )
  assert_true(
    passing.regression_test().contains("test \"replayed steps keep passing\""),
  )
}

///|
fn bag_ops() -> Array[@explore.Op[Bag]] {
  [@explore.Op::new("add", (bag : Bag, key : Int32) => bag_add(bag, key, 0))]
}

///|
fn invariant(bag : Bag) -> String? {
  if bag_size(bag) > 2 {
    Some("too big")
  } else {
    None
  }
}

///|
/// The generated test above, pasted as is: it passes once the bag may hold
/// two keys.
test "add keeps working after the fix" {
  let script =
    #|add 1, add 2
  let replay = @explore.replay(
    () => Tip,
    bag_ops(),
    @explore.Step::parse(script),
    invariant~,
  )
  if replay.failure is Some(_) {
    fail(replay.report())
  }
}
