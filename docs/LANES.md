# golfVs — Work Lanes

**Status:** working document. Not the plan of record — `DESIGN.md` is that, and scope changes there.
**What this is for:** letting several sessions work at once without treading on each other.

Lanes are **lettered rather than numbered, because they are parallel and not sequential.** Each owns a
disjoint set of paths, so two sessions in two worktrees can run a lane each and merge without a conflict.
Lane 0 is the exception: it is a prerequisite, and it is mostly human.

Update the **Status** and **Tasks** of the lane you worked, and nothing else. Two sessions editing two lanes
edit two parts of this file.

---

## The rules that make this safe

**1. Stay inside your lane's paths.** If a change wants a file another lane owns, that is a signal the work
belongs in the other lane, not a reason to reach across. Say so in `HANDOFF.md` and let that lane pick it up.

**2. Three files are shared, and each has a rule.**

| File | Rule |
|---|---|
| `project.godot` | One lane at a time, and **never with the Godot editor open** — it silently overwrites the file on save, which has already cost this project two settings. Announce it in `HANDOFF.md` before and after. |
| `docs/DESIGN.md` + `docs/DECISIONS.md` | CI-coupled: they must move in the same commit. Scope does not change without a logged rationale (ADR-006). |
| `docs/HANDOFF.md` | Append a section per session under §7. Never rewrite another session's. |
| `docs/PLAYTEST.md` | Append a round. Never edit a previous one — what somebody said is not revisable. |

**3. Nothing is ratified by writing code.** Assistants draft, humans ratify (ADR-006). If a lane's work
implies a decision, add it to `DECISIONS.md` under *Pending ratification*, put the reasoning in `HANDOFF.md`,
and carry on — flagged, not blocked. Deviating from `DESIGN.md` silently is the one failure mode this project
has already had.

**4. Leave the suite green and the demo passing.** Both are fast:

```sh
GODOT_BIN=/path/to/godot ./addons/gdUnit4/runtest.sh --add res://tests --continue
"$GODOT_BIN" --headless --fixed-fps 120 --path . res://tools/demo_round.tscn
```

The demo is a real gate — it exits non-zero if a stroke fails to replay to its own hash, if the round on disk
differs from the round played, or if a defender's verdict is not reproducible from its seed. Three of the
five bugs found in session build-04 were invisible to unit tests and obvious within one headless round.

---

## Lane 0 — Ground truth

**Owns:** git · `.github/` · `docs/DECISIONS.md` · `CODEOWNERS` · `governance/`
**Status:** in progress. ADR-012 to ADR-015 ratified; the remaining items are human or hardware. The remote
is decided: **`quaternionmedia/golfvs`**, and golfVs adopts the QM constitution as the first project in the
**qm studios** family.
**Gate:** M0 exits when the APK launches on a phone and CI is green on a real remote.

- [x] First commit, and a baseline that matches the tree the tests were run against
- [x] Ratify the float precision and hash-input proposals (ADR-012, ADR-013)
- [x] Settle the first run: wordless, no glyphs, no onboarding document (ADR-014)
- [x] Settle the intro hole's defender (ADR-015)
- [x] **Pushed to `quaternionmedia/golfvs`** -- public, in the org, `main` first, then the branch as draft
      PR #1
- [x] **Actions turned on** at the ratifier's request, with the build enabled for Windows, Linux and
      Android on every pull request. See `HANDOFF.md` §7 build-06 part seven for what the first run did
- [x] Branch protection on `main`: required checks `DESIGN and DECISIONS agree`, `gdUnit4 headless
      (ubuntu-latest)`, `Windows, Linux and Android (debug)`; no required reviews (the QM house rule);
      admins not enforced, so the ratifier keeps a bypass; no force-push, no deletion. Code-owner review
      off until the handles are confirmed. PR #1 is CLEAN against it
- [x] **Prove the coupling check.** PR #3, cut from `main`, editing `DESIGN.md` alone: red, with the
      ADR-006 message verbatim. Closed, not merged. (PR #2, cut from the feature branch, *passed* -- see
      Lane H: a stacked branch slips a `DESIGN.md`-only change past a per-PR-diff rule)
