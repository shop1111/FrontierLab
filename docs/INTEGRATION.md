# Integrating an Algorithm

1. Assign stable IDs to logical entities. Do not use the current array index as identity if elements move. Address them with `TargetRef::entity(object_id, entity_id)`; use `TargetRef::object(object_id)` for an entire scene object.
2. Build an initial `Scene` from one or more `Sequence`, `Sets`, `Graph`, or `Grid` objects.
3. Create a `TraceBuilder` with a title and stable algorithm key.
4. At meaningful algorithm boundaries, call `record` with a semantic event, complete scene, and optional annotation.
5. Finish and validate the trace, then pass it to the HTML/SVG renderer or `encode_json`. Use `AlgorithmTrace::decode_json` to consume an external schema-v1 document.

Prefer meaningful steps over logging every assignment. A sorting trace normally records comparisons and moves; graph search records visits and relaxations; dynamic programming records cell updates and dependency choices.

Use `Custom` when no built-in event describes the transition. Keep the custom `kind` stable and put display text in `Annotation`, not in the event key.

`TraceBuilder` deep-copies every scene, so callers can continue mutating their working arrays after `record` returns.

For existing FrontierLab searches, call `search_trace_to_algorithm_trace` rather than rebuilding grid scenes manually.

## Semantic debugging and AI-agent verification

After building a trace, prefer `diagnose_trace(actual, contract=..., expected=...)` for a single authoritative result. It returns the contract report, optional first divergence, focus step, actual transition diff, reference diff, and a portable focused window around the failure. Use `trace.diff(from_step=..., to_step=...)`, `trace.breakpoint_hits(...)`, and `trace.slice(center=...)` when assembling a custom workflow.

Use `sequence_transition_contract`, `sorted_int_sequence_contract`, the backward-compatible `insertion_sort_int_contract`, or `grid_path_contract` for bundled semantics. Library authors can create a `TraceContract::new` with a pure MoonBit checker callback that returns stable `TraceViolation` values. Agents and CI should call the CLI with `--format json`; exit code 2 means the trace parsed correctly but failed a semantic contract or diverged from its reference.

## Three supported integration paths

### 1. MoonBit library

Depend on the published package, construct a `TraceBuilder`, and call the
debugging/contract APIs directly. The nested
`consumer/frontierlab_consumer_demo` is an auditable example: it has its own
`moon.mod`, resolves `shop1111/frontierlab@0.6.0` from Mooncakes, and has no
local override.

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
requirements, and uses the same frozen selection-sort semantics as the CLI
fixtures.
