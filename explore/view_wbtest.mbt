///|
fn drawn(value : Json, views : Array[View]) -> String raise {
  outline(snapshot(value, views).objects).join("\n")
}

///|
test "buckets accept options, entry arrays and constructor chains" {
  // `Array[(String, Int)?]`: open addressing.
  inspect(
    drawn([Json::null(), [["a", 1]], [5]], [Buckets("")]),
    content=(
      #|State:
      #|  0: -
      #|  1: a: 1
      #|  2: 5
    ),
  )
  // Chains of positional and labeled constructors, records as entries, and a
  // repeated entry.
  let chain : Json = ["Cons", "a", 1, ["Cons", "b", 2, "Nil"]]
  let labeled : Json = [
    "Link",
    { "key": "c", "value": 3, "next": ["Link", { "key": "d", "next": "End" }] },
  ]
  inspect(
    drawn(
      {
        "table": {
          "slots": [chain, labeled, [{ "k": 1, "v": 2 }], ["Cons", "x", "y", 3]],
        },
        "size": 4,
      },
      [Buckets("table.slots")],
    ),
    content=(
      #|table.slots:
      #|  0: a: 1, b: 2
      #|  1: key=c, value=3, key=d
      #|  2: k=1, v=2
      #|  3: x, y, 3
      #|fields: [size=4]
    ),
  )
  inspect(
    drawn([["a"], ["a"], "Nil", ["Wrap", "Nil"]], [Buckets("")]),
    content=(
      #|State:
      #|  0: a
      #|  1: a (2)
      #|  2: -
      #|  3: -
    ),
  )
  inspect(
    drawn({ "other": 1 }, [Buckets("missing")]),
    content=(
      #|missing:
      #|fields: [other=1]
    ),
  )
}

///|
test "graphs accept arrays, weight maps, pairs and records" {
  inspect(
    drawn([[1, 2], [2], Json::null()], [Graph("")]),
    content=(
      #|State:
      #|  0 -> 1, 2
      #|  1 -> 2
      #|  2 -> -
    ),
  )
  inspect(
    drawn(
      {
        "a": { "b": 5 },
        "b": [["c", 2], { "to": "a", "cost": 1 }, { "id": 3 }, "c"],
      },
      [Graph("")],
    ),
    content=(
      #|State:
      #|  a -> b (5)
      #|  b -> c (2), a (cost=1), {...}, c
      #|  c -> -
      #|  {...} -> -
    ),
  )
  let edges = snapshot({ "b": ["c", "c"] }, [Graph("")]).entities.map(e => e.id)
  assert_eq(edges, ["n:b", "n:c", "e:b->c", "e:b->c#2"])
  inspect(
    drawn(Json::null(), [Graph("")]),
    content=(
      #|State:
    ),
  )
}

///|
test "matrices accept string rows and empty matrices" {
  inspect(
    drawn({ "maze": ["#.", ".#", Json::null()] }, [Matrix("maze")]),
    content=(
      #|maze:
      #|  # .
      #|  . #
      #|  . .
    ),
  )
  let empty = snapshot({ "m": [] }, [Matrix("m")])
  guard empty.objects is [Grid(grid)] else { fail("expected a grid") }
  assert_eq((grid.width, grid.height, grid.cells.length()), (1, 1, 0))
}

///|
test "views name the part they cannot draw" {
  let problems = [
    (Json::number(1.0), Graph("")),
    ({ "a": 1 }, Graph("")),
    (Json::string("x"), Buckets("")),
    (Json::number(1.0), Matrix("")),
    ([1], Matrix("")),
  ].map(pair => {
    let (value, view) = pair
    try snapshot(value, [view]) catch {
      error => error.to_string()
    } noraise {
      _ => "drawn"
    }
  })
  inspect(
    problems.join("\n"),
    content=(
      #|Invalid graph: View Graph("") cannot draw 1
      #|Invalid graph: View Graph("") cannot draw 1
      #|Invalid trace step: View Buckets("") cannot draw "x"
      #|Invalid grid: View Matrix("") cannot draw 1
      #|Invalid grid: View Matrix("") cannot draw 1
    ),
  )
}

///|
test "view paths go through records and labeled constructors" {
  let value : Json = ["Wrapper", { "inner": { "grid": [[1]], "n": 2 } }]
  assert_eq(lookup(value, "inner.grid"), Some([[1]]))
  assert_eq(lookup(value, "inner.grid.x"), None)
  assert_eq(lookup(value, "inner.none"), None)
  assert_eq(without(value, ["inner", "grid"]), [
    "Wrapper",
    { "inner": { "n": 2 } },
  ])
  assert_eq(without(Json::number(1.0), ["a"]), Json::number(1.0))
  assert_eq(without({ "a": 1 }, ["b", "c"]), { "a": 1 })
}