- [ ] Ratify or reject the four M1 blockers: stroke gesture · three clubs + auto-putter · Stroke Record
      schema v1 · GDScript + gdUnit4 + determinism
- [ ] ADR or revert for the three open divergences: the press-anchored pull, the 7 % ribbon, `RecordStore`
      as a static class rather than an autoload
- [x] `CODEOWNERS` names confirmed: all four are `quaternionmedia` org members (build-06). Code-owner
      review stays off only because there are no required reviews to attach it to
- [ ] Close Open Question 1 — the name. The Android package ID must be final by M4
- [x] **Android debug APK builds** (ADR-024). `org.golfvs.test`, arm64, 30 MB, signed with the debug key
- [ ] **Install that APK on a physical phone and play it.** This is the part that really was hardware, and
      it is now the only part: M0's gate, M1's gate and every tuning number in Lane C are waiting on it

**Adopting the QM constitution -- in the handbook's order, no step skipped.** The authority is
`quaternionmedia/qm`'s `handbook/forking-a-project.md`; `docs/usage/first-project.md` there outlines it and
says in so many words not to improvise a lighter version, because most adoption defects come from skipped or
partial steps. So: the eight steps as written, each with its own verification check, staged rather than
thinned. Steps 1-3 all need the remote and are done together at push time.

- [ ] 0. Confirm the starting commit, in both repositories
- [ ] 1. Add `qm` as a submodule at `governance/qm`
- [ ] 2. Create `project/golfvs` in `qm` off `main`, copy `project-seed/adr/` onto it as `adr/`, and
      **push the branch** -- no pull request; it is the one place content arrives on a shared branch by push
- [ ] 3. Point the submodule at the branch; `branch = project/golfvs` in `.gitmodules`
- [ ] 4. Wire CI: the four seed workflows verbatim -- `adr-lint.yml`, `submodule-check.yml`,
      `reuse-lint.yml`, `one-pr-check.yml` -- plus the licence gates the open-licence record requires
- [ ] 5. `project-seed/ide/` onto the root, symlinks preserved (`cp -a`); fill in `AGENTS.md`; check
      `.gitignore` does not swallow any of it
- [ ] 6. First records on the branch as numberless drafts: an adoption record and a scope record
- [ ] 7. Register carried patches in `qm`'s `registers/carried-patches.md` (none known)

Two things the adoption record has to say, because they are decisions and not details:

- **The family.** `qm studios` is not yet declared anywhere in the corpus -- no record, no register entry.
  golfVs names it in its adoption record; declaring it at org level is a `qm` pull request of its own.
- **The ADR format.** `project-seed/ci/adr_lint.py` wants one `ADR-0001-slug.md` file per record, a
  `| **Status** |` row, and an index that matches the directory. This project keeps every decision as a row
  in one table in `DECISIONS.md`, and the coupling check that enforces ADR-006 reads that table. Step 4
  will fail on it. The choice is migrate or carry the divergence, and it is made in the record, not by
  letting the lint fail quietly.

---

## Lane A — Records

**Owns:** `records/` · `docs/RECORD_SCHEMA.md` · `tests/records/` · `tests/fixtures/`
**Status:** the spine is built and ratified. What remains is the parts nothing has needed yet.
**Depends on:** nothing. Entirely headless.

- [x] Canonical serialisation, quantization, SHA-256 (ADR-012, ADR-013)
- [x] `StrokeRecord` with `to_json` / `from_json`, and §4.1 notation
- [x] `RecordStore` — append-only rounds under `user://records/`
- [ ] **Promote a demo round into a real fixture** and turn on the replay test. Now unblocked: ADR-012 is
      ratified, so a recorded fixture is no longer scrap
- [ ] Retire the all-zero hash from `0001-parkland-03-stroke-2.json`, or keep it deliberately as the
      "never simulated" case with a test that says so
