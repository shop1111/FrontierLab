///|
/// Build an intentionally faulty trace for debugger and contract demos.
fn faulty_insertion_sort_demo_trace() -> @frontierlab.AlgorithmTrace raise {
  let sequence = fn(ids : Array[(String, String)]) -> @frontierlab.Scene raise {
    @frontierlab.Scene::new(objects=[
      @frontierlab.Sequence(
        @frontierlab.SequenceState::new(
          id="values",
          label="Faulty insertion sort",
          items=ids.map(fn(item) {
            @frontierlab.SequenceItem::new(id=item.0, value=item.1)
          }),
        ),
      ),
    ])
  }
  let builder = @frontierlab.TraceBuilder::new(
    title="Faulty AI-generated insertion sort",
    algorithm="faulty-insertion-sort",
    description="Compare illegally mutates order; contracts must stop at step 0.",
    initial_scene=sequence([("a", "2"), ("b", "1"), ("c", "3")]),
  )
  builder.record(
    event=@frontierlab.Compare([
      @frontierlab.TargetRef::entity("values", "a"),
      @frontierlab.TargetRef::entity("values", "b"),
    ]),
    scene=sequence([("b", "1"), ("a", "2"), ("c", "3")]),
    annotation=@frontierlab.Annotation::new(
      title="Fault injected",
      body="This compare incorrectly changes the sequence order.",
    ),
  )
  builder.finish()
}

///|
/// Build the Union-Find trace used by the bundled demo.
fn union_find_demo_trace() -> @frontierlab.AlgorithmTrace raise {
  @classics.union_find_trace(6, [
    @classics.UnionOperation::new(left=0, right=1),
    @classics.UnionOperation::new(left=2, right=3),
    @classics.UnionOperation::new(left=1, right=3),
    @classics.UnionOperation::new(left=4, right=5),
    @classics.UnionOperation::new(left=3, right=5),
  ])
}

