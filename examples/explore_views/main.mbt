///|
/// The user's code: a hash map with separate chaining. Nothing here knows
/// about FrontierLab except `derive(ToJson)` and one `@explore.mark` call.
#derive(ToJson)
struct HashMap {
  mut buckets : Array[Array[(String, Int32)]]
  mut size : Int32
}

///|
fn HashMap::new() -> HashMap {
  { buckets: [[], []], size: 0, }
}

///|
fn index(key : String, count : Int32) -> Int32 {
  let mut h = 0
  for c in key {
    h = h * 31 + c.to_int()
  }
  (h & 0x7fffffff) % count
}

///|
/// Bug: copies every bucket to the same index of the wider table instead of
/// rehashing, so some keys end up where `get` never looks.
fn HashMap::grow(self : HashMap) -> Unit {
  let wider : Array[Array[(String, Int32)]] = Array::makei(
    self.buckets.length() * 2,
    _ => [],
  )
  for i, bucket in self.buckets {
    for entry in bucket {
      wider[i].push(entry) // should be wider[index(entry.0, wider.length())]
    }
  }
  self.buckets = wider
  @explore.mark(self, note="after grow")
}

///|
fn HashMap::put(self : HashMap, key : String, value : Int32) -> HashMap {
  let bucket = self.buckets[index(key, self.buckets.length())]
  match bucket.search_by(entry => entry.0 == key) {
    Some(i) => bucket[i] = (key, value)
    None => {
      bucket.push((key, value))
      self.size += 1
      if self.size > self.buckets.length() {
        self.grow()
      }
    }
  }
  self
}

///|
fn HashMap::get(self : HashMap, key : String) -> Int32? {
  let bucket = self.buckets[index(key, self.buckets.length())]
  bucket.search_by(entry => entry.0 == key).map(i => bucket[i].1)
}

///|
fn keys() -> @quickcheck.Generator[String] {
  @quickcheck.elements(["ant", "bee", "cat", "dog", "eel", "fox"])
}

///|
fn entries() -> @quickcheck.Generator[(String, Int32)] {
  keys().flat_map(key => @quickcheck.int_range(0, 9).map(value => (key, value)))
}

///|
fn ops() -> Array[@explore.Op[HashMap]] {
  [
    @explore.Op::with_gen("put", entries(), (map, entry) => {
      map.put(entry.0, entry.1)
    }),
    @explore.Op::returning_with_gen("get", keys(), (map, key) => {
      (map, map.get(key))
    }),
  ]
}

///|
/// The reference: an association list.
fn model() -> @explore.Model raise @frontierlab.TraceError {
  @explore.Model::new(() => ([] : Array[(String, Int32)]), [
    @explore.Op::with_gen("put", entries(), (list, entry) => {
      match list.search_by(pair => pair.0 == entry.0) {
        Some(i) => list[i] = entry
        None => list.push(entry)
      }
      list
    }),
    @explore.Op::returning_with_gen("get", keys(), (list, key) => {
      (list, list.search_by(pair => pair.0 == key).map(i => list[i].1))
    }),
  ])
}

///|
/// Usage: `moon run examples/explore_views -- [smallest.html]`
fn main raise {
  let found = @explore.explore(HashMap::new, ops(), model=model(), views=[
    Buckets("buckets"),
  ])
  guard found is Some(found) else {
    println("No failing sequence found.")
    return
  }
  println(found.explain())
  println("")
  println(
    found.regression_test(
      name="get finds every key after a grow",
      init="HashMap::new",
      ops="ops()",
      checks="model=model()",
    ),
  )
  let args = @env.args()
  if args.length() > 1 {
    found.save_html(args[1])
  }
}
