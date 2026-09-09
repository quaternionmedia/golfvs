# golfVs — Handoff Packet

**Generated:** 2026-09-09 · **Session:** build-04 (Claude Code) · **Next reader:** any assistant or human starting the next session
**Rule:** this file is the only cross-session memory. If it isn't here, it didn't happen. Update at the end of every session.

## 1. Where we are
- **Phase:** M0, with M1/M2/M3 work running well ahead of it. Appendix A steps 1–4 are done. **Step 5 is done
  except its device leg**; step 6 is not started. The M0 blocker is unchanged and is hardware.
- **Repo: committed, still no remote.** Eighteen commits on `main`. `c777564` is the bootstrap baseline —
  everything sessions 01–03 produced, unchanged from the tree the tests were run against. This file reserved
  the first commit for the ratifier; Peter asked for it directly, so that is the instruction carried out
  rather than the convention broken.
- **Engine:** pinned to **Godot 4.7.2.stable** (ADR-008), unchanged. Steam install; set `GODOT_BIN` to
  `godot.windows.opt.tools.64.exe` under `Steam/steamapps/common/Godot Engine/`.
- **Tests: 135 cases, 0 failures, 0 orphans** (was 22 at bootstrap, 66 at build-04), headless on the pinned
  engine.
- **There is a playable vertical slice.** It is the **practice range**, not the intro hole: ADR-017 replaced
  the par-4 with three pins and three clubs, ADR-018 made the player choose between them, and the skeet
  shooter gave way to the archer of ADR-015. Every stroke is written as a schema-v1 Stroke Record and the
  session is saved under `user://records/`. `tools/demo_round.tscn` plays it headless and verifies what it
  wrote:

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
**The full board is `docs/LANES.md`** — what is free to start, what is blocked, and on what. These three
are the ones that unblock other people.

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
- **`docs/ONBOARDING.md` — closed by ADR-014.** The citations were removed rather than the document
  written, and `GRANDFATHERED_DOCS` is empty again. The check that caught it stands.
- **The Godot editor was open for this whole session,** so `project.godot` was deliberately not touched. That
  is why `RecordStore` is a static class rather than an autoload.
- **CODEOWNERS names are carried from `qm`,** unverified for this repository. Unchanged.
- **Repo name, soft.** Unchanged; the Android package ID still has to be final by M4.

## 7. Artifacts produced this session

### build-05 (this session)

**Asked for:** review the repo, clean up, make the club selector much more subtle and move it to the top
left, and add orbit controls.

- **`ui/club_selector.gd` — rewritten, and ADR-019 logged for the move.** It was a full-width bar along the
  bottom with three filled trays; it is now a corner mark: one hairline per club against a faint rail, the
  two clubs not in hand at about a quarter of the live one's alpha. **The tap targets did not shrink** — the
  rows are still 36 px, and `test_the_rows_stay_a_finger_tall` exists so that "subtle" cannot later be
  traded against ADR-007. Moving it also freed the bottom strip, so `Scorecard.lift` is gone: it existed
  only to dodge the selector.
- **`core/camera/camera_orbit.gd` — new, and it builds ADR-001 rather than deciding anything.** The orbit is
  an *offset*: the range still frames the shot and `apply()` swings that eye around that focus, so a centred
  orbit returns the framing untouched and every existing camera is unchanged until somebody drags. Two
  fingers on touch, right-drag and wheel on mouse. Elevation is clamped out of the deck and off the pole;
  zoom is clamped both ways.
- **The one-finger / two-finger collision, and how it is resolved.** `StrokeGesture` starts a stroke on a
  press *anywhere*, deliberately, so the orbit had to take the second finger without the first ever playing
  a shot. `CameraOrbit` listens on `_input` — before GUI, before `_unhandled_input` — so it sees the second
  touch land first, marks it handled, and emits `engaged`; the range wires that to `StrokeGesture.abort()`.
  Ordering in the scene tree is not load-bearing, which was the point.
- **`tapped` is a new signal, and it is not `cancelled`.** ADR-001 asks for a one-tap reset to the line of
  play. A press that goes down and comes up without leaving the deadzone is the only screen-wide gesture
  nothing else claims, so that is the reset. It has to be separate from `cancelled`: `abort()` reports
  `cancelled` so the ribbon comes down, and if the two were one signal, taking hold of the camera would
  instantly recentre it. There is a test for exactly that.
