///|
/// A binary search tree whose `contains` looks in the wrong subtree for
/// larger keys. Every state is still a valid search tree, so only a model
/// can find this bug.
fn wrong_contains(t : Tree, k : Int32) -> Bool {
  match t {
    Leaf => false
    Node(l, v, r) =>
      if k < v {
        wrong_contains(l, k)
      } else if k > v {
        ignore(r)
        wrong_contains(l, k)
      } else {
        true
      }
  }
}

///|
/// The model: an unsorted array without duplicates.
fn set_model() -> @explore.Model raise @frontierlab.TraceError {
  @explore.Model::new(() => ([] : Array[Int32]), [
    @explore.Op::new("insert", (keys, k) => {
      if !keys.contains(k) {
        keys.push(k)
      }
      keys
    }),
    @explore.Op::returning("contains", (keys, k) => (keys, keys.contains(k))),
  ])
}

///|
test "a model finds a wrong result that no invariant sees" {
  let ops = [
    @explore.Op::new("insert", insert),
    @explore.Op::returning("contains", (t, k) => (t, wrong_contains(t, k))),
  ]
  assert_true(@explore.explore(() => Leaf, ops, invariant=is_bst) is None)
  let found = @explore.explore(() => Leaf, ops, model=set_model())
  guard found is Some(found) else { fail("expected a failing sequence") }
  let replay = found.replay
  assert_eq(
    replay.steps,
    @explore.Step::parse("insert 0, insert 1, contains 1"),
  )
  guard replay.failure is Some(failure) else { fail("expected a failure") }
  assert_eq(failure.message, "returned false, but the model returned true")
  assert_eq(replay.outputs, [None, None, Some("false")])
  replay.trace.validate()
}

///|
test "results are shown in the replay" {
  let ops = [
    @explore.Op::new("insert", insert),
    @explore.Op::returning("contains", (t, k) => (t, wrong_contains(t, k))),
  ]
  let replay = @explore.replay(
    () => Leaf,
    ops,
    @explore.Step::parse("insert 5, contains 5, contains 7"),
  )
  assert_true(replay.passed())
  assert_eq(replay.outputs, [None, Some("true"), Some("false")])
  let note = replay.trace.steps[1].annotation.unwrap()
  assert_true(note.body.contains("Returned: true."))
  guard replay.trace.steps[1].event is Custom("contains", attributes) else {
    fail("expected a custom event")
  }
  assert_true(
    attributes.iter().any(fn(a) { a.key == "result" && a.value == "true" }),
  )
}

///|
/// A stack whose `pop` returns the removed value.
fn stack_ops(pop_empty_ok : Bool) -> Array[@explore.Op[Array[Int32]]] {
  [
    @explore.Op::new("push", (s, x) => {
      s.push(x)
      s
    }),
    @explore.Op::returning_without_arg("pop", s => {
      match s.pop() {
        Some(x) => (s, x)
        None => if pop_empty_ok { (s, -1) } else { fail("empty stack") }
      }
    }),
  ]
}

///|
test "raising is fine when the model raises too" {
  let model = @explore.Model::new(() => [], stack_ops(false))
  let both = @explore.replay(
    () => [],
    stack_ops(false),
    @explore.Step::parse("pop, push 1, pop"),
    model~,
  )
  assert_true(both.passed())
  assert_true(both.outputs[0] is Some(text) && text.has_prefix("raised"))
  assert_eq(both.outputs[2], Some("1"))
  // The structure under test returns -1 where the model raises.
  let lenient = @explore.replay(
    () => [],
    stack_ops(true),
    @explore.Step::parse("pop"),
    model~,
  )
  guard lenient.failure is Some(failure) else { fail("expected a failure") }
  assert_true(failure.message.has_prefix("returned -1, but the model raised"))
  // The structure under test raises where the model returns.
  let strict = @explore.replay(
    () => [],
    stack_ops(false),
    @explore.Step::parse("pop"),
    model=@explore.Model::new(() => [], stack_ops(true)),
  )
  guard strict.failure is Some(failure) else { fail("expected a failure") }
  assert_true(failure.message.contains("but the model returned -1"))
}

///|
/// An association list whose `put` appends instead of replacing, so `get`
/// keeps returning the first value.
fn alist_ops() -> Array[@explore.Op[Array[(String, Int32)]]] {
  let entry = @quickcheck.elements(["a", "b", "c"]).flat_map(key => {
    @quickcheck.int_range(0, 3).map(value => (key, value))
  })
  [
    @explore.Op::with_gen("put", entry, (list, pair) => {
      list.push(pair)
      list
    }),
    @explore.Op::returning_with_gen(
      "get",
      @quickcheck.elements(["a", "b", "c"]),
      (list, key) => {
        for pair in list {
          if pair.0 == key {
            return (list, Some(pair.1))
          }
        }
        (list, None)
      },
    ),
  ]
}

