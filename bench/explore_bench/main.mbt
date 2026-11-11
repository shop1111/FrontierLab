///|
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
fn is_bst(t : Tree) -> String? {
  let keys : Array[Int32] = []
  fn walk(t : Tree) {
    match t {
      Leaf => ()
      Node(l, v, r) => {
        walk(l)
        keys.push(v)
        walk(r)
      }
    }
  }

  walk(t)
  for i in 1..<keys.length() {
    if keys[i - 1] >= keys[i] {
      return Some("not ordered")
    }
  }
  None
}

///|
/// Inserts `n` distinct keys in a scrambled order.
fn script(n : Int32) -> Array[@explore.Step] {
  Array::makei(n, i => @explore.Step::new("insert", arg=i * 7919 % n))
}

///|
/// Average milliseconds per call, repeated for at least 200 ms.
fn time_ms(f : () -> Unit raise) -> Double raise {
  let mut runs = 0
  let start = @env.now()
  while runs == 0 || @env.now() - start < 200UL {
    f()
    runs += 1
  }
  (@env.now() - start).to_double() / runs.to_double()
}

///|
fn main raise {
  let ops = [
    @explore.Op::new("insert", insert),
    @explore.Op::new("delete", delete),
  ]
  let buggy = [
    @explore.Op::new("insert", insert),
    @explore.Op::new("delete", buggy_delete),
  ]
  println("## replay: one snapshot of the whole tree after every insert")
  println(
    "| inserts | ops only ms | ops + invariant ms | replay ms | replay window=20 ms | html bytes | window html bytes |",
  )
  println("|---:|---:|---:|---:|---:|---:|---:|")
  for n in [50, 200, 1000] {
    let steps = script(n)
    let plain = time_ms(() => {
      let mut t = Leaf
      for step in steps {
        t = insert(t, step.arg.unwrap())
      }
    })
    let checked = time_ms(() => {
      let mut t = Leaf
      for step in steps {
        t = insert(t, step.arg.unwrap())
        ignore(is_bst(t))
      }
    })
    let options = @frontierlab.TraceOptions::new(max_steps=n + 1)
    let replayed = time_ms(() => {
      ignore(
        @explore.replay(() => Leaf, ops, steps, invariant=is_bst, options~),
      )
    })
    let html = @explore.replay(
      () => Leaf,
      ops,
      steps,
      invariant=is_bst,
      options~,
    ).to_html()
    let windowed = time_ms(() => {
      ignore(
        @explore.replay(
          () => Leaf,
          ops,
          steps,
          invariant=is_bst,
          window=20,
          options~,
        ),
      )
    })
    let window_html = @explore.replay(
      () => Leaf,
      ops,
      steps,
      invariant=is_bst,
      window=20,
      options~,
    ).to_html()
    println(
      "| \{n} | \{plain} | \{checked} | \{replayed} | \{windowed} | \{html.length()} | \{window_html.length()} |",
    )
  }
  println("")
  println("## explore: random search, shrinking, and the final replay")
  println("| case | sequences tried | smallest steps | ms |")
  println("|---|---:|---:|---:|")
  let mut found : @explore.Exploration? = None
  let buggy_ms = time_ms(() => {
    found = @explore.explore(() => Leaf, buggy, invariant=is_bst)
  })
  let found = found.unwrap()
  println(
    "| buggy delete | \{found.cases_tried} | \{found.replay.steps.length()} | \{buggy_ms} |",
  )
  let correct_ms = time_ms(() => {
    ignore(@explore.explore(() => Leaf, ops, invariant=is_bst))
  })
  println(
    "| correct delete (no failure, all 300 cases) | 300 | - | \{correct_ms} |",
  )
}