- **`tools/shoot_range.gd` now photographs the game rather than half of it.** It loaded
  `practice_range.tscn`, which has no flat layer, while a comment two lines below the `preload` claimed the
  shot showed "the club selector along the bottom". It loads `main_menu.tscn` now, and there is a new
  `7-orbit` shot whose whole purpose is to show that the framing underneath is unchanged.
- **Docs trued up against the tree.** `DESIGN.md` §2.1 still specified driver/iron/wedge and an auto-putter,
  which ADR-018 superseded. `LANES.md` pointed three times at `intro_hole`, a file ADR-017 deleted, and
  blocked Lane C on a ratification that has happened; Lane C and Lane D also both claimed the range, which
  the lane rules forbid. ADR-018's row contained an unescaped pipe inside backticks and had been rendering
  as a seven-column table row since it was written.
- **The flight camera no longer whips when the archer connects.** Reported as "too chaotic when the defender
  hits off screen", and it was three separate teleports landing on the same frame:
  1. `back = -vel.normalized()` was recomputed every frame, and the arrow *reverses* the ball rather than
     stopping it — so the camera cut to the far side of the ball the instant it landed. There is a `_trail`
     now, turned at `TRAIL_TURN` rad/s and frozen outright while `_pinned`: a ball being buried is travelling
     the arrow's direction, not the shot's, and chasing it is wrong as well as violent.
  2. The defender framing was a branch — present or absent, with the width of the range between the two
     positions, and an *uncapped* pull-back proportional to the ball-to-defender gap. It is a blend now
     (`_threat`, 0→1, in at 2.6/s and out at 0.9/s) with the spread capped at `THREAT_SPREAD`.
  3. The shake ran at 97/71/59 rad/s — 9 to 16 Hz, under four samples per cycle at 60 fps. That does not
     render as a shake, it renders as noise. Now 41/33/27, with the fov kick cut from 26° to 9°.
  Four tests in `test_practice_range.gd` pin all of it, measuring metres of camera movement per frame.
- **The selector draws flight shapes, not bars** (ADR-019 amended, not yet committed when it was first
  drafted this session). The putt is a flat line because it rolls; the short club is a small steep arc; the
  long club a long shallow one. Span comes from `carry()` and height from `launch_deg`, so the picture is the
  club rather than an illustration of it — retune a club and the mark redraws. It sits on a black panel local
  to the corner, which is the only opaque thing the game draws: the first corner draft was quiet enough to be
  unreadable over a lit deck, and that is being quiet in the wrong place.
- **Gates:** suite 139/139 green, docs check green, `demo_round` PASS, and eight screenshots re-rendered and
  looked at.

**Not done, deliberately:** the orbit is tuned on a mouse. `YAW_PER_PX`, `PITCH_PER_PX` and `ZOOM_PER_PX`
are guesses in exactly the way `LOCK_PX` is, and ADR-007 makes the thumb the arbiter. Lane C's tuning task
now covers both.

### build-05, part two — the other side (ADR-020)

**Asked for:** defence mechanics. The direction was given in pieces and each piece changed the shape, which
is worth recording because the end state does not look like the start.

1. *"Defender position is calculated halfway between hole and player. Defender sees exactly what the player
   sees in the UI, and an animation to signal the golfer swinging and ball travelling. The intro screen
   should let you switch back and forth to practice."*
2. *"Should be archer not skeet."*
3. *"Putt placement should be radial mirror to the hole."*
4. *"Double the distance for the hole for the defender. A close putt should be easy for offence."*

- **Placement is derived, not authored.** `defender_stand()` is the only code that knows where a defender
  goes: twice the distance to the pin, mirrored through it, clamped inside the fence. Halving was the first
  rule and it was wrong — a six-metre putting pin across a three-metre mat put an archer at the player's
  elbow, which §3 forbids outright ("defenders never enter the tee box"). Doubling also changes what the
  defender is *for*: it guards the ground beyond the target, so going long is what it punishes.
