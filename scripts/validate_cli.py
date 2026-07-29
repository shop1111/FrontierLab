#!/usr/bin/env python3
"""Exercise FrontierLab CLI exit semantics through the real process boundary."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "_build" / "cli-validation"
EXPECTED = ROOT / "fixtures" / "agent-traces" / "selection-sort-expected.json"
ACTUAL = ROOT / "fixtures" / "agent-traces" / "selection-sort-actual.json"
BASE = ["moon", "run", "cmd/main", "--"]


def run_case(name: str, args: list[str], expected_exit: int) -> None:
    result = subprocess.run(
        BASE + args,
        cwd=ROOT,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.returncode != expected_exit:
        raise AssertionError(
            f"{name}: expected exit {expected_exit}, got {result.returncode}\n"
            f"{result.stdout}"
        )
    print(f"PASS {name}: exit {result.returncode}")


def main() -> int:
    WORK.mkdir(parents=True, exist_ok=True)
    malformed = WORK / "malformed.json"
    malformed.write_text("{", encoding="utf-8")
    unsupported = WORK / "unsupported-schema.json"
    document = json.loads(EXPECTED.read_text(encoding="utf-8"))
    document["schema_version"] = "2.0"
    unsupported.write_text(json.dumps(document), encoding="utf-8")

    run_case("missing diagnose arguments", ["diagnose"], 1)
    run_case("unknown command", ["unknown"], 1)
    run_case(
        "unknown format",
        [
            "diagnose",
            str(EXPECTED),
            str(EXPECTED),
            "--contract",
            "sequence-transition",
            "--object",
            "values",
            "--format",
            "xml",
        ],
        1,
    )
    run_case(
        "invalid number",
        ["render", str(EXPECTED), "--step", "not-a-number"],
        1,
    )
    run_case("missing file", ["validate", str(WORK / "missing.json")], 1)
    run_case("malformed JSON", ["validate", str(malformed)], 1)
    run_case("unsupported schema", ["validate", str(unsupported)], 1)
    run_case(
        "unwritable output target",
        ["playground", "--output", str(WORK)],
        1,
    )
    run_case(
        "successful diagnosis",
        [
            "diagnose",
            str(EXPECTED),
            str(EXPECTED),
            "--contract",
            "sequence-transition",
            "--object",
            "values",
            "--format",
            "json",
        ],
        0,
    )
    run_case(
        "contract failure",
        [
            "verify",
            str(ACTUAL),
            "--contract",
            "insertion-sort-int",
            "--object",
            "values",
            "--format",
            "json",
        ],
        2,
    )
    run_case(
        "first divergence",
        [
            "diagnose",
            str(EXPECTED),
            str(ACTUAL),
            "--contract",
            "sequence-transition",
            "--object",
            "values",
            "--format",
            "json",
        ],
        2,
    )
    print("CLI process matrix: PASS (11/11)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
