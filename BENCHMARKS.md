# Reproducible Benchmarks

Measured on Windows with MoonBit `0.1.20260608`, native target, using one sequence entity and full scene snapshots. Times are milliseconds from one local run; rerun before quoting results on another machine.

```bash
moon run bench --target native
```

| Steps | Build | Encode | Decode | HTML | JSON bytes | HTML bytes |
|---:|---:|---:|---:|---:|---:|---:|
| 100 | 0 | 1 | 0 | 0 | 44,431 | 53,692 |
| 1,000 | 0 | 24 | 20 | 15 | 442,231 | 451,492 |
| 10,000 | 27 | 170 | 250 | 200 | 4,438,231 | 4,447,492 |

These results demonstrate bounded operation at the default 10,000-step limit. They are not cross-machine performance guarantees. The logical v1 model intentionally uses complete snapshots; compressed transport is deferred to a later schema-compatible layer.
