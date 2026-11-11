///|
fn drain(heap : Heap, pop : (Heap) -> Heap) -> Array[Int32] {
  let out = []
  let mut h = heap
  while !h.items.is_empty() {
    out.push(h.items[0])
    h = pop(h)
  }
  out
}

///|
test "pop_fixed drains keys in ascending order" {
  let mut h = Heap::empty()
  for k in [5, 1, 4, 2, 3, 1] {
    h = push(h, k)
  }
  assert_eq(drain(h, pop_fixed), [1, 1, 2, 3, 4, 5])
}

///|
test "explore finds and shrinks the pop bug" {
  let found = @explore.explore(
    Heap::empty,
    heap_ops(pop),
    invariant=heap_violation,
  ).unwrap()
  assert_eq(found.seed, 1)
  assert_eq(
    found.replay.steps,
    @explore.Step::parse("push 0, push 1, push 0, push 1, pop"),
  )
  let failure = found.replay.failure.unwrap()
  assert_eq(failure.index, 4)
  assert_eq(failure.step, @explore.Step::new("pop"))
  assert_true(found.original.length() > found.replay.steps.length())
}

///|
test "replay locates the failing step of a hand-written input" {
  let replay = @explore.replay(
    Heap::empty,
    heap_ops(pop),
    @explore.Step::parse("push 1, push 5, push 2, push 6, push 7, pop"),
    invariant=heap_violation,
  )
  assert_false(replay.passed())
  assert_eq(
    replay.failure.unwrap().message,
    "parent 5 at index 0 is larger than child 2 at index 2",
  )
}

///|
test "the fixed pop passes the same search and replay" {
  assert_true(
    @explore.explore(Heap::empty, heap_ops(pop_fixed), invariant=heap_violation)
    is None,
  )
  let replay = @explore.replay(
    Heap::empty,
    heap_ops(pop_fixed),
    @explore.Step::parse("push 1, push 5, push 2, push 6, push 7, pop"),
    invariant=heap_violation,
  )
  assert_true(replay.passed())
}

///|
test "the replay page is a self-contained HTML document" {
  let replay = @explore.replay(
    Heap::empty,
    heap_ops(pop),
    @explore.Step::parse("push 1, push 5, push 2, push 6, push 7, pop"),
    invariant=heap_violation,
  )
  let html = replay.to_html()
  assert_true(
    html.has_prefix("<!DOCTYPE html>") || html.has_prefix("<!doctype html>"),
  )
  assert_false(html.contains("<script src="))
}