- [ ] `MatchRecord` — a header plus turns. Nothing needs it before M7, but the shape freezes at M1
- [ ] Answer question 2 of `RECORD_SCHEMA.md` §6: do shared records carry full `after`, or only its hash?
- [ ] Compressed base64 form, and check a one-stroke record still fits a QR code

**Start here:** `records/canonical.gd` is the file to read first; everything else in the lane depends on
what it promises.

---

## Lane B — Determinism spine

**Owns:** `core/` except `core/stroke/` and `core/camera/` · `tests/core/`
**Status:** not started. **The largest unquantified risk in the project.**
**Gate:** one recorded stroke replays to its own hash, twice, on two platforms.

- [ ] **Measure Jolt across two operating systems.** Run one fixture 1000 ticks on Windows and on Linux and
      diff the final state. §9 rates cross-platform physics nondeterminism "Med" and names fixture-replay CI
      as the mitigation; neither the CI nor the measurement exists, so the rating rests on nothing. **If it
      drifts, that is an ADR-sized finding** and five of the eleven 1.0 modes are affected
- [ ] Decide the stepping model: does gameplay advance on `_physics_process`, or on an explicitly stepped
      fixed loop a replay can drive? Everything after depends on the answer
- [ ] `BallController` — apply a `ShotIntent` through a `ClubProfile`, track spin, detect rest. Currently
      the intro hole does this inline
- [ ] Seed plumbing audit: a test that fails on any bare `randf()` in gameplay code
- [ ] `SurfaceTable` and collider metadata for lie detection, replacing `practice_range._lie_at`'s hardcoded
      radii
- [ ] `GameState` and `EventBus` autoloads (§6.2). **Takes the `project.godot` lock**
- [ ] Promote the CCD sweep in `m0_physics_smoke.gd` to an optional CI gate

**Start here:** `core/m0_physics_smoke.gd` already measures CCD the way this lane needs to measure drift.

---

## Lane C — The stroke (M1)

**Owns:** `core/stroke/` · `core/camera/` · `clubs/` · `holes/range/` · `tests/stroke/` · `tests/camera/`
**Status:** unblocked and largely built. ADR-018 ratified three clubs, `ClubProfile` exists, and the range is
playable. What is left is tuning, which needs a thumb.
**Gate:** is it fun to hit balls at nothing, on a phone?

- [x] **Aiming correctness** (ADR-026): the drag unprojected through the camera, the line locking only where
      there is curve to bend, the putt previewed as roll, a flat direction line. Three tests pin it and they
      fail against the code that shipped
- [ ] **Tune the gesture on a real thumb.** `LOCK_PX`, `MAX_PULL_PX`, `MAX_CURVE_PX` are all mouse guesses,
      and ADR-007 makes touch the reference feel (hardware). Correctness is settled; this is feel
- [x] **Confirmed by the player who reported it** — "much better" (`docs/PLAYTEST.md`, round 1). Desktop and
      mouse; the low-angle read still has not been tried with a thumb, and ADR-007 makes the thumb the
      arbiter of feel
- [x] `ClubProfile` — long, short, putt (ADR-018), as named constructors. `BallFlight`'s hardcoded
      `MIN_SPEED` / `MAX_SPEED` / `LAUNCH_DEG` now live in them
- [ ] `ClubProfile` as `.tres`, once the numbers stop moving every session. See the note in the file
- [x] Practice Range: three pins, unlimited balls, `defended` togglable
- [x] `start_defending` on the range, and taking the bow now leaves `ATTRACT` (ADR-028). The second is
      a fix: the attract screen only ever left on the golfer's drag, so a defender there was stuck with a
      golfer who never played. Three tests go red without it. Done from Lane D at the ratifier's direction
- [x] **The range never ends** (ADR-029): `State.DONE` removed, the next pin is π's next ternary digit
      (`PIN_ORDER`, `pin_at`), a round of three writes the session and carries on. The idle camera:
      `IDLE_AFTER` without a touch and the view goes round the line of play from where it was. Ten tests