- **It is an archer, not the skeet, and that was the right correction on the project's own terms.** ADR-015
  keeps skeet for M2, so putting it here would have settled a roster question by accident. Archery is the
  sport §3 already gives two jobs, and `ArcherBrain` already fell back to the apex trigger when it was not
  guarding a boundary — so an adversarial archer needed no new sport, no new brain and no new decision. It
  is drawn in threat amber rather than the safety net's green, via a new `Archer.ink`.
- **The golfer has a tell, and the ball is genuinely held for it.** `GolferFigure` owns the swing clock and
  the range asks it for `windup()`, so the backswing and the pause are one fact rather than two kept in
  step. This was a *missing requirement* rather than a missing feature: §3 asks every defender to telegraph
  and never said the same of the golfer, which left a defender reading a shot off a ball that had gone.
- **A hand-played defender is deterministic.** `DefenderBrain.act_now()` is the one way into ACT that does
  not go through a prediction. It keeps every fairness property that lives on the profile — cooldown, zone,
  blind spot — and drops the dice: a person who timed it right is never told they were unlucky, which fails
  Pillar 2 harder than any amount of chaos. `falloff_at()` was split out of `accuracy_at()` for it.
- **The switch.** `SideSwitch`, top-right, mirroring the club selector top-left in size, ink and language.
  Defending, the club selector dims (the clubs are not yours), the ghost stops (it demonstrates a stroke you
  are not going to play), and the aim thread follows the ball — bright while the shot is on, dim while it is
  not, straight from `brain.can_reach()` so the line cannot promise what the brain would refuse.
- **`contested` defaults to false.** The bare range is what ADR-017 describes and what `demo_round` gates
  on; only `main_menu.tscn` turns the archer on. That keeps the demo a question about physics.

**For the ratifier — ADR-020 conflicts with §11.4** and says so in its own rationale. §11.4 proposes that a
human defender authors a `DefensePlan` rather than steering in real time; this steers in real time. The
property §11.4 exists to protect is replayability, and it survives — the action is deterministic and its
time is one scalar — but whether the plan model replaces this at M5 or wraps it is not settled here.

**Known gap, and it is the next thing worth doing.** Defending, the thread reports reachability, so the
defender has a live read. **Golfing, there is still nothing.** Nothing draws a zone, so "keep it low" has to
be discovered by being pinned rather than seen beforehand — which is the wrong half of Pillar 2 to leave
unbuilt. `DefenderZone` as a visible thing is now flagged as the most valuable item in Lane E.

**Gates:** suite 149/149 green (10 new), docs check green, `demo_round` PASS, ten screenshots re-rendered
and looked at.

### build-05, part three — third person on both sides (ADR-021)

**Asked for:** *"have the defender be third person like the golfer when selected, and the same mechanism
should apply for defense input."* Two corrections to ADR-020, and they turned out to be the same one.

- **The camera was wrong on principle, not only in practice.** ADR-020 handed the defender the golfer's
  view because "both sides see the same thing". Pillar 5 says defence is a *whole way to play*, and a whole
  way to play does not get somebody else's viewpoint — what has to be equal is that neither side gets a god
  view. `_frame_defend()` now stands over the archer's shoulder exactly as `_frame_aim()` stands over the
  golfer's, and it had to: a lead is a direction, and a direction cannot be judged from a camera pointed
  the other way.
- **The tap was a different game played with the same fingers.** Pillar 1 rules out a separate minigame for
  the golfer; nobody had written down the symmetric claim for the defender. The drag draws the bow now —
  same `StrokeGesture`, same `BallFlight` launch model against a bow profile, same `AimRibbon` preview.
- **The arrow travels, and that fell out of the gesture rather than being bolted to it.** §3's counter for
  archery is literally "arrows have travel time". The AI's arrow stays a *tracer* for the reason its own
  comment gives — its pin lands on the tick it acts, so a projectile would arrive after the ball had
  already stopped, and cause after effect reads as a glitch. A hand-played arrow inverts that exactly:
  nothing has happened when the player lets go, so the travel is the anticipation. `commit_by_hand()`
  starts the cooldown at the release, `connected_at()` resolves on arrival, and both are deterministic.
- **The amber thread went away while aiming by hand.** It said what the ribbon already says. `aim_at()`
  points the bow without one; `track()` keeps the thread for the AI's tell.

