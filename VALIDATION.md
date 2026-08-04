# FrontierLab v0.7.0 candidate validation

- Validation date: 2026-08-04 (Asia/Shanghai)
- Branch: `codex/frontierlab-v0.7.0-sprint`
- Pinned compiler: `moonc v0.10.4+2cc641edf`
- v0.6.1 candidate: `fe75f65dadb1fb0ab4f517240729bf838c7134c4`
- Pre-hardening v0.7.0 anchor: `0902c54333d9c3f66ed15432311a5af54351ff2e`

The final v0.7.0 candidate SHA is intentionally reported in the handoff because
it is the commit that contains this file. The complete command output is kept
locally in `_build/validation-v0.7.0-rc.txt`.

## Root module gates

| Command | Result |
|---|---|
| `moon check --target all --deny-warn` | PASS |
| `moon build --target all --deny-warn` | PASS |
| `moon fmt --check` | PASS |
| `moon info` | PASS |
| `moon test --target all --deny-warn` | PASS, 71/71 on wasm, wasm-gc, js, native |
| `python scripts/validate_cli.py` | PASS, 12/12 process cases |
| `python scripts/check_coverage.py` | PASS, 6/10 counted uncovered lines |
| `node scripts/check_playground.mjs` | PASS |
| `python scripts/build_cli.py` | PASS |
| `moon package --list` | PASS, consumer, local application paperwork, and `_dist` absent |
| `moon package` | PASS, `shop1111-frontierlab-0.7.0.zip` (217,604 bytes) |

`moon info` changed the root public interface by exactly four approved additions:
`TraceDiagnosis`, `diagnose_trace`, `TraceDiagnosis::passed`, and
`sorted_int_sequence_contract`. The command package interface is unchanged.

## Coverage

- Raw uncovered lines: 34.
- Documented thin-boundary exemptions: 28.
- Counted uncovered lines: 6/10.
- `trace_debugger.mbt`: 0.
- `trace_contracts.mbt`: 0.
- `trace_codec.mbt`: 0.
- `trace_reports.mbt`: 0.
- `trace_quality.mbt`: 0.
- `trace_diagnosis.mbt`: 0.
- `cmd/main/cli_run.mbt`: 0.
- `cmd/main/cli_execution.mbt`: 0.

Only the operating-system entry, benchmark entry, and executable examples are
exempt. Their exact patterns and reasons are checked from
`coverage-exemptions.json`.

## Diagnosis evidence

The shared selection-sort fixture produced the same golden result through the
MoonBit facade, CLI, and browser core:

```text
failure_exit=2
contract_passed=false
contract_failure_step=13
first_divergence_step=10
focus_step=10
focused_slice=8..12
counterexample_kind=focused-window
```

Diagnosing the expected trace against itself produced exit 0, `ok=true`, focus
`-1`, and no slice. Without an expected trace, divergence was explicitly
skipped while the contract still ran. The CLI process matrix also verified
missing arguments, unknown command, unknown format, invalid number, missing
file, malformed JSON, unsupported Schema, unwritable output, success, contract
failure, and first divergence.

## Independent published-package consumer

Inside `consumer/frontierlab_consumer_demo`:

- `moon tree` resolved `shop1111/frontierlab@0.6.0` from Mooncakes.
- No local override or copied FrontierLab source exists.
- `moon check --target all --deny-warn` passed.
- `moon test --target all --deny-warn` passed 2/2 on all four backends.
- The frozen evidence still reproduces step 10 and the failing final contract.

## Browser and offline checks

The generated `docs/playground.html` was opened through a local static server
and verified in the in-app browser:

- Default Faulty selection sort required one Run diagnosis click.
- It focused step 10 and displayed expected/actual swaps, the actual transition,
  the reference difference, contract failure, and focused slice 8..12.
- Correct selection sort returned PASS with no divergence or slice.
- Custom actual without expected displayed skipped divergence.
- Generic sorted-sequence and real grid-path contracts both ran in the Clinic.
- Semantic comparison ignored JSON object-key ordering.
- Duplicate IDs, dangling references, invalid grid/highlight/event data, and
  configured resource limits were rejected visibly.
- SVG titles were XML escaped, reports used an offline CSP, and repair prompts
  placed trace evidence inside an explicit untrusted-data boundary.
- A 10,000-step trace rendered at most 101 timeline nodes while its slider
  retained the complete range.
- Focused-slice/report/repair actions showed visible in-page feedback.
- At 390 px width the layout used one column with no horizontal overflow.
- The page contained one inline script, no external assets, and no external
  network request path.

## Local executable

`python scripts/build_cli.py` created the ignored local artifact:

```text
_dist/frontierlab.exe
size=738816
sha256=e75d3bf0ce6afa096f1cbf0fd892a20dcf3cd2bcb2267ce5ff311372a29f7f1e
```

The build script also ran `frontierlab.exe --version`. No binary is included in
the package or repository.

## Benchmark

`moon run bench --target native -- 100 1000 10000 50000` passed. The 50,000
step row recorded 119 ms build, 950 ms encode, 1,186 ms decode, 1,025 ms HTML,
22,089,340 JSON bytes, and 22,098,601 HTML bytes. The process-tree peak working
set for the four-case run was approximately 278.1 MiB. No timing threshold is
enforced; full data and measurement scope are in `BENCHMARKS.md`.

## Remote safety

Read-only verification found both remote branches still at the original
baseline:

```text
GitHub main:    26814a6abed16bee040cdd8b0c097708a1b58988
Gitlink master: 26814a6abed16bee040cdd8b0c097708a1b58988
```

No `v0.7.0` tag exists locally. No push, tag, release, Mooncakes publish, or
Pages deployment was performed.
