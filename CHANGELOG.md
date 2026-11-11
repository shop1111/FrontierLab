# Changelog

## Unreleased

`explore` can now compare against a reference implementation and take
arguments of any type, and HTML players store only what changes between
steps. `Step.arg` and `Op` change shape; see below.

- Added `Model`, a reference implementation that `explore` and `replay` run
  alongside the structure under test (`model=`). After every step, results
  must be equal and an operation must raise exactly when the model raises;
  a mismatch fails the step with a message such as
  `returned false, but the model returned true`. When both raise, the step
  passes and the state is unchanged.
- Added operations that return a result: `Op::returning`,
  `Op::returning_without_arg`, and `Op::returning_with_gen` take functions
  that return `(state, result)`, where the result needs `Debug`. Results are
  listed in `Replay.outputs` and shown in each step of the replay.
- Added `Op::with_gen` for arguments of any type with `ToJson` and
  `FromJson`, drawn from a core `quickcheck` `Generator` that receives
  `max_arg` as its size. Integer operations made with `Op::new` keep drawing
  from `0..<max_arg`, so existing searches find the same sequences.
- Breaking: `Step.arg` is now `Json?` instead of `Int32?`. Use
  `Step::int_arg()` in checks, `Step::new(op, arg=n)` for integers, and
  `Step::with_arg(op, value)` for other types. `Op.run` is no longer public;
  `Op` now has a public `returns` field.
- `Step::parse` reads arguments as JSON, such as `put ["a", 1], get "a"`, and
  splits steps only at separators outside brackets and strings. Unquoted
  words are rejected with a hint to quote them.
- `replay` now rejects a step whose argument does not fit its operation (for
  example `insert 1.5` or `insert "x"` for an integer operation) and an
  argument given to an operation that takes none.
- Shrinking now also shrinks strings, arrays, and fields of arguments, and
  shrinks every occurrence of the same argument together, so
  `insert 4, contains 4` can become `insert 1, contains 1`. The duplicated
  successor example now shrinks to `insert 1, insert 2, insert 0, delete 1`.
- `render_trace_html` stores the initial scene and then, for each step, only
  the change from the previous scene; the player restores full scenes with
  `unpackTrace` when it loads. The embedded data is also no longer indented.
  The page for 1000 tree inserts drops from 149 MB to 505 KB and renders in
  0.93 s instead of 2.8 s. Trace Schema v1 and `encode_json` are unchanged.
- Snapshots no longer copy constructor arguments while reading `ToJson`
  output; replaying 1000 inserts drops from about 4.1 s to 2.0 s.
- Added the `examples/explore_model` example.

## 0.12.0 - 2026-11-11

This release turns FrontierLab into a debugger for the user's own data
structures, splits the module into packages, and narrows the core to trace
recording, checking, testing tools, and the HTML player. Several public APIs
are removed or moved without a deprecation period; the package is still
pre-1.0.

- Added the `shop1111/frontierlab/explore` package. `explore` runs random
  operation sequences against any `ToJson` data structure, checks an
  `invariant` and a per-step `check` after every operation, shrinks the first
  failing sequence, and replays only that sequence with a snapshot of the whole
  structure after each step. `replay` runs a sequence written by hand, for
  example with `Step::parse("insert 5, insert 3; delete 5")`. Both return the
  trace, a text report, and `save_html`. Operations are plain functions
  wrapped with `Op::new` or `Op::without_arg`; an operation that raises fails
  its step.
- Snapshots are drawn from `derive(ToJson)` output without knowing the user's
  types: constructors with two subtrees become left and right children,
  constant constructors in subtree positions become empty children, struct
  fields and map entries become named edges, and flat values become sequences.
  Nodes are identified by their labels, so a key keeps its identity when it
  moves.
- Added `replay(..., window=N)`, which finds the failing step without
  snapshots and draws only the last `N` steps before it. Replaying 1000
  inserts drops from about 4 s and 149 MB of HTML to about 0.2 s and 6.4 MB.
- Added the `examples/explore_bst` example and the `bench/explore_bench`
  benchmark.
- Made scene validation linear. Duplicate-id checks, graph edge endpoints, and
  highlight targets used pairwise comparison or a linear scan per item;
  they now use hash maps. Validating a 10,000-node graph with every node
  highlighted drops from about 438 ms to 45 ms. Error messages still name the
  first duplicated id.
- Moved the classic algorithm adapters (`insertion_sort_trace`,
  `insertion_sort_items_trace`, `SortTraceItem`, `union_find_trace`,
  `UnionOperation`, `fibonacci_dp_trace`, `coin_change_dp_trace`,
  `zero_one_knapsack_dp_trace`, `lcs_dp_trace`, `red_black_tree_trace`,
  `RedBlackTreeOperation`) into `shop1111/frontierlab/classics`.
- Moved complexity profiling (`profile_complexity`, `profile_traced_array`,
  `ComplexityClass`, `ComplexityFit`, `ComplexityProfile`,
  `ComplexitySample`, `CostMetric`, `measure_tracing_overhead`,
  `TracingOverhead`) into `shop1111/frontierlab/profile`.

- Removed AI Trace Clinic: `render_trace_playground`, the `playground` CLI
  command, `docs/playground.html`, and `scripts/check_playground.mjs`. The
  Clinic re-implemented validation, contracts, divergence, slicing, and lint
  in browser JavaScript, so every rule change had to be made twice. Use
  `diagnose --report report.html` for an offline diagnostic page.
