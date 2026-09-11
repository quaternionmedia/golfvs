# golfVs — Design & Project Plan

**Version:** 1.0-draft.1 (refreshed 2026-09-03 from working drafts v0.1–v0.8)
**Status:** DRAFT — assistant-authored, humans ratify. Every decision carries a tag: `[RATIFIED ADR-nnn]`, `[PROPOSED]`, or `[OPEN]`. The ADR log is `DECISIONS.md`; session state is `HANDOFF.md`.
**Engine:** Godot 4.x, pinned to the latest stable at M0 (ADR-008)
**Genre:** Arcade sports / physics golf with asymmetric defense
**Platforms:** Desktop (Linux/Win/Mac) and Android for 1.0; web export post-1.0
**Audience:** All ages
**License:** Apache-2.0 (code), CC-BY-4.0 (art/audio) — ADR-005

Milestones are ordered by dependency and end at gates. This plan contains no dates or durations (ADR-011).

---

## 1. Pitch

Golf is the only sport where nobody is trying to stop you. golfVs fixes that.

You play golf. Every other sport plays defense. A skeet shooter tries to blast your drive out of the sky. A bowler rolls a strike across the fairway. An outfielder camps the green to catch your approach for an out. A hockey goalie guards the cup. You still just have to get the ball in the hole in as few strokes as possible — but now the course fights back.

And you can switch sides. Defense is a full way to play: set your players, read the golfer, hold the hole.

Caricatured, chunky low-poly characters, one-thumb controls, thirty-second holes, offline by default.

**Design pillars**
1. **Golf is always the answer.** Every defense is beaten with golf skills — aim, power, spin, club, reading terrain — never with a separate minigame. The golfer never stops being a golfer.
2. **Readable chaos.** Every defender telegraphs. The player always knows *why* a shot was stopped and what to do differently.
3. **Thirty seconds to fun.** A hole is a bite. No menus between the urge to play and the first swing.
4. **Offline core, records everywhere.** The game is complete single-player and offline. Every stroke is saved as a small, portable, deterministic **Stroke Record**; every social feature — sharing, practice forks, duels, async matches — is built on exchanging records, never on a live connection. If two phones can pass a string, they can play each other.
5. **Two ways to play, both whole.** Offense and defense are each a complete game. A pure defender never has to swing.
6. **Kind comedy.** Defenders are rivals, not villains. Getting stopped is funny, not punishing. No violence framing.

---

## 2. Core Mechanic

### 2.1 The stroke
The atomic unit is one stroke. It must be fun on an empty hole before anything else is built.

**Input — "pull, curve, release"**, one continuous gesture, tuned touch-first (ADR-007):
- **Pull back** from the ball to set power (distance = power, capped).
- **Drag sideways** while pulled to set curve (draw/fade). Small offset = subtle shape; large = banana.
- **Release** to swing.
- **Club** chosen with a tap before the pull: **long**, **short**, **putt** (ADR-018). The putter is picked like the other two rather than applied to the player on the green — an auto-putter is a rule you have to notice is happening to you. The selector is a small mark in the top-left corner (ADR-019), not a bar across the bottom.
- **Rationale:** one gesture keeps the floor low for kids and touch; curve-on-the-same-gesture gives skilled players expression without a second input. Timing-bar golf was rejected: it rewards reflexes over reading the hole, against Pillar 1.

**Aiming aid:** a 3D ribbon predicting the arc, *accurate on an empty hole* and *blind to defenders*. It tells the truth about physics and lies about the world — that is the core tension. It is joined by a flat direction line lying in the aim plane, which is the only part of the aid that survives a low camera angle intact.

**Aiming is a subsystem, and it has correctness requirements** (`ADR-026`). Not a feel to be tuned — three properties that hold or do not, and each is a test:

1. **The shot leaves opposite the drag, as seen on screen, at every camera angle.** The drag is unprojected onto the aim plane through the camera. Building the heading from the camera's flattened basis instead is exact only looking straight down, and drifts further the shallower the angle gets — measured at 2.8° of error steep and 32.9° shallow, which is a control that wanders as you orbit.
2. **The drag responds all the way through.** The line locks only where there is a second phase to lock for. A stroke has curve to bend; a bow does not, and locking its line means the second half of every drag does nothing.
3. **Every club is previewed in the terms it actually moves.** A putt rolls, so it is drawn as roll. Sampled as a projectile it lands within a metre and its stub comes to six centimetres, which is no preview at all for the club whose whole skill is distance.

These were found by playing, not by testing, and the tests that hold them now were written from the report.

**Camera** (ADR-001): free orbit, decoupled from aim. Two-finger drag on touch so it never collides with the one-finger stroke. One-tap "reset to line of play"; auto-snap to putt view on the green; zoom limited so the cup is always findable. Consequences: defender tells must read from any angle (silhouette + audio), and holes are authored without a hero angle.

### 2.2 The ball
- `RigidBody3D`, continuous collision detection, physics material per surface (bounce ~0.4 grass / 0.7 cart path / 0.15 sand).
- Spin modeled simply: lateral spin as a small constant flight force (Magnus-lite); backspin as a scalar scaling rolling friction on first bounce. Tunable curves in a `BallProfile` Resource. No aero simulation.
- Stroke ends when velocity < threshold for 0.5 s, or the ball is OB / in water / captured.

