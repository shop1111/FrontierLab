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

After building a trace, use `trace.diff(from_step=..., to_step=...)` to inspect stable-entity changes, or `trace.breakpoint_hits(...)` to search by event, target, role, and actual scene mutation. `trace.slice(center=...)` produces a portable minimal counterexample around a failing step.

Use `sequence_transition_contract`, `insertion_sort_int_contract`, or `grid_path_contract` for the bundled semantics. Library authors can create a `TraceContract::new` with a pure MoonBit checker callback that returns stable `TraceViolation` values. Agents and CI should call the CLI with `--format json`; exit code 2 means the trace parsed correctly but failed a semantic contract or diverged from its reference.
