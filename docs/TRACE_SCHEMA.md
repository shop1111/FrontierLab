# FrontierLab Trace Schema 1.0

`AlgorithmTrace` is the portable boundary between an algorithm and a renderer.

## Document

- `schema_version`: currently `1.0`.
- `title`, `algorithm`, `description`: human and machine-readable identity.
- `initial_scene`: state before the first event.
- `steps`: ordered semantic events with complete scene snapshots.
- `summary`: deterministic string key/value metrics.

Every step has a zero-based `index`, one `TraceEvent`, a complete `Scene`, and an optional `Annotation`. Full snapshots make random access constant-time and keep renderers independent of algorithm-specific reducers.

## Stable IDs

Scene objects and their entities use caller-owned string IDs. An ID must remain attached to the same logical entity even if its position changes. Object IDs must be unique, graph endpoints must exist, grid cells must be inside the declared dimensions, and highlights must reference an existing object or entity.

## Events

The stable built-in vocabulary is `Initialize`, `Compare`, `Swap`, `Visit`, `Update`, `Union`, `Relax`, and `Complete`. `Custom(kind, attributes)` adds domain semantics without changing the schema.

## Compatibility

- Additive fields may appear in a compatible 1.x release.
- Consumers should ignore unknown fields and custom event kinds.
- A breaking wire-format change increments the major schema version.
- Version 1 stores full scenes; a future compressed transport must decode to the same logical document.
