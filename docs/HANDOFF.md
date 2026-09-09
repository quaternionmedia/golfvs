# golfVs — Handoff Packet

**Generated:** 2026-09-08 · **Session:** bootstrap-03 (Claude Code) · **Next reader:** any assistant or human starting the next session
**Rule:** this file is the only cross-session memory. If it isn't here, it didn't happen. Update at the end of every session.

## 1. Where we are
- **Phase:** M0, in progress, with M1/M3 work now running ahead of it (the intro hole, §7). Steps 1–4 of
  Appendix A are done. **Step 5 is done except its device leg** — the
  scene exists, runs, and the physics guarantees are confirmed on desktop; the Android APK on a phone is not done
  and is still the M0 blocker. Step 6 is not started.
- **Repo:** exists at `C:\Users\peter\Documents\golf-vs`, `git init` on `main`. **Nothing is committed yet** — the first commit is the ratifier's, not an assistant's. There is no remote.
- **Engine:** pinned to **Godot 4.7.2.stable** (ADR-008). Recorded in `.godot-version` (machine-readable source), `project.godot` (`golfvs/engine/pinned_godot_version`), `README.md`, CI, and the ADR-008 row.
- **Tests:** gdUnit4 v6.2.1 vendored under `addons/gdUnit4/`. **22 test cases, 0 failures**, run headless
  against 4.7.2 on this machine (10 from bootstrap-01, 3 for the §6.4 physics guarantees, 9 for the stroke).
- **Engine location on this machine:** Godot is a **Steam** install —
  `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`. It reports
  `4.7.2.stable.steam.ed1daf0bf`, which satisfies the pin. There is no Godot on `PATH` and the copy in
  `~/Downloads` is an unrelated 4.3. Set `GODOT_BIN` to the Steam path to run the suite.
- **Plan of record:** `docs/DESIGN.md` 1.0-draft.1 (ADR-000). Twelve ADRs logged in `docs/DECISIONS.md`.
- **Scope shape:** unchanged. 1.0 = stroke, four-then-eight defenders, Scottish Rules sandbox, Course Play, Gauntlet, Daily, Defense Range, Replay & Fork, Pass-and-play, Postal Round, Spot Duel, async Match. Scorecard is the only result (§12, ADR-010).

## 2. Ratified this session
None. No new ADRs. Like bootstrap-01, this session executed already-ratified decisions rather than making any:
Appendix A step 5 is a task, not a choice, and nothing it turned up changed the plan.

The CCD measurement in §7 is a **finding**, not a decision — it constrains how §6.4 must be implemented, but §6.4
already required CCD, so there is nothing new to ratify. (bootstrap-01 fulfilled ADR-008 the same way: its row
names the concrete pin `4.7.2.stable`, which is what the decision itself instructed.)

## 3. Awaiting ratification
The fifteen `[PROPOSED]` items from planning-01, **plus six new first-run proposals** added this session
(§2.6 / `ONBOARDING.md`). The six stand or fall together — each only makes sense if the first, *wordless
first run*, is ratified. Nothing is built on them yet, so reversing them costs only the document. Nothing has been ratified since planning-01. The four that block M1 design work are still: **stroke gesture**, **three clubs + auto-putter**, **Stroke Record schema v1**, **GDScript + gdUnit4 + determinism**.

Two of the four are now partly built on, so the cost of a late reversal has gone up:
- `docs/RECORD_SCHEMA.md` and the first fixture assume the §11.1 schema.
- `addons/`, `tests/` and CI assume GDScript + gdUnit4.

Neither is expensive to unwind at M0. Both become expensive after M1 starts.

## 4. Open questions
From `DESIGN.md` §10 (unchanged):
1. Title and casing — see Blockers; the working directory is `golf-vs`, the plan says `golfvs`
2. Share full `after` state or only `after.hash`
3. "Scottish Rules" vs "Golf" as the sandbox name
4. Per-sport repositioning ranges (tune at M5)
5. Per-sport placement budget costs (tune at M5)

New, from drafting `RECORD_SCHEMA.md` — all four must be closed **before the M1 exit freeze**:
6. **`stroke_no` off-by-one.** DESIGN.md §11.1 shows `"stroke_no": 2` beside a notation line reading `3.`. `RECORD_SCHEMA.md` defines it as the 1-based ordinal of the stroke the record describes, and the fixture follows that. Confirm, or correct §11.1.
7. **Exact hash input** for `after.hash` — canonical JSON of `after.ball` + `after.events`, or a struct hash over the sim's final state.
8. **Float serialisation precision.** Records must round-trip bit-for-bit across platforms. Fix this before the first fixture is *recorded*, not after.
9. Question 2 above is now also a schema question, not only a transport one.

