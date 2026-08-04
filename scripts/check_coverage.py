#!/usr/bin/env python3
"""Run FrontierLab's portable line-coverage gate."""

from __future__ import annotations

import fnmatch
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "coverage-exemptions.json"
REPORT_PATH = ROOT / "_build" / "coverage-gate.txt"
FILE_LINE = re.compile(r"^(\d+) uncovered line\(s\) in (.+):$")


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    print(result.stdout, end="")
    return result


def main() -> int:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    test = run(
        [
            "moon",
            "test",
            "--target",
            "native",
            "--enable-coverage",
            "--deny-warn",
        ]
    )
    if test.returncode != 0:
        return test.returncode

    analysis = run(["moon", "coverage", "analyze"])
    if analysis.returncode != 0:
        return analysis.returncode
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(analysis.stdout, encoding="utf-8")

    uncovered: dict[str, int] = {}
    for line in analysis.stdout.splitlines():
        match = FILE_LINE.match(line)
        if match:
            path = match.group(2).replace("\\", "/")
            uncovered[path] = int(match.group(1))

    exempted: dict[str, tuple[int, str]] = {}
    for path, count in uncovered.items():
        for item in config["exemptions"]:
            if fnmatch.fnmatch(path, item["pattern"]):
                exempted[path] = (count, item["reason"])
                break

    raw_total = sum(uncovered.values())
    exempted_total = sum(item[0] for item in exempted.values())
    adjusted_total = raw_total - exempted_total
    maximum = int(config["maximum_uncovered_lines"])
    protected_failures = {
        path: uncovered.get(path, 0)
        for path in config["protected_files"]
        if uncovered.get(path, 0) != 0
    }

    print("\nFrontierLab coverage gate")
    print(f"  raw uncovered:      {raw_total}")
    print(f"  exempted boundary:  {exempted_total}")
    print(f"  counted uncovered:  {adjusted_total}/{maximum}")
    for path, (count, reason) in sorted(exempted.items()):
        print(f"  exempt {path}: {count} ({reason})")

    if protected_failures:
        for path, count in protected_failures.items():
            print(f"ERROR: protected core file {path} has {count} uncovered lines")
    if adjusted_total > maximum:
        print(
            f"ERROR: counted uncovered lines {adjusted_total} exceed limit {maximum}"
        )
    if protected_failures or adjusted_total > maximum:
        return 1
    print("Coverage gate: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