### 2.3 The hole
Tee, fairway, rough, sand, water, green, cup — standard vocabulary. Par 2–4; nine holes = a course. Terrain is a `GridMap` of low-poly tiles plus hand-placed props. **Rationale:** fast authoring, trivially low-poly, a path to a level editor later.

### 2.4 The scorecard (the only result in 1.0)
Strokes vs par, per hole, as in golf. That is the complete result of any hole in any mode — there is no rating, medal, ledger, or leaderboard in 1.0 (ADR-010; see §12 for what was designed and parked). A defended hole is simply a hole where the golfer took more strokes; a Match is two scorecards side by side.

**Defender effects on the card:**
- **Blocked / deflected** — ball drops where it was stopped, no stroke added.
- **Caught** — +1 stroke, replay from the previous lie (like a water hazard).
- **Rationale:** the card stays pure golf, legible to anyone who has seen one, and defense never becomes a punishment table.

### 2.5 The Stroke Record
Because the sim is deterministic (§6.1), a stroke is fully described by its inputs. That description is a **Stroke Record** and it is written for *every* stroke from the first M1 prototype onward — see §11. Two rules from day one:
- Gameplay state changes only through a `ShotIntent` or a `DefensePlan`; both are serializable and both go into the record.
- A stroke that can't replay bit-for-bit from its record is a P0 bug.

**Decisions**
- `[PROPOSED]` Pull-curve-release as the sole stroke input.
- `[RATIFIED ADR-018]` Three clubs — long, short, putt — chosen by the player, as `ClubProfile` resources.
- `[PROPOSED]` Blocked = drop in place; caught = +1 and replay.
- `[PROPOSED]` Scorecard is the only result in 1.0; everything in the game is available from first launch.
- `[RATIFIED ADR-001]` Free orbit camera. `[RATIFIED ADR-007]` Touch-first.

### 2.6 First run
A first-time player is taught the stroke, the curve, the defender read and the putt in **one par-4 hole,
under sixty seconds, without a single word**.

This is ADR-004 followed through. That decision made the defenders silent — "no VO, no text bubbles" — for
"no VO budget, no localization surface". Onboarding is the one screen that would otherwise reintroduce the
entire localization surface on day one, so it gets the same treatment.