- [x] **The camera turns about the player** (ADR-030): `_framed(eye, at, pivot)`, pivot always the active
      player; defend view pulled back and `DEFEND_YAW` right; the tour is the framing eased, never a mode.
      `test_the_tour_never_jumps` steps sixty frames a second through the whole cycle and bounds every step
- [x] The orbit camera (ADR-001) — two fingers, a tap to recentre, zoom and elevation limited
- [ ] Preview accuracy test — 50 random shots, preview landing within 5 % of the sim (§6.6)
- [ ] Write and replay a Stroke Record for every range shot (needs A and B)

**Note for whoever takes this:** `intent.club` now records what was actually in hand, because there is now
more than one club to be in it. The orbit means the aim mapping is no longer fixed either —
`StrokeGesture._screen_pull_to_heading` reads the camera basis, so "pull back" is relative to wherever the
player has orbited to, which is the behaviour you want and the one to check first on a phone.

---

## Lane D — First run

**Owns:** `ui/` · `tests/ui/`
**Status:** playable, defended, and writing records. What remains needs a person and a phone.

**Lane C owns the range itself** (`holes/range/`), so the two do not overlap: this lane is the flat layer
drawn over it — the selector, the card, the ghost and the signals.

- [x] The wordless signalling: the ghost, the beacons, the ribbon stub, the spin dial
- [x] The club selector, moved into the corner and quietened (ADR-019)
- [x] The archer (ADR-015)
- [x] **The first run opens on defence** (ADR-028) -- `start_defending` on the range instance in
      `main_menu.tscn`, pinned by `tests/ui/test_first_run.gd`. The ghost stays quiet for a defender
- [x] The loading screen is the icon, not Godot's logo (ADR-028)
- [x] No more tap-to-restart: there is nothing to restart (ADR-029). The card fills through each round of
      three and clears
- [ ] **Play it on a phone.** The ghost is placed by `unproject_position` and its `PULL_PX` is a desktop guess
- [ ] **Watch a stranger play it, and watch one thing:** can they judge *distance* from a 7 % ribbon stub and
      a target ring? That is the known weak point. The cheap fix is a landing ring, which gives back most of
      what truncating the ribbon bought — so be sure before spending it
- [ ] Play it with `defended` false. §4 makes "is it still a good golf hole with the defender gone" the
      sign-off for every hole, and this is the first time that is checkable
- [ ] `HoleLayout` as a resource, and GridMap tiles to replace `hole_builder.gd` at M3

---

## Lane E — Defenders

**Owns:** `defenders/` · `tests/defenders/`
**Status:** the framework holds two sports, and archery now does both of its §3 jobs — the boundary net of
ADR-015 and an adversary contesting the line (ADR-020). Skeet is still built and still on no hole.

- [x] `DefenderProfile` / `DefenderBrain` / `DifficultyTier`, and fairness as a signature rather than a rule
- [x] Skeet (apex trigger, knock down) and the archer (boundary trigger, pin)
- [ ] **A third sport, to prove the framework generalises before four more are built on it.** Bowling is the
      useful one: it is the first *ground* sport, so it is the first `_target_index` that is neither an apex
      nor a boundary
- [ ] Put skeet on a hole. It has never been played against
- [ ] `DefenderZone` as a visible thing — the player has to read where a defender's zone is *before* the
      stroke, and right now nothing draws it. **The most valuable thing in this lane.** Defending, the aim
      thread reports reachability live, which is a read of *now*; the golfer still gets nothing before the
      stroke, so "keep it low" has to be discovered rather than seen
- [x] Per-lie re-planning (ADR-009) on the range: the contesting archer moves every lie, to a position
      derived from it. The *choice* of where — the part ADR-009 leaves to a plan — is still not built
- [x] Defence is playable: third person over the defender, same gesture as the stroke, arrow with travel
      time (ADR-020, ADR-021), and the archer solves the elevation so a planar aim can reach an airborne
      ball at all (ADR-023). **It has been played by nobody.** `BOW_MIN_SPEED` / `BOW_MAX_SPEED` set how much
      lead the shot needs and `ARROW_HIT` sets how forgiving it is; all three are tuned against a mouse, and
      two tests now pin the *shape* of the skill — a good lead connects, no lead misses — so those numbers
      can be moved without wondering whether the side still works
