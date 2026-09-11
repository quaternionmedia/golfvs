#!/usr/bin/env python3
"""Keep the version the same in every place that states it.

docs/RELEASE.md has carried this as a checklist item -- "Version, in three
places that have to agree" -- since the first build was published. A checklist
item is a hope. This is the same move ADR-006 made for DESIGN.md and
DECISIONS.md: the thing a person was asked to remember becomes a thing a machine
refuses to let past.

Four places now, since the macOS preset landed:

  1. project.godot          config/version                     -- the source
  2. export_presets.cfg     application/file_version           -- Windows
                            application/product_version        -- Windows
                            version/name                       -- Android
                            application/short_version          -- macOS
                            application/version                -- macOS
  3. CHANGELOG.md           the topmost released heading
  4. the tag                when run on one

Only the *numeric core* has to match. project.godot may carry a milestone
suffix ("0.0.1-m0"); Windows and Android both reject anything but numerals and
periods, which is why those presets state the bare number and why this check
compares 0.0.1 to 0.0.1 rather than demanding four identical strings.

    python tools/check_version_consistency.py
    python tools/check_version_consistency.py --tag v0.0.1
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

PROJECT = Path("project.godot")
PRESETS = Path("export_presets.cfg")
CHANGELOG = Path("CHANGELOG.md")

# `key="value"` at the start of a line. Anchoring matters: both files are
# heavily commented and several comments quote a version string.
def field(text: str, key: str) -> str | None:
    m = re.search(rf'^{re.escape(key)}="([^"]*)"$', text, re.MULTILINE)
    return m.group(1) if m else None


def all_fields(text: str, key: str) -> list[str]:
    return re.findall(rf'^{re.escape(key)}="([^"]*)"$', text, re.MULTILINE)


# "0.0.1" out of "0.0.1-m0", "v0.0.1-test" or "0.0.1".
CORE = re.compile(r"(\d+(?:\.\d+)*)")

# "## [0.0.1] — 2026-09-09", but never "## [Unreleased]".
RELEASED_HEADING = re.compile(r"^##\s*\[(\d+(?:\.\d+)*)\]", re.MULTILINE)

# Every preset key that states a human-facing version. `version/code` is
# deliberately absent: it is Android's monotonic build number, an integer that
# is *supposed* to move independently of the version name.
PRESET_KEYS = (
    "application/file_version",
    "application/product_version",
    "version/name",
    "application/short_version",
    "application/version",
)


def core_of(value: str, what: str, errors: list[str]) -> str | None:
    m = CORE.search(value)
    if not m:
        errors.append(f"{what} is {value!r}, which contains no version number.")
        return None
    return m.group(1)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--tag",
        default="",
        help="Tag to check too, e.g. v0.0.1. Defaults to GITHUB_REF_NAME on a tag build.",
    )
    args = ap.parse_args()

    errors: list[str] = []

    for path in (PROJECT, PRESETS, CHANGELOG):
        if not path.is_file():
            errors.append(f"{path} is missing.")
    if errors:
        for e in errors:
            print(f"FAIL: {e}", file=sys.stderr)
        return 1

    project_text = PROJECT.read_text(encoding="utf-8")
    presets_text = PRESETS.read_text(encoding="utf-8")
    changelog_text = CHANGELOG.read_text(encoding="utf-8")

    declared = field(project_text, "config/version")
    if declared is None:
        print(
            "FAIL: project.godot has no config/version. It is the source every "
            "other version is checked against; it cannot be absent.",
            file=sys.stderr,
        )
        return 1

    expected = core_of(declared, "project.godot config/version", errors)
    if expected is None:
        for e in errors:
            print(f"FAIL: {e}", file=sys.stderr)
        return 1

    # --- 2. Every export preset states the same number ----------------------
    seen_any = False
    for key in PRESET_KEYS:
        values = all_fields(presets_text, key)
        for value in values:
            seen_any = True
            if value != expected:
                errors.append(
                    f"export_presets.cfg {key} is {value!r}, but "
                    f"project.godot says {expected!r}. A build states its own "
                    "version to the operating system; the two must not differ."
                )
    if not seen_any:
        errors.append(
            "no version fields found in export_presets.cfg. Have the preset "
            f"keys changed? Expected one of: {', '.join(PRESET_KEYS)}."
        )

    # --- 3. The changelog's most recent release -----------------------------
    headings = RELEASED_HEADING.findall(changelog_text)
    if not headings:
        errors.append(
            "CHANGELOG.md has no released version heading. An [Unreleased] "
            "section alone does not say what the build in hand is."
        )
    elif headings[0] != expected:
        errors.append(
            f"CHANGELOG.md's most recent release is {headings[0]!r}, but the "
            f"project version is {expected!r}. Either the changelog is missing "
            "a section for this version, or the version was bumped without one."
        )

    # --- 4. The tag, when there is one --------------------------------------
    tag = args.tag
    if not tag and os.environ.get("GITHUB_REF_TYPE") == "tag":
        tag = os.environ.get("GITHUB_REF_NAME", "")
    if tag:
        tag_core = core_of(tag, f"tag {tag!r}", errors)
        if tag_core is not None and tag_core != expected:
            errors.append(
                f"tag {tag!r} carries version {tag_core!r}, but the tree says "
                f"{expected!r}. ADR-002 makes releases canonical; a tag that "
                "disagrees with what it builds is the worst kind of release."
            )

    if errors:
        for e in errors:
            print(f"FAIL: {e}", file=sys.stderr)
        print(f"\n{len(errors)} problem(s) found.", file=sys.stderr)
        return 1

    where = "4 places" if tag else "3 places"
    print(f"OK: version {expected} agrees across {where}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
