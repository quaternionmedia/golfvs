# golfVs

**Golf is the only sport where nobody is trying to stop you. golfVs fixes that.**

You play golf. Every other sport plays defense. A skeet shooter tries to blast your drive out of the sky.
A bowler rolls a strike across the fairway. An outfielder camps the green to catch your approach for an out.
A hockey goalie guards the cup. You still just have to get the ball in the hole in as few strokes as
possible — but now the course fights back.

And you can switch sides. Defense is a full way to play: set your players, read the golfer, hold the hole.

Caricatured, chunky low-poly characters, one-thumb controls, thirty-second holes, offline by default.

---

## Status

**M0 — Bootstrap,** with M1 to M3 work running ahead of it.

> **What is actually in the box.** Everything above is the pitch. What builds
> today is a **practice range**: three pins, three clubs, one archer, and box art
> standing in for meshes that do not exist. There is **no audio at all**, no
> course, no scoring beyond the card, and no multiplayer of any kind. One of the
> twelve sports in §3 is built. Builds before v0.1.0 are **debug builds** meant
> for finding out what breaks. [`CHANGELOG.md`](CHANGELOG.md) has the honest list.

What is real is the spine: the stroke, the defender framework, a camera you can
orbit, a side you can switch to, and a portable hash-verified record for every
stroke played. What M0 still owes is somebody launching the APK on a phone.

The honest question the project is built toward is still M1's: *is it fun to hit balls at nothing, on a
phone?* Nothing here has been played on one yet.

The plan of record is [`docs/DESIGN.md`](docs/DESIGN.md). What is actually in progress is
[`docs/HANDOFF.md`](docs/HANDOFF.md).

## Engine

**Godot 4.7.2.stable** — pinned, not floated (ADR-008).

The pin is recorded in four places, which must agree: [`.godot-version`](.godot-version) (the machine-readable
source), `project.godot` (`golfvs/engine/pinned_godot_version`), this README, and ADR-008 in
[`docs/DECISIONS.md`](docs/DECISIONS.md). Upgrading the engine is its own ADR with a full export-target test
pass — never a bump inside a feature branch.

## Getting started

```sh
git clone https://github.com/quaternionmedia/golfvs.git
cd golfvs
git lfs install          # required before touching art; binaries are LFS-tracked
```

Open the project in Godot 4.7.2. gdUnit4 is vendored under `addons/` and enabled in `project.godot`, so the
test panel is available on first open.

**New here?** [`walkthrough/`](walkthrough/README.md) is the one path through the game, and every page
after its first is written by the test suite from itself — the prose is each suite's own header, every
line is a test's name linking to its assertion, and the pictures were taken by those tests (ADR-031).
This one is the first frame, as `tests/ui/test_first_run.gd` saw it:

