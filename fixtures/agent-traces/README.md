# Trace diagnosis inputs

This directory contains two stable input traces used by CLI, browser, and
cross-backend tests:

- `selection-sort-expected.json`: the correct selection-sort execution;
- `selection-sort-actual.json`: an intentionally incorrect execution that uses
  a stale index during the third pass.

Both files are valid Trace Schema v1 documents. Their first difference is step
10: the expected trace swaps `item-2` with `item-4`, while the incorrect trace
swaps `item-2` with `item-0`.

Generate reports under the ignored `_build/` directory:

```sh
moon run cmd/main -- diagnose \
  fixtures/agent-traces/selection-sort-expected.json \
  fixtures/agent-traces/selection-sort-actual.json \
  --contract sorted-int-sequence \
  --object values \
  --format json \
  --counterexample _build/selection-sort-counterexample.json \
  --report _build/selection-sort-diagnosis.html
```

The command intentionally exits with code `2` because the inputs are valid but
their behavior differs.