- Removed the deprecated SVG renderer (`render_trace_svg`,
  `render_trace_svg_frames`) and the CLI `--format svg` and `render --step`
  options.
- Removed the legacy grid path-search API: `GridMap`, `Position`, `MoveRule`,
  `Heuristic`, `bfs`, `dijkstra`, `astar` and their `*_trace` variants,
  `SearchTrace`, `TraceStep`, `PathResult`, `CostEntry`, `ParentLink`,
  `compare_algorithms`, `AlgorithmReport`, `CompareReport`, `export_ascii`,
  `export_svg`, `heuristic_distance`, and `search_trace_to_algorithm_trace`,
  together with the `maze_bfs`, `weighted_astar`, `compare`, and
  `pathfinding_trace` examples. `grid_path_contract` is unchanged. The CLI
  `pathfinding` demo is now an A* trace recorded directly with
  `TraceBuilder`, and its final path passes `grid_path_contract`.
- Removed trace lint and timeline reports (`AlgorithmTrace::lint`,
  `lint_report`, `lint_markdown`, `lint_count`, `has_lint_errors`,
  `has_lint_warnings`, `timeline`, `timeline_report`, `timeline_table`,
  `TraceLintIssue`, `TraceLintSeverity`, `TraceTimelineEntry`) and the
  Markdown analysis tables (`TraceStats::to_markdown`, `event_table`,
  `object_table`, `target_table`, `AlgorithmTrace::analysis_markdown`).
  `analyze` and `summary_report` remain.
- Moved the demo factories (`insertion_sort_demo_trace`,
  `faulty_insertion_sort_demo_trace`, `union_find_demo_trace`,
  `pathfinding_demo_trace`) into the CLI. Call `insertion_sort_trace` and
  `union_find_trace` directly.
- Moved `PhaseTimer` and `PhaseTiming` into the CLI and removed the `timer`
  argument of `diagnose_trace`. `diagnose --timings` now reports the
  contract check, divergence search, state diffs, and slice as one
  `diagnose` phase.
- Deprecated `insertion_sort_int_contract`, an alias of
  `sorted_int_sequence_contract`; it will be removed in v1.0.

## 0.11.0 - 2026-11-09

- Raised the supported toolchain to MoonBit `moonc` 0.10.20 or newer and moved
  every type to the `#derive(...)` syntax that 0.10.20 requires under
  `--deny-warn`; CI now pins `0.10.20+65efd5b93`.
- Added `search_sequence_counterexample`, which runs seeded random inputs at
  `TraceLevel::Count`, shrinks the first failure, and diagnoses the minimal
  input against a reference algorithm or the sorted-output property.
  `match_events` also reports algorithms whose operations differ from the
  reference while their outputs agree.
- Added the `search` CLI command and built-in `faulty-insertion-sort`,
  `lossy-insertion-sort`, `faulty-quick-sort`, and `shift-insertion-sort`
  algorithms; a found counterexample exits with code 2.
- Added the `examples/counterexample_search` example.
- The `sequence-transition`, `sorted-int-sequence`, and `insertion-sort-int`
  contracts now accept `Update` steps that change only their target to the
  recorded value, and the sorting contracts reject results that are not a
  permutation of the input. The Playground uses the same rules.
- `TracedArray::swap` now records the lower position first, so `swap(i, j)`
  and `swap(j, i)` record the same step.
- Added complexity profiling: `profile_complexity` and `profile_traced_array`
  measure operation counts across input sizes, fit O(1) through O(2^n) by
  relative least squares, and report the empirical log-log exponent.
- Added `ComplexityProfile::check_bound` for deterministic complexity bounds
  in tests and CI, plus Markdown reports.
- Added `measure_tracing_overhead`, which times an algorithm at the `Off`,
  `Count`, and `Full` levels with a caller-supplied clock and reports ratios,
  per-step cost, and trace size.
- Added `OperationCounts::new` for profiling algorithms measured without
  `TracedArray`.
- Added the `examples/complexity_profile` example and measured results in
  `BENCHMARKS.md`.
- Added `PhaseTimer` and an optional `timer` argument to `diagnose_trace`,
  which records the contract check, divergence search, state diffs, and
  counterexample slice as separate phases.
- Added `ComplexityClass::parse` for labels such as `O(n log n)` and `n^2`.
- Added `diagnose --timings`, which reports per-phase time for reading,
  decoding, validating, diagnosing, and rendering, in text or as
  `result.timings` in JSON.
- Added the `profile` CLI command: complexity profiles of built-in
  `TracedArray` sorts on random, sorted, or reversed input, with `--bound`
  checks that exit with code 2 on violation and optional `--overhead`
  timing.

## 0.10.0 - 2026-10-31

- Added `TracedArray[T]`, an array whose `less`, `compare`, `swap`, and
  indexed writes record `Compare`, `Swap`, and `Update` events, so array
  algorithms are traced without `TraceBuilder` code.
- Added `SequenceProbe[T]`, which infers `Swap`, `Update`, and `Custom`
  move/insert/remove/edit events from value snapshots and keeps element ids
  stable across moves.
- Added `TraceLevel` (`Full`, `Count`, `Off`) and `OperationCounts` for
  counting compares, swaps, reads, and writes with or without recording.
- Added the `examples/traced_sort` executable example.
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
