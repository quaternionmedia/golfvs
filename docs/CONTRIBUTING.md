# Contributing to golfVs

golfVs is open source and free, with no paid tier, no DLC and no in-app purchases (ADR-002). Contributions
are welcome from anyone.

## The one rule

**Assistants draft, humans ratify** (ADR-006). Anyone — human or AI assistant — may open a pull request.
A decision only becomes real when a human ratifier merges it. Tool involvement is never a byline.

## Licensing

- **Code** is Apache-2.0. See `LICENSE`.
- **Art and audio** are CC-BY-4.0. See `art/LICENSE` and `audio/LICENSE`.
- Inbound contributions are accepted under **Apache-2.0 §5**. There is no CLA to sign (ADR-005).
- Contributed art must be original or compatibly licensed, with provenance stated in the pull request.

## Before you start

1. Read `docs/DESIGN.md`. It is the plan of record and it is where scope lives.
2. Read `docs/DECISIONS.md`. Every ratified decision is there with its rationale. If your change
   contradicts one, that is a conversation, not a pull request.
3. Read `docs/HANDOFF.md`. It says what is actually in progress right now.
4. Read `docs/LANES.md` and pick a lane. It says what is free to start, what is blocked, and on what.

## Working a lane

Work is split into lanes that own **disjoint sets of paths**, so several people or sessions can run at once
and merge without conflicts. `docs/LANES.md` is the board.

- **Stay inside your lane's paths.** If a change wants a file another lane owns, that is a signal the work
  belongs in the other lane — say so in `HANDOFF.md` and let that lane take it, rather than reaching across.
- **Three files are shared.** `project.godot` is one lane at a time and never with the Godot editor open —
  it silently overwrites the file on save. `DESIGN.md` and `DECISIONS.md` must move in the same commit; CI
  enforces it. `HANDOFF.md` is append-only: add your session's section, never rewrite another's.
- **Nothing is ratified by writing code.** If your work implies a decision, add it to `DECISIONS.md` under
  *Pending ratification*, put the reasoning in `HANDOFF.md`, and carry on. Flagged, not blocked. Deviating
  from `DESIGN.md` silently is the one failure mode this project has already had — four such divergences
  went unrecorded for a whole session, and the next reader would have built on the document instead.
- **Leave both gates green.** The suite, and the demo round:

  ```sh
  GODOT_BIN=/path/to/godot ./addons/gdUnit4/runtest.sh --add res://tests --continue
  "$GODOT_BIN" --headless --fixed-fps 120 --path . res://tools/demo_round.tscn
  ```

  The demo exits non-zero if a stroke fails to replay to its own hash, if the round on disk differs from the
  round played, or if a defender's verdict is not reproducible from its seed. It is fast, and it catches a
  whole class of bug the unit suite cannot see.
- **Commit what the suite wrote.** The suite writes `walkthrough/` from itself (ADR-031): a test you add
  is a line on a page, a suite you add needs a row in `tests/walkthrough/registry.gd` or the suite fails,
  and a picture the walkthrough shows is taken by the test that asserts it -- `await Walkthrough.capture(
  self, "<page>", "<shot>")`, from the scene the assertion ran against, never from a separate harness.
  Run the suite with a display; if `git status` shows `walkthrough/` changed, that is your change's
  documentation, and it goes in the same commit. Do not edit a generated page by hand: edit the suite.

## Changing the plan

`docs/DESIGN.md` and `docs/DECISIONS.md` move together. CI enforces this: **a pull request that edits
DESIGN.md without a matching DECISIONS.md entry fails.**

Every decision in DESIGN.md carries a tag:

| Tag | Meaning |
|---|---|
| `[RATIFIED ADR-nnn]` | Settled. Changing it means superseding an ADR, which is a new ADR. |
| `[PROPOSED]` | Drafted, awaiting a human ratifier. Do not build on it without saying so. |
| `[OPEN]` | Not yet decided by anyone. |

To ratify a proposal: add a row to the table in `DECISIONS.md` with the next ADR number, the date, the
decision, its **rationale**, and status `Active`; flip the tag in `DESIGN.md` to `[RATIFIED ADR-nnn]`;
remove it from the "Pending ratification" list. Superseded ADRs are kept and marked, never deleted.

Planning documents contain **no dates and no durations** (ADR-011). Milestones are ordered by dependency
and end at gates. If you want to express urgency, express it as a dependency.

## Code

- **GDScript**, typed, in the style of the surrounding file. C# or GDExtension only if profiling demands it.
- Godot is pinned to the version in `.godot-version` (ADR-008). Upgrading is its own ADR with a full export
  target test pass, never a bump in a feature PR.
- **Determinism is not negotiable.** Gameplay state changes only through a `ShotIntent` or a `DefensePlan`,
  both serializable. No wall-clock reads in gameplay code. A stroke that cannot replay bit-for-bit from its
  record is a **P0 bug**, not a rough edge.
- Data before code: sports, clubs, balls, holes and difficulty tiers are `Resource` subclasses in `.tres`,
  editable in the inspector and diffable in git. A new defender should be content, not a new class.
- One scene, one responsibility. Composition over inheritance.

## Art

See `docs/ART_PIPELINE.md` — it is normative on budgets, vertex colours, export settings and the four
required animations. Run `git lfs install` once per clone before adding any binary asset.

## Tests

Tests use [gdUnit4](https://github.com/MikeSchulze/gdUnit4), vendored under `addons/gdUnit4/`.

```sh
GODOT_BIN=/path/to/godot ./addons/gdUnit4/runtest.sh --add res://tests --continue
```

CI runs the same suite headless on every pull request, then plays a round through `tools/demo_round.tscn`.
Either one red blocks a merge.

New fixtures go in `tests/fixtures/records/`. Add one whenever a physics or defender change is ratified —
the fixture set is the record of what the simulation used to do.

## Pull requests

- One decision, or one coherent change, per pull request.
- `CODEOWNERS` routes `docs/`, `core/`, `records/`, `async/` and `replay/` to named ratifiers. Expect review
  there to be slower and more particular; those paths are load-bearing for every mode in the game.
- Say what you changed and why. The why ends up in `DECISIONS.md`, so write it once, well.
- If you are an assistant working a session: update `docs/HANDOFF.md` before you finish. It is the only
  cross-session memory this project has. If it is not in the handoff, it did not happen.
