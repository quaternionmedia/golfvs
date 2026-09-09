# golfVs — Record Schema

**Status:** DRAFT (M0 deliverable, Appendix A step 4). Normative from M1 exit, when schema v1 freezes.
**Owns:** the wire and disk format for Stroke, Round and Match Records.
**Derived from:** `DESIGN.md` §11. Where this file and §11 disagree, §11 wins until this file is ratified.

A record is the whole game's currency. Determinism (§6.1) makes a stroke *data*; every social feature in
1.0 — sharing, forks, Spot Duel, Postal Round, Match — is an exchange of these files and nothing else
(Pillar 4). There is no server-side game logic anywhere.

---

## 1. The freeze rule

Schema v1 is frozen at the M1 exit gate. After that:

- **No field is added, removed, renamed or retyped in the core schema.** Everything new goes in `ext`.
- `ext` is a namespaced bag: `ext.<feature>.<field>`. A reader that does not know a namespace ignores it.
- Migrations are **forward-only**. Any `schema: 1` record must load in every future version.
- Bumping `schema` is an ADR, not a patch.

Why the freeze is early and hard: records written during M1 playtesting are the fixtures the determinism
tests replay against for the rest of the project. If the format drifts, the fixtures die and the guarantee
dies with them.

---

## 2. Stroke Record

The atomic unit. One stroke by one golfer against zero or more defenders.

```json
{
  "schema": 1,
  "game": "0.0.1-m0+godot4.7.2",
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

### 2.1 Fields

| Field | Type | Notes |
|---|---|---|
| `schema` | int | `1`. Not the game version. |
| `game` | string | `"<game version>+godot<engine version>"`. Identifies what produced the record; a mismatch is a reason to distrust `after`, never to refuse to load. |
| `hole.id` | string | `"<biome>/<nn>"`, stable for the life of the hole. |
| `hole.layout_hash` | hex string | Hash of the `HoleLayout` resource. A different hash means a different hole, whatever the id says. |
| `seed` | int | The only source of randomness in the stroke. Same seed plus same inputs equals same result, or it is a P0 bug. |
| `before` | object | Full restorable state at address. `ReplayController` must be able to reconstruct the world from this alone. |
| `before.ball.pos` | `[float,float,float]` | Godot world coordinates, metres. |
| `before.ball.lie` | enum | `tee` · `fairway` · `rough` · `sand` · `water` · `green` · `ob`. |
| `before.stroke_no` | int | 1-based ordinal of **the stroke this record describes**. The first stroke on a hole is `1`. |
| `before.defenders[]` | array | One entry per defender on the hole, in `HoleLayout` order. Empty in Scottish Rules. |
| `before.defenders[].state` | enum | `idle` · `tell` · `act` · `cooldown` — the `DefenderBrain` states (§6.3). |
| `intent` | object | The golfer's `ShotIntent`. The only thing that crosses from input into simulation. |
| `intent.club` | enum | `long` · `short` · `putt`. Named for the decision rather than the equipment (ADR-018). |
| `intent.power` | float | `0.0`–`1.0`, normalised. Never metres — metres are a `ClubProfile` concern, and storing them would break replay whenever a club is retuned. |
| `intent.curve` | float | `-1.0`–`1.0`. Negative is a draw (left), positive a fade (right), for a right-handed golfer. |
| `intent.dir` | `[float,float,float]` | Unit vector, aim direction on the XZ plane. |
| `defense` | object \| null | `null` when the AI defended at the recorded tier; a `DefensePlan` (§3) when a human did. |
| `after` | object | **Derived, never authoritative.** See §2.2. |
| `after.events[]` | string[] | Ordered gameplay events. The vocabulary is open; readers ignore events they do not know. |
| `after.hash` | hex string | See §2.2. |
| `ext` | object | Namespaced extensions. `{}` when unused. |

### 2.2 `after` is derived

A client that loads a record **recomputes** `after` by replaying `before` plus `intent` plus `defense` at
`seed`, then compares its own hash against `after.hash`.

- **Match** — the record is trustworthy; show it.
- **Mismatch** — flag it as version drift and show the *recomputed* result. Never trust the stored one.

This is what lets a relay be a mailbox rather than a referee, and what makes a tampered record pointless:
there is nothing to gain by editing `after`, because nobody reads it.

`after.hash` covers the canonical serialisation of `after.ball` and `after.events` (ADR-013), as implemented
by `Canonical.hash_of`. Fixtures that carry an all-zero hash mean *not yet computed by a simulation*, and the
replay test skips them.

### 2.3 Size

The shared form is compressed base64 (§4), so the pretty-printed file on disk is not the constraint. The
target from §11.1 — under 1 KB — applies to the record with an empty `ext`, so that one stroke fits in a QR
code, a URL fragment, or a chat message. `tests/fixtures/records/0001-parkland-03-stroke-2.json` is the
reference: 996 bytes pretty-printed *including* a long explanatory `ext`.

---

## 3. DefensePlan

How a human plays the other sports (§11.4). A human defender never steers in real time. They author a plan
that the same `DefenderBrain` executes, so human and AI defense share one code path and both are recordable.

```json
{
  "placements": [ { "sport": "skeet", "pos": [x, y, z], "facing": 1.2 } ],
  "focus":      { "skeet_0": { "watch_zone": [x, z, radius], "trigger": "apex" } },
  "moved":      "skeet_0",
  "budget_spent": 3
}
```

| Field | Type | Notes |
|---|---|---|
| `placements[]` | array | Only on the first plan of a hole. Costs are drawn from a per-sport budget (`[OPEN]`, DESIGN.md §10.5). |
| `placements[].facing` | float | Radians, world Y rotation. |
| `focus` | object | Defender id to what it watches. Re-settable on **every** defender **every** lie: moving is scarce, watching is free (ADR-009). |
| `focus.*.trigger` | enum | `apex` · `landing` · `crossing_altitude:<n>`. |
| `moved` | string \| null | The **one** defender repositioned this lie (ADR-009), within its sport's repositioning range. `null` if none moved. |
| `budget_spent` | int | Validated against the tier cap on load. |

**Fairness invariant:** nothing in a plan may exceed what the AI could do at the current `DifficultyTier`.
Human defense is *smarter*, never *stronger*. A plan that violates this is rejected at load rather than
clamped — clamping would silently change a recorded game.

---

## 4. Round, Match, storage, transport

- **Round Record** is a header plus ordered Stroke Records. **Match Record** is a header plus turns, each
  holding one Stroke Record. Roles alternate per hole, or stay fixed in a fixed-role match.
- **Storage:** `user://records/`, one JSON file per round or match, append-only during play. `RecordStore`
  keeps an index for the Replay browser; the plain files stay the source of truth. Nothing under `res://`
  is written at runtime.
