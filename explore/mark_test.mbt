///|
/// Insertion into a sorted array, one swap at a time, marking each swap.
fn sorted_insert(xs : Array[Int32], x : Int32) -> Array[Int32] {
  xs.push(x)
  let mut i = xs.length() - 1
  while i > 0 && xs[i - 1] > xs[i] {
    xs.swap(i - 1, i)
    @explore.mark(xs, note="swapped")
    i -= 1
  }
  xs
}

///|
fn sorted_ops() -> Array[@explore.Op[Array[Int32]]] {
  [
    @explore.Op::new("insert", sorted_insert),
    @explore.Op::without_arg("fail", (xs : Array[Int32]) => {
      @explore.mark(xs.length())
      raise Failure("gave up")
    }),
  ]
}

///|
test "marks show the states inside an operation" {
  let replay = @explore.replay(
    () => [],
    sorted_ops(),
    @explore.Step::parse("insert 3, insert 5, insert 1, fail"),
    // Node identity applies to marks of any part.
    views=[NodeId("key")],
  )
  inspect(
    replay.explain(),
    content=(
      #|Initial state:
      #|  State: []
      #|Step 1: insert 3
      #|  State: [] -> [3]
      #|Step 2: insert 5
      #|  State: [3] -> [3, 5]
      #|Step 3: insert 1
      #|  at explore/mark_test.mbt:8 (swapped):
      #|    State: [3, 1, 5]
      #|  at explore/mark_test.mbt:8 (swapped):
      #|    State: [3, 1, 5] -> [1, 3, 5]
      #|  State: [3, 5] -> [1, 3, 5]
      #|Step 4: fail
      #|  at explore/mark_test.mbt:19:
      #|    State: 3
      #|  (no change)
      #|  FAILED: raised Failure(gave up)
      #|State after the failing step:
      #|  State: [1, 3, 5]
    ),
  )
  // Every mark is a step of its own in the player, before the step it is in.
  let titles = replay.trace.steps.map(step => step.annotation.unwrap().title)
  assert_eq(titles[2:5].to_owned(), [
    "Step 3: insert 1 at explore/mark_test.mbt:8", "Step 3: insert 1 at explore/mark_test.mbt:8",
    "Step 3: insert 1",
  ])
}

///|
test "marks are recorded only for the operation under test" {
  // Outside a replay a mark does nothing.
  @explore.mark([1, 2])
  let model = @explore.Model::new(() => ([] : Array[Int32]), [
    @explore.Op::new("insert", (xs : Array[Int32], x : Int32) => {
      @explore.mark(xs, note="model")
      xs.push(x)
      xs.sort()
      xs
    }),
    @explore.Op::without_arg("fail", (xs : Array[Int32]) => {
      raise Failure("gave up \{xs.length()}")
    }),
  ])
  let replay = @explore.replay(
    () => [],
    sorted_ops(),
    @explore.Step::parse("insert 2, insert 1"),
    model~,
  )
  assert_false(replay.explain().contains("(model)"))
  assert_eq(replay.trace.steps.length(), 4)
  // `explore` searches without recording, and replays the result with marks.
  let found = @explore.explore(
    () => [],
    [@explore.Op::new("insert", sorted_insert)],
    // Fails whenever the new key had to move, so the shrunk sequence swaps.
    check=(xs, step) => {
      if xs.last() != step.int_arg() {
        Some("the new key moved")
      } else {
        None
      }
    },
  )
  guard found is Some(found) else { fail("expected a failure") }
  inspect(
    found.replay.report(),
    content=(
      #|Step 2 of 2 (insert 0) failed: the new key moved
      #|Steps: insert 1, insert 0
    ),
  )
  assert_true(found.explain().contains("at explore/mark_test.mbt:8 (swapped):"))
  assert_true(
    found.regression_test(checks="").contains("@explore.Step::parse(script),"),
  )
}

