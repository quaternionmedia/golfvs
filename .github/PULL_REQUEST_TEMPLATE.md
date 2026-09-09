**What this changes, and why.**

**Gates** — both, please, and paste the counts:

- [ ] `./addons/gdUnit4/runtest.sh --add res://tests --continue`
- [ ] `$GODOT_BIN --headless --fixed-fps 120 --path . res://tools/demo_round.tscn`

The demo is a real gate. It exits non-zero if a stroke fails to replay to its own
hash, if the round on disk differs from the round played, or if a defender's
verdict is not reproducible from its seed — three of five bugs found in one
early session were invisible to the unit suite and obvious within one round.

**Scope**

- [ ] This changes nothing in `docs/DESIGN.md` — *or* it does, and there is a
      matching row in `docs/DECISIONS.md`. CI enforces the pair (ADR-006).
- [ ] Lane updated in `docs/LANES.md`, if this finished or started something.

**If it touches `project.godot`:** say so here, and confirm the Godot editor was
closed while you did. It silently rewrites that file on save, which has already
cost this project two settings.
