# Changelog

Notable changes, newest first. This project is pre-1.0: the version is a
milestone marker rather than a promise, and anything can move.

The detailed record is elsewhere and stays there — [`docs/DECISIONS.md`](docs/DECISIONS.md)
for *why* something is the way it is, [`docs/HANDOFF.md`](docs/HANDOFF.md) for
what a given session actually did. This file is the short version for somebody
deciding whether to download a build.

## [Unreleased]

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
  project is built toward.
