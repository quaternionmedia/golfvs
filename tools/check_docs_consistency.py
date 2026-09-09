#!/usr/bin/env python3
"""Keep DESIGN.md and DECISIONS.md in step.

ADR-006 makes "assistants draft, humans ratify" mechanical rather than cultural.
The mechanism is this check, run on every pull request. It enforces four things:

  1. Coupling      -- a change to DESIGN.md must arrive with a change to
                      DECISIONS.md. Scope does not move without a rationale.
  2. Resolvable    -- every ADR-nnn cited in DESIGN.md exists in the log.
  3. Not stale     -- a [RATIFIED ADR-nnn] tag never points at a superseded ADR.
  4. Well-formed   -- ADR ids in the log are unique and ascending.

Check 1 needs a base ref to diff against and is skipped without one, so the
script is also useful locally:

    python tools/check_docs_consistency.py
    python tools/check_docs_consistency.py --base-ref origin/main
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

DESIGN = Path("docs/DESIGN.md")
DECISIONS = Path("docs/DECISIONS.md")

# "| 009 | 2026-09-03 | Defence re-plans ... | ... | Active |"
ADR_ROW = re.compile(r"^\|\s*(\d{3})\s*\|(.*)\|\s*$")
# Any reference in prose or a status tag: "ADR-009", "[RATIFIED ADR-001]".
ADR_REF = re.compile(r"ADR-(\d{3})")


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)


def parse_adr_log(text: str) -> dict[str, str]:
    """Map ADR id -> status, from the table rows of DECISIONS.md."""
    adrs: dict[str, str] = {}
    for line in text.splitlines():
        m = ADR_ROW.match(line)
        if not m:
            continue
        adr_id = m.group(1)
        cells = [c.strip() for c in m.group(2).split("|")]
        # Date, Decision, Rationale, Status -- status is last.
        status = cells[-1] if cells else ""
        adrs[adr_id] = status
    return adrs


def changed_files(base_ref: str) -> set[str] | None:
    """Paths changed between base_ref and HEAD, or None if the diff fails."""
    try:
        out = subprocess.run(
            ["git", "diff", "--name-only", f"{base_ref}...HEAD"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        print(f"note: could not diff against {base_ref!r} ({exc}); "
              "skipping the coupling check.")
        return None
    return {line.strip() for line in out.splitlines() if line.strip()}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--base-ref",
        default="",
        help="Ref to diff against for the coupling check. Omit to skip it.",
    )
    args = ap.parse_args()

    errors = 0

    for path in (DESIGN, DECISIONS):
        if not path.is_file():
            fail(f"{path} is missing. It is the plan of record; it cannot be absent.")
            errors += 1
    if errors:
        return 1

    design = DESIGN.read_text(encoding="utf-8")
    decisions = DECISIONS.read_text(encoding="utf-8")
    adrs = parse_adr_log(decisions)

    if not adrs:
        fail(f"no ADR rows parsed from {DECISIONS}. Has the table format changed?")
        return 1

    # --- 4. Well-formed log -------------------------------------------------
    ids = [
        m.group(1)
        for line in decisions.splitlines()
        if (m := ADR_ROW.match(line))
    ]
    if len(ids) != len(set(ids)):
        dupes = sorted({i for i in ids if ids.count(i) > 1})
        fail(f"duplicate ADR ids in {DECISIONS}: {', '.join(dupes)}")
        errors += 1
    if ids != sorted(ids):
        fail(f"ADR ids in {DECISIONS} are not in ascending order: {', '.join(ids)}")
        errors += 1

    # --- 2 & 3. References resolve, and are not stale -----------------------
    for adr_id in sorted(set(ADR_REF.findall(design))):
        status = adrs.get(adr_id)
        if status is None:
            fail(
                f"{DESIGN} cites ADR-{adr_id}, which is not in {DECISIONS}. "
                "Every citation must resolve to a logged decision."
            )
            errors += 1
        elif not status.startswith("Active"):
            fail(
                f"{DESIGN} cites ADR-{adr_id}, whose status is {status!r}. "
                "A design document must not lean on a superseded decision."
            )
            errors += 1

    # --- 1. Coupling --------------------------------------------------------
    if args.base_ref:
        changed = changed_files(args.base_ref)
        if changed is not None:
            design_changed = str(DESIGN).replace("\\", "/") in changed
            decisions_changed = str(DECISIONS).replace("\\", "/") in changed
            if design_changed and not decisions_changed:
                fail(
                    "DESIGN.md changed but DECISIONS.md did not. "
                    "Scope does not move without a rationale (ADR-006): add the "
                    "ADR row, or explain in the PR why this edit decides nothing."
                )
                errors += 1

    if errors:
        print(f"\n{errors} problem(s) found.", file=sys.stderr)
        return 1

    print(
        f"OK: {len(adrs)} ADRs logged; "
        f"{len(set(ADR_REF.findall(design)))} cited in DESIGN.md; all resolve and are active."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
