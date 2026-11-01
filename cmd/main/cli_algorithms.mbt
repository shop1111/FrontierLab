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
fn selection_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for i in 0..<(a.length() - 1) {
    let mut smallest = i
    for j in (i + 1)..<a.length() {
      if a.less(j, smallest) {
        smallest = j
      }
    }
    if smallest != i {
      a.swap(i, smallest)
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
/// Lomuto quicksort with the last element as pivot, so sorted input shows the
/// quadratic worst case. It recurses into the smaller part to bound the stack.
/// With `skip_last`, partitioning never looks at the element before the pivot.
fn lomuto_quick_sort(
  a : @frontierlab.TracedArray[Int32],
  skip_last~ : Bool,
) -> Unit {
  fn sort(lo : Int32, hi : Int32) -> Unit {
    let mut lo = lo
    let mut hi = hi
    while lo < hi {
      let mut store = lo
      for j in lo..<(if skip_last { hi - 1 } else { hi }) {
        if a.less(j, hi) {
          if j != store {
            a.swap(j, store)
          }
          store += 1
        }
      }
      if store != hi {
        a.swap(store, hi)
      }
      if store - lo < hi - store {
        sort(lo, store - 1)
        lo = store + 1
      } else {
        sort(store + 1, hi)
        hi = store - 1
      }
    }
  }

  sort(0, a.length() - 1)
}

///|
fn quick_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  lomuto_quick_sort(a, skip_last=false)
}

///|
fn faulty_quick_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  lomuto_quick_sort(a, skip_last=true)
}

///|
/// Insertion sort whose inner loop stops before position 0.
fn faulty_insertion_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for i in 1..<a.length() {
    let mut j = i
    while j > 1 && a.less(j, j - 1) {
      a.swap(j, j - 1)
      j -= 1
    }
  }
}

///|
/// Insertion sort that shifts values with indexed writes. With `lossy`, the
/// key is not written back when it belongs at position 0.
fn shifting_insertion_sort(
  a : @frontierlab.TracedArray[Int32],
  lossy~ : Bool,
) -> Unit {
  for i in 1..<a.length() {
    let key = a[i]
    let mut j = i
    while j > 0 && a[j - 1] > key {
      a[j] = a[j - 1]
      j -= 1
    }
    if j != i && (j > 0 || !lossy) {
      a[j] = key
    }
  }
}

///|
/// Built-in sorts written against `TracedArray`; the `faulty-` and `lossy-`
/// variants contain deliberate bugs for `search`.
fn sort_algorithm(
  name : String,
) -> ((@frontierlab.TracedArray[Int32]) -> Unit) raise {
  match name {
    "bubble-sort" => bubble_sort
    "insertion-sort" => insertion_sort
    "selection-sort" => selection_sort
    "heap-sort" => heap_sort
    "quick-sort" => quick_sort
    "shift-insertion-sort" => fn(a) { shifting_insertion_sort(a, lossy=false) }
    "faulty-insertion-sort" => faulty_insertion_sort
    "lossy-insertion-sort" => fn(a) { shifting_insertion_sort(a, lossy=true) }
    "faulty-quick-sort" => faulty_quick_sort
    other => fail("Unknown algorithm: \{other}")
  }
}