- [x] The first run's defence is the archer on the rock, held by the player (ADR-022). The contesting
      archer is built, tested and **off** — `set_contested(true)` stands one up, and the first hole that
      wants one is the first real test of whether the placement rule holds away from a range
- [ ] `DefensePlan` as the human's authored defence (§11.4). **ADR-020 conflicts with it** by letting a
      person steer in real time, and says why the replayability §11.4 protects survives anyway. Whoever
      takes this decides whether the plan model replaces that or wraps it
- [ ] The audio motif per sport. ADR-004 makes it a gameplay signal, not decoration

**Read before adding a sport:** `test_defender_brain.gd` pins a counter-intuitive measurement — at full
curve the apex moves only about three metres against an eleven-metre zone radius, so "curve so the lead is
wrong" works through the accuracy falloff and *not* by leaving the zone. A hole designed on the opposite
assumption plays as unfair. Also check any new tell against the flight time: a tell longer than the time to
the action means the defender silently never acts, which looks exactly like one that is working and missing.

---

## Lane F — Art and audio

**Owns:** `art/` · `audio/` · `docs/ART_PIPELINE.md` · the outline shader in `addons/`
**Status:** not started. **Nothing blocks it and it blocks M3.** The longest lead in the project.

- [ ] **Prove the LFS path end to end** — commit one `.blend`, clone fresh, confirm it comes down. Do this
      while there is one file, not fifty. The filters are written and have never touched a file
- [ ] The outline shader — the only post-processing 1.0 permits, and what makes vertex-colour-only art read
      on a phone
- [ ] First vertex-coloured mesh through the whole pipeline, matched against the placeholder albedos in
      `hole_builder.gd`
- [ ] Art cards (idle / tell / act / react) for skeet and archery. `DefenderArt`'s block proportions are what
      a real mesh has to match — how far a barrel reaches and how tall an archer stands are read at distance
- [ ] Ratify `ART_PIPELINE.md` out of DRAFT

---

## Lane G — Async and replay

**Owns:** `async/` · `replay/`
**Status:** not started. Buildable against the existing fixture before anything else lands.

- [ ] `Transport` interface plus Clipboard, File and DeepLink. All four testable against a fixture today
- [ ] `ReplayController` — restore `before`, drive the sim from `intent` and `defense`, render a ghost
- [ ] Fork tests: Retry and Defend both reproduce `before` exactly
- [ ] `DefensePlan` and its fairness validator. A plan exceeding the tier cap is **rejected at load, never
      clamped** — clamping silently alters a recorded game
- [ ] Commit-reveal, and the scripted two-client Spot Duel that must resolve identically from both sides

---

## Lane H — Infrastructure

**Owns:** `.github/` · `tools/`
**Status:** the docs check has six enforcement rules; the demo is a gate; all five targets build from one
script and the suite is matrixed across three operating systems (ADR-027). CI has run, and is green.

- [x] Documents-exist and proposals-agree checks
- [x] The demo round as a CI job
- [x] Matrix the test job across Linux, Windows and macOS (ADR-027). **Lane B's gate needs it to mean
      anything.** Authored and the Linux leg is what ran locally; the other two legs have never executed and
      are expected to be informative before they are green -- they stay off the required list until each has
      passed once
- [x] Export presets for Android and desktop, keystore path out of the repo (ADR-024). `tools/build.sh`
      produces both; `.github/workflows/build.yml` runs the same script on demand or on a `v*` tag
- [x] Linux and macOS presets; **four targets from one script** (ADR-027). All four exported from a clean
      tree on Windows; the three desktop packs are byte-identical. The Godot install is one composite action,
      `.github/actions/setup-godot`, reading the pin from `.godot-version`
- [x] A `v*` tag assembles a **draft** release with notes from `CHANGELOG.md`; a person publishes it (ADR-027)
- [x] **CI builds Windows, Linux and Android on every pull request** (ADR-027 revised); `build.sh` takes a
      list of targets; macOS is local-only until somebody can open one