///|
test "a step keeps at most 200 marks" {
  let ops = [
    @explore.Op::new("spin", (n : Int32, times : Int32) => {
      for i in 0..<times {
        @explore.mark(i)
      }
      n
    }),
  ]
  let replay = @explore.replay(() => 0, ops, @explore.Step::parse("spin 205"))
  assert_true(replay.explain().contains("(5 more marks were not recorded)"))
  assert_eq(replay.trace.steps.length(), 202)
}

///|
#derive(ToJson)
struct Grid2 {
  cells : Array[Array[Int32]]
}

///|
test "marks of a part skip views that do not fit" {
  let ops = [
    @explore.Op::without_arg("touch", (g : Grid2) => {
      @explore.mark(g.cells[0], note="first row")
      @explore.mark(g, note="whole")
      g.cells[0][0] = 1
      @explore.mark(g, note="after")
      g
    }),
    @explore.Op::without_arg("odd", (g : Grid2) => {
      // The view finds `cells` but cannot draw it, so this mark is drawn
      // without views.
      @explore.mark(({ "cells": 5 } : Json))
      g
    }),
  ]
  let replay = @explore.replay(
    () => { cells: [[0, 0]], },
    ops,
    @explore.Step::parse("touch, odd"),
    views=[Matrix("cells")],
  )
  inspect(
    replay.explain(),
    content=(
      #|Initial state:
      #|  cells:
      #|    0 0
      #|Step 1: touch
      #|  at explore/mark_test.mbt:141 (first row):
      #|    State: [0, 0]
      #|  at explore/mark_test.mbt:142 (whole):
      #|    - State: [0, 0]
      #|    + (0, 0) = 0
      #|    + (1, 0) = 0
      #|  at explore/mark_test.mbt:144 (after):
      #|    ~ (0, 0): 0 -> 1
      #|  ~ (0, 0): 0 -> 1
      #|Step 2: odd
      #|  at explore/mark_test.mbt:150:
      #|    fields: [cells=5]
      #|  (no change)
      #|All 2 steps passed. Final state:
      #|  cells:
      #|    1 0
    ),
  )
}

///|
#derive(ToJson)
struct Chained {
  mut slots : Array[Array[Int32]]
}

///|
test "inserted marks name the line and draw a part with its view" {
  // What `frontierlab-instrument --fn widen --watch wider` produces, after
  // `moon fmt` moved each mark onto its own line.
  let widen = (t : Chained) => {
    let wider : Array[Array[Int32]] = [[], [], [], []]
    @explore.auto_mark(wider, 200, "for i, slot in t.slots {")
    for i, slot in t.slots {
      @explore.auto_mark(wider, 202, "wider[i] = slot")
      wider[i] = slot
    }
    @explore.auto_mark(wider, 205, "t.slots = wider")
    t.slots = wider
    t
  }
  let replay = @explore.replay(
    () => { slots: [[1], [2]], },
    [@explore.Op::without_arg("widen", widen)],
    @explore.Step::parse("widen"),
    views=[Buckets("slots")],
  )
  inspect(
    replay.explain(),
    content=(
      #|Initial state:
      #|  slots:
      #|    0: 1
      #|    1: 2
      #|Step 1: widen
      #|  at explore/mark_test.mbt:200 (before: for i, slot in t.slots {):
      #|    State:
      #|      0: -
      #|      1: -
      #|      2: -
      #|      3: -
      #|  at explore/mark_test.mbt:202 (before: wider[i] = slot):
      #|    (no change)
      #|  at explore/mark_test.mbt:202 (before: wider[i] = slot):
      #|    + 1 in bucket 0
      #|  at explore/mark_test.mbt:205 (before: t.slots = wider):
      #|    + 2 in bucket 1
      #|  slots: 2 -> 4 buckets
      #|All 1 steps passed. Final state:
      #|  slots:
      #|    0: 1
      #|    1: 2
      #|    2: -
      #|    3: -
    ),
  )
  // Outside a replay an inserted mark does nothing.
  @explore.auto_mark(1, 1, "x")
}
