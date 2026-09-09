# Playtest log

ADR-026 promoted feedback from playing to a first-class input, alongside the
suite and the demo round. The other two have a home — `tests/` and
`tools/demo_round.gd` — and this is the third one's.

**What goes in a round:** what was said, in the player's own words; what it
turned out to be; and what changed because of it. The middle column is the one
that earns the file. A report is a symptom, and the gap between the symptom and
the cause is where the interesting defects live — three complaints that sounded
like three problems in round 1 were one, and none of them was the thing the
words appeared to describe.

**Verbatim, not paraphrased.** "It starts to feel like it's not responding to the
direction I'm choosing" is a better bug report than anything it could be
summarised into: it names the camera angle, the sensation, and the fact that the
player had already worked out what the control was *meant* to do.

**Every fix here should arrive with a test that fails against the code that was
being played.** If it cannot, either the defect is not understood yet or it is a
matter of feel — and feel is settled by playing it again, which is a row in this
file rather than a green check.

---

## Round 1 — 2026-09-09 · pre-alpha, desktop, mouse

Played the practice range and the defence side after ADR-020 to ADR-023.
Three reports. **They were one failure**: the aiming model had been specified for
a fixed camera, one club and one side, and everything built since reached outside
it without anyone restating its domain.

| Said | Was | Changed |
|---|---|---|
| "The defense is a bit more difficult to internalize the aiming… from straight top down it works pretty straightforward, but with the camera at a lower angle, it starts to feel like it's not responding to the direction I'm choosing." | The heading was mixed from the camera's **flattened** basis, exact only looking straight down. Measured at **2.8° of error steep, 32.9° shallow**. ADR-001's orbit is what made every angle reachable. | The drag is unprojected onto the aim plane through the camera. `test_the_shot_leaves_opposite_the_drag_at_every_camera_angle` |
| "I expected more live side-to-side feedback, like the clubs; it might make the angle changes based on camera position easier to correct for." | The line **locks** after 26 px so sliding across it becomes curve — right for a stroke, and a bow has no curve, so the archer's aim froze a quarter-inch into every drag and the rest was discarded. The control had genuinely stopped responding. | `locks_line`, plus a flat direction line in the aim plane. `test_a_bow_can_be_re_aimed_without_letting_go` |
| "Also the putter doesn't have the aiming graphic when winding up." | It had one, about six centimetres long. A putt previewed as a projectile lands within a metre, so `VISIBLE_FRACTION` of it was nothing — no distance preview for the club whose whole skill is distance. | `AimRibbon.show_roll()`. `test_a_putt_previewed_as_roll_can_actually_be_seen` |

**Confirmed fixed** in the same session: *"Much better."* Desktop and mouse only
— the low-angle read has not been tried with a thumb, and ADR-007 makes the thumb
the arbiter of feel.

**What the round cost the suite's credibility.** 161 tests were green throughout.
All three defects were about the relationship between what the player sees and
what the code does, and nothing was checking that relationship — the tests that
hold it now were written from this report and fail against the code that was
being played. That is the reason this file exists.

---

## What to ask in the next round

Not a script — a list of things nobody has watched anybody do.

- **The aim at a low camera angle, with a thumb.** Round 1's fix is measured
  rather than felt; "much better" was said with a mouse.
- **Does the defence read as the same gesture as the stroke?** ADR-021 claims
  anybody who has learned one has learned the other. Nobody has been watched
  discovering that.
- **Is the club selector findable at all?** It is deliberately quiet and in a
  corner (ADR-019). Quiet and unfindable are one bad decision apart.
- **Does the archer on the rock read as *yours* when you take it?** (ADR-022.)
  The safety net going quiet while you hold it is a rule nothing says out loud.
- **The first thirty seconds, cold, with no explanation.** Pillar 3's actual
  claim, and §8 makes it M3's gate.