Teaching falls through three layers, cheapest first: **the world** (geometry that makes the right shot the
only shot) → **the ribbon** (§2.1's preview, coloured for blocked/clear) → **the ghost** (a looping gesture
demo, pinned to the ball's position on screen). There is no fourth layer, and no symbolic one:
`ADR-014` rejected the eight-glyph vocabulary after the hole was built without it and taught fine.

What carries meaning instead is drawn and animated by the engine: ripple rings travelling outward from a
point on the ground, a gold column and rings at the cup, a ghost hand performing the gesture where the
player has to perform it, a trajectory stub that is cyan when the line is clear and amber when it is not,
and a scorecard of filled and empty rings. Nothing is typed, so nothing needs translating and nothing
depends on a vendor's emoji set rendering the same on two devices.

The first run is a **private practice range** (`ADR-017`): a mat, and three pins at three distances, one for
each club. Unlimited balls, and nothing scored against par — you are done with a pin when you have put a ball
on it, and the strokes it took are counted but never held against you. **The range never ends** (`ADR-029`):
when a pin is made the next one comes up, and the next one is the next ternary digit of π — putt, short,
putt, long, short, short, and never the same three twice. Every three pins made is a round, written to disk
as a record; nothing stops for it. On the first run the golfer is the game, and the game just keeps golfing.

There are three clubs, **long**, **short** and **putt**, and the player picks between them (`ADR-018`). The
pin suggests one when it comes up and never insists: taking the long club to the putting pin is a perfectly
good way to find out what the long club is. The selector sits quietly in the top-left corner (`ADR-019`) and
has no words on it either — each club is drawn as the shot it hits: the putt a flat line because it rolls, the
short club a small steep arc, the long club a long shallow one, with both the length and the height taken from
the club's own numbers. That is legible faster than a name would be readable, needs no translating, and says
the thing a bar could not — which club gets a ball *over* something. It is drawn faint, on a small black panel
local to the corner: the range is what is being looked at and the club in hand is a note in the margin. Its
rows stay a fingertip tall regardless, because subtle is a claim about ink and not about what a thumb has to
hit.

**The first run opens on defence** (`ADR-028`): the first thing a new player sees is the game's golfer
addressing a ball, and a bow in their own hands. A switch in the opposite corner to the club selector puts
them on the other end of it (`ADR-020`) whenever they like — the game golfs while they defend, and **the
archer on the rock is theirs** (`ADR-022`). The
tutorial has that one defender and no other — an adversary as well would be a second idea arriving with the
first — and handing the player the *safety net* is the better lesson anyway, because the ball you are asked
to shoot is the one that was about to be lost. Working that side teaches where the course ends by patrolling
it. While it is held it stops guarding by itself: taking the bow means the saving is now your job.

Defence is played third person over the archer, with **the same pull-aim-release drag as the stroke**
(`ADR-021`) — the drag draws a bow instead of swinging a club, the same ribbon previews where the arrow goes,
and the arrow travels, so leading the ball is the skill. The drag reads a bearing on the ground plane, as the
stroke's does, so the **archer supplies the elevation** and the player supplies the lead, the draw and the
moment (`ADR-023`): a club gives a golfer their launch angle and an arrow has nobody to give it one, and a
planar aim with a fixed one cannot be pointed at a ball in the air at all. The bearing is never assisted, so
a lead that is wrong misses by exactly how wrong it was. Neither side gets a god view; that, and not a shared
camera, is what makes the two halves fair to each other. The golfer has a tell now — a backswing, during
which the ball is genuinely held — because §3 asks every defender to telegraph and never said the same of the
golfer, which left a defender reading a shot from a ball that had already gone.

The camera is the free orbit of `ADR-001`, and it is an offset rather than a mode: the range still frames the
shot — behind the ball on the line to the pin, trailing the flight, wide on the archer as it draws — and two
fingers swing that framing around whatever it chose to look at. One finger is the stroke and always was, so
the two never meet. A tap that never became a stroke puts the camera back on the line of play. And a player
who touches nothing for a few seconds is shown the range instead of a viewpoint (`ADR-029`): the camera
leaves the shoulder it was standing over and goes round the line of play, slowly, from wherever it already
was. The first touch brings it back. A defender who is only watching gets the tour; one about to shoot does
not have the view pulled out from under them.

This replaced "The Handshake", a par-4 dogleg that taught power, shaping and the putt through a lie-driven
lesson machine. That was good work for a hole and the wrong first thing to show: it taught three lessons with
one club, because until `ClubProfile` existed there was only one club. A range also puts the first screen on
§8's M1 gate — *is it fun to hit balls at nothing, on a phone?* — instead of on a question from a later
milestone.

The range's defender is an **archer who shoots only balls that are leaving it** (`ADR-015`). A beginner's
characteristic disaster is spraying one off the map; the archer pins those where they were hit, so the range
cannot lose a ball and has no failure state at all.

**Decisions**
- `[RATIFIED ADR-014]` Zero words in the first-run experience; ADR-004's reasoning extended from defenders to onboarding.
- `[RATIFIED ADR-014]` No glyph vocabulary. Teaching is world → ribbon → ghost, three layers, all drawn.
- `[RATIFIED ADR-017]` The first run is a private practice range: three pins, three clubs, unlimited balls, no par.
- `[RATIFIED ADR-015]` Guarded by an archer that only stops balls leaving the range.
- `[RATIFIED ADR-028]` The first run opens on defence. The range itself opens as the golfer; the menu scene that owns the first run says otherwise.
- `[RATIFIED ADR-029]` The range never ends. The next pin is the next ternary digit of π; a round of three is a record, not a stop; an idle player's camera tours the line of play.

---

## 3. The Defenders

Each defender is a **Sport**: a cast, a **zone** it patrols, a **tell**, an **action**, and a **counter** expressed in golf terms. Behavior is data-driven (§6), so a new sport is content, not code. Difficulty scales on three shared axes: **reaction**, **accuracy**, **coverage**.

| Sport | Zone | Tell | Action | Golf counter | Vibe |
|---|---|---|---|---|---|
| **Skeet** | Air, mid-fairway | Shotgun tracks the ball | Fires at apex; hit knocks ball down in place | Keep it low, or curve so the lead is wrong | Grumpy tweed uncle |
| **Bowling** | Ground, fairway lane | Run-up from the side | Bowling ball crosses fairway, deflects | Fly it (wedge), or land behind the roll | Retro shirt, oiled strip on the grass |
| **Archery** | Air, near green | Bow draws, aim line | Arrow pins ball where hit (stops dead, no penalty) | Fast low shots; arrows have travel time | Elf-ish, overly serious |
| **Baseball** | Green + rough | Settles under the arc, glove up | Catches on the fly = OUT | Bounce it in; grounders can't be caught | Sunflower seeds everywhere |
| **Hockey goalie** | Cup | Crouches, tracks the line | Blocks putts through the front 120° | Putt from the sides or off a slope | Padded to twice their width |
| **Soccer keeper** | Green edge | Dives toward landing | Punches ball on landing | Drop it nearly vertical | Argues with nobody |
| **Tennis** | Fairway, both sides | Split-step, racket back | Volleys airborne ball back | Ground it early | Grunts on every hit |
| **Curling** | Green | Sweepers with brooms | Sweeps ahead of a putt so it runs long | Under-hit, or use the sweep | Polite, apologetic |
| **American football** | Fairway | Linemen set, cadence | Wall shoves rolling ball sideways | Air it over the line | Pads bigger than torsos |
| **Basketball** | Near pin | Jumps to block | Swats descending ball | Bank off a slope; no double jump | Headband, G-rated trash talk |
| **Dodgeball** | Anywhere | Wind-up | Throws at ball mid-flight | Vary trajectory | Gym-class chaos |
| **Cricket** | Green | Slips + keeper | Multiple small fielders, 5 m catch radius | Aim for gaps | Cardigans, tea break |

**1.0 roster:** Skeet, Bowling, Baseball, Hockey goalie first (they cover all four zones and all four action types — deflect, block, capture, guard), then four more in M7.

**Rules of defense**
- Defenders are **fair**: they act on the ball's actual state, never on input before release.
- Every defender has a **cooldown** and a **blind spot** visible in its idle.
- Defenders never enter the tee box; the first swing is always yours. On the practice range, placement is derived from the lie rather than authored (`ADR-020`): the defender stands at twice the distance to the pin, mirrored through it, so it guards the ground beyond the target and a short putt is uncontested.
- Difficulty tuning touches only reaction/accuracy/coverage, never invents abilities.
- **Silent** (ADR-004): personality is carried by idle / tell / act / react animations and prop gags. No VO, no text bubbles. The tell's audio motif is a gameplay signal, not dialogue.

**Decisions**
- `[PROPOSED]` MVP four above; four more at M7.
- `[RATIFIED ADR-004]` Silent, animation-only taunts.

---

## 4. Modes

Three families: **solo**, **local**, **async** (turn-based over records, never live). Everything is available from first launch.

### Solo
1. **Practice Range (M1)** — three pins at three distances, one per club, unlimited balls, player-chosen clubs. Exists to tune the stroke, and is also the first run (§2.6, ADR-017 and ADR-018). The archer is its only defender, and it is a safety net rather than an opponent.
2. **Scottish Rules (M2)** — the sandbox: any course, no defenders, plain golf. This is the control group for the game: every hole must be a good golf hole *before* it's a good golfVs hole, and Scottish Rules is how that's checked.
3. **Course Play (M2)** — 9-hole course, defenders placed per hole by the designer.
4. **Gauntlet (M5)** — fixed layouts; each replay adds a defender or raises an axis. Pick one of three modifiers between holes. Seeded, shareable.
5. **Daily Hole (M5)** — one seeded hole per day; local history via records.
6. **Defense Range (M5)** — the defender's practice range. You defend a **whole hole, re-planning at every lie** (ADR-009): the golfer plays, the ball rests, you adjust, repeat until holed. Golfers come from the bundled fixture library, from your own or friends' records replayed lie-by-lie, or from a simple **AI golfer** with tunable skill. Same turn rhythm as a Match, so Defense Range is Match practice.

### Local (one device)
7. **Replay & Fork (M4)** — open any record, scrub it, fork it (§11.3): retry the shot, or switch sides and defend against it.
8. **Pass-and-play VS (M5)** — one golfs, one defends, on one device. **Rationale:** validates asymmetric play without netcode.

### Async (records exchanged by any transport)
9. **Postal Round (M5)** — both play the same seeded course vs the same AI defenders, in their own time; exchange round records; compare cards. Zero interaction; the on-ramp.
10. **Spot Duel (M6)** — one lie, one stroke, one defense. Challenger sends a stroke record ("stop this"); defender answers with a `DefensePlan`; the sim resolves. Best-of-N, alternate sides. Startable from *any* stroke in *any* record.
11. **Match (M7)** — the long form. Full course, roles alternate per hole, simultaneous commit each turn with commit-reveal. Turns take as long as they take; the record is the game. Also **fixed-role** matches (you always defend, I always golf) for pure specialists.

**Decisions**
- `[PROPOSED]` Modes 1–11 for 1.0.
- `[PROPOSED]` Scottish Rules par check is the sign-off gate for every hole.
- `[PROPOSED]` No live multiplayer at any milestone; async-only is a design choice.
- `[RATIFIED ADR-002]` Open source, free; no DLC/IAP; GitHub releases canonical, itch.io / F-Droid mirrors.
- `[OPEN]` Mode name: "Scottish Rules" (cheeky) vs "Golf" (clear).

---

## 5. Art, Audio, Tone

**Look:** flat-shaded low poly, vertex colors only (no textures in 1.0 → tiny builds, trivial mobile perf). Characters ~600–1200 tris, big heads, big hands, stubby legs. Each sport has one silhouette-defining prop.
**Pipeline** (ADR-003): modeled in-house in Blender; `.blend` sources in-repo under LFS; Blender → glTF → Godot. `docs/ART_PIPELINE.md` (export settings, vertex-color conventions, tri budgets) is an M0 deliverable. Each sport has an **art card**: silhouette prop, palette slots, four required animations — idle, tell, act, react.
**Palette:** one 32-color ramp per biome (Parkland, Links, Desert, Snow); defenders share the ramp so they never clash with the ground.
**Post:** none except a subtle outline shader for readability on phones.
**Animation:** snappy, 12–20 frames per action, squash-and-stretch on the ball. Tells are exaggerated to the point of comedy.
**Audio:** club "thwock" pitch-scaled to power; every defender has a 2-note motif on its tell (doubles as accessibility). Music: upbeat lo-fi/chiptune-adjacent, loopable per biome. No dialogue.
**Accessibility:** colorblind-safe zone overlays; all tells have audio + visual + optional haptic; hold-to-slow aiming; no timing-critical input in the base stroke.

**The tutorial is drawn, not grown** (ADR-016). The intro hole is a holodeck blueprint: a solid dark-grey
deck, a cyan grid, glowing outlines, an amber boundary, and one lit ball. It does not depict a golf course
and does not try to — the sunlit manicured fairway sells an image of the sport, and its irrigation, that this
game has no interest in promoting. It is also the honest look for what the hole *is*: a hole that already
teaches through geometry, a coloured trajectory stub and a ghost hand was a diagram drawn on grass.

The blueprint reuses the signal language rather than adding one — cyan is clear, amber costs you, gold is the
cup, green is done — so scenery and signalling cannot contradict each other. Whether the biomes of §5 adopt
it, contrast with it, or are reached *through* it as the simulation it implies, is open and is a 1.0-content
question rather than an M1 one.

**Decisions**
- `[PROPOSED]` Vertex-color-only pipeline for 1.0.
- `[RATIFIED ADR-003]` In-house art in Blender.
- `[RATIFIED ADR-016]` The intro hole renders as a holodeck blueprint; no depicted golf course.

---

## 6. Technical Architecture (Godot 4.x)

### 6.1 Principles
- **Data-driven everything:** sports, clubs, balls, holes, difficulty tiers are `Resource` subclasses (`.tres`), editable in the inspector, diffable in git.
- **One scene, one responsibility.** Composition over inheritance; behavior via child nodes and signals.
- **Deterministic core:** stroke → ball sim → defender reactions replay identically from (seed, inputs). Fixed tick; no wall-clock reads in gameplay code. Required for records, forks, seeds, and async play.
- **GDScript first**, typed, `@tool` scripts for editor helpers. C#/GDExtension only if profiling demands it.

### 6.2 Scene tree
```
Main
├─ GameState (autoload)         # mode, settings, current round
├─ EventBus (autoload)          # stroke_started, ball_stopped, ball_captured, hole_completed
├─ RecordStore (autoload)       # stroke/round/match records; import/export (§11)
├─ Hole (instanced per hole)
│  ├─ Terrain (GridMap + colliders + surface metadata)
│  ├─ Cup (Area3D) · TeeBox (Marker3D) · Hazards/ (Area3D)
│  ├─ Defenders/ (from HoleLayout)
│  └─ Ball (RigidBody3D + BallController)
├─ ShotController               # gesture → ShotIntent; owns aim ribbon
├─ ReplayController             # drives sim from a record; ghosts, forks, async resolution
├─ CameraRig                    # Tee / Follow / Orbit / Putt / Cinematic
├─ HUD (CanvasLayer)
└─ Audio
```

### 6.3 Key classes
- `ShotIntent` (RefCounted): `club`, `power`, `curve`, `direction`. The only thing that crosses from input into simulation.
- `DefensePlan` (RefCounted): human-authored defense (§11.4). Pure data.
- `BallController`: applies `ShotIntent` via `ClubProfile`, tracks spin, detects rest.
- `Defender` (base scene): `DefenderProfile` + `DefenderBrain` (Idle → Tell → Act → Cooldown) + `DefenderZone`. Subclasses override `_can_act(ball_state)` / `_act(ball_state)`. Never reads input.
- `HoleLayout` (Resource): terrain, par, tee, cup, defender placements + difficulty overrides.
- `DifficultyTier` (Resource): reaction/accuracy/coverage multipliers.
- `AIGolfer`: emits `ShotIntent`s toward the cup from a `GolferProfile` (skill, aggression, shape bias). A shot generator, not an opponent.
- `StrokeRecord` / `RoundRecord` / `MatchRecord` (Resources with `to_json()` / `from_json()`).
- `RecordStore` (autoload): append-only writes, index, import/export, deep links.
- `ReplayController`: restores `before`, drives the sim from `intent` / `defense`, renders ghosts.
- `Transport` (interface): `ClipboardTransport`, `FileTransport`, `DeepLinkTransport`; `RelayTransport` post-1.0.
- `TrajectoryPreview`: cheap analytic arc, separate from the physics sim; must land within ~5% of the sim on an empty hole (enforced by test).

### 6.4 Physics
Fixed 60 Hz tick; ball uses CCD; terrain colliders are trimesh baked at import; surface type via collider metadata → `SurfaceTable`. Defender hits are **impulses from the action**, never rigid collisions with animated meshes (flaky, nondeterministic).

### 6.5 Persistence
`GameState` → `user://save.json` with a schema version and explicit migrations. Gameplay history lives only in records under `user://records/`. Nothing in `res://` is written at runtime.

### 6.6 Testing
- **gdUnit4** unit tests: intent→launch math, `SurfaceTable`, migrations.
- **Determinism:** scripted 9-hole round twice from one seed → identical stroke logs. Headless CI.
- **Preview accuracy:** 50 random shots on an empty hole → preview landing within tolerance.
- **Records:** see §11.7.

**Decisions**
- `[PROPOSED]` GDScript-only, gdUnit4, determinism as a hard requirement from M1.
- `[PROPOSED]` Analytic preview separate from the sim.
- `[RATIFIED ADR-008]` Godot pinned to latest 4.x stable at M0; upgrades are ADRs.

---

## 7. Repository and Governance

```
golfvs/                      # working repo name; see OPEN: title
├─ project.godot · README.md · LICENSE (Apache-2.0) · NOTICE · CODEOWNERS
├─ docs/
│  ├─ DESIGN.md              # this document; sections carry status tags
│  ├─ DECISIONS.md           # ADR log — one entry per ratified decision, with rationale
│  ├─ HANDOFF.md             # session handoff packet; the only cross-session memory
│  ├─ ART_PIPELINE.md · RECORD_SCHEMA.md · CONTRIBUTING.md
├─ addons/                   # gdUnit4, outline shader
├─ core/                     # GameState, EventBus, ShotIntent, BallController
├─ records/                  # Stroke/Round/MatchRecord, RecordStore, notation
├─ async/                    # DefensePlan, commit-reveal, Transports
├─ replay/                   # ReplayController, ghosts, fork UI
├─ defenders/_base/ + one folder per sport (scene, profile.tres, models)
├─ holes/ · clubs/ · art/ (LICENSE: CC-BY-4.0, .blend via LFS) · audio/ (LICENSE: CC-BY-4.0) · ui/ · tests/
└─ .github/workflows/        # headless tests on PR; exports on tag
```

**Process** (ADR-006): assistants draft, humans ratify by merging. `CODEOWNERS` routes `docs/` and `core/` to a named ratifier; branch protection requires one review + green CI; a CI check fails any PR that edits `DESIGN.md` without a matching `DECISIONS.md` entry. `HANDOFF.md` is updated at the end of every working session and is the only cross-session state assistants may rely on. Contributors sign nothing; Apache-2.0 §5 covers inbound contributions.

---

## 8. Milestones

Each ends at its gate; the next begins when the gate is ratified.

| # | Name | Exit criteria |
|---|---|---|
| **M0** | Bootstrap | Repo, version pin, CI green on an empty test, `DESIGN` / `DECISIONS` / `HANDOFF` / `ART_PIPELINE` / `RECORD_SCHEMA` seeded, placeholder capsule golfer, Android debug APK launches on a phone |
| **M1** | The Stroke | Practice Range: gesture, 3 clubs, ball physics, aim ribbon, determinism test passing, every stroke written as a Stroke Record and replayable from it, on-device touch tuning. Ghost-gesture demo (§2.6) so a stranger can swing without being told how. **Gate: is it fun to hit balls at nothing, on a phone?** — which cannot be asked before its precondition: **does the control do what it looks like it does** (`ADR-026`, §2.1)? A player fighting the aim is not answering the question the gate poses. Schema v1 frozen at exit. |
| **M2** | First Defender + Scottish Rules | Skeet with full Idle→Tell→Act→Cooldown, data-driven profile, difficulty tiers, defender state in records; Scottish Rules on the same holes. **Gate: does the player feel outsmarting the shooter, and is the hole still good golf with the shooter gone?** |
| **M3** | Vertical Slice | 3 holes, 4 MVP defenders, scorecard, HUD, first real low-poly set, one biome, music loop. **The intro hole and the wordless tutorial layer (§2.6)** — the external playtest is the gate for both. External playtest with kids and adults in Course Play and Scottish Rules. **Gate: can a stranger who was handed the phone with no explanation hole out, and did they smile?** |
| **M4** | Course Play + Replay & Fork | 9 holes, save/load, settings, accessibility; Replay browser, scrubber, Retry / Defend / Ghost forks; record export/import via clipboard, QR, file, deep link. Android release export at 60 fps; desktop exports with mouse + gamepad adaptations. |
| **M5** | Local + Postal | Gauntlet, Daily Hole, Pass-and-play VS (placement UI, budget), Defense Range with AI golfer, Postal Round. `DefensePlan` placement + per-lie re-planning implemented and recorded. |
| **M6** | Spot Duel | `DefensePlan` focus, commit-reveal, two-client resolution test, duel from any fork point, best-of-N, all transports except relay. |
| **M7** | Match + Content | Full async Match (alternating and fixed-role), advisory clocks, match browser; four more sports, second biome, store assets. |
| **1.0** | Release | Desktop + Android. See §12 for what comes next. |

---

## 9. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Stroke isn't fun on its own | Fatal | M1 gate is a hard stop; budget at least two full input-model iterations |
| Defenders feel random/unfair | High | Fairness rules (§3), tell-first policy, determinism so bugs reproduce |
| Physics nondeterminism across platforms | Med | Fixed tick, no animated colliders, impulse hits; fixture-replay CI on every platform |
| Record schema churn | Med | Freeze v1 at M1 exit; `ext` for everything after; forward-only migrations |
| Human `DefensePlan` trivial or unfair | Med | Same brain executes human and AI plans; capped at tier limits; one move per lie; tune in Pass-and-play before any async mode |
| Async play feels dead without a relay | Med | Postal Round and Spot Duel designed for friends on messengers first; relay is a convenience |
| Scope creep from the roster | Med | Data-driven defenders; new sports must map onto existing zone/action types |
| "Kid-friendly" framing of skeet/archery | Low-Med | Cartoon props, ball reacts with sparkles/bounce, no hit effects on characters; check at M3 playtest |

---

## 10. Open Questions

1. **Title and casing** — `golfVs` as written, `GolfVs`, or `golfvs` repo / `golfVs` title. Repo starts as `golfvs`; the Android package ID (`org.quaternionmedia.golfvs`) must be final by M4 and cannot change after first release.
2. Include full `after` state in *shared* records, or only `after.hash`? (§11.1)
3. "Scottish Rules" vs "Golf" as the sandbox mode name. (§4)
4. Repositioning ranges per sport — numbers, tuned in Pass-and-play. (§11.4)
5. Per-sport placement budget costs. (§11.4)

---

## 11. Records, Forks, and Async Play

The design for Pillar 4. Determinism (§6.1) makes a stroke *data*; data can be saved, shared, replayed, forked, and answered.

### 11.1 Stroke Record
```json
{
  "schema": 1,
  "game": "1.0.0+godot4.x.y",
  "hole": { "id": "parkland/03", "layout_hash": "…" },
  "seed": 8123481,
  "before": {
    "ball": { "pos": [x, y, z], "lie": "fairway" },
    "stroke_no": 2,
    "defenders": [ { "id": "skeet_0", "pos": [x, y, z], "state": "idle", "cooldown": 0.0 } ]
  },
  "intent":  { "club": "short", "power": 0.72, "curve": -0.15, "dir": [x, y, z] },
  "defense": null,
  "after":   { "ball": { "pos": [x, y, z], "lie": "green" }, "events": ["skeet_fired", "miss"], "hash": "…" },
  "ext": {}
}
```
- `intent` is the golfer's `ShotIntent`; `defense` is null when the AI defends or a `DefensePlan` when a human does.
- `after` is **derived, not authoritative**: clients recompute and compare `hash`; mismatch = version drift, flagged, never trusted.
- `ext` is a namespaced bag so forks and future features extend without bumping the schema. The core schema is frozen small at M1 exit.
- Target under 1 KB: fits a QR code, a URL fragment, a chat message.
- **Round Record** = header + ordered Stroke Records. **Match Record** = header + turns, each holding one Stroke Record.

**Text notation** — a derived one-line PGN-style view per stroke, readable in a diff or dictated aloud:
```
3. I 0.72 L15 → G (skeet ✗)
```

### 11.2 Storage
`user://records/`, one JSON file per round or match, append-only during play. `RecordStore` keeps a small index for the Replay browser; plain files stay the source of truth. Export as raw JSON, compressed base64 (chat/QR), or `.gvs` file; deep link `golfvs://record/<base64>`.

### 11.3 Forks
A **Fork Point** is `(record_id, stroke_index, side)`. From any fork point:

| Fork | You play | Loads | Purpose |
|---|---|---|---|
| **Retry** | Golfer | `before`, same seed, same defense | Try a different shot against the identical defense |
| **Defend** | Defender | `before` + recorded `intent` replayed exactly | Practice stopping a specific shot; the golfer is a ghost |
| **Ghost** | Golfer | Retry + the recorded ball as a translucent ghost | Beat your or a friend's shot side by side |
| **Duel** | Either | Fork point becomes a challenge (§11.5) | Turn any moment into a game against a person |

Forks record `ext.fork = {parent_record, parent_index, kind}` so lineages can be shown.

### 11.4 DefensePlan — how a human plays the other sports
A human defender **does not steer in real time**. They author a plan that the same `DefenderBrain` executes, so human and AI defense share one code path and both are recordable.
```json
{ "placements": [ { "sport": "skeet", "pos": [x, y, z], "facing": 1.2 } ],
  "focus":      { "skeet_0": { "watch_zone": [x, z, radius], "trigger": "apex" } },
  "moved":      "skeet_0",
  "budget_spent": 3 }
```
- **Placement** from a budget (per-sport costs `[OPEN]`).
- **Focus**: what each defender watches — a zone plus a trigger (`apex` / `landing` / `crossing_altitude:n`). The human's read of the golfer.
- **Fairness:** nothing in a plan exceeds what the AI could do at the current tier. Human defense is *smarter*, never *stronger*.
- **Re-planning between lies** (ADR-009): a plan is set per stroke. Between strokes **exactly one defender may move**, only within its sport's **repositioning range** (goalie shuffles, outfielder jogs, skeet shooter lumbers); cooldowns carry over. Focus may be re-set on every defender every lie — moving is scarce, watching is free. **Rationale:** unlimited re-placement makes defense omniscient; none makes the first plan the whole game.

### 11.5 Async turn structure
All async modes are turn-based over records. No server-side game logic exists anywhere; a "server," if any, is a mailbox.

**Simultaneous commit-reveal (Spot Duel, Match):**
1. Golfer computes `intent`, publishes `H(intent ‖ nonce)`.
2. Defender publishes their `DefensePlan` for this lie in the clear, within repositioning limits.
3. Golfer reveals `intent` + nonce. Both clients run the sim; both get the same `after.hash`.
4. Turn appended to the Match Record; roles alternate per hole (or stay fixed in a fixed-role match).

**Rationale:** commit-reveal removes any need to trust a relay, and step 2 gives the golfer real information — the defense is visible, the exact shot isn't. Steps 1 and 3 collapse to one message between trusting friends.

**Cadence:** none enforced. An optional per-turn clock is advisory. Correspondence-chess norms apply.

**Transports** (one `Transport` interface: `send(record)`, `poll() → [record]`): clipboard / QR → file / share sheet (`.gvs`) → deep link → relay (post-1.0: dumb store-and-forward, encrypted blobs by match ID, self-hostable, no accounts).

### 11.6 Parked ideas the record model makes cheap
Blind Match (results hidden until the round ends); Course Duel (each player authors holes and their defense — needs the level editor); tournament-as-directory-of-records.

### 11.7 Testing
- **Replay:** every fixture in `tests/fixtures/records/` replays to its stored `after.hash` on Linux, Windows, macOS, and Android runners. Fixtures are added whenever a physics or defender change is ratified.
- **Fork:** Retry and Defend forks reproduce `before` exactly.
- **Commit-reveal:** a scripted two-client Spot Duel resolves identically from both sides.
- **Schema:** any `schema: 1` record loads in all future versions; migrations are forward-only.

**Decisions**
- `[PROPOSED]` Schema above as v1, frozen at M1 exit, extensions via `ext` only.
- `[PROPOSED]` Human defense = authored `DefensePlan` executed by the AI brain; no real-time defender control.
- `[PROPOSED]` Commit-reveal as the async protocol; no game logic on any server.
- `[PROPOSED]` PGN-style notation as a derived view.
- `[RATIFIED ADR-009]` Per-lie re-planning, one move per lie within per-sport range, focus free.

---

## 12. Post-1.0 Phase: Progression & Ranking (designed, parked — ADR-010)

Everything below was designed in drafts v0.6–v0.8 and then removed from 1.0 scope. It is preserved here as the design of record so it can be picked up without re-deriving it. Nothing in 1.0 depends on it; 1.0 ships with the scorecard as the sole result and everything available from first launch.

**Two ledgers.** Offense and Defense, each in *strokes per hole relative to expectation*. Offense index ≈ a handicap (under = negative, better). Defense index = strokes forced above expectation per hole defended (higher = better). A pure defender's profile shows `Offense —` and is complete.

**Defense baseline** (was ADR-010's predecessor, now folded in): Expected Strokes = Scottish Rules par + the golfer's rating adjustment, computed from that golfer's **per-hole record** (rolling window of Scottish Rules and Course Play strokes on this hole; cold start → global index → 0). Frozen into each Stroke Record at stroke time so replays score identically forever. Only sandbox and Course Play strokes feed the window, so sandbagging costs real rounds.

**Medals** per hole on each ledger (offense: eagle/birdie/par; defense: Wall +2 / Stop +1 / Held 0). **Unlock trees** per ledger (offense: clubs, ball skins, hats; defense: sports, defender cosmetics, placement budget), fully independent, all earned.

**Compound display.** Never rank on the pair. Two specialist ladders (one per index) plus a third ledger, **Match rating**, an Elo that moves only on alternating-role Match outcomes. **Net swing** (`Offense + Defense`) shown only as a pre-match forecast of per-hole margin, never stored or ranked. Ladders declare which of the three they rank on.

**Relay + League/Ladder.** Store-and-forward relay (§11.5) and rating computation from match records.

**What 1.0 must not do to keep this cheap later:** records must keep enough `before`/`after` state to compute expectation retroactively; the golfer identity in a Match Record must be stable; `ext` must remain open.

**Decisions**
- `[RATIFIED ADR-010]` All scoring beyond the scorecard, all ratings, medals, unlocks, leaderboards, and ladders are post-1.0.
- `[OPEN]` Level editor is the other candidate post-1.0 phase; order the two when 1.0 ships.

---

## Appendix A — M0 task list

1. `git init` as `golfvs`; `.gitattributes` with LFS for `*.blend`, `*.wav`, `*.png`; add `LICENSE` (Apache-2.0), `art/LICENSE` + `audio/LICENSE` (CC-BY-4.0), `NOTICE`, `CODEOWNERS`.
2. Create the Godot project on the latest 4.x stable; record the exact version in README, `project.godot`, CI, and `DECISIONS.md`.
3. Install gdUnit4; one trivial test; CI green headless. Add the DESIGN↔DECISIONS consistency check.
4. Commit `docs/DESIGN.md` (this file), `docs/DECISIONS.md`, `docs/HANDOFF.md`, `docs/ART_PIPELINE.md`, `docs/RECORD_SCHEMA.md` (the §11.1 schema plus one fixture record).
5. Capsule + plane + `RigidBody3D` sphere; confirm CCD and fixed tick; produce an Android debug APK and launch it on a phone.
6. Ratify or reject every `[PROPOSED]` item in this document; answer §10 as far as possible.
