#!/usr/bin/env python3
"""Keep DESIGN.md and DECISIONS.md in step.

ADR-006 makes "assistants draft, humans ratify" mechanical rather than cultural.
The mechanism is this check, run on every pull request. It enforces four things:

  1. Coupling      -- a change to DESIGN.md must arrive with a change to
                      DECISIONS.md. Scope does not move without a rationale.
  2. Resolvable    -- every ADR-nnn cited in DESIGN.md exists in the log.
  3. Not stale     -- a [RATIFIED ADR-nnn] tag never points at a superseded ADR.
  4. Well-formed   -- ADR ids in the log are unique and ascending.
  5. Documents exist -- every UPPERCASE .md document either file cites is
                      actually in the tree.
  6. Proposals agree -- DESIGN.md's [PROPOSED] tags and DECISIONS.md's pending
                      list are the same length.

Checks 5 and 6 were added after a review found both of their failure modes live
in the tree at once: docs/ONBOARDING.md was cited four times and did not exist,
and the only thing keeping the two proposal lists in step was someone counting
them by hand.

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

# A cited planning document: "docs/ONBOARDING.md", or a bare "ART_PIPELINE.md"
# as they appear inside the layout block in DESIGN.md section 7. Only SHOUTING
# names match, which is what every document in docs/ is called -- keeping the
# check to zero false positives against prose that happens to mention a file.
DOC_REF = re.compile(r"(?:docs/)?([A-Z][A-Z0-9_]{2,}\.md)")

# A real proposal is a bullet in a "**Decisions**" block. The two other
# appearances of the tag -- the legend at the top of DESIGN.md and Appendix A's
# instruction to ratify them all -- are about proposals, not proposals
# themselves, and anchoring on "- `[PROPOSED]`" excludes both.
PROPOSAL = re.compile(r"^- `\[PROPOSED\]`")

# Documents that are cited but deliberately absent, each with the decision that
# has to be taken before the entry can go. This is a debt list, not a mute
# switch: an entry here is a promise that a human is going to resolve it.
GRANDFATHERED_DOCS: dict[str, str] = {}


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


def check_cited_documents() -> int:
    """Every UPPERCASE .md document either planning file cites must exist.

    A citation of a document that was never written is worse than no citation:
    the reader who follows it concludes the spec is somewhere they have not
    looked, rather than that it does not exist. The ADR reference check has
    caught the same class of problem for decisions since M0; this extends it to
    the documents those decisions point at.
    """
    errors = 0
    for source in (DESIGN, DECISIONS):
        cited = sorted(set(DOC_REF.findall(source.read_text(encoding="utf-8"))))
        for name in cited:
            if (Path("docs") / name).is_file() or Path(name).is_file():
                continue
            if name in GRANDFATHERED_DOCS:
                print(f"note: {source} cites docs/{name}, which does not exist "
                      f"-- grandfathered: {GRANDFATHERED_DOCS[name]}")
                continue
            fail(
                f"{source} cites docs/{name}, which is not in the tree. Write "
                "it, remove the citation, or add it to GRANDFATHERED_DOCS with "
                "the decision that will resolve it."
            )
            errors += 1

    # A grandfathered entry is a debt, so it has to expire. Once the document
    # exists, the entry is what is now wrong.
    for name in GRANDFATHERED_DOCS:
        if (Path("docs") / name).is_file():
            fail(
                f"docs/{name} now exists, so its GRANDFATHERED_DOCS entry in "
                f"{Path(__file__).as_posix()} is stale. Delete the entry."
            )
            errors += 1
    return errors


def check_proposals_agree() -> int:
    """DESIGN.md's [PROPOSED] bullets and DECISIONS.md's pending list agree.

    The two lists are maintained by hand in different files and nothing but
    care has kept them the same length. Counting is a weaker check than
    matching them item by item, but the pending list abbreviates every entry
    ("async-only, no live play" for a bullet three times that long), so pairing
    them textually would fail on wording rather than on substance. A count
    catches the failure that actually happens: a proposal added to one file and
    forgotten in the other.
    """
    design = DESIGN.read_text(encoding="utf-8")
    decisions = DECISIONS.read_text(encoding="utf-8")

    tagged = sum(1 for line in design.splitlines() if PROPOSAL.match(line))

    pending = decisions.split("## Pending ratification", 1)
    if len(pending) < 2:
        fail(f"{DECISIONS} has no '## Pending ratification' section to compare "
             f"{DESIGN}'s {tagged} [PROPOSED] items against.")
        return 1

    body = pending[1]
    # The section is one middot-separated run of names, then any number of
    # sub-groups whose members are bold-led bullets ("- **Wordless first run.**").
    inline = body.split("\n\n", 1)[0]
    listed = len([p for p in inline.split("·") if p.strip()])
    listed += sum(1 for line in body.splitlines() if line.startswith("- **"))

    if listed != tagged:
        fail(
            f"{DESIGN} carries {tagged} [PROPOSED] items but {DECISIONS}'s "
            f"pending list names {listed}. Every proposal appears in both, or "
            "one of them is quietly out of date."
        )
        return 1

    print(f"OK: {tagged} proposals, listed in both documents.")
    return 0


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

    # --- 5. Cited documents exist -------------------------------------------
    errors += check_cited_documents()

    # --- 6. The two proposal lists agree ------------------------------------
    errors += check_proposals_agree()

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
