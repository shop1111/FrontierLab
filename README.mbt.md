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

Local-first development. No remote repository is configured yet.

## Development

```bash
moon check
moon test
moon fmt
moon info
```
