# 01 — Getting it running

The one page in this directory written by a person. Everything on it that can
be run is checked against the tree by `tests/walkthrough/test_walkthrough.gd`:
a build target this page names must be one `tools/build.sh` has, a script it
names must exist, a `res://` path it names must resolve. The prose is prose and
ages the way prose does; the commands cannot.

The pages after this one are not written by anyone. The test suite writes them,
from itself, every time it runs — [the index](README.md) says how.

## What you need

- **Godot, at the pinned version.** The pin is in `.godot-version`; the first
  suite (`tests/test_bootstrap.gd`) refuses any other engine, and so does the
  build script. Do not upgrade it inside a feature branch: an engine change is
  its own decision with a full export pass (ADR-008).
- **Git LFS**, before you touch art: `.blend` and audio sources are LFS-tracked.
- A JDK 17+ and the Android SDK only if you want the APK; `tools/build.sh`
  finds both where Android Studio puts them.

## The first run

Open `project.godot` in the editor and press play, or from a shell:

```sh
"$GODOT_BIN" --path . res://ui/menu/main_menu.tscn
```

You are on defence. The game's golfer is addressing a ball down the range; the
bow is in your hands; the switch in the corner hands you the club whenever you
want it. Leave it alone for a few seconds and the camera goes for a walk around
you. That is the whole game as it stands, and
[the next page](02-the-first-thing-you-see.md) is the suite's account of what
you are looking at.

## The suite

gdUnit4 is vendored under `addons/`, so this is the whole command:

```sh
GODOT_BIN=/path/to/godot ./addons/gdUnit4/runtest.sh --add res://tests --continue
```

Run it with a display — the ordinary way — and it also records the pictures
the walkthrough embeds, and rewrites the walkthrough's pages. If `git status`
then shows a change under `walkthrough/`, the suite is telling you the
documentation moved with your change; commit both. CI runs the same suite
headless on Linux, Windows and macOS, and fails if the pages it writes differ
from the ones committed.

## The demo round

The second gate. It plays a round headless and exits non-zero if any stroke
fails to replay to its own hash, if the round on disk differs from the round
that was played, or if a defender's verdict is not reproducible from its seed:

```sh
"$GODOT_BIN" --headless --fixed-fps 120 --path . res://tools/demo_round.tscn
```

`--fixed-fps` decouples the physics from the wall clock; without it a few
strokes take minutes.

## The document gates

The two planning documents move together, and the version is stated in four
places that have to agree. Both are checked, not remembered:

```sh
python tools/check_docs_consistency.py
python tools/check_version_consistency.py
```

## Building it

Debug builds, all of them, from one script that installs the export templates
if they are missing:

```sh
tools/build.sh                                    # all five, into build/
tools/build.sh windows linux linux-arm64 android  # what CI builds on every pull request
tools/build.sh macos                              # local only; nobody here can open one
```

The Linux arm64 build is the Raspberry Pi 5's, and ships with an `override.cfg`
beside the binary that starts it on the Compatibility renderer; the file's
header says why, and that it is provisional. A `v*` tag publishes the same four
archives as a pre-release on the releases page —
[`docs/RELEASE.md`](../docs/RELEASE.md) is the checklist that comes before the
tag.

## Where things are

| Path | What lives there |
|---|---|
| `core/` · `holes/` · `clubs/` · `defenders/` · `ui/` | The game |
| `records/` | Stroke records: the wire format, canonical bytes, the schema |
| `tests/` | The gdUnit4 suites — and, since every page after this one is written from them, the documentation |
| `walkthrough/` | This. Generated except for this page; do not edit the others |
| `docs/` | `DESIGN.md` (the plan of record), `DECISIONS.md` (every ratified decision and why), `HANDOFF.md` (the only cross-session memory), `LANES.md` (the board) |
| `tools/` | `build.sh`, the demo round, the checks CI runs |

---

[Index](README.md) · [02 — The first thing you see](02-the-first-thing-you-see.md) →