**Watch out — `DECISIONS.md` has no blank line between the ADR table and the "Pending ratification"
heading**, and appending a row by anchoring on that heading silently concatenates it onto the previous row.
That happened this session and was caught by the docs check, which is exactly the failure it exists for. A
blank line has been added; append rows by matching the last row, not the next heading.

**Not played by anybody.** The lead is tuned against a mouse. `BOW_MIN_SPEED`, `BOW_MAX_SPEED` and
`ARROW_HIT` are the three numbers that decide whether this is fun, and ADR-007 makes the thumb the arbiter.

**Gates:** suite 153/153 green, docs check green, `demo_round` PASS, ten screenshots re-rendered and looked
at — `10-defending` is now over the archer's shoulder with the ribbon on the ball.

### build-05, part four — one defender, and you can be it (ADR-022)

**Asked for:** *"remove the additional defender, and have the one on the rock be the only for the tutorial.
The closer put one will be in game further"*, then *"the helpful main screen archer should also be
controllable."*

- **The contesting archer is scoped out of the tutorial, not deleted.** `set_contested()` builds and frees
  it at runtime, so the flag and the world cannot disagree, and a later hole turns it on. The first run
  meets one defender, which is the whole budget it has: ADR-014 and ADR-017 make it about the clubs, and an
  adversary would be a second idea arriving with the first.
- **The archer on the rock is holdable, and that is the part worth the ADR.** Playing the safety net is a
  better first defence lesson than an adversary would be — the ball you are asked to shoot is the one that
  was about to be lost, so working that side teaches where the course ends by patrolling it. Same lesson as
  the golfing side, from the other end.
- **A held guard stops guarding by itself.** `_guard_the_boundary()` skips whatever the player is holding.
  A net that keeps catching balls while somebody aims it themselves is doing their job for them, and a shot
  they just missed would read as one they made. It costs nothing to be wrong — a range charges nothing for
  a lost ball — but it is the difference between watching a safety net and being one.
- **`held()` is the seam.** One accessor decides which archer the player has: the contender if a hole stood
  one up, otherwise the guard. Every part of the defence path goes through it, so a hole with two defenders
  and a hole with one differ in a single expression.
- **The side switch appears only when there is somebody to be**, and its `mouse_filter` goes with its
  fade — a faded Control that still eats presses is exactly the bug the club selector shipped once.

**The elevated vantage turned out to matter.** Defending from the rock looks over the whole range, which
suits a lookout and reads far better than the contender's ground-level view did. Worth remembering when a
later hole places one: height is doing work here that the placement rule does not know about.

**Gates:** suite 158/158 green (5 new), docs check green, `demo_round` PASS, ten screenshots re-rendered.
`10-defending` is now the first run's own defence — over the archer on the spire, bow drawn, ribbon out.

### build-05, part five — making the defence actually possible (ADR-023)

**Asked for:** *"aiming the archer is on a plane. Make sure it's possible to successfully defend in this
scenario."* Correct, and it was three faults stacked rather than one.

1. **The aim is planar and the target is not.** `StrokeGesture` reads a heading on the ground plane, which
   is right for a stroke — a club supplies the launch angle, so the drag only has to supply a bearing. An
   arrow has nobody to supply it. With a fixed 9° launch, the arrow could only hit a ball that happened to
   be at the right height at the right range: not a hard shot, an unaimable one. The bow solves the
   elevation now, against a two-pass prediction of where the ball will be. The **bearing is not assisted**,
   so the lead and the moment remain the whole of the skill.
2. **The ribbon was a 7% stub.** That is a deliberate denial for the golfer, because judging distance is the
   game. An archer *sights*, and a bow whose line stops a metre past the arrow has no sights on it.
   `AimRibbon.SIGHTED_FRACTION` is 0.62 and `show_arc` takes the fraction as an argument.
3. **The hit test stepped over the ball.** At 100 m/s an arrow covers 1.7 m between physics ticks, so a
   point test tunnels through a ball it passed within centimetres of. It is a swept segment now
   (`Geometry3D.get_closest_point_to_segment`) — the same reason the ball itself runs CCD, and the kind of
   miss a player cannot tell from a bad shot, which is the worst kind there is.

**Three tests now pin the shape of the skill**, and they are the answer to the question that was asked: a
correct lead stops the ball, shooting at where the ball *is* misses it, and a harder draw needs less lead.
The second one matters as much as the first — without it, a passing suite would be consistent with every
arrow hitting. They fly the ball by hand rather than through the physics server so they measure the
interception and not the engine.

