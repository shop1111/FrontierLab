# Reproducible Benchmarks

Measured on Windows with `moonc 0.10.18+6c83a7f62`, native debug target, using
one sequence entity and full scene snapshots. Times are milliseconds from one
local run on 2026-10-31; rerun before quoting results on another machine.

```bash
moon run bench --target native -- 100 1000 10000 50000
```

| Steps | Build | Encode | Decode | HTML | Diff | Contract | Divergence | JSON bytes | HTML bytes |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 100 | 1 | 1 | 2 | 2 | 0 | 0 | 0 | 44,340 | 81,519 |
| 1,000 | 3 | 17 | 21 | 18 | 0 | 0 | 2 | 440,340 | 477,519 |
| 10,000 | 28 | 149 | 177 | 176 | 0 | 4 | 10 | 4,409,340 | 4,446,519 |
| 50,000 | 196 | 875 | 898 | 936 | 0 | 22 | 60 | 22,089,340 | 22,126,519 |

HTML bytes grew by a constant ~28 KB per page against the 0.10.4 run because
the v0.9.1 player embeds more styles and scripts; trace data size is unchanged.
Memory was not re-measured for this run. The 50,000-step case uses explicit
`TraceOptions` for both build
and decode. CI only runs 100/1,000-step correctness smoke tests and intentionally
has no fragile millisecond threshold.

`Diff` compares the final two frames, `Contract` runs sequence-transition over
the complete trace, and `Divergence` compares the trace with itself. Schema v1
uses complete snapshots, so JSON/HTML size grows roughly linearly.
