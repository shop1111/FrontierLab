# Reproducible Benchmarks

Measured on Windows with MoonBit `0.1.20260608`, native target, using one sequence entity and full scene snapshots. Times are milliseconds from one local run; rerun before quoting results on another machine.

```bash
moon run bench --target native
```

| Steps | Build | Encode | Decode | HTML | Diff | Contract | Divergence | JSON bytes | HTML bytes |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 100 | 2 | 0 | 2 | 1 | 0 | 0 | 0 | 44,340 | 53,601 |
| 1,000 | 2 | 16 | 19 | 18 | 0 | 0 | 1 | 440,340 | 449,601 |
| 10,000 | 28 | 205 | 193 | 179 | 0 | 3 | 7 | 4,409,340 | 4,418,601 |

`Diff` compares the final two frames, `Contract` runs the sequence-transition contract over the complete trace, and `Divergence` compares the trace with itself. These results demonstrate bounded operation at the default 10,000-step limit; they are not cross-machine performance guarantees. The logical v1 model intentionally uses complete snapshots, while compressed transport remains a later schema-compatible layer.
