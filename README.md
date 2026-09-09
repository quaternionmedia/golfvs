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

**M0 — Bootstrap.** The repository, the engine pin, CI and the planning documents exist. There is no
gameplay yet; the first playable thing is M1's Practice Range, whose gate is the honest question *is it fun
to hit balls at nothing, on a phone?*

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
git clone <this repo>
cd golf-vs
git lfs install          # required before touching art; binaries are LFS-tracked
```

Open the project in Godot 4.7.2. gdUnit4 is vendored under `addons/` and enabled in `project.godot`, so the
test panel is available on first open.

### Running the tests

```sh
GODOT_BIN=/path/to/godot ./addons/gdUnit4/runtest.sh --add res://tests --continue
```

CI runs the same suite headless on every pull request, plus a check that `DESIGN.md` and `DECISIONS.md`
stay in step.

## Layout

| Path | What lives there |
|---|---|
| `docs/` | The plan of record, the ADR log, the session handoff, and the two pipeline documents |
| `core/` | `GameState`, `EventBus`, `ShotIntent`, `BallController` — the deterministic simulation |
| `records/` | Stroke, Round and Match Records, `RecordStore`, text notation |
| `async/` | `DefensePlan`, commit-reveal, transports |
| `replay/` | `ReplayController`, ghosts, fork UI |
| `defenders/` | `_base/` plus one folder per sport (scene, profile, models, art card) |
| `holes/` · `clubs/` | `HoleLayout` and `ClubProfile` resources |
| `art/` · `audio/` | CC-BY-4.0 assets; `.blend` sources under Git LFS |
| `tests/` | gdUnit4 suites and the record fixtures |
| `tools/` | CI helpers |

## Documents

| Document | What it is for |
|---|---|
| [`docs/DESIGN.md`](docs/DESIGN.md) | The plan of record. Scope lives here. Every decision carries a status tag. |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | The ADR log — one entry per ratified decision, with its rationale. |
| [`docs/HANDOFF.md`](docs/HANDOFF.md) | Session handoff. The only cross-session memory. If it is not here, it did not happen. |
| [`docs/RECORD_SCHEMA.md`](docs/RECORD_SCHEMA.md) | The record format, frozen at M1 exit. |
| [`docs/ART_PIPELINE.md`](docs/ART_PIPELINE.md) | Blender to Godot: budgets, vertex colours, export settings, art cards. |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | How to work here. Assistants draft, humans ratify. |

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
