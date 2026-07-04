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

Scene objects and their entities use caller-owned string IDs. References are encoded as `{ "object_id": "...", "entity_id": "..." }`; omit `entity_id` to target the whole object. Entity IDs only need to be unique inside their owning object, so different objects may safely contain the same local ID. Graph endpoints must exist, grid cells must be inside the declared dimensions, and highlights and semantic events must resolve to existing targets.

## Events

The stable built-in vocabulary is `initialize`, `compare`, `swap`, `visit`, `update`, `union`, `relax`, and `complete`. Events are JSON objects with a `type` field and named payload fields. Unknown event types decode as `Custom(kind, attributes)` so domain semantics do not require a schema revision.

## Compatibility

- Additive fields may appear in a compatible 1.x release.
- Consumers should ignore unknown fields and custom event kinds.
- A breaking wire-format change increments the major schema version.
- Version 1 stores full scenes; a future compressed transport must decode to the same logical document.
- Complete machine-readable examples live in `fixtures/schema-v1/`.