///|
/// A* on a small weighted grid, recorded directly with `TraceBuilder`.
///
/// Cells are numbered `y * width + x`. Each expansion records a `Visit`, each
/// improved neighbor a `Relax`, and the final `Complete` step highlights the
/// path as `Result` so `grid_path_contract` can check it.
fn pathfinding_demo_trace() -> @frontierlab.AlgorithmTrace raise {
  let width = 7
  let height = 5
  let cell = fn(x : Int32, y : Int32) { y * width + x }
  let blocked = [cell(2, 0), cell(2, 1), cell(2, 2)]
  let heavy = cell(4, 3)
  let start = cell(0, 0)
  let goal = cell(6, 4)
  let weight = fn(c : Int32) { if c == heavy { 7 } else { 1 } }
  let id = fn(c : Int32) { "cell-\{c % width}-\{c / width}" }
  let target = fn(c : Int32) {
    @frontierlab.TargetRef::entity("search-grid", id(c))
  }
  let cost : Map[Int32, Int32] = Map([])
  let parent : Map[Int32, Int32] = Map([])
  let frontier = [start]
  let visited : Array[Int32] = []
  let estimate = fn(c : Int32) {
    cost.get(c).unwrap() +
    (c % width - goal % width).abs() +
    (c / width - goal / width).abs()
  }
  let neighbors = fn(c : Int32) {
    let out : Array[Int32] = []
    for delta in [(0, -1), (1, 0), (0, 1), (-1, 0)] {
      let x = c % width + delta.0
      let y = c / width + delta.1
      if x >= 0 &&
        x < width &&
        y >= 0 &&
        y < height &&
        !blocked.contains(cell(x, y)) {
        out.push(cell(x, y))
      }
    }
    out
  }
  let scene = fn(
    current : Int32?,
    path : Array[Int32],
  ) -> @frontierlab.Scene raise {
    let cells : Array[@frontierlab.GridCellState] = []
    for y in 0..<height {
      for x in 0..<width {
        let c = cell(x, y)
        let label = if c == start {
          "S"
        } else if c == goal {
          "E"
        } else if weight(c) != 1 {
          weight(c).to_string()
        } else {
          ""
        }
        cells.push(
          @frontierlab.GridCellState::new(
            id=id(c),
            x~,
            y~,
            label~,
            blocked=blocked.contains(c),
          ),
        )
      }
    }
    let highlights : Array[@frontierlab.Highlight] = []
    if current is Some(c) {
      highlights.push(
        @frontierlab.Highlight::new(target=target(c), role=@frontierlab.Current),
      )
    }
    for c in path {
      highlights.push(
        @frontierlab.Highlight::new(target=target(c), role=@frontierlab.Result),
      )
    }
    for c in frontier {
      highlights.push(
        @frontierlab.Highlight::new(
          target=target(c),
          role=@frontierlab.Frontier,
        ),
      )
    }
    for c in visited {
      highlights.push(
        @frontierlab.Highlight::new(target=target(c), role=@frontierlab.Visited),
      )
    }
    @frontierlab.Scene::new(
      objects=[
        @frontierlab.Grid(
          @frontierlab.GridState::new(
            id="search-grid",
            label="Grid search",
            width~,
            height~,
            cells~,
          ),
        ),
      ],
      highlights~,
    )
  }
  let builder = @frontierlab.TraceBuilder::new(
    title="A* frontier exploration",
    algorithm="A*",
    description="A* with a Manhattan heuristic on a weighted grid, recorded with TraceBuilder.",
    initial_scene=scene(None, []),
  )
  cost[start] = 0
  let mut found = false
  while !frontier.is_empty() {
    let mut best = 0
    for i in 1..<frontier.length() {
      if estimate(frontier[i]) < estimate(frontier[best]) {
        best = i
      }
    }
    let current = frontier.remove(best)
    visited.push(current)
    builder.record(
      event=@frontierlab.Visit(target(current)),
      scene=scene(Some(current), []),
      annotation=@frontierlab.Annotation::new(
        title="Expand the cheapest cell",
        body="f = g + h = \{estimate(current)}; \{frontier.length()} cells remain in the frontier.",
      ),
    )
    if current == goal {
      found = true
      break
    }
    for next in neighbors(current) {
      if visited.contains(next) {
        continue
      }
      let next_cost = cost.get(current).unwrap() + weight(next)
      let improved = match cost.get(next) {
        Some(existing) => next_cost < existing
        None => true
      }
      if improved {
        cost[next] = next_cost
        parent[next] = current
        if !frontier.contains(next) {
          frontier.push(next)
        }
        builder.record(
          event=@frontierlab.Relax(
            target(current),
            target(next),
            next_cost.to_string(),
          ),
          scene=scene(Some(current), []),
          annotation=@frontierlab.Annotation::new(
            title="Relax a neighbor",
            body="Reach \{id(next)} through \{id(current)} with cost \{next_cost}.",
          ),
        )
      }
    }
  }
  let path : Array[Int32] = []
  if found {
    let mut c = goal
    path.push(c)
    while c != start {
      c = parent.get(c).unwrap()
      path.push(c)
    }
    path.rev_in_place()
  }
  let total = if found { cost.get(goal).unwrap() } else { 0 }
  builder.record(
    event=@frontierlab.Complete,
    scene=scene(None, path),
    annotation=@frontierlab.Annotation::new(
      title=if found { "Path found" } else { "No path" },
      body="Cost \{total}; visited \{visited.length()} cells.",
    ),
  )
  builder.finish(summary=[
    @frontierlab.TraceAttribute::new(key="reachable", value=found.to_string()),
    @frontierlab.TraceAttribute::new(key="cost", value=total.to_string()),
    @frontierlab.TraceAttribute::new(
      key="visited_count",
      value=visited.length().to_string(),
    ),
  ])
}
