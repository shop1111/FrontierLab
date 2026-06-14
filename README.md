# FrontierLab

FrontierLab is a MoonBit path-search visualization and algorithm teaching lab.
It focuses on how the `frontier` or `open set` evolves while BFS, Dijkstra,
and A* explore a two-dimensional grid.

This project is intentionally not a general graph algorithm library. The first
version focuses on:

- `GridMap` for weighted two-dimensional maps with obstacles.
- Search traces for every step of BFS, Dijkstra, and A*.
- ASCII and SVG exports for local teaching examples.
- Lightweight comparison reports across the supported algorithms.

## Status

The project is in early contest development. The core library, tests, and
terminal examples are already usable; later work may add a Wasm or browser
playground after the API settles.

## Public API Overview

Core map types:

- `Position::new(x, y)`
- `GridMap::new(width, height)`
- `GridMap::with_obstacle(position)`
- `GridMap::with_weight(position, weight)`
- `GridMap::neighbors(position, FourDirections | EightDirections)`

Search APIs:

- `bfs(...)` and `bfs_trace(...)`
- `dijkstra(...)` and `dijkstra_trace(...)`
- `astar(...)` and `astar_trace(...)`
- `heuristic_distance(Manhattan | Chebyshev | Zero, from, to)`

Trace and report types:

- `PathResult`
- `TraceStep`
- `SearchTrace`
- `AlgorithmReport`
- `CompareReport`

Exports:

- `export_ascii(...)`
- `export_svg(...)`
- `compare_algorithms(...)`

## Examples

```bash
moon run examples/maze_bfs
moon run examples/weighted_astar
moon run examples/compare
```

The examples are intentionally small and terminal-friendly. They are meant to
make the frontier visible before adding a future Wasm or HTML playground.

## Differentiation

FrontierLab is built for teaching search behavior, not for being the broadest
graph toolkit. The central artifact is the trace: every algorithm records the
current node, frontier, visited set, cost table, and parent links so the search
process can be replayed, exported, and compared.

That makes it useful for contest demos, classroom explanations, and MoonBit
library examples where the important question is not only "what path was found"
but also "how did the algorithm discover it".

## Development

```bash
moon check
moon test
moon fmt
moon info
```

## Current Non-goals

- No arbitrary graph abstraction in the first version.
- No Wasm or browser playground until the core API is stable.