///|
fn map_model() -> @explore.Model raise @frontierlab.TraceError {
  let entry = @quickcheck.elements(["a"]).map(key => (key, 0))
  @explore.Model::new(() => ({} : Map[String, Int32]), [
    @explore.Op::with_gen("put", entry, (map, pair) => {
      map[pair.0] = pair.1
      map
    }),
    @explore.Op::returning_with_gen("get", @quickcheck.elements(["a"]), (
      map,
      key,
    ) => (map, map.get(key))),
  ])
}

///|
test "arguments of any type are generated, shown, and shrunk" {
  let found = @explore.explore(() => [], alist_ops(), model=map_model())
  guard found is Some(found) else { fail("expected a failing sequence") }
  let steps = found.replay.steps
  assert_eq(steps.length(), 3)
  assert_eq(steps[0].op, "put")
  assert_eq(steps[1].op, "put")
  assert_eq(steps[2].op, "get")
  // Keys and values shrink as far as the bug allows.
  assert_eq(steps[0].to_string(), "put [\"a\",0]")
  assert_eq(steps[1].to_string(), "put [\"a\",1]")
  assert_eq(steps[2].to_string(), "get \"a\"")
  guard found.replay.failure is Some(failure) else {
    fail("expected a failure")
  }
  assert_eq(failure.message, "returned Some(0), but the model returned Some(1)")
  // The shrunk sequence replays from its script.
  let script = steps.map(fn(step) { step.to_string() }).join(", ")
  let again = @explore.replay(
    () => [],
    alist_ops(),
    @explore.Step::parse(script),
    model=map_model(),
  )
  assert_eq(again.failure, found.replay.failure)
}

///|
test "scripts take JSON arguments" {
  assert_eq(
    @explore.Step::parse(
      "put [\"a, b\", 1]; get \"x;y\"\nclear, put {\"k\": [1, 2]}",
    ),
    [
      @explore.Step::with_arg("put", ("a, b", 1)),
      @explore.Step::with_arg("get", "x;y"),
      @explore.Step::new("clear"),
      @explore.Step::with_arg("put", { "k": [1, 2] }),
    ],
  )
  assert_eq(@explore.Step::with_arg("get", "a").to_string(), "get \"a\"")
  assert_eq(@explore.Step::new("insert", arg=-3).int_arg(), Some(-3))
  assert_eq(@explore.Step::with_arg("get", "a").int_arg(), None)
  let bare = error_of(() => ignore(@explore.Step::parse("get abc")))
  assert_true(
    bare is Some(InvalidStep(message)) && message.contains("double quotes"),
  )
}

///|
test "arguments and models are validated before running" {
  let ops = [
    @explore.Op::new("insert", insert),
    @explore.Op::returning("contains", (t, k) => (t, wrong_contains(t, k))),
  ]
  for
    script in ["insert \"x\"", "insert 1.5", "contains", "insert 1, insert 2 3"] {
    let problem = error_of(() => {
      ignore(@explore.replay(() => Leaf, ops, @explore.Step::parse(script)))
    })
    assert_true(problem is Some(InvalidStep(_)))
  }
  let extra = error_of(() => {
    ignore(
      @explore.replay(() => [], stack_ops(false), @explore.Step::parse("pop 1")),
    )
  })
  assert_true(
    extra is Some(InvalidStep(message)) && message.contains("takes no argument"),
  )
  let missing = error_of(() => {
    let model = @explore.Model::new(() => [], [
      @explore.Op::new("insert", (keys : Array[Int32], k) => {
        keys.push(k)
        keys
      }),
    ])
    ignore(@explore.explore(() => Leaf, ops, model~))
  })
  assert_true(
    missing is Some(InvalidStep(message)) &&
    message.contains("no operation 'contains'"),
  )
  let no_result = error_of(() => {
    let model = @explore.Model::new(() => [], [
      @explore.Op::new("insert", (keys : Array[Int32], _) => keys),
      @explore.Op::new("contains", (keys : Array[Int32], _) => keys),
    ])
    ignore(@explore.explore(() => Leaf, ops, model~))
  })
  assert_true(
    no_result is Some(InvalidStep(message)) &&
    message.contains("returning a result"),
  )
  let no_arg = error_of(() => {
    let model = @explore.Model::new(() => [], [
      @explore.Op::without_arg("insert", (keys : Array[Int32]) => keys),
      @explore.Op::returning("contains", (keys : Array[Int32], _) => {
        (keys, false)
      }),
    ])
    ignore(@explore.explore(() => Leaf, ops, model~))
  })
  assert_true(
    no_arg is Some(InvalidStep(message)) &&
    message.contains("taking an argument"),
  )
}