## 5. Next three tasks
1. **Ratify the four M1-blocking proposals** (§3) — human. Everything at M1 waits on these.
2. **M0 step 5, device leg only** — human. The scene and the desktop confirmation are done (§7). What remains is
   the Android debug APK on a physical phone: needs export templates, the Android SDK and Peter's device.
3. **Play the intro hole on a phone.** It is tuned entirely against a mouse. The gesture is touch-first by
   ADR-007 and every constant in `StrokeGesture` (LOCK_PX, MAX_PULL_PX, MAX_CURVE_PX) is a guess until a thumb
   has been on it.
4. **M0 step 6 and gate:** answer §10 as far as possible, then ratify or reject each `[PROPOSED]` item —
   now including the six first-run proposals. M0 exits when the APK launches on a phone and CI is green on
   a real remote.

Not blocking, but worth deciding early: **glyphs as sprites or as a bundled emoji font** (`ONBOARDING.md`
§8). It is cheap to decide now and expensive once the eight glyphs are authored.

## 6. Blockers
- **`DESIGN.md` §2.6 and the "First run" block at the bottom of `DECISIONS.md` are debris** from an abandoned
  attempt, half-removed. Peter flagged them as "an incomplete purge of a failed attempt — disregard", and this
  session built nothing on them. They are still in the tree, they still reference a `docs/ONBOARDING.md` that
  does not exist, and `tools/check_docs_consistency.py` does not catch either problem. **Finish the purge or
  reinstate them deliberately** — the next assistant to read `DESIGN.md` cold will otherwise build on them.
- **M0 exit is blocked on hardware.** The Android debug APK on a real phone (ADR-007 makes it an M0/M1 exit criterion) needs Peter's device, the Android SDK and Godot export templates. Nothing else in M0 is blocked.
- **CI has never actually run.** `.github/workflows/ci.yml` is written and its commands were verified locally against 4.7.2, but there is no remote, so no GitHub Actions run has happened. Treat "CI green" as unproven until a push proves it.
- **Repo name, soft.** The working directory is `golf-vs`; Appendix A says `golfvs`. Left alone deliberately — the Godot editor is open on this path. The Android package ID (`org.quaternionmedia.golfvs`) must be final by M4 and cannot change after first release, so Open Question 1 has a real deadline.
- **CODEOWNERS names are carried from `qm`,** unverified for this repository. Confirm the set before enabling code-owner review.

## 7. Artifacts produced this session

### bootstrap-03 (this session)
**The intro hole and the wordless tutorial, built and playable.** `run/main_scene` is now
`res://ui/menu/main_menu.tscn`.

The shape of it: **the menu has no buttons.** Its background state is the intro hole, live, with the ball on
the tee and a ghost hand looping the stroke over it. Touching the screen does not open the game -- it is the
first stroke. Pillar 3, taken literally.

Created:
- `holes/intro/intro_hole.gd` + `.tscn` -- the hole and its beat machine. Par 4, a dogleg right around a rock
  spire. Geometry is built in code (`holes/intro/hole_builder.gd`) until the M3 GridMap tile set exists.
- `core/stroke/stroke_gesture.gd` -- §2.1's pull / curve / release, as one drag.
- `core/stroke/ball_flight.gd` -- the single flight model shared by the shot and its preview.
- `core/stroke/aim_ribbon.gd` -- the preview.
- `ui/signals/beacon.gd` -- pulsing world markers; `ui/signals/ghost_gesture.gd` -- the looping demo.
- `ui/menu/main_menu.gd` + `.tscn`, `ui/menu/scorecard.gd`.
- `tests/stroke/test_ball_flight.gd`, `tests/stroke/test_aim_ribbon.gd` -- 9 tests.

**No glyph font, and no glyphs.** The signalling is drawn and animated by the engine: ripple rings that travel
outward from a point on the ground, a gold column and rings at the cup, a ghost hand that performs the gesture
at the ball's screen position, a trajectory stub that is cyan when the line is clear and amber when it runs
into the spire, and a scorecard of filled and empty rings. Nothing is typed, so nothing needs translating and
nothing depends on a vendor's emoji set rendering the same on two devices.