**Gates:** suite 161/161 green (3 new), docs check green, `demo_round` PASS, ten screenshots re-rendered —
`10-defending` now shows the sighted ribbon reaching the ball rather than stopping at the bow.

### build-05, part six — it builds for Windows and Android (ADR-024)

**Asked for:** a test build for Android and Windows. Both now exist and both come out of `tools/build.sh`.

**`project.godot` was edited** — the shared-file rule says announce it, so: `textures/vram_compression/
import_etc2_astc=true` was added, because the Android export refuses to run without it. The Godot editor was
**not** open at the time. The pin and the gdUnit4 plugin line were checked afterwards and are intact.

- **`export_presets.cfg` is tracked now** (ADR-024). It was ignored because it "carries local keystore
  paths", which was answering half the problem by giving up the other half — it kept the whole preset out of
  the repo. The keystore fields are blank and `GODOT_ANDROID_KEYSTORE_DEBUG_*` supplies them at build time.
- **M0's exit was not blocked on hardware**, or not mostly, and this file has said it was since the first
  session. What was in the way: export templates, a Java path, a keystore. All three are in the script now.
  The genuinely hardware part is one line — somebody installing the APK on a phone.
- **The trap, and it cost the most time: the Steam build of Godot runs self-contained.** A `._sc_` file
  beside the binary moves the entire editor data directory to `<godot>/editor_data/`. So the export templates
  were already installed and invisible, a settings file written to `%APPDATA%/Godot` did nothing at all, and
  the export kept reporting "A valid Java SDK path is required in Editor Settings" while a perfectly good one
  sat in a file Godot was never going to read. `build.sh` detects it. **If an export complains about
  something you can see is configured, check this first.**
- **Second trap: Git Bash hands out MSYS paths** and Godot is a native Windows binary that cannot read
  `/c/Program Files/...`. Same error message, different cause. `winpath()` runs everything through `cygpath`.
- **Verified rather than asserted:** `aapt2 dump badging` reports `native-code: 'arm64-v8a'`, no
  `uses-permission` lines at all, and `apksigner verify` reports the debug certificate. The game asks the
  phone for nothing, which is Pillar 4 as a fact about the artifact.

**Artifacts:** `build/windows/golfVs.exe` (99 MB, plus the .pck and a console wrapper) and
`build/android/golfVs.apk` (30 MB). Both debug. Both gitignored.

**Note for whoever ratifies:** `package/unique_name` is `org.golfvs.test` and Open Question 1 — the name — is
still open. A package id change is an uninstall for anybody who has the old one, so the real id wants
settling before a build goes anywhere other than a personal phone.

**Gates:** suite 161/161 green, docs check green, `demo_round` PASS, and both exports succeed from a clean
`build/`.

### build-05, part seven — ready to be published, not ready to be released (ADR-025)

**Asked for:** a review of the gaps to publishing an open v0.0.1, then a logo from the game art, the rest of
the gaps closed, and a round of polish.

**Three of the gaps were not cosmetic.**

1. **The icon was Godot's logo.** `icon.svg` had been the stock robot since the repository was created, and
   with `launcher_icons` and `application/icon` empty, both artifacts inherited it. It told anyone who saw it
   that the application *is* Godot, and it used the Godot Foundation's mark as this project's identity.
2. **Godot's licence travelled with nothing.** The engine is statically linked into both binaries and MIT
   requires the notice to accompany the distribution. `NOTICE` covered gdUnit4 — which does not ship — and
   not the engine, which does. `THIRDPARTY.md` now carries it.
3. **The export packed the whole workshop.** gdUnit4 (2.1 MB of source), `tests/`, `tools/`, against 355 KB
   of game. An `exclude_filter` took the data pack **from 1.9 MB to 232 KB**, which is the plainest possible
   statement of how much of what shipped was not the game.

