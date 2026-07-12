# Changelog

## 0.6.0 - 2026-07-12

- Upgraded FrontierLab into a semantic time-travel debugger with frame diffs, event/entity breakpoints, trace slicing, and first-divergence detection.
- Added extensible trace contracts plus sequence-transition, integer insertion-sort, and grid-path contract implementations.
- Added deterministic JSON CLI workflows for AI agents with semantic-failure exit code 2 and portable counterexample export.
- Expanded the offline Playground with debugger controls, a faulty AI-generated trace, contract navigation, and expected/actual comparison.
- Extended CI and benchmarks to cover debugger reports, semantic failures, contract verification, and divergence detection.

## 0.5.0 - 2026-07-11

- Added a self-contained offline Trace Playground with JSON paste/file import, drag-and-drop, schema-v1 diagnostics, analysis, quality checks, timeline replay, and SVG/JSON export.
- Added `render_trace_playground` and the `frontierlab playground --output ...` CLI workflow.
- Expanded CI with an explicit all-target build, package verification, acceptance artifacts, and Playground checks.
- Added the Playground to the GitHub Pages showcase and aligned release-readiness documentation.

## 0.4.0 - 2026-07-11

- Added reusable trace statistics, Markdown reports, timeline inspection, and lint-style quality diagnostics.
- Added reusable insertion-sort and Union-Find trace adapters and refactored bundled demos to use them.
- Added CLI trace analysis and strengthened all-target CI validation.

## 0.3.0 - 2026-07-04

- Stabilized the explicit `frontierlab-trace` schema-v1 JSON format with round-trip decoding.
- Added scoped `TargetRef`, typed validation errors, builder limits, and complete reference validation.
- Added external trace validation/rendering CLI commands and golden schema fixtures.
- Added deterministic DAG/cyclic graph layout, directed arrows, edge labels, and self-loops.
- Added reproducible 100/1,000/10,000-step benchmarks and automated Pages deployment.

## 0.2.0 - 2026-07-04

- Added the versioned generic algorithm trace model and deep-copying builder.
- Added sequence, set, graph, and grid scenes with stable IDs and validation.
- Added semantic events, highlights, annotations, JSON, SVG frames, and offline HTML playback.
- Added insertion-sort, Union-Find, and A* flagship traces plus a file-generating CLI.
- Preserved the existing BFS, Dijkstra, A*, ASCII, SVG, and comparison APIs.

## 0.1.0

- Initial FrontierLab grid pathfinding and teaching trace release.
