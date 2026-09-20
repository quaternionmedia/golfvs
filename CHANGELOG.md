# Changelog

Notable changes, newest first. This project is pre-1.0: the version is a
milestone marker rather than a promise, and anything can move.

The detailed record is elsewhere and stays there — [`docs/DECISIONS.md`](docs/DECISIONS.md)
for *why* something is the way it is, [`docs/HANDOFF.md`](docs/HANDOFF.md) for
what a given session actually did. This file is the short version for somebody
deciding whether to download a build.

## [Unreleased]

### Added
- **A Raspberry Pi 5 build.** `linux-arm64` is the fifth target of `tools/build.sh` and the fourth CI
  builds on every pull request (ADR-027, revised again). One preset, no new tooling; its pack carries
  ETC2/ASTC textures rather than BC because that is what the Pi's GPU samples. It ships with an
  `override.cfg` beside the binary that starts the game on the Compatibility renderer -- provisional
  until both renderers have been measured on a Pi; delete the file to try Forward Mobile.
- **CI boots the Linux build with a renderer**, twice -- Forward Mobile on lavapipe and Compatibility
  on llvmpipe, under a virtual X server. Advisory for now: the step goes red, the job stays green.

### Fixed
- **A crash before the first frame on machines whose only Vulkan device is `llvmpipe`** (a VM, or a
  desktop without a Vulkan driver), reported by the first outside tester. Not ours to fix -- it is
  Mesa's software driver aborting inside its own shader compiler on one of the engine's Mobile-renderer
  shaders -- but ours to name: `./golfVs.x86_64 --rendering-method gl_compatibility` avoids it, and
  the release notes now say so. The `propagate_notification` error printed just before the crash is
  Godot's crash handler running on the driver's thread, not a second bug.
- The launcher-icon renders under `build/` are no longer imported by the editor at all
  (`build/.gdignore`); the export exclusion stays as the second line of defence.

## [0.0.2] — 2026-09-19

**Pre-alpha.** The first build that came out of CI rather than off a desk, and the
first one with a defender you can be from the first frame. Still a debug build of a
practice range, still one sport of twelve, still nothing you would call a game -- the
*Not in it* and *Known gaps* lists below are the honest part. Tagged `v0.0.2-prealpha`.

### Playable

- **You open on defence.** The game golfs at three pins; you hold the archer on the
  rock and the same drag that swings a club draws a bow. The switch in the corner
  hands you the club whenever you want it.
- **It never stops.** Make a pin, the next comes up -- in the order of π's ternary
  digits, so never the same three twice. Leave it alone and the camera goes round you.

### Changed
- **The range never ends** (ADR-029). Make a pin and the next one comes up, in the order of
  π's ternary digits -- putt, short, putt, long, short, short, and never the same three twice.
  Every three pins you played is written to disk as a round; nothing stops for it. On the first
  run the golfer is the game, and it just keeps golfing -- and writes nothing, because a round
  nobody played is not a record of anything.
- **Leave it alone and the camera goes for a walk** (ADR-029, ADR-030). A few seconds without a
  touch and the view eases out and round the player -- you, whichever end of the swing you are
  on -- from wherever it was. Touch anything and it eases home. Nothing cuts.
- **The camera orbits you** (ADR-030). Two fingers now turn the view around the archer you are
  holding, or the ball you are about to hit, rather than a point down the range. The defender's
  view stands further back and seven degrees to the right.
- **The first run opens on defence** (ADR-028). The first thing a new player sees is the game's
  golfer addressing a ball and a bow in their own hands; the switch in the corner still hands them
  the club. The range itself still opens as the golfer -- the menu scene is what says otherwise.
- **The loading screen is our icon on the deck's black**, not Godot's logo (ADR-028). It is the
  one PNG in the tree, because Godot accepts nothing else there.
- **Linux and macOS test builds**, beside Windows and Android (ADR-027). All four from
  `tools/build.sh`; the macOS bundle is unsigned and Gatekeeper will want
  `xattr -dr com.apple.quarantine golfVs.app` before it opens.
- **CI runs the suite and the demo round on Linux, Windows and macOS**, and did, green, on its
  first run. That proves the game runs and the files land on three operating systems; it does
  not yet prove the same seed hashes the same on each -- nothing compares the legs yet.
