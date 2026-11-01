///|
fn bubble_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for end = a.length() - 1; end > 0; end = end - 1 {
    for i in 0..<end {
      if a.less(i + 1, i) {
        a.swap(i, i + 1)
      }
    }
  }
}

///|
fn insertion_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for i in 1..<a.length() {
    let mut j = i
    while j > 0 && a.less(j, j - 1) {
      a.swap(j, j - 1)
      j -= 1
    }
  }
}

///|
fn sift_down(
  a : @frontierlab.TracedArray[Int32],
  start : Int32,
  end : Int32,
) -> Unit {
  let mut root = start
  while 2 * root + 1 < end {
    let mut child = 2 * root + 1
    if child + 1 < end && a.less(child, child + 1) {
      child += 1
    }
    if !a.less(root, child) {
      return
    }
    a.swap(root, child)
    root = child
  }
}

///|
fn heap_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  let n = a.length()
  for start = n / 2 - 1; start >= 0; start = start - 1 {
    sift_down(a, start, n)
  }
  for end = n - 1; end > 0; end = end - 1 {
    a.swap(0, end)
    sift_down(a, 0, end)
  }
}

///|
/// A deterministic permutation of 0..<n for sizes coprime with 7919.
fn scrambled(n : Int32) -> Array[Int32] {
  Array::makei(n, fn(i) { i * 7919 % n })
}

///|
fn main raise {
  let sizes = [128, 256, 512, 1024, 2048]
  for
    entry in [
      ("Bubble sort", bubble_sort),
      ("Insertion sort", insertion_sort),
      ("Heap sort", heap_sort),
    ] {
    let profile = @frontierlab.profile_traced_array(
      sizes,
      scrambled,
      entry.1,
      metric=Compares,
    )
    println("# \{entry.0}\n")
    println(profile.report())
  }
  let overhead = @frontierlab.measure_tracing_overhead(
    scrambled(64),
    insertion_sort,
    clock=@env.now,
  )
  println("# Insertion sort, n = 64\n")
  println(overhead.report())
}
