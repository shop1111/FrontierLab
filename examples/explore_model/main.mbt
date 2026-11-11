///|
/// The user's code: a persistent binary search tree of strings used as a set.
/// Nothing here knows about FrontierLab except `derive(ToJson)`.
#derive(ToJson)
enum Set {
  Empty
  Node(Set, String, Set)
}

///|
fn add(s : Set, word : String) -> Set {
  match s {
    Empty => Node(Empty, word, Empty)
    Node(l, w, r) =>
      if word < w {
        Node(add(l, word), w, r)
      } else if word > w {
        Node(l, w, add(r, word))
      } else {
        s
      }
  }
}

///|
/// Bug: for a larger word it searches the left subtree again. Every tree is
/// still ordered, so no invariant notices; only the answers are wrong.
fn contains(s : Set, word : String) -> Bool {
  match s {
    Empty => false
    Node(l, w, _) =>
      if word < w {
        contains(l, word)
      } else if word > w {
        contains(l, word) // should be the right subtree
      } else {
        true
      }
  }
}

///|
/// Words drawn from a small vocabulary, so that the same word comes back.
fn words() -> @quickcheck.Generator[String] {
  @quickcheck.elements(["apple", "fig", "kiwi", "lime", "pear"])
}

///|
/// The reference: an unsorted array, too simple to get wrong.
fn model() -> @explore.Model raise @frontierlab.TraceError {
  @explore.Model::new(() => ([] : Array[String]), [
    @explore.Op::with_gen("add", words(), (list, word) => {
      if !list.contains(word) {
        list.push(word)
      }
      list
    }),
    @explore.Op::returning_with_gen("contains", words(), (list, word) => {
      (list, list.contains(word))
    }),
  ])
}

///|
/// Usage: `moon run examples/explore_model -- [smallest.html]`
fn main raise {
  let ops = [
    @explore.Op::with_gen("add", words(), add),
    @explore.Op::returning_with_gen("contains", words(), (s, word) => {
      (s, contains(s, word))
    }),
  ]
  match @explore.explore(() => Empty, ops, model=model()) {
    Some(found) => {
      println(found.report())
      let args = @env.args()
      if args.length() > 1 {
        found.save_html(args[1])
      }
    }
    None => println("No failing sequence found.")
  }
}