**The icon is drawn from the game.** Every colour is a constant in `hole_builder.gd` and every shape is
something the game actually draws: the deck grid, the amber boundary, a target ring, the flight arc the club
selector uses as a label, and the ball as the one lit solid object. It was rebalanced after looking at it at
48 px, where the first draft turned to mush — the grid is texture, and texture is the first thing to go. SVG
rather than PNG throughout, because `.gitattributes` sends every PNG through Git LFS and the LFS path has
never been proven end to end; an icon is not worth being the file that discovers LFS is misconfigured.
Android accepts the SVGs directly. Windows needs an `.ico`, which cannot be text, so that one is generated
and committed, and `build.sh` fetches `rcedit` to apply it.

**`window/handheld/orientation=4` is load-bearing, not tidiness.** The project was landscape only because
that is Godot's default, and Godot strips defaults on save — so the single thing the game most assumes about
a phone was recorded nowhere and would have vanished if written plainly. Sensor-landscape is both the better
behaviour and a value that survives.

**Also:** `config/version` is `0.0.1` in all three places that have to agree; `in_bounds()` in
`defender_profile.gd` had lost a line continuation and was one 130-column line; and the community files
GitHub looks for now exist.

**Two placeholders a human has to fill.** `CODE_OF_CONDUCT.md` and `SECURITY.md` route reports through
GitHub rather than an email address, deliberately — publishing somebody's personal address is not a decision
an assistant gets to take. And `.github/ISSUE_TEMPLATE/config.yml` has no contact links, because they need
absolute URLs and there is still no remote to point at.

**Still not a release.** Debug builds, provisional package id, CI that has never run, and nobody has launched
either binary. `docs/RELEASE.md` is the checklist and the standing list of what stands in the way.

**Gates:** suite 161/161 green, docs check green, `demo_round` PASS, both exports clean from an empty
`build/`, APK verified to carry our icon and no permissions.

### build-05, part eight — the first pre-alpha feedback, and what it was really saying (ADR-026)

**Three reports, one failure.** The aiming model was specified for a fixed camera, one club and one side, and
everything built since reached outside it. Each addition was individually sound and each quietly widened the
domain of a function nobody had restated.

1. *"With the camera at a lower angle, it starts to feel like it's not responding to the direction I'm
   choosing."* The heading was built by mixing the camera's **flattened** right and forward vectors, which
   is exact only looking straight down. Everywhere else the ground is foreshortened and the error grows as
   the angle drops. **Measured: 2.8 degrees off at a steep camera, 32.9 at a shallow one.** ADR-001's orbit
   is what made every angle reachable. The drag is unprojected through the camera now.
2. *"I expected more live side-to-side feedback."* Worse than drift: the line **locks** after 26 px so that
   sliding across it becomes curve — correct for a stroke, and a bow has no curve, so the archer's aim was
   frozen for the rest of the drag and the sideways movement was discarded. `locks_line` is a switch now.
   Plus a flat direction line in the aim plane, which is the one part of the aid perspective cannot ruin.
3. *"The putter doesn't have the aiming graphic when winding up."* It had one, about six centimetres long: a
   putt was previewed as a projectile, and a projectile at zero degrees from ball height lands within a
   metre, so VISIBLE_FRACTION of it was nothing. `show_roll()` draws it as roll, same truncation rule.

**The tests are the point, not the three fixes.** They were written from the report and they *fail against
the code that shipped* — verified by temporarily restoring the old mapping and watching them go red with the
exact numbers above. A green suite of 161 cases had nothing to say about any of this.

**Goals moved, not just code.** ADR-026 makes aiming a subsystem with three stated correctness properties
rather than a feel to be tuned, and M1's gate gains a precondition: *does the control do what it looks like
it does?* A player fighting the aim is not answering "is it fun to hit balls at nothing on a phone". Pillar 2
— the player always knows why — had only ever been read as a rule about defenders; it applies first to the
player's own aim.

**Feedback from playing is now a first-class input** alongside the suite and the demo. Nothing here was
findable from either, and the first round found three real defects in an afternoon.

**Next:** somebody has to say whether it now *feels* right at a low angle. The fix is measured; feel is not.
Lane C carries that as its own task.

**Gates:** suite 169/169 green (8 new), docs check green, `demo_round` PASS, screenshots re-rendered —
`6-aim-aids` and `6b-putt-aim` are new and exist to show the two previews that were wrong.

### build-04
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

