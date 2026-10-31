# Integrating an Algorithm

For array algorithms, start with automatic tracing and fall back to
`TraceBuilder` only when you need custom scenes or events:

- `TracedArray[T]` records `Compare`, `Swap`, and `Update` events from the
  operations the algorithm performs (`less`, `compare`, `swap`, `a[i] = v`).
  Reads are counted but not recorded as steps.
- `SequenceProbe[T]` infers `Swap`, `Update`, and `Custom` `move`, `insert`,
  `remove`, or `edit` events from value snapshots passed to `observe`, while
  keeping element ids stable. Unchanged snapshots record nothing.

Both take a `TraceLevel` (`Full`, `Count`, or `Off`), expose `counts()`, and
defer recording errors to `finish()`. Traces with `Update` or `Custom` events
change element values, so the permutation-based `sequence-transition` and
`sorted-int-sequence` contracts apply only to swap-based traces.

To build a trace by hand:

1. Assign stable IDs to logical entities. Do not use the current array index as identity if elements move. Address them with `TargetRef::entity(object_id, entity_id)`; use `TargetRef::object(object_id)` for an entire scene object.
2. Build an initial `Scene` from one or more `Sequence`, `Sets`, `Graph`, or `Grid` objects.
3. Create a `TraceBuilder` with a title and stable algorithm key.
4. At meaningful algorithm boundaries, call `record` with a semantic event, complete scene, and optional annotation.
5. Finish and validate the trace, then pass it to the HTML renderer or `encode_json`. Use `AlgorithmTrace::decode_json` to consume an external schema-v1 document. The SVG renderer is deprecated in v0.9 and scheduled for removal in v1.0.

Prefer meaningful steps over logging every assignment. A sorting trace normally records comparisons and moves; graph search records visits and relaxations; dynamic programming records cell updates and dependency choices.

Use `Custom` when no built-in event describes the transition. Keep the custom `kind` stable and put display text in `Annotation`, not in the event key.

`TraceBuilder` deep-copies every scene, so callers can continue mutating their working arrays after `record` returns.

For existing FrontierLab searches, call `search_trace_to_algorithm_trace` rather than rebuilding grid scenes manually.

## Bundled classic adapters

FrontierLab includes algorithm-level adapters for insertion sort, Union-Find,
Fibonacci DP, minimum coin change, 0/1 knapsack, longest common subsequence,
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

`TraceContract` is a rule checker: it reports whether individual steps or the final result violate predefined requirements. Use `sequence_transition_contract`, `sorted_int_sequence_contract`, the backward-compatible `insertion_sort_int_contract`, or `grid_path_contract` for bundled rules. Library authors can create a `TraceContract::new` with a pure MoonBit checker callback that returns stable `TraceViolation` values. Agents and CI should call the CLI with `--format json`; exit code 2 means the trace parsed correctly but violated a rule or differed from its reference.

## Three supported integration paths

### 1. MoonBit library

Depend on the published package, construct a `TraceBuilder`, and call the
checking and debugging APIs directly. `consumer/frontierlab_consumer_demo` is
a standalone example project that resolves `shop1111/frontierlab@0.7.1` from
Mooncakes and has no local override. It simulates an external user and verifies
that the release is installable; ordinary users do not need to run it.

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

Generate AI Trace Clinic with:

```bash
moon run cmd/main -- playground --output playground.html
```

Open the resulting file directly. It contains no external scripts or network
requirements, and includes the same intentionally incorrect selection-sort
example as the CLI fixtures.

For a focused algorithm demonstration instead of diagnosis, generate the v0.9
interactive player:

```bash
moon run cmd/main -- demo insertion-sort --format html --output insertion-sort.html
moon run cmd/main -- demo lcs --format html --output lcs.html
moon run cmd/main -- demo red-black-tree --format html --output red-black-tree.html
```

The player explains semantic events in Chinese or English, preserves Adapter
annotations, shows indexes/grid coordinates, and animates stable entity IDs
between complete scene snapshots.