///|
test "scripts keep escaped quotes inside strings" {
  assert_eq(@explore.Step::parse("add \"a\\\"b, c\", add \"d\""), [
    @explore.Step::with_arg("add", "a\"b, c"),
    @explore.Step::with_arg("add", "d"),
  ])
}

///|
test "the model must read every argument and may disagree on raising" {
  let ops = [@explore.Op::new("insert", insert)]
  let words = @explore.Model::new(() => [], [
    @explore.Op::with_gen("insert", @quickcheck.elements(["a"]), (
      list : Array[String],
      word,
    ) => {
      list.push(word)
      list
    }),
  ])
  let unreadable = error_of(() => {
    ignore(
      @explore.replay(
        () => Leaf,
        ops,
        @explore.Step::parse("insert 1"),
        model=words,
      ),
    )
  })
  assert_true(
    unreadable is Some(InvalidStep(message)) &&
    message.contains("the model cannot read"),
  )
  let full = @explore.Model::new(() => 0, [
    @explore.Op::new("insert", (_, _) => fail("full")),
  ])
  let replay = @explore.replay(
    () => Leaf,
    ops,
    @explore.Step::parse("insert 1"),
    model=full,
  )
  guard replay.failure is Some(failure) else { fail("expected a failure") }
  assert_true(
    failure.message.has_prefix("returned normally, but the model raised"),
  )
}

///|
#derive(ToJson, FromJson)
struct Entry {
  on : Bool
  name : String
  note : String
  weight : Double
}

///|
test "decimals, booleans, strings, and record fields shrink" {
  // Fails for an enabled entry with a long name and a heavy weight.
  let entries = @quickcheck.Generator((_, rs) => {
    let pick = rs.next_uint(limit=4).reinterpret_as_int()
    (
      {
        on: pick != 0,
        name: ["abcd", "xy", "q", "lmnop"][pick],
        note: if pick % 2 == 0 {
          ""
        } else {
          "x"
        },
        weight: 1.25 + rs.next_double() * 6.0,
      } : Entry)
  })
  let ops = [
    @explore.Op::with_gen("add", entries, (count : Int32, entry : Entry) => {
      if entry.on && entry.name.length() >= 2 && entry.weight >= 1.5 {
        fail("rejected \{entry.name}")
      }
      count + 1
    }),
  ]
  let found = @explore.explore(() => 0, ops, check=(_, _) => None)
  guard found is Some(found) else { fail("expected a failing sequence") }
  guard found.replay.steps is [{ op: "add", arg: Some(arg), }] else {
    fail("expected one add")
  }
  let entry : Entry = @json.from_json(arg)
  assert_true(entry.on)
  assert_eq(entry.name.length(), 2)
  assert_eq(entry.note, "")
  // 1.5 is not a whole number, so the weight lands on the smallest whole
  // number that still fails.
  assert_eq(entry.weight, 2.0)
}

///|
test "generated arguments the model cannot read are skipped" {
  let wrong = error_of(() => {
    ignore(
      @explore.replay(() => [], alist_ops(), @explore.Step::parse("put 5")),
    )
  })
  assert_true(
    wrong is Some(InvalidStep(message)) && message.contains("does not fit"),
  )
  // The model reads strings, but the structure under test draws integers.
  let model = @explore.Model::new(() => 0, [
    @explore.Op::with_gen("add", @quickcheck.elements(["a"]), (n, _ : String) => {
      n + 1
    }),
  ])
  let ops = [
    @explore.Op::with_gen("add", @quickcheck.int_range(0, 5), (
      n : Int32,
      _ : Int32,
    ) => n + 1),
  ]
  assert_true(@explore.explore(() => 0, ops, model~) is None)
}

///|
test "a false argument cannot shrink further" {
  let ops = [
    @explore.Op::with_gen("flag", @quickcheck.elements([false]), (
      n : Int32,
      on : Bool,
    ) => if on { n } else { fail("off") }),
  ]
  let found = @explore.explore(() => 0, ops, check=(_, _) => None)
  guard found is Some(found) else { fail("expected a failing sequence") }
  assert_eq(found.replay.steps, [@explore.Step::with_arg("flag", false)])
}