**The hole reads the lie, not a step counter.** `_lesson_for()` picks the lesson from where the ball actually
is: on the green it is a putt, blocked by the spire it is the curve, otherwise it is power. A player who tops
the tee shot gets the power lesson again; one who drives it long skips ahead. There is no step to fall out of,
so the tutorial cannot be got out of sync and cannot be failed.

**The dogleg is the curve lesson.** The spire is placed so the flag is visible from the tee and hidden from
the landing zone. The player sees where they are going, walks up to the ball, and finds the straight line
gone -- and the ribbon turns amber if they aim through the rock anyway.

**Ratified-decision deviations, both needing a call:**
- **§2.1 says the pull is measured from the ball. It is measured from the press point instead.** Ball-relative
  aiming means a player who reaches in from the left and pulls straight back watches the ball leave to the
  right, for a reason nothing on screen explains. Press-anchored, "drag back" is drag back from wherever you
  started. Confirmed by playing it; the difference is not subtle.
- **The aim ribbon draws only the first 7% of the arc and fades out** (Peter's call, this session). A full arc
  solves the hole and deletes the read. Consequence to watch at the M3 playtest: distance is now judged from
  the length of the stub and the target ring, and that is the hardest part of the hole for a newcomer. If it
  tests badly the cheap fix is a landing ring, but that gives back most of what truncating the ribbon bought.

**Three bugs worth remembering, all invisible in a screenshot:**
- **The launch angle was applied with the wrong sign,** firing every stroke into the turf. The ball still
  travelled -- it skipped -- so the hole looked playable. Found only by instrumenting the preview, which was
  terminating after four samples. `test_the_ball_leaves_the_ground` guards it now.
- **`AABB.intersects_segment()` returns the hit point or null, not a bool.** Returning it from a `-> bool`
  function is a runtime error, not a compile one.
- **The green was a 0.18 m step.** Given its own collider for putting friction, its rim became a wall the
  ball's own radius high; putts into it stopped dead. It now stands 2 cm proud.

### bootstrap-02
Created:
- `core/m0_physics_smoke.tscn` + `core/m0_physics_smoke.gd` — **M0 step 5.** Placeholder capsule golfer, ground
  plane with a grass `PhysicsMaterial` (bounce 0.4, §2.2), a regulation-mass `RigidBody3D` ball (45.93 g,
  21.335 mm) with CCD on, and a 20 mm wall to fire it at. Space fires, `R` resets, `C` toggles CCD. Run headless
  it sweeps launch speeds with CCD on and off, prints a table, and exits non-zero if a guarantee fails.
- `tests/core/test_physics_guarantees.gd` — 3 tests asserting the §6.4 guarantees in CI: the tick is 60 Hz, the
  physics engine is Jolt, and the ball has `continuous_cd`.

- `docs/ONBOARDING.md` — **the first-run design.** Wordless tutorial and intro hole: the eight-glyph
  vocabulary and its grammar, the four-layer teaching hierarchy (world → ribbon → ghost → glyph), the
  par-4 intro hole "The Handshake" beat by beat, the tutorial layer's state machine and escalation ladder,
  sound, accessibility, and the font-vs-sprite recommendation.
- A visual storyboard of the above, published as an artifact for review:
  https://claude.ai/code/artifact/489d4641-70be-45b0-8c27-7710cb0de4aa

Modified:
- `project.godot` — `run/main_scene` now points at the smoke scene, so F5 runs something.
- `docs/DESIGN.md` — new **§2.6 First run** with six `[PROPOSED]` decisions; §8 milestone rows for M1
  (ghost-gesture demo) and M3 (the intro hole, with the external playtest as its gate); `ONBOARDING.md`
  added to the §7 layout block.
- `docs/DECISIONS.md` — the six first-run proposals appended to "Pending ratification", with the reasoning
  for each. No new ADR: ratifying is the human's move.

**What step 5 actually measured** (Godot 4.7.2, Jolt, 60 Hz, a 20 mm wall):

| launch speed | CCD on | CCD off |
|---|---|---|
| 50 m/s | stopped | **tunnels** |
| 80 m/s | stopped | **tunnels** |
| 200 m/s | stopped | stopped |
| 500 – 8000 m/s | stopped | **tunnels** |

Two things follow, and both matter for M1:
- **CCD is load-bearing, not a safety margin.** Without it the ball is already through a 20 mm wall at 50 m/s,
  under the ~75 m/s a driver produces. Any `RigidBody3D` ball added later must set `continuous_cd`, or it will
  leave the course. The test suite now fails if the smoke scene's ball loses it.
- **The 200 m/s row is an artefact, not a reprieve.** At that speed the per-tick step happens to land the ball
  on the wall face, where an ordinary discrete contact catches it. The sweep is therefore not monotonic; only
  the *lowest* speed at which the bare solver fails means anything. Do not read the row as headroom.

### bootstrap-01
Created:
- `README.md`, `NOTICE`, `LICENSE` (Apache-2.0), `art/LICENSE` + `audio/LICENSE` (CC-BY-4.0), `CODEOWNERS`, `.godot-version`
- `.gitattributes` (LFS for `*.blend`, `*.wav`, `*.ogg`, `*.png`; `addons/**` excluded), `.gitignore`
- `docs/RECORD_SCHEMA.md`, `docs/ART_PIPELINE.md`, `docs/CONTRIBUTING.md`
- `tools/check_docs_consistency.py` — the ADR-006 check
- `.github/workflows/ci.yml` — docs check + headless gdUnit4
- `tests/test_bootstrap.gd`, `tests/records/test_record_schema.gd`, `tests/fixtures/records/0001-parkland-03-stroke-2.json`
- `addons/gdUnit4/` — vendored at tag v6.2.1, minus its own self-test corpus
- Directory skeleton per §7: `core/ records/ async/ replay/ defenders/_base/ holes/ clubs/ art/ audio/ ui/`

Modified:
- `project.godot` — version, `flush_stdout_on_print`, gdUnit4 enabled, the engine pin
- `docs/DECISIONS.md` — ADR-008 row now names the concrete pin

Copied verbatim from the planning-01 packet: `docs/DESIGN.md`, `docs/DECISIONS.md`.

## 8. Notes for the next session
- **`project.godot` was edited this session while the editor was open** (again — the same hazard bootstrap-01
  flagged). `run/main_scene` was verified on disk afterwards. If it is missing, the editor overwrote it: reload
  the project and re-add it.
- **`physics/common/physics_ticks_per_second` is deliberately not written to `project.godot`.** 60 is Godot's
  default, and the editor strips settings equal to their default on save — a line there would vanish and read as
  sabotage later. The tick is asserted at runtime instead, in `tests/core/test_physics_guarantees.gd`.
- **The first run is designed but not built.** `ONBOARDING.md` is a specification, not an implementation:
  there is no `holes/intro.tres`, no `TutorialLayer`, and no glyph art. Nothing in `core/` knows about any
  of it. Do not read §2.6 as describing something that exists.
- **The first-run design leans on two things that are themselves unratified** — the stroke gesture and the
  aim ribbon. If the gesture proposal changes, beats 1 and 2 change with it. This is drafting on sand by
  necessity, not by oversight; it is cheap to redraw while it is only a document.
- **The CCD sweep is not run by CI**, only the three static assertions are. The sweep takes ~15 s and wants a
  real physics step; if it is ever wanted as a gate, run
  `godot --headless --path . --quit-after 6000 res://core/m0_physics_smoke.tscn` and check the exit code.
- **The fixture's `after.hash` is all zeros on purpose.** It means "no simulation has computed this yet". M1 replaces the fixture with a recorded stroke and turns on the replay test. Do not let anyone "fix" the zeros by hand.
- **gdUnit4 v6.2.1's compatibility table lists Godot up to 4.7.1**; we run 4.7.2. It passes, and 4.7.2 is a patch release, but this is the first thing to suspect if the suite starts behaving oddly.
- **`project.godot` was edited while the Godot editor was open.** If the pin or the gdUnit4 plugin entry looks wrong, the editor may have written over it — reload the project and check `golfvs/engine/pinned_godot_version` survives.
- Determinism and the Stroke Record are load-bearing for everything after M1; do not let M1 ship without the replay test.
- Defense Range and Match share the per-lie turn rhythm on purpose — keep them on one code path (`ReplayController` + `DefenderBrain`).
- §12 is parked, not deleted. When 1.0 ships, the first post-1.0 decision is ordering Progression & Ranking against the level editor.
