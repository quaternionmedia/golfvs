# Contributing to golfVs

The working guide is **[`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md)** — this
file exists so that GitHub finds one, since it only looks in the repository
root, `docs/`, and `.github/`.

Three things worth knowing before you open anything:

**Assistants draft, humans ratify** (ADR-006). Scope lives in
[`docs/DESIGN.md`](docs/DESIGN.md) and every change to it arrives with a row in
[`docs/DECISIONS.md`](docs/DECISIONS.md). CI enforces that pairing, so a pull
request that moves scope without a rationale fails before anyone reads it.

**Work is organised in lanes,** not tickets. [`docs/LANES.md`](docs/LANES.md)
says what is free to start and on what it depends; each lane owns a disjoint set
of paths so two people can work at once without colliding.

**Leave the suite green and the demo passing.** Both are fast, and the demo is a
real gate rather than a showcase:

```sh
GODOT_BIN=/path/to/godot ./addons/gdUnit4/runtest.sh --add res://tests --continue
"$GODOT_BIN" --headless --fixed-fps 120 --path . res://tools/demo_round.tscn
```

Contributions are accepted under Apache-2.0 §5. There is no CLA.