///|
test "node id rules read fields and constructor positions" {
  let rules = ["key", "Node#2", "Node#", "Node#x", "#1"].map(id_rule)
  assert_eq(rules.map(r => (r.tag, r.field, r.position)), [
    ("", "key", -1),
    ("Node", "", 2),
    ("", "Node#", -1),
    ("", "Node#x", -1),
    ("", "", 1),
  ])
}

///|
test "change lines cover every kind of entity" {
  let before = snapshot(
    {
      "g": { "a": [["b", 1]], "x": [] },
      "t": [[["k", 1]]],
      "m": [[1, 2]],
      "list": [1, 2],
      "gone": [3],
    },
    [Graph("g"), Buckets("t"), Matrix("m")],
  )
  let after = snapshot(
    { "g": { "a": [["b", 2]] }, "t": [[], [["k", 1]]], "m": [[1]], "list": [1] },
    [Graph("g"), Buckets("t"), Matrix("m")],
  )
  inspect(
    change_lines(before, after, diff(before, after)).join("\n"),
    content=(
      #|t: 1 -> 2 buckets
      #|list: [1, 2] -> [1]
      #|- gone: [3]
      #|~ edge a -> b: 1 -> 2
      #|~ k: 1: bucket 0 -> bucket 1
      #|- node x
      #|- (1, 0)
    ),
  )
  inspect(
    change_lines(after, before, diff(after, before)).join("\n"),
    content=(
      #|t: 2 -> 1 buckets
      #|list: [1] -> [1, 2]
      #|+ gone: [3]
      #|+ node x
      #|~ edge a -> b: 2 -> 1
      #|~ k: 1: bucket 1 -> bucket 0
      #|+ (1, 0) = 2
    ),
  )
}

///|
test "outlines of forests, empty labels and moved tree nodes" {
  let before = snapshot(["Node", "", ["Leaf_", 1]], [])
  inspect(
    outline(before.objects).join("\n"),
    content=(
      #|State:
      #|  ""
      #|    0: 1
    ),
  )
  let after = snapshot(["Node", "", "Leaf"], [])
  inspect(
    change_lines(before, after, diff(before, after)).join("\n"),
    content=(
      #|- 1
    ),
  )
}

///|
test "node ids by field follow a node that moves and changes" {
  let node = fn(
    key : Int32,
    color : String,
    left : Json,
    right : Json,
  ) -> Json {
    { "key": key.to_double(), "color": color, "left": left, "right": right }
  }
  let views = [NodeId("key")]
  let before = snapshot(node(2, "red", node(1, "red", "E", "E"), "E"), views)
  let after = snapshot(node(1, "black", "E", node(2, "red", "E", "E")), views)
  inspect(
    change_lines(before, after, diff(before, after)).join("\n"),
    content=(
      #|~ key=1, color=red -> key=1, color=black: left of key=2, color=red -> root
      #|~ key=2, color=red: root -> right of key=1, color=black
    ),
  )
}

///|
test "weighted edges, plain buckets, missing matrices and wrapped states" {
  let before = snapshot({ "g": { "a": [] } }, [Graph("g")])
  let after = snapshot({ "g": { "a": [["b", 4]] } }, [Graph("g")])
  inspect(
    change_lines(before, after, diff(before, after)).join("\n"),
    content=(
      #|+ node b
      #|+ edge a -> b (4)
    ),
  )
  inspect(
    drawn([5, { "k": 1 }], [Buckets("")]),
    content=(
      #|State:
      #|  0: 5
      #|  1: k=1
    ),
  )
  inspect(
    drawn({ "m": Json::null() }, [Matrix("m"), Matrix("none")]),
    content=(
      #|m:
      #|  .
      #|none:
      #|  .
    ),
  )
  inspect(
    drawn(["Wrapper", { "inner": { "grid": [[1]] }, "n": 2 }], [
      Matrix("inner.grid"),
    ]),
    content=(
      #|inner.grid:
      #|  1
      #|State:
      #|  2
    ),
  )
}

///|
test "shrinking removes runs of any length" {
  // Fails while it has an even, non-zero number of `a`s, an even number of
  // `b`s, and a `y`. From `a a a a b b y`, removing three steps or one step
  // breaks a parity; only removing two does not, which halving the run length
  // (3, then 1) never tries.
  let count = fn(steps : Array[Step], op : String) {
    steps.filter(fn(step) { step.op == op }).length()
  }
  let fails = fn(steps : Array[Step]) {
    let a = count(steps, "a")
    a > 0 && a % 2 == 0 && count(steps, "b") % 2 == 0 && count(steps, "y") > 0
  }
  let steps = ["a", "a", "a", "a", "b", "b", "y"].map(fn(op) { Step::new(op) })
  let (smallest, rounds) = shrink(steps, fails, fn(_) { true }, 10)
  assert_eq(smallest.map(fn(step) { step.op }), ["a", "a", "y"])
  assert_eq(rounds, 1)
}
