# Integrating an Algorithm

1. Assign stable IDs to logical entities. Do not use the current array index as identity if elements move.
2. Build an initial `Scene` from one or more `Sequence`, `Sets`, `Graph`, or `Grid` objects.
3. Create a `TraceBuilder` with a title and stable algorithm key.
4. At meaningful algorithm boundaries, call `record` with a semantic event, complete scene, and optional annotation.
5. Finish the trace and pass it to the HTML, SVG, or JSON exporter.

Prefer meaningful steps over logging every assignment. A sorting trace normally records comparisons and moves; graph search records visits and relaxations; dynamic programming records cell updates and dependency choices.

Use `Custom` when no built-in event describes the transition. Keep the custom `kind` stable and put display text in `Annotation`, not in the event key.

`TraceBuilder` deep-copies every scene, so callers can continue mutating their working arrays after `record` returns.

For existing FrontierLab searches, call `search_trace_to_algorithm_trace` rather than rebuilding grid scenes manually.
