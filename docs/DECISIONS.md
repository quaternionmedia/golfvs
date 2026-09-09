# golfVs — Decision Log (ADRs)

One entry per ratified decision. Ratified by the human ratifier; drafted by assistants. A `[PROPOSED]` item in `DESIGN.md` becomes an ADR here when merged. Superseded entries are kept and marked.

| ADR | Date | Decision | Rationale | Status |
|---|---|---|---|---|
| 000 | 2026-09-03 | Adopt `DESIGN.md` 1.0-draft.1 as the plan of record | Refreshed from working drafts v0.1–v0.8; supersedes them entirely | Active |
| 001 | 2026-09-03 | Camera: free orbit, decoupled from aim; two-finger drag on touch; one-tap reset; auto putt view | Feels like golf; readability recovered via any-angle tells and mandatory audio motifs | Active |
| 002 | 2026-09-03 | Distribution: open source, free; no DLC/IAP/entitlements; GitHub releases canonical, itch.io / F-Droid mirrors | Consistent with QM; removes an entire server/receipt surface | Active |
| 003 | 2026-09-03 | Art: modeled in-house in Blender; `.blend` in repo via LFS; vertex-color pipeline; per-sport art card with idle/tell/act/react | Reproducible by contributors; placeholders and finals share one pipeline | Active |
| 004 | 2026-09-03 | Defenders are silent; personality via animation and props only; no VO, no text bubbles | No VO budget, no localization surface; tell audio motif is a gameplay signal and is unaffected | Active |
| 005 | 2026-09-03 | Licenses: Apache-2.0 (code), CC-BY-4.0 (art/audio); inbound contributions under Apache-2.0 §5, no CLA | Patent grant; permissive art reuse with attribution | Active |
| 006 | 2026-09-03 | Team: small QM team; process enforced by tooling — CODEOWNERS on `docs/` and `core/`, branch protection, CI check that DESIGN edits carry a DECISIONS entry; `HANDOFF.md` is the only cross-session memory | "Assistants draft, humans ratify" made mechanical | Active |
| 007 | 2026-09-03 | Input: touch-first; the stroke gesture is tuned on a phone; Android debug build on device is an M0/M1 exit criterion; mouse and gamepad adapt from touch | One reference feel; mobile is the hardest target | Active |
| 008 | 2026-09-03 | Godot: pin to the latest 4.x stable at M0; record exact version in `project.godot`, README, CI, and here; upgrades are their own ADR. **Pinned at M0 to `4.7.2.stable`** (`.godot-version` is the machine-readable source; CI resolves the official Linux build from it; the bootstrap suite fails if the running engine differs) | Never float on "latest"; upgrades get a full export-target test pass | Active |
| 009 | 2026-09-03 | Defense re-plans at every lie (Defense Range and Match); exactly one defender moves per lie, within its sport's repositioning range; focus zones re-settable on all defenders every lie | Bounded movement makes the hole a series of reads; unlimited is omniscient, none is static | Active |
| 010 | 2026-09-03 | All scoring beyond the per-hole scorecard — ledgers, indexes, rating-adjusted defense baseline, medals, unlock trees, Compound display, Match Elo, ladders, relay — is deferred to a post-1.0 phase. 1.0 ships with the scorecard as the sole result and everything available from first launch. The parked design is preserved in `DESIGN.md` §12. | Scope; 1.0 must prove the stroke, the defenders, records, and async play before any meta-game is layered on | Active — supersedes the interim rating-baseline and per-hole-record decisions from drafts v0.7–v0.8, which now live in §12 |
| 011 | 2026-09-03 | No dates or durations in planning documents; milestones are dependency-ordered and gate-terminated; `HANDOFF.md` records what is in progress, not when it is due | Estimates were noise before M1; gates are the real schedule | Active |

## Pending ratification (tracked in `DESIGN.md` as `[PROPOSED]`)
Stroke gesture · three clubs + auto-putter · blocked/caught penalty model · scorecard-only 1.0 · MVP four defenders · modes 1–11 for 1.0 · Scottish Rules par check as hole sign-off · async-only, no live play · vertex-color pipeline · GDScript + gdUnit4 + determinism · analytic preview · Stroke Record schema v1 · DefensePlan as human defense · commit-reveal protocol · PGN-style notation

**First run** (§2.6; full spec in `docs/ONBOARDING.md`) — six proposals that stand or fall together, since
each one only makes sense if the first is ratified:
- **Wordless first run.** Zero words in the tutorial and the intro hole. This extends ADR-004's reasoning
  ("no VO budget, no localization surface") from the defenders to the one screen that would otherwise
  reintroduce the whole localization surface on day one.
- **The eight-glyph vocabulary** — 👆 ⛳ ✅ ❌ 👀 ⭐ 🔁 ⏭ — and its three grammar rules: one glyph on screen
  at a time, pinned to a world position, and ❌ never meaning "you failed". The count is the constraint.
- **The four-layer teaching hierarchy:** world → ribbon → ghost → glyph, cheapest first.
- **"The Handshake" as the intro hole** — par 4, four beats, one new concept per stroke, ending on a made
  putt, with par set so a median first-timer scores it.
- **Glyphs as in-house sprites, not a bundled emoji font.** A colour emoji font costs ~10 MB against §5's
  "tiny builds", and vendor-specific rendering would make the one screen that must be legible everywhere
  look different on every device. Counter-argument recorded in `ONBOARDING.md` §8.
- **No blocking modals or confirmation dialogs anywhere in the first run**, and a one-tap ⏭ on every
  screen. A confirmation dialog would need words.

Ratifying these also accepts two milestone edits in §8: the ghost-gesture demo lands at **M1**, and the full
intro hole at **M3**, where the external playtest becomes its gate.