- **Transport:** raw JSON · compressed base64 (chat, QR) · `.gvs` file · deep link `golfvs://record/<base64>`.
  One `Transport` interface: `send(record)`, `poll() → [record]`. A relay is post-1.0 and is still a mailbox.

### 4.1 Text notation

A **derived** one-line view per stroke — readable in a diff, dictatable over the phone. Never parsed as input.

```
2. I 0.72 L15 → G (skeet ✗)
```

`<stroke_no>. <club letter> <power> <curve> → <resulting lie> (<defender> <hit ✓ | miss ✗>)`

Club letters `D` / `I` / `W` / `P`. Curve is `L` or `R` plus hundredths, omitted when zero.

---

## 5. Testing (DESIGN.md §11.7)

| Test | From |
|---|---|
| **Shape** — every fixture in `tests/fixtures/records/` carries the required keys and `schema: 1` | M0 (`tests/records/test_record_schema.gd`) |
| **Replay** — every fixture replays to its stored `after.hash` on Linux, Windows, macOS and Android | M1, once a simulation exists |
| **Fork** — Retry and Defend forks reproduce `before` exactly | M4 |
| **Commit-reveal** — a scripted two-client Spot Duel resolves identically from both sides | M6 |
| **Schema** — any `schema: 1` record loads in all future versions | from the M1 freeze onward |

A fixture is added whenever a physics or defender change is ratified. That is the whole point: the fixture
set is the record of what the simulation used to do.

---

## 6. Questions to settle before the M1 freeze

**Two of the four are closed.** ADR-012 fixes float serialisation and ADR-013 fixes the hash input;
`records/canonical.gd` implements both and `tests/records/test_canonical.gd` asserts them.

1. **`stroke_no` off-by-one.** DESIGN.md §11.1 shows `"stroke_no": 2` beside a notation line reading `3.`.
   This file defines `stroke_no` as the 1-based ordinal of the stroke the record describes, and the fixture
   follows that reading. Confirm it, or correct §11.1.
2. **Share full `after`, or only `after.hash`?** (DESIGN.md §10.2) Dropping `after.ball` and `after.events`
   from *shared* records roughly halves the wire size and costs nothing, since `after` is recomputed anyway.
   The cost is that a Replay browser can no longer list a shared record without replaying it first.
3. ~~**Exact hash input.**~~ **Closed by ADR-013:** SHA-256 over the canonical encoding of `after.ball` and
   `after.events`, and nothing else. The struct-hash alternative was rejected because hashing the inputs makes
   the digest move for reasons that are not the stroke's outcome, and a fork could then never be compared
   against its parent.
4. ~~**Float serialisation.**~~ **Closed by ADR-012:** quantize on write — positions to 0.1 mm, normalised
   scalars and unit-vector components to six decimals — so the number the simulation consumes *is* the number
   on disk. Hex floats were unnecessary once nothing depended on a round trip.
