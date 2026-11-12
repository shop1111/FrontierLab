# Integrating an Algorithm

## Your own data structure: `explore`

If the code under test is a data structure with operations such as `insert`,
`delete`, `push`, or `pop`, use the `shop1111/frontierlab/explore` package. It
needs no changes to your code beyond `derive(ToJson)`:

```mbt nocheck
let ops = [@explore.Op::new("insert", insert), @explore.Op::new("delete", delete)]
match @explore.explore(() => Leaf, ops, invariant=is_bst) {
  Some(found) => found.save_html("bst.html")
  None => ()
}
```

- `invariant : (S) -> String?` must hold after every operation.
- `check : (S, Step) -> String?` sees the step that produced the state, for
  rules such as "after `delete k`, `k` is gone". Read integer arguments with
  `step.int_arg()`.
- `model : Model` runs a simple reference implementation alongside, with
  operations of the same names, and requires equal results. Operations made
  with `Op::returning`, `Op::returning_without_arg`, or
  `Op::returning_with_gen` return `(state, result)`; results need `Debug`.
- Without a model, an operation that raises fails its step. With a model, it
  fails only when the model does not raise too.
- `Op::new` draws integer arguments from `0..<max_arg`. `Op::with_gen` takes a
  core `quickcheck` `Generator` for any argument type with `ToJson` and
  `FromJson`; scripts write such arguments as JSON, such as `put ["a", 1]`.
- `init` must return a fresh state on every call; mutable structures update
  the value in place and return it.
- `replay` runs a script you wrote, such as
  `Step::parse("insert 5, insert 3; delete 5")`. Pass `window=N` to draw only
  the last `N` steps before the failure.
- `views` says how to draw parts that the `ToJson` output does not reveal:
  `Graph(path)` for adjacency lists, `Buckets(path)` for hash table buckets,
  `Matrix(path)` for rows of cells, and `NodeId(field)` to identify tree nodes
  by one field (`"key"`) or constructor position (`"N#2"`), so a recolored
  node stays the same node. Paths are dotted field names; `""` is the state.
- `@explore.mark(value, note=...)` inside an operation records `value` with
  its source line; `replay` shows each mark as a step of its own before the
  step it belongs to. Marks are ignored outside `replay`.
- `frontierlab-instrument FILE --fn NAME [--watch VAR]` inserts
  `@explore.auto_mark(VAR, LINE, "code")` before every statement of `NAME`, so
  that each line becomes a step of the replay; `--remove` restores the file.
  See [instrument/README.md](../instrument/README.md).
- `explain()` on a replay or exploration gives a plain-text, step-by-step
  account with `+`/`-`/`~` change lines, for terminals and AI agents.
  `regression_test(init=..., ops=..., checks=...)` prints a MoonBit test that
  replays the found steps and fails while the bug is there.

Snapshots are drawn from the `ToJson` output: constructors with exactly two
subtree positions become left and right children, constant constructors in
subtree positions (such as `Leaf`) become empty children, values that never
hold a subtree become the node label, struct fields and map entries become
named edges, and arrays of plain values become sequences. Nodes are identified
by label, with repeated labels numbered in pre-order. Types with parent
pointers or cycles need a hand-written `ToJson` without the back edges.

## Array algorithms

For array algorithms, start with automatic tracing and fall back to
`TraceBuilder` only when you need custom scenes or events:

- `TracedArray[T]` records `Compare`, `Swap`, and `Update` events from the
  operations the algorithm performs (`less`, `compare`, `swap`, `a[i] = v`).
  Reads are counted but not recorded as steps.
- `SequenceProbe[T]` infers `Swap`, `Update`, and `Custom` `move`, `insert`,
  `remove`, or `edit` events from value snapshots passed to `observe`, while
  keeping element ids stable. Unchanged snapshots record nothing.

Both take a `TraceLevel` (`Full`, `Count`, or `Off`), expose `counts()`, and
defer recording errors to `finish()`. The `sequence-transition` and
`sorted-int-sequence` contracts accept `Swap` and `Update` steps: an `Update`
may change only its target, to the recorded value. The sorting contracts also
require the final values to be a permutation of the initial ones. `Custom`
insert, remove, and edit steps from `SequenceProbe` still count as violations.

To find a failing input automatically, pass the algorithm to
`search_sequence_counterexample`. It runs random inputs at `Count` level,
shrinks the first failure to a minimal input, and diagnoses that input
against a reference implementation or the default sorted-output property.

To build a trace by hand:

1. Assign stable IDs to logical entities. Do not use the current array index as identity if elements move. Address them with `TargetRef::entity(object_id, entity_id)`; use `TargetRef::object(object_id)` for an entire scene object.
2. Build an initial `Scene` from one or more `Sequence`, `Sets`, `Graph`, or `Grid` objects.
3. Create a `TraceBuilder` with a title and stable algorithm key.
4. At meaningful algorithm boundaries, call `record` with a semantic event, complete scene, and optional annotation.
5. Finish and validate the trace, then pass it to the HTML renderer or `encode_json`. Use `AlgorithmTrace::decode_json` to consume an external schema-v1 document.

Prefer meaningful steps over logging every assignment. A sorting trace normally records comparisons and moves; graph search records visits and relaxations; dynamic programming records cell updates and dependency choices.

Use `Custom` when no built-in event describes the transition. Keep the custom `kind` stable and put display text in `Annotation`, not in the event key.

`TraceBuilder` deep-copies every scene, so callers can continue mutating their working arrays after `record` returns.

For grid algorithms, build a `Grid` scene and record `Visit` and `Relax` steps; the CLI `pathfinding` demo (`cmd/main/cli_demos.mbt`) is a complete A* example recorded with `TraceBuilder`.

## Bundled classic adapters

The `shop1111/frontierlab/classics` package includes algorithm-level adapters
for insertion sort, Union-Find, Fibonacci DP, minimum coin change, 0/1
knapsack, longest common subsequence,
and red-black-tree insertion/search. Fibonacci and coin change share the same
private one-dimensional scene representation while preserving distinct public
inputs, validation, recurrence annotations, and summaries.

The DP adapters emit `Update` for completed states and highlight the states
used by the recurrence. Knapsack and LCS map rows and columns to stable
`cell-x-y` grid ids; LCS additionally emits `Visit` while reconstructing its
deterministic result. Red-black-tree nodes retain insertion-order ids and encode
persistent colors as `[R]`/`[B]` labels. Its stable custom event keys are
`rb-insert`, `rb-recolor`, `rb-rotate-left`, `rb-rotate-right`, `rb-find-hit`,
and `rb-find-miss`.

Every new adapter accepts `TraceOptions`. Invalid dimensions or domain inputs
raise `TraceError`, and oversized state spaces are rejected before allocating
their complete scene tables.

## Checking and comparing traces

After building a trace, prefer `diagnose_trace(actual, contract=..., expected=...)` for a single authoritative result. It returns the contract report, optional first divergence, focus step, actual transition diff, reference diff, and a portable focused window around the failure. Use `trace.diff(from_step=..., to_step=...)`, `trace.breakpoint_hits(...)`, and `trace.slice(center=...)` when assembling a custom workflow.

`TraceContract` is a rule checker: it reports whether individual steps or the final result violate predefined requirements. Use `sequence_transition_contract`, `sorted_int_sequence_contract`, or `grid_path_contract` for bundled rules (`insertion_sort_int_contract` is a deprecated alias of `sorted_int_sequence_contract`). Library authors can create a `TraceContract::new` with a pure MoonBit checker callback that returns stable `TraceViolation` values. Agents and CI should call the CLI with `--format json`; exit code 2 means the trace parsed correctly but violated a rule or differed from its reference.

## Three supported integration paths

### 1. MoonBit library

Depend on the published package, construct a `TraceBuilder`, and call the
checking and debugging APIs directly, or hand your own data structure to the
`explore` package. `consumer/frontierlab_consumer_demo` is a standalone example
project that resolves the published package from Mooncakes with no local
override. It plays an external user who uses `explore` to find a bug in their
own min-heap, and verifies that the release is installable; ordinary users do
not need to run it.

### 2. CLI or AI Agent

Use the unified command:

```bash
moon run cmd/main -- diagnose expected.json actual.json \
  --contract sorted-int-sequence --object values --format json \
  --counterexample counterexample.json --report diagnosis.html
```

The outer `frontierlab-debug-report/1.0` envelope remains stable. The result
keeps `state_changes` for the actual transition and adds `reference_changes`
plus `counterexample_kind: "focused-window"`. Exit 0 means pass, 2 means
semantic failure, and 1 means invocation/input failure.

### 3. Offline browser

`diagnose --report report.html` writes an offline diagnostic report. For an
algorithm demonstration, generate the interactive player:

```bash
moon run cmd/main -- demo insertion-sort --format html --output insertion-sort.html
moon run cmd/main -- demo lcs --format html --output lcs.html
moon run cmd/main -- demo red-black-tree --format html --output red-black-tree.html
```

The player explains semantic events in Chinese or English, preserves Adapter
annotations, shows indexes/grid coordinates, and animates stable entity IDs
between complete scene snapshots.
