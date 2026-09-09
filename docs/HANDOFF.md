# golfVs — Handoff Packet

**Generated:** 2026-09-09 · **Session:** build-04 (Claude Code) · **Next reader:** any assistant or human starting the next session
**Rule:** this file is the only cross-session memory. If it isn't here, it didn't happen. Update at the end of every session.

## 1. Where we are
- **Phase:** M0, with M1/M2/M3 work running well ahead of it. Appendix A steps 1–4 are done. **Step 5 is done
  except its device leg**; step 6 is not started. The M0 blocker is unchanged and is hardware.
- **Repo: now committed.** Four commits on `main`, no remote. `c777564` is the bootstrap baseline —
  everything sessions 01–03 produced, unchanged from the tree the tests were run against — and `d85e247`,
  `cfc572e`, `2e9e0fe` are this session's. This file reserved the first commit for the ratifier; Peter asked
  for it directly, so that is the instruction carried out rather than the convention broken.
- **Engine:** pinned to **Godot 4.7.2.stable** (ADR-008), unchanged. Steam install; set `GODOT_BIN` to
  `godot.windows.opt.tools.64.exe` under `Steam/steamapps/common/Godot Engine/`.
- **Tests: 66 cases, 0 failures, 0 orphans** (was 22), headless on the pinned engine.
- **There is a playable vertical slice.** The intro hole hosts a skeet shooter, every stroke is written as a
  schema-v1 Stroke Record, and the round is saved under `user://records/`. `tools/demo_round.tscn` plays the
  hole headless and verifies what it wrote:

      godot --headless --fixed-fps 120 --path . res://tools/demo_round.tscn

## 2. Ratified this session
None. Three decisions were *drafted* and wait in §3. Ratifying is the human's move (ADR-006).

## 3. Awaiting ratification
The twenty-one `[PROPOSED]` items are unchanged, and a new check now enforces that the two lists agree in
number. **Three new proposals** were drafted this session, all with running code behind them, all cheap to
reverse now and expensive later:

1. **Float serialisation: quantize on write** (`records/canonical.gd`). Positions to 0.1 mm; normalised
   scalars and unit-vector components to six decimals. This closes question 4 of `RECORD_SCHEMA.md` §6, which
   warns it must be settled *before the first fixture is recorded*. It sidesteps the round-trip problem rather
   than solving it: the number the simulation consumes is the number on disk, so nothing depends on a double
   surviving a decimal round trip. `test_canonical.gd` round-trips 2000 seeded values and demands exact
   equality, not approximate.
2. **`RecordStore` as a static class, not the autoload §6.2 names.** Registering an autoload means editing
   `project.godot`, which this file records the open editor silently overwriting twice, and every method is a
   pure function of its arguments. Adding the autoload later changes call sites and nothing else.
3. **A skeet shooter on the intro hole, gentle tier, `defended` defaulting to true.** This moves the built
   hole *toward* §2.6, which asks it to teach "power, curve, **the defender**, putt"; the built hole taught
   power, curve, putt. The toggle also gives §4's Scottish Rules control group a switch.

The four proposals that block M1 design work are still unratified: **stroke gesture**, **three clubs +
auto-putter**, **Stroke Record schema v1**, **GDScript + gdUnit4 + determinism**. Considerably more is now
built on the last two.

## 4. Open questions
`DESIGN.md` §10's five are unchanged. Of `RECORD_SCHEMA.md` §6's four:

- **Question 4, float serialisation — answered** by proposal 1 above, pending ratification.
- **Question 3, the exact hash input — answered in code.** `Canonical.hash_of` over `after.ball` and
  `after.events`, canonical JSON, sorted keys, fixed-width floats. Pending ratification.
- **Questions 1 and 2 are still open.** `stroke_no` is implemented as the 1-based ordinal of the stroke the
  record describes, which is what `RECORD_SCHEMA.md` says and what `DESIGN.md` §11.1's example appears to
  contradict. Whether a *shared* record carries full `after` or only its hash is untouched.

