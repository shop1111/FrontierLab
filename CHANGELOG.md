# Changelog

## Unreleased

- Added `TracedArray[T]`, an array whose `less`, `compare`, `swap`, and
  indexed writes record `Compare`, `Swap`, and `Update` events, so array
  algorithms are traced without `TraceBuilder` code.
- Added `SequenceProbe[T]`, which infers `Swap`, `Update`, and `Custom`
  move/insert/remove/edit events from value snapshots and keeps element ids
  stable across moves.
- Added `TraceLevel` (`Full`, `Count`, `Off`) and `OperationCounts` for
  counting compares, swaps, reads, and writes with or without recording.
- Added the `examples/traced_sort` executable example.

## 0.9.2 - Unreleased

- Raised the supported toolchain to MoonBit `moonc` 0.10.16 or newer; CI now
  pins `0.10.18+6c83a7f62` and adds a non-blocking latest-toolchain job.
- Declared every derived `Debug`, `Eq`, `ToJson`, `FromJson`, and `Show`
  method explicitly with `pub extend`, so `--deny-warn` passes on current
  compilers and existing calls such as `trace.to_json()` keep working.
- Replaced the deprecated `Array::to_json()` call in the CLI breakpoint report.
- Moved Mooncakes packaging rules from the deprecated `moon.mod` `exclude`
  option to `.moonignore`, and stopped local presentation drafts from being
  packaged.
- Reformatted sources with the current `moon fmt` and refreshed benchmarks.

## 0.9.1 - 2026-08-10

- Rebuilt the standalone HTML trace player around readable role palettes,
  Chinese/English interface switching, event-specific guidance, sequence/grid
  axes, deterministic graph rendering, and reduced-motion-aware FLIP movement.
- Added explicit Compare, Swap, Update, Visit, Relax, Union, Complete, and
  Custom-event explanations, including swap index direction, DP dependencies,
  value transitions, and custom red-black-tree attributes.
- Removed AI Trace Clinic's placeholder SVG title-card export and completed its
  readable styling for every highlight role.
- Deprecated `render_trace_svg` and `render_trace_svg_frames`; the compatible
  CLI SVG format is now marked legacy, with removal scheduled for v1.0.
- Added built-in HTML demos for Fibonacci, coin change, knapsack, LCS, and
  red-black trees plus renderer conformance and contrast checks.

## 0.8.0 - 2026-08-10

- Added algorithm-level adapters for Fibonacci DP, minimum coin change, 0/1
  knapsack, and longest common subsequence with reusable sequence/grid scenes.
- Added a Schema-v1-compatible red-black-tree adapter with stable node ids,
  insertion balancing, recoloring, rotations, lookup paths, and invariant
  validation.
- Added checked API examples, JSON/rendering coverage, invalid-input tests, and
  deterministic DP/red-black-tree acceptance scenarios.

## 0.7.1 - 2026-08-09

- Migrated executable argument handling from the legacy `@sys.get_cli_args()`
  API to `@env.args()` for current native-toolchain compatibility.
- Replaced the floating compatibility probe with blocking checks on the fixed
  minimum and current stable MoonBit toolchains.
- Rewrote the public README around installation, library use, CLI behavior,
  the browser tool, and a clear explanation of the standalone consumer.
- Removed non-library release material and generated diagnostic outputs from the
  public repository and release package while retaining reproducible sources.

## 0.7.0 - 2026-08-05

- Added the unified `diagnose` CLI path that combines schema validation,
  contracts, first divergence, state changes, focus step, counterexample
  slicing, stable JSON, and offline HTML reports.
- Added the public `TraceDiagnosis`/`diagnose_trace` facade and generic
  `sorted_int_sequence_contract` while retaining every v0.6.0 API.
- Added a nested, independently resolved Mooncakes consumer and stable
  selection-sort inputs whose first divergence is deterministically step 10.
- Reframed the offline Playground as AI Trace Clinic with a one-click default
  case, correct/no-reference modes, visible diagnostics, downloads, and repair
  prompt copying.
- Hardened Clinic with codec-aligned reference checks, a real grid-path
  contract, semantic key-order-independent comparison, no-network CSP, escaped
  exports, bounded rendering, and separate transition/reference evidence.
- Added schema edge fixtures, white-box debugger/contract/codec/report/quality
  coverage, and a portable reasoned coverage gate.
- Extended the benchmark through 50,000 steps with explicit `TraceOptions`;
  `decode_json` now accepts backward-compatible optional limits.
- Expanded integration, validation, and release documentation around the
  complete diagnosis loop.
- Added a structured CLI execution layer, `--version`, a local release build
  script, and removed the CLI dispatch coverage exemption.

## 0.6.0 - 2026-07-12

- Upgraded FrontierLab into a semantic time-travel debugger with frame diffs, event/entity breakpoints, trace slicing, and first-divergence detection.
- Added extensible trace contracts plus sequence-transition, integer insertion-sort, and grid-path contract implementations.
- Added deterministic JSON CLI workflows for AI agents with semantic-failure exit code 2 and portable counterexample export.
- Expanded the offline Playground with debugger controls, a faulty AI-generated trace, contract navigation, and expected/actual comparison.
- Extended CI and benchmarks to cover debugger reports, semantic failures, contract verification, and divergence detection.

## 0.5.0 - 2026-07-11

- Added a self-contained offline Trace Playground with JSON paste/file import, drag-and-drop, schema-v1 diagnostics, analysis, quality checks, timeline replay, and SVG/JSON export.
- Added `render_trace_playground` and the `frontierlab playground --output ...` CLI workflow.
- Expanded CI with an explicit all-target build, package verification, CI artifacts, and Playground checks.
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