- A `v*` tag now assembles a **draft** release with these notes; a person publishes it. Every
  pull request builds Windows, Linux and Android and leaves them in the run's artifacts.

### Fixed
- Switching to defence on the attract screen left the game's golfer standing over the ball
  forever. The only drag that leaves the attract screen was the one the defending side ignores.
  Reachable since the switch existed; found the day the first run started there.

### Not in it

- No audio at all. ADR-004 makes the defender tell an audio signal; it is unbuilt.
- No real art. Every figure is boxes standing in for meshes that do not exist.
- One defender, one range. Skeet is built and on no hole; the other ten sports in
  `DESIGN.md` §3 are a table.
- No course, no scoring beyond the card, no async play, no multiplayer.
- No macOS build in the release. It exports; nobody on the project can open it.
- No signing, anywhere. Windows will warn, Android will ask, and both are right to.

### Known gaps

- **Nobody has watched the idle camera.** Every number that says it is smooth was
  taken headless. The first person to leave the Windows build alone for a minute
  knows more than the tests do.
- **Cross-platform determinism is measured but not yet compared.** The suite and
  the demo round pass on three operating systems; no leg's hashes have met
  another's. The records are advertised as portable on the strength of a check
  that is half built.
- **Colour carries meaning and there is no second channel.** The game is wordless
  and leans on cyan, amber, green and gold; with no audio yet, a colour-blind
  player loses distinctions the game never says another way.
- **Nobody has played this on a phone**, which is the one question the whole
  project is built toward. The APK in this release is the first one that did
  not come off a developer's machine, and it has not been installed on anything.
- **The package id is provisional** -- `org.golfvs.test`. Installing this is
  installing something that will have to be uninstalled when the name is settled.

## [0.0.1] — 2026-09-09

The first build that leaves the machine it was made on. It is a **debug build of
a practice range**, not a game — the pitch in the README describes twelve sports
and a course, and what exists is one range, one defender, and box art.

### Playable

- **A practice range.** Three pins at three distances, one per club, unlimited
  balls, nothing scored against par (ADR-017).
- **Three clubs — long, short, putt — chosen by the player** (ADR-018). The
  selector sits in the top-left corner and draws each club as the shot it hits:
  a flat line for the putt, a small steep arc, a long shallow one (ADR-019).
- **The stroke:** pull, curve, release, as one continuous gesture. The ball is
  held for a real backswing, which is also the golfer's tell.
- **A free orbit camera** (ADR-001): two fingers on touch, right-drag and wheel
  on mouse, a tap to recentre.
- **Aiming that does what it looks like it does** (ADR-026). The drag is read
  through the camera rather than off its flattened basis, so the shot leaves
  opposite the drag at every camera angle instead of drifting up to 33° as the
  view gets shallower. The line only locks where there is curve to bend, so the
  bow can be re-aimed all the way through the drag. A putt is previewed as roll,
  because previewed as a projectile it landed in a metre and showed nothing.
  Found by playing — see `docs/PLAYTEST.md`.
- **You can play the other side.** A switch in the opposite corner hands you the
  archer on the rock — the safety net itself (ADR-020, ADR-022). Defence is
  third person over your own figure and uses the same drag as the stroke; the
  arrow travels, so leading the ball is the skill (ADR-021, ADR-023).
- **Every stroke is written as a portable, hash-verified record** and the round
  is saved under `user://records/`.

### Not in it

- No audio at all. ADR-004 makes the defender tell an audio signal; it is unbuilt.
- No real art. Every figure is boxes standing in for meshes that do not exist.
- One defender, one range. Skeet is built and on no hole; the other ten sports in
  `DESIGN.md` §3 are a table.
- No course, no scoring beyond the card, no async play, no multiplayer.

### Known gaps

- **Colour carries meaning and there is no second channel.** The game is wordless
  and leans on cyan, amber, green and gold; with no audio yet, a colour-blind
  player loses distinctions the game never says another way.
- **Cross-platform determinism is unmeasured.** Records are designed to be
  portable and nothing has yet checked that the physics agrees across operating
  systems.
- **Nobody has played this on a phone**, which is the one question the whole
  project is built toward. Everything confirmed so far was confirmed with a
  mouse, and ADR-007 makes the thumb the arbiter of feel.
