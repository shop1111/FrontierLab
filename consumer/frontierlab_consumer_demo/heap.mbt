///|
/// The user's code: an ordinary array-backed binary min-heap. Nothing here
/// knows about FrontierLab except `derive(ToJson)`.
#derive(ToJson)
struct Heap {
  items : Array[Int32]
}

///|
fn Heap::empty() -> Heap {
  { items: [], }
}

///|
fn push(heap : Heap, key : Int32) -> Heap {
  let items = heap.items.copy()
  items.push(key)
  let mut i = items.length() - 1
  while i > 0 {
    let parent = (i - 1) / 2
    if items[parent] <= items[i] {
      break
    }
    items.swap(parent, i)
    i = parent
  }
  { items, }
}

///|
/// Removes the smallest key. When `both_children` is false, sift-down only
/// looks at the left child, which is the bug this demo finds.
fn remove_min(heap : Heap, both_children~ : Bool) -> Heap {
  if heap.items.is_empty() {
    return heap
  }
  let items = heap.items.copy()
  let last = items.pop().unwrap()
  if items.is_empty() {
    return { items, }
  }
  items[0] = last
  let mut i = 0
  while true {
    let left = 2 * i + 1
    let right = left + 1
    let mut smallest = i
    if left < items.length() && items[left] < items[smallest] {
      smallest = left
    }
    if both_children && right < items.length() && items[right] < items[smallest] {
      smallest = right
    }
    if smallest == i {
      break
    }
    items.swap(i, smallest)
    i = smallest
  }
  { items, }
}

///|
/// Bug: forgets to compare the right child during sift-down.
fn pop(heap : Heap) -> Heap {
  remove_min(heap, both_children=false)
}

///|
fn pop_fixed(heap : Heap) -> Heap {
  remove_min(heap, both_children=true)
}

///|
/// The property to check after every operation: no parent is larger than
/// either of its children.
fn heap_violation(heap : Heap) -> String? {
  let items = heap.items
  for i in 1..<items.length() {
    let parent = (i - 1) / 2
    if items[parent] > items[i] {
      return Some(
        "parent \{items[parent]} at index \{parent} is larger than child \{items[i]} at index \{i}",
      )
    }
  }
  None
}

///|
fn heap_ops(pop : (Heap) -> Heap) -> Array[@explore.Op[Heap]] {
  [@explore.Op::new("push", push), @explore.Op::without_arg("pop", pop)]
}