![The first frame, from behind your archer on the tower: the game's golfer at the ball down the range, the switch in the corner](walkthrough/shots/the-first-thing-you-see/opens-on-defence.png)

*Every picture the suite has is on [the walkthrough's index](walkthrough/README.md#as-recorded).*

### Running the tests

```sh
GODOT_BIN=/path/to/godot ./addons/gdUnit4/runtest.sh --add res://tests --continue
```

Run it with a display and it also rewrites `walkthrough/` and records the pictures in it; if `git status`
then shows a change there, commit it with the change that caused it. CI fails if the pages the suite
writes differ from the ones committed.

Then play a round headless. It is a gate, not a showcase — it exits non-zero if a stroke fails to replay to
its own hash, if the round on disk differs from the round played, or if a defender's verdict is not
reproducible from its seed.

```sh
$GODOT_BIN --headless --fixed-fps 120 --path . res://tools/demo_round.tscn
```

### Building it

```sh
tools/build.sh            # all five, into build/
tools/build.sh windows
tools/build.sh linux
tools/build.sh linux-arm64  # Raspberry Pi 5; ships with an override.cfg (Compatibility renderer)
tools/build.sh macos
tools/build.sh android
```

Debug builds, all of them. The script installs the export templates if they are
missing, finds a JDK, makes an Android debug keystore if there isn't one, and
tells Godot where all three are — so the only thing you need in advance is the
engine. `.github/workflows/build.yml` runs the same script for Windows, Linux
(x86_64 and arm64) and Android on every pull request -- the APK is in the run's
artifacts -- and on
a `v*` tag publishes the same four as a **pre-release** on the
[releases page](https://github.com/quaternionmedia/golfvs/releases), where
anyone can download them (ADR-027, revised: the checking happens on the pull
request's artifact, and the tag is the person's act). macOS builds locally
only, unsigned; Gatekeeper will want
`xattr -dr com.apple.quarantine golfVs.app` before it opens.

Nothing is signed for release. There is no release keystore, and there will not
be one until there is something to release. [`docs/RELEASE.md`](docs/RELEASE.md)
is the checklist, and the standing list of what is not ready to be a release yet.

CI runs the suite and the demo round on **Linux, Windows and macOS** on every pull request — the same seed
must hash the same everywhere, and that is the first thing that has ever checked it — plus a check that
`DESIGN.md` and `DECISIONS.md` stay in step, and one that the version agrees with itself.

## Layout

| Path | What lives there |
|---|---|
| `docs/` | The plan of record, the ADR log, the session handoff, the work board, and the two pipeline documents |
| `core/` | `GameState`, `EventBus`, `ShotIntent`, `BallController` — the deterministic simulation |
| `records/` | Stroke, Round and Match Records, `RecordStore`, text notation |
| `async/` | `DefensePlan`, commit-reveal, transports |
| `replay/` | `ReplayController`, ghosts, fork UI |
| `defenders/` | `_base/` plus one folder per sport (scene, profile, models, art card) |
| `tools/` | CI helpers, and `demo_round.tscn` — a whole round played headless |
| `holes/` · `clubs/` | `HoleLayout` and `ClubProfile` resources |
| `art/` · `audio/` | CC-BY-4.0 assets; `.blend` sources under Git LFS |
| `tests/` | gdUnit4 suites and the record fixtures — and the source the walkthrough is written from |
| `walkthrough/` | The documentation, one page per suite, generated on every run; only `01-` is written by hand |

## Documents

| Document | What it is for |
|---|---|
| [`docs/DESIGN.md`](docs/DESIGN.md) | The plan of record. Scope lives here. Every decision carries a status tag. |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | The ADR log — one entry per ratified decision, with its rationale. |
| [`docs/HANDOFF.md`](docs/HANDOFF.md) | Session handoff. The only cross-session memory. If it is not here, it did not happen. |
| [`docs/LANES.md`](docs/LANES.md) | The work board. Lanes own disjoint paths, so several sessions can run at once. |
| [`docs/RECORD_SCHEMA.md`](docs/RECORD_SCHEMA.md) | The record format, frozen at M1 exit. |
| [`docs/ART_PIPELINE.md`](docs/ART_PIPELINE.md) | Blender to Godot: budgets, vertex colours, export settings, art cards. |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | How to work here. Assistants draft, humans ratify. |
| [`docs/RELEASE.md`](docs/RELEASE.md) | Getting a build out, and what still stands in the way of a real one. |
| [`CHANGELOG.md`](CHANGELOG.md) | What is in a given build — including what is not. |
| [`THIRDPARTY.md`](THIRDPARTY.md) | Everything redistributed in a build, and its licence. |

## Design pillars

1. **Golf is always the answer.** Every defense is beaten with golf skills, never with a separate minigame.
2. **Readable chaos.** Every defender telegraphs. You always know why a shot was stopped.
3. **Thirty seconds to fun.** A hole is a bite. No menus between the urge to play and the first swing.
4. **Offline core, records everywhere.** Every stroke is a small, portable, deterministic record. If two
   phones can pass a string, they can play each other. There is no live multiplayer, by design.
5. **Two ways to play, both whole.** A pure defender never has to swing.
6. **Kind comedy.** Defenders are rivals, not villains.

## Licence

- Code: **Apache-2.0** — [`LICENSE`](LICENSE)
- Art and audio: **CC-BY-4.0** — [`art/LICENSE`](art/LICENSE), [`audio/LICENSE`](audio/LICENSE)
- Inbound contributions under Apache-2.0 §5. No CLA (ADR-005).

Free and open source, with no DLC and no in-app purchases (ADR-002). GitHub releases are canonical;
itch.io and F-Droid are mirrors.

Third-party components are listed in [`NOTICE`](NOTICE).
