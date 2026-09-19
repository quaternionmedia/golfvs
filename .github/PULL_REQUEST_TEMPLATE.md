**What this changes, and why.**

**Gates** — all three, locally, before opening this. Paste the counts.

- [ ] `./addons/gdUnit4/runtest.sh --add res://tests --continue` — the suite
- [ ] `$GODOT_BIN --headless --fixed-fps 120 --path . res://tools/demo_round.tscn` — the demo round
- [ ] `python tools/check_docs_consistency.py && python tools/check_version_consistency.py` — the docs

The demo round is a real gate. It exits non-zero if a stroke fails to replay to
its own hash, if the round on disk differs from the round played, or if a
defender's verdict is not reproducible from its seed.

**Scope**

- [ ] `docs/DESIGN.md` is unchanged — *or* it changed and `docs/DECISIONS.md` has
      a matching row. CI enforces the pair (ADR-006).
- [ ] `docs/LANES.md` updated, if this finished or started something.
- [ ] `docs/HANDOFF.md` §7 has a section for this session.

**If it touches `project.godot` or `export_presets.cfg`:** say so, and confirm
the Godot editor was closed. It rewrites both files on save and strips their
comments.
