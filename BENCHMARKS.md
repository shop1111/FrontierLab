# Reproducible Benchmarks

Measured on Windows with `moonc 0.10.4+2cc641edf`, native debug target, using
one sequence entity and full scene snapshots. Times are milliseconds from one
local run on 2026-07-29; rerun before quoting results on another machine.

```bash
moon run bench --target native -- 100 1000 10000 50000
```

| Steps | Build | Encode | Decode | HTML | Diff | Contract | Divergence | JSON bytes | HTML bytes |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 100 | 0 | 2 | 2 | 2 | 0 | 0 | 0 | 44,340 | 53,601 |
| 1,000 | 3 | 17 | 21 | 21 | 0 | 0 | 1 | 440,340 | 449,601 |
| 10,000 | 22 | 175 | 213 | 188 | 0 | 4 | 8 | 4,409,340 | 4,418,601 |
| 50,000 | 123 | 901 | 1,102 | 1,003 | 0 | 21 | 49 | 22,089,340 | 22,098,601 |

Peak working set for the process running all four cases was approximately
304 MiB; this is a process-wide high-water mark, not a per-case allocation
measurement. The 50,000-step case uses explicit `TraceOptions` for both build
and decode. CI only runs 100/1,000-step correctness smoke tests and intentionally
has no fragile millisecond threshold.

`Diff` compares the final two frames, `Contract` runs sequence-transition over
the complete trace, and `Divergence` compares the trace with itself. Schema v1
uses complete snapshots, so JSON/HTML size grows roughly linearly.
