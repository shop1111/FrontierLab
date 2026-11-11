///|
/// The user's code: an ordinary persistent binary search tree. Nothing here
/// knows about FrontierLab except `derive(ToJson)`.
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
/// Bug: when the node has two children, the successor is removed from the
/// left subtree instead of the right one, so the successor stays duplicated.
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
            Node(delete(l, m), m, r) // should be Node(l, m, delete(r, m))
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
/// The property to check after every operation.
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
/// Usage: `moon run examples/explore_bst -- [smallest.html] [script.html]`
fn main raise {
  let ops = [
    @explore.Op::new("insert", insert),
    @explore.Op::new("delete", delete),
  ]
  let args = @env.args()

  // 1. Let FrontierLab search for the smallest failing sequence.
  match @explore.explore(() => Leaf, ops, invariant=is_bst) {
    Some(found) => {
      println(found.report())
      if args.length() > 1 {
        found.save_html(args[1])
      }
    }
    None => println("No failing sequence found.")
  }

  // 2. Replay an input you wrote yourself.
  let replay = @explore.replay(
    () => Leaf,
    ops,
    @explore.Step::parse(
      "insert 50, insert 30, insert 70, insert 20, insert 40, delete 30",
    ),
    invariant=is_bst,
    title="My own input",
  )
  println(replay.report())
  if args.length() > 2 {
    replay.save_html(args[2])
  }
}
