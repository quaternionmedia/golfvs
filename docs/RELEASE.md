# Releasing golfVs

ADR-002 makes GitHub releases the canonical distribution. This is the checklist
that gets one out, and the standing list of what is not ready to be one yet.

Nothing here is automated on purpose. A release is the one moment this project
speaks to people who have not read any of the rest of it, and the checks that
matter — *does the icon look like ours, does the pitch oversell what is in the
box, does the thing start* — are judgements rather than assertions.

## Before every release

**Gates.** All three, on the tip of the branch being tagged.

```sh
GODOT_BIN=/path/to/godot ./addons/gdUnit4/runtest.sh --add res://tests --continue
"$GODOT_BIN" --headless --fixed-fps 120 --path . res://tools/demo_round.tscn
python tools/check_docs_consistency.py
```

**Build both targets from a clean tree.**

```sh
rm -rf build && tools/build.sh
```

The script boots the Windows build once at the end of its own export. An export
that produced a file is not the same as one that produced a game.

**Then look at what came out.** These are the ones a script cannot do:

- [ ] **Run both binaries.** Windowed, not headless, and the APK on a real
      phone. An unlaunched binary is not a release, it is a hypothesis.
- [ ] **Check the icon** on a launcher and in Explorer. It should be the arc and
      the ball, never Godot's logo — if it is Godot's, `rcedit` did not run or
      `launcher_icons` came unset.
- [ ] **Check the pack is only the game.** `exclude_filter` keeps the tests, the
      tools and gdUnit4 out; the pack should be a couple of hundred KB, not two
      megabytes. If it jumped, something is shipping that should not.
- [ ] **Confirm the Android build asks for nothing:**
      `aapt2 dump badging build/android/golfVs.apk | grep uses-permission`
      should print nothing at all. Pillar 4 as a fact about the artifact.
- [ ] **Log a playtest round** in [`PLAYTEST.md`](PLAYTEST.md) if anybody played this build. A release that
      nobody played is a release nobody has checked, and the log is where the third gate lives (ADR-026).
- [ ] **Read the README's Status section as a stranger.** The pitch describes
      twelve sports and a course. Anybody arriving at a download must not be able
      to miss what is actually in it.

**Version, in three places that have to agree:**

- [ ] `project.godot` → `config/version`
- [ ] `export_presets.cfg` → `version/name` (Android; numerals and periods only)
      and `application/file_version` / `product_version` (Windows)
- [ ] the tag, and the heading in [`CHANGELOG.md`](../CHANGELOG.md)

**Paperwork:**

- [ ] `CHANGELOG.md` has a section for this version, including a **Not in it**
      list and a **Known gaps** list. Both matter more than the feature list at
      this stage.
- [ ] [`THIRDPARTY.md`](../THIRDPARTY.md) is current, and **ships beside the
      binaries**. Godot is statically linked into both artifacts and its licence
      has to travel with them.

**Tag it.** `.github/workflows/build.yml` runs on `v*` and uploads both
artifacts.

```sh
git tag -a v0.0.1 -m "…" && git push origin v0.0.1
```

## What still stands between here and a real release

These are the reasons builds before v0.1.0 are labelled test builds.

- **They are debug builds.** `tools/build.sh` runs `--export-debug`: larger,
  slower, verbose errors, remote-debug hooks live. A release build needs a
  release preset and a release keystore, and where that secret lives is a
  decision nobody has taken.
- **The Android package id is provisional.** `org.golfvs.test`, and Open
  Question 1 — the name — is still open. Changing a package id later is an
  uninstall for everybody holding the old one, so the real id wants settling
  before a build goes anywhere other than a personal phone.
- **CI has never run on a remote.** The docs-coupling check has never executed
  once. A gate that has never failed has never been tested.
- **`CODEOWNERS` names are carried from another project** and unverified. Wrong
  handles block merges the moment code-owner review is switched on.
- **Cross-platform determinism is unmeasured** (Lane B). The records are
  advertised as portable and nothing has checked that they are.

## Why the artifacts are what they are

**Debug, not release.** Deliberate while the point of a build is to find out
what breaks: a debug build says so loudly, and there is nobody to protect from
the noise yet.

**Windows and Android only.** ADR-007 makes the phone the reference device and
Windows is what the work happens on. Linux and macOS templates ship with the
engine and cost one preset each — they are absent because nobody has run one,
not because anything stops them.

**arm64 only on Android.** Every phone worth testing on has been 64-bit for
years, and a second architecture doubles the APK for nobody.
