///|
struct DemoItem {
  id : String
  value : Int
} derive(Debug, Eq)

///|
fn selection_scene(
  items : Array[DemoItem],
  highlights : Array[@frontierlab.Highlight],
) -> @frontierlab.Scene raise {
  @frontierlab.Scene::new(
    objects=[
      @frontierlab.Sequence(
        @frontierlab.SequenceState::new(
          id="values",
          label="Selection sort",
          items=items.map(fn(item) {
            @frontierlab.SequenceItem::new(
              id=item.id,
              value=item.value.to_string(),
            )
          }),
        ),
      ),
    ],
    highlights~,
  )
}

///|
fn selection_target(item : DemoItem) -> @frontierlab.TargetRef {
  @frontierlab.TargetRef::entity("values", item.id)
}

///|
fn selection_sort_trace(faulty : Bool) -> @frontierlab.AlgorithmTrace raise {
  let working = [5, 2, 4, 1, 3].mapi(fn(index, value) {
    { id: "item-\{index}", value }
  })
  let title = if faulty {
    "Faulty selection sort - stale index"
  } else {
    "Expected selection sort"
  }
  let builder = @frontierlab.TraceBuilder::new(
    title~,
    algorithm="selection-sort",
    description="Published-package consumer trace with stable entity ids.",
    initial_scene=selection_scene(working, []),
  )
  for i in 0..<working.length() {
    let mut minimum_index = i
    for candidate_index in (i + 1)..<working.length() {
      let minimum = working[minimum_index]
      let candidate = working[candidate_index]
      builder.record(
        event=@frontierlab.Compare([
          selection_target(minimum),
          selection_target(candidate),
        ]),
        scene=selection_scene(working, [
          @frontierlab.Highlight::new(
            target=selection_target(minimum),
            role=@frontierlab.Compared,
          ),
          @frontierlab.Highlight::new(
            target=selection_target(candidate),
            role=@frontierlab.Current,
          ),
        ]),
        annotation=@frontierlab.Annotation::new(
          title="Compare candidate",
          body="Pass \{i}: compare \{minimum.value} with \{candidate.value}.",
          pseudocode_line=3,
        ),
      )
      if candidate.value < minimum.value {
        minimum_index = candidate_index
      }
    }
    if minimum_index != i {
      let swap_index = if faulty && i == 2 { 3 } else { minimum_index }
      let left = working[i]
      let selected = working[swap_index]
      working[i] = selected
      working[swap_index] = left
      builder.record(
        event=@frontierlab.Swap(
          selection_target(left),
          selection_target(selected),
        ),
        scene=selection_scene(working, [
          @frontierlab.Highlight::new(
            target=selection_target(left),
            role=if faulty && i == 2 {
              @frontierlab.Error
            } else {
              @frontierlab.Changed
            },
          ),
          @frontierlab.Highlight::new(
            target=selection_target(selected),
            role=@frontierlab.Result,
          ),
        ]),
        annotation=@frontierlab.Annotation::new(
          title=if faulty && i == 2 {
            "Stale-index fault"
          } else {
            "Place minimum"
          },
          body=if faulty && i == 2 {
            "Expected item-4 (3), but stale index 3 selected item-0 (5)."
          } else {
            "Place \{selected.value} at sorted position \{i}."
          },
          pseudocode_line=5,
        ),
      )
    }
  }
  builder.record(
    event=@frontierlab.Complete,
    scene=selection_scene(
      working,
      working.map(fn(item) {
        @frontierlab.Highlight::new(
          target=selection_target(item),
          role=if faulty { @frontierlab.Error } else { @frontierlab.Result },
        )
      }),
    ),
    annotation=@frontierlab.Annotation::new(
      title=if faulty { "Incorrect result" } else { "Sorted" },
      body="Final values: \{working.map(fn(item) { item.value.to_string() }).join(",")}.",
    ),
  )
  builder.finish(summary=[
    @frontierlab.TraceAttribute::new(
      key="consumer_dependency",
      value="shop1111/frontierlab@0.6.0",
    ),
    @frontierlab.TraceAttribute::new(
      key="fault_injected",
      value=faulty.to_string(),
    ),
  ])
}