**New, and the most consequential thing found this session:** the curve sign was inverted relative to
`RECORD_SCHEMA.md` §2.1, and every test passed anyway. See §7.

## 5. Next three tasks
1. **Ratify or reject the three new proposals** (§3), and the four M1 blockers — human. Float precision is
   the urgent one: anything recorded before it settles is scrap.
2. **Rule on the built-vs-planned divergences.** Four were found last session and recorded only in this file,
   which is the wrong place for scope (ADR-006). Building the defender closes one of them; three are open —
   the press-anchored pull, the 7 % ribbon, and the absence of glyphs. Each needs an ADR or a revert.
3. **Push to a remote and watch CI actually run.** It never has. The coupling check in particular has never
   executed once, because it needs a base ref to diff against.

Then the unchanged hardware task: **the Android debug APK on a physical phone**, which is M0's exit.

## 6. Blockers
- **M0 exit is blocked on hardware,** unchanged: the APK needs Peter's device, the Android SDK and export
  templates.
- **CI has still never run,** because there is no remote. Treat "CI green" as unproven — what is actually
  known is "the suite is green on this machine".
- **`DESIGN.md` §2.6 and `docs/ONBOARDING.md`.** The document is cited four times and does not exist.
  `check_docs_consistency.py` now catches this class of problem and carries `ONBOARDING.md` in an explicit
  `GRANDFATHERED_DOCS` list so the suite stays green. The entry names the decision that removes it, and the
  check fails if the file ever appears without the entry being deleted. **Finish the purge or write the
  document** — it is no longer invisible, but it is still unresolved.
- **The Godot editor was open for this whole session,** so `project.godot` was deliberately not touched. That
  is why `RecordStore` is a static class rather than an autoload.
- **CODEOWNERS names are carried from `qm`,** unverified for this repository. Unchanged.
- **Repo name, soft.** Unchanged; the Android package ID still has to be final by M4.

## 7. Artifacts produced this session

### build-04 (this session)
**A defended hole that writes records, and a demo that checks them.** Four commits; the suite went from 22
cases to 66.

Created:
- `records/canonical.gd` — quantization, canonical JSON, SHA-256. The one place a float becomes text.
- `records/stroke_record.gd` — the §2 wire format, with `resolve()`, `compute_hash()` and §4.1 notation.
- `records/record_store.gd` — append-only rounds under `user://records/`.
- `core/shot_intent.gd` — the only thing crossing from input into simulation. Quantized at construction
  rather than on write, so the number the player produced, the number the sim consumes and the number on
  disk are one number.
- `core/ai_golfer.gd` — a shot generator, not an opponent. Written because a hand-scripted golfer aimed at
  the flag four times and hit the same rock four times; it also unblocks Defense Range (§4 mode 6) and gives
  the Scottish Rules par check something to run.
- `defenders/_base/difficulty_tier.gd`, `defender_profile.gd`, `defender_brain.gd`; `defenders/skeet/skeet.gd`.
- `tools/demo_round.gd` + `.tscn` — the merged demo, and a real smoke test: it exits non-zero if a stroke
  fails to replay to its own hash, if the round on disk differs from the round played, or if a defender's
  verdict is not reproducible from its seed.
- `tests/records/test_canonical.gd`, `tests/records/test_stroke_record.gd`,
  `tests/defenders/test_defender_brain.gd`, `tests/stroke/test_stroke_gesture.gd`.

Modified:
- `tools/check_docs_consistency.py` — two new checks. **5. Documents exist:** every UPPERCASE `.md` document
  either planning file cites is in the tree, with a self-expiring grandfather list. **6. Proposals agree:**
  `DESIGN.md`'s `[PROPOSED]` bullets and `DECISIONS.md`'s pending list are the same length — 21 each today.
