# FrontierLab v0.7.0 candidate validation

Validation date: 2026-07-29 (Asia/Shanghai)  
Branch: `codex/frontierlab-v0.7.0-sprint`  
Pinned compiler: `moonc v0.10.4+2cc641edf`  
v0.6.1 candidate: `fe75f65dadb1fb0ab4f517240729bf838c7134c4`

The final v0.7.0 candidate SHA is intentionally reported in the handoff because
it is the commit that contains this file.

## Root module gates

| Command | Result |
|---|---|
| `moon check --target all --deny-warn` | PASS |
| `moon build --target all --deny-warn` | PASS |
| `moon fmt --check` | PASS |
| `moon info` | PASS |
| `moon test --target all --deny-warn` | PASS, 65/65 on wasm, wasm-gc, js, native |
| `python scripts/check_coverage.py` | PASS |
| `python scripts/validate_cli.py` | PASS, 11/11 process cases |
| `moon package --list` | PASS, consumer and application paperwork absent |
| `moon package` | PASS, `shop1111-frontierlab-0.7.0.zip` (136,270 bytes) |

`moon info` changed the root public interface only by adding the optional
`TraceOptions` parameter to `AlgorithmTrace::decode_json`; calls that omit it
remain source compatible.

## Coverage

- Raw uncovered lines: 111.
- Documented thin-boundary exemptions: 91.
- Counted uncovered lines: 20/20.
- `trace_debugger.mbt`: 0.
- `trace_contracts.mbt`: 0.
- `trace_codec.mbt`: 0.
- `trace_reports.mbt`: 0.
- `trace_quality.mbt`: 0.

The exact patterns and reasons are checked from `coverage-exemptions.json`.

## Diagnosis evidence

The frozen selection-sort failure produced:

```text
failure_exit=2
contract_passed=false
contract_failure_step=13
first_divergence_step=10
focus_step=10
counterexample_range=8..12
```

Diagnosing expected against itself produced exit 0, `ok=true`, focus `-1`.
The real-process matrix also verified missing arguments, unknown command,
unknown format, invalid number, missing file, malformed JSON, unsupported
Schema, unwritable output, success, contract failure, and first divergence.

## Independent published-package consumer

Inside `consumer/frontierlab_consumer_demo`:

- `moon tree` resolved `shop1111/frontierlab@0.6.0` from Mooncakes.
- No local override or copied FrontierLab source exists.
- `moon check --target all --deny-warn` passed.
- `moon test --target all --deny-warn` passed 2/2 on all four backends.
- `moon run . -- evidence` reproduced step 10 and the failing final contract.

## Browser and offline checks

The generated `docs/playground.html` was opened through a local static server
and verified in the browser:

- Default Faulty selection sort required one Run diagnosis click.
- It focused step 10 and displayed expected/actual swaps, state changes,
  contract failure, and counterexample 8..12.
- Correct selection sort returned PASS with no divergence.
- Custom actual without expected displayed SKIPPED for divergence.
- Counterexample/report/repair actions showed visible in-page feedback.
- At 390 x 844 the layout used one column with no horizontal overflow.
- No external script was present; the page continued to work offline.

## Benchmark

`moon run bench --target native -- 100 1000 10000 50000` passed. The 50,000
step row recorded 123 ms build, 901 ms encode, 1,102 ms decode, 1,003 ms HTML,
22,089,340 JSON bytes, and 22,098,601 HTML bytes. Process peak working set for
the four-case run was approximately 304 MiB. No timing threshold is enforced.

## Remote safety

Read-only verification found both remote branches still at the original
baseline:

```text
GitHub main:    26814a6abed16bee040cdd8b0c097708a1b58988
Gitlink master: 26814a6abed16bee040cdd8b0c097708a1b58988
```

No push, tag, release, Mooncakes publish, or Pages deployment was performed.