**Late in build-04, the hole was rebuilt to look and feel like what it is.** ADR-016 makes the intro hole a
holodeck blueprint -- a solid unlit dark-grey deck with no grid of its own, cyan grids only on surfaces that
are in play, an amber course boundary drawn where it actually is, and one lit ball. It rejects the manicured
fairway on tone, and it also fixed a real problem: the archer enforces a boundary the player had no way to
see. The trees went with the grass; they existed to hide a world edge that is now the thing worth showing.

Four refinements followed from playing it, each recorded here because none of them changes a ratified
decision:
- **The hole is a third longer** -- cup at 77 m, spire at 51 m -- with `BallFlight.MAX_SPEED` raised from 25
  to 29 to match. Range goes as the square of launch speed, so those two constants have to move together or a
  longer hole plays as a shorter one with more walking.
- **The archer stands on top of the spire**, at 1.6x human scale with a drawn curved bow. It was invisible
  before, in both senses.
- **The interception is an event now**: an instant tracer rather than a slow projectile (the projectile had
  the causality backwards -- the ball stopped, *then* the arrow arrived), the ball driven into the deck rather
  than switched off in mid-air, an `Impact` burst in the defender's own colour, and a view-only camera kick.
  The flight camera also frames a committed defender alongside the ball, because a tell that happens
  off-screen is not a tell.
- **`SpinDial`** shows how much shape is on the shot without showing where it lands. The 7 % ribbon made the
  curve half of the gesture nearly invisible; the dial reports the input rather than predicting the outcome,
  which is the line the truncated ribbon exists to hold.

`tools/shoot_hole.tscn` renders the hole to PNGs, including two live states -- the spin dial mid-gesture and
the archer's impact mid-frame -- because those are the moments most likely to be wrong and least likely to be
noticed. `tools/probe_bounds.tscn` plays 22 tee shots through the real physics and reports how many escape.

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
- **Float precision is settled** (ADR-012) and fixtures are safe to record. The warning that used to stand
  here — do not record anything before it settles — has been discharged, not forgotten.
- **When adding the second defender, check its tell against the flight time first.** A tell longer than the
  time to the action means the defender silently never acts, which looks exactly like a defender that is
  working and missing.
- **`project.godot` was edited this session while the editor was open** (again — the same hazard bootstrap-01
  flagged). `run/main_scene` was verified on disk afterwards. If it is missing, the editor overwrote it: reload
  the project and re-add it.
- **`physics/common/physics_ticks_per_second` is deliberately not written to `project.godot`.** 60 is Godot's
  default, and the editor strips settings equal to their default on save — a line there would vanish and read as
  sabotage later. The tick is asserted at runtime instead, in `tests/core/test_physics_guarantees.gd`.
- **The first run is built, and it is the practice range** (ADR-017, ADR-018). There is no `TutorialLayer`
  and no glyph art, and there never will be: ADR-014 rejected the vocabulary, and teaching falls through the
  world, the ribbon and the ghost instead. Do not go looking for `ONBOARDING.md`.
- **The first run still leans on the unratified stroke gesture and aim ribbon.** If the gesture proposal
  changes, the range changes with it — and now there is code to change and not only a document.
- **The CCD sweep is not run by CI**, only the three static assertions are. The sweep takes ~15 s and wants a
  real physics step; if it is ever wanted as a gate, run
  `godot --headless --path . --quit-after 6000 res://core/m0_physics_smoke.tscn` and check the exit code.
- **The fixture's `after.hash` is all zeros on purpose.** It means "no simulation has computed this yet". M1 replaces the fixture with a recorded stroke and turns on the replay test. Do not let anyone "fix" the zeros by hand.
- **gdUnit4 v6.2.1's compatibility table lists Godot up to 4.7.1**; we run 4.7.2. It passes, and 4.7.2 is a patch release, but this is the first thing to suspect if the suite starts behaving oddly.
- **`project.godot` was edited while the Godot editor was open.** If the pin or the gdUnit4 plugin entry looks wrong, the editor may have written over it — reload the project and check `golfvs/engine/pinned_godot_version` survives.
- Determinism and the Stroke Record are load-bearing for everything after M1; do not let M1 ship without the replay test.
- Defense Range and Match share the per-lie turn rhythm on purpose — keep them on one code path (`ReplayController` + `DefenderBrain`).
- §12 is parked, not deleted. When 1.0 ships, the first post-1.0 decision is ordering Progression & Ranking against the level editor.