- [x] `tools/check_version_consistency.py` -- the four places a version is stated, refused in CI if they
      disagree, and the tag with them on a tag build
- [x] **Linux arm64, for the Raspberry Pi 5** (ADR-027 revised again). Fifth target, fourth in CI; one
      preset, ETC2/ASTC textures, an `override.cfg` beside the binary for the Compatibility renderer.
      Exported from a clean tree on Windows and confirmed aarch64; never booted, nobody has the chip
- [x] **CI boots the Linux build with a renderer**, lavapipe and llvmpipe under xvfb, thirty frames each.
      Advisory (`continue-on-error`) until it has been green long enough to be believed; the headless
      boot had never created a renderer and so could not have seen the first outside tester's crash
- [ ] **Measure both renderers on a Pi 5** and turn the arm64 `override.cfg` from a guess into a
      decision: frame time on Forward Mobile and on Compatibility, at the Pi's display resolution, with
      and without glow. The next knob if Compatibility is still slow is 3D resolution scale
- [ ] **Promote the rendered boot to a gate** once it has passed on, say, ten consecutive runs -- drop
      `continue-on-error` and add the step to nothing; the job is already required
- [x] Publishing hygiene (ADR-025): own icon, `THIRDPARTY.md`, the workshop excluded from exports, community
      files, `CHANGELOG.md`, and `docs/RELEASE.md` as the checklist
- [ ] **Make the matrix measure what it was built for.** Today each CI leg plays its own random round
      and checks it agrees with itself; no leg's hashes meet another's. Three pieces: (1) the demo takes a
      seed -- `--seed N` on the command line or `GOLFVS_SEED` in the environment, into `_round_seed`
      before `_setup_play`; (2) each leg prints and uploads a digest -- the `after.hash` of every stroke,
      one per line, as `determinism-<os>.txt`; (3) a fourth job, `needs: tests`, downloads the three and
      `diff`s them, and is the one that goes on the required list. About forty lines. Until it exists the
      Windows and macOS legs are "it runs there", not "it agrees there"
- [ ] **The coupling check is per-PR-diff, and a stacked branch evades it.** Found by the first probe (PR
      #2): a `DESIGN.md`-only commit on a branch cut from another branch that already touched
      `DECISIONS.md` passes, because `git diff base...HEAD` sees the whole stack. In the normal flow --
      branch from `main`, PR to `main` -- it holds. Two fixes, either is small: check per commit in the PR
      range, or require the *same commit* that touches `DESIGN.md` to touch `DECISIONS.md`
- [ ] A release build and a release keystore. Needs a decision about where the secret lives, and something
      worth releasing
- [ ] **Push to `quaternionmedia/golfvs` and cut v0.0.1-test.** Everything the tag needs is in place; what
      is missing is the remote, one green CI run, and somebody launching the binaries. The remote is the
      org's, not a personal one: golfVs is a QM project (Lane 0)
- [ ] Verify the Windows and macOS Godot asset names on the first matrix run. Only the Linux one
      (`Godot_v<pin>_linux.x86_64.zip`) has ever been fetched; `win64.exe.zip` and `macos.universal.zip`
      follow the convention and have not been proven
- [ ] A check that the engine pin and the autoload list survived the last editor save
- [ ] Note-level check that gdUnit4's supported-Godot range still contains the pin. It currently does not —
      6.2.1 lists up to 4.7.1 and the pin is 4.7.2

---

## Running order

The critical path to M1 is **0 → (A ∥ B) → C**. Everything else runs beside it.

| | Can start now | Waiting on |
|---|---|---|
| **0** | yes | a human, and a phone |
| **A** | yes | — |
| **B** | yes | — |
| **C** | no | Lane 0 ratifying three clubs; its record leg needs A and B |
| **D** | yes | a phone and a stranger |
| **E** | yes | — |
| **F** | yes | — |
| **G** | yes | converges on A when the classes land |
| **H** | yes | — |