- `core/stroke/ball_flight.gd`, `core/stroke/stroke_gesture.gd` — the curve sign, below.
- `holes/intro/intro_hole.gd` — hosts defenders, emits a `ShotIntent`, writes and saves records, reads the
  lie off the same constants the geometry is built from, and gained a `defended` toggle. Par docstring fixed.

**Fairness is now structural rather than conventional.** `DefenderBrain.read_shot` takes an arc and a seed.
There is no argument through which a `ShotIntent`, a club or a gesture could reach it, so §3's "act on the
ball's actual state, never on input before release" cannot be violated without changing the signature — and
a test asserts the signature's argument names. Randomness comes from the stroke seed mixed with the defender
id, so two shooters on one hole roll independently and both replay.

**The curve sign was inverted relative to the schema, and every test passed anyway.** `RECORD_SCHEMA.md` §2.1
says positive curve is a fade (right), negative a draw (left). `BallFlight.curve_acceleration` negated, and
`StrokeGesture` handed it a value of the opposite sign. The two cancelled: the ball flew exactly where the
player expected, and the number written into `intent.curve` meant the opposite of what the schema says. Every
existing test passed, because each looked at only one half of the pair. The negation now lives only in the
gesture — screen space is the thing with a flipped axis, not the golf — and `test_stroke_gesture.gd` tests
pixel-in to world-vector-out so a cancelling pair cannot hide there again. **This had to be caught before the
M1 freeze. Afterwards it would have been unfixable.**

**Four more bugs, three of them findable only by running it:**
- **`tell_lead` was 0.9 s against a flight that peaks at 0.9 s,** so the tell could never fit before the apex
  and the shooter never fired at all. At the gentle tier — which *lengthens* the warning — it came to 1.29 s.
  Now 0.45 s. The tell is for legibility, not for reaction: by the time it appears the ball has been struck
  and the player cannot answer it. The answer is played *before* the stroke, by reading where the shooter is
  standing.
- **`DefenderBrain` never entered `COOLDOWN`,** sitting in `ACT` for the whole reload and hiding the one
  window in which a defender is harmless.
- **Skeet's barrel fed `Basis.slerp` its own output,** drifting off orthonormal until Godot refused the
  conversion outright and tracking stopped dead.
- **`AIGolfer` scored candidates on where a shot lands, but the ball then rolls,** so it played everything
  through the green — 38 m past a 27 m target. It now aims at a landing spot short of the target. Crude on
  purpose; the honest fix is scoring against the simulated rest position, which needs Lane B's stepped sim.

**A measurement worth keeping.** `test_defender_brain.gd` pins something counter-intuitive: at full curve the
apex moves only about three metres, against an eleven-metre zone radius. So §3's "curve so the lead is wrong"
does *not* work by moving the ball out of the zone — it works through the accuracy falloff toward the rim. A
hole designed on the assumption that curve alone beats a shooter will play as unfair. The intro hole's
shooter therefore uses a 7 m radius, not the profile default of 11.

**What the demo does not prove.** `after` is produced by the analytic `BallFlight` model plus a Jolt
rigid-body roll-out, and the hash covers where the ball finished. That round-trips on *this* machine. It is
not yet the cross-platform determinism §11.7 requires, and nothing has measured Jolt's behaviour on two
operating systems. Lane B's stepped sim is what closes that. Until then, "the record replays" means
"replays here".


### bootstrap-03
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
- **The Godot editor was open throughout build-04, so `project.godot` is untouched by it.** Nothing in that
  file changed; if the pin or the plugin entry looks wrong, the editor did it.
- **Run the demo, not just the suite.** Three of build-04's five bugs were invisible to unit tests and
  obvious within one headless round. `--fixed-fps 120` matters: without it the run happens in wall-clock
  time and a few strokes take minutes.
- **Do not record a fixture until the float precision proposal is ratified.** Anything written before it
  settles is scrap, and RECORD_SCHEMA.md §6 says so.
- **When adding the second defender, check its tell against the flight time first.** A tell longer than the
  time to the action means the defender silently never acts, which looks exactly like a defender that is
  working and missing.
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
