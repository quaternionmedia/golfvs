# Releasing golfVs

ADR-002 makes GitHub releases the canonical distribution. This is the checklist
that gets one out, and the standing list of what is not ready to be one yet.

The judgements here are not automated, on purpose. A release is the one moment
this project speaks to people who have not read any of the rest of it, and the
checks that matter — *does the icon look like ours, does the pitch oversell what
is in the box, does the thing start* — are judgements rather than assertions.
What a machine can assert, it does: the build, the version, and the release
itself (ADR-027, revised). What it cannot, it leaves on this list -- and the
list is worked *before* the tag, on the pull request's artifact, because the
tag is what publishes.

## Before every release

**Gates.** All four, on the tip of the branch being tagged.

```sh
GODOT_BIN=/path/to/godot ./addons/gdUnit4/runtest.sh --add res://tests --continue
"$GODOT_BIN" --headless --fixed-fps 120 --path . res://tools/demo_round.tscn
python tools/check_docs_consistency.py
python tools/check_version_consistency.py
```

**Build from a clean tree.** All five locally; CI builds the four it can on
every pull request and puts them in the run's artifacts, so the APK you put on
a phone can be the one CI made rather than the one on your machine.

```sh
rm -rf build && tools/build.sh                                    # all five
rm -rf build && tools/build.sh windows linux linux-arm64 android  # what CI builds
```

The script boots the Windows build once at the end of its own export, and the
Linux build when it is running on Linux -- which it is, in CI. Headless, so it
proves the pack loads and the first scene builds and nothing about drawing; CI
boots the Linux build with a renderer as well, advisory, because the first crash
an outside tester reported was in exactly that gap. An export that produced a
file is not the same as one that produced a game. The macOS and Linux arm64
builds are the ones nobody here can boot; that is a gap in the proof and it is
named below.

**Then look at what came out.** These are the ones a script cannot do:

- [ ] **Run every binary you can.** Windowed, not headless, and the APK on a real
      phone. An unlaunched binary is not a release, it is a hypothesis.
- [ ] **On a machine with no real GPU, expect the Linux build to crash and know
      why.** If Godot's first line says `Using Device #0: ... llvmpipe`, the only
      Vulkan device is Mesa's software one, and its shader compiler aborts on
      the Mobile renderer before the first frame (signal 4, a backtrace full of
      `libLLVM` and `libvulkan_lvp`). `--rendering-method gl_compatibility` is
      the whole fix; it is in the release notes, and it belongs there until the
      engine stops picking a CPU device over OpenGL by itself.
- [ ] **On a mac, strip the quarantine first.** The bundle is unsigned and
      un-notarized (no Apple identity -- ADR-027), so Gatekeeper refuses it on
      sight. `unzip golfVs.zip && xattr -dr com.apple.quarantine golfVs.app`
      is the whole fix, and it belongs in the release notes until there is a
      signature. If nobody on the project has a mac, say so in the notes rather
      than implying it was run.
- [ ] **Check the icon** on a launcher and in Explorer, **and the loading screen**
      on first launch. Both should be the arc and the ball, never Godot's logo —
      if the icon is Godot's, `rcedit` did not run or `launcher_icons` came
      unset; if the splash is, `art/icon/boot_splash.png` is an LFS pointer
      rather than a PNG (ADR-028).
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

**Version, in four places that have to agree -- checked, not remembered.**
`tools/check_version_consistency.py` runs in CI and refuses the tree if they
differ; on a tag build it refuses the tag too (ADR-027). For the record, they are:

- `project.godot` → `config/version`
- `export_presets.cfg` → `version/name` (Android), `application/file_version` /
  `product_version` (Windows), `application/short_version` / `version` (macOS);
  numerals and periods only, all of them
- the topmost released heading in [`CHANGELOG.md`](../CHANGELOG.md)
- the tag

**Paperwork:**

- [ ] `CHANGELOG.md` has a section for this version, including a **Not in it**
      list and a **Known gaps** list. Both matter more than the feature list at
      this stage.
- [ ] [`THIRDPARTY.md`](../THIRDPARTY.md) is current, and **ships beside the
      binaries**. Godot is statically linked into every artifact and its licence
      has to travel with them; `build.yml` puts it inside each archive.

**Tag it -- and know that the tag publishes.** `.github/workflows/build.yml`
builds Windows, Linux x86_64, Linux arm64 and Android on every pull request and
leaves them in the run's artifacts; on a `v*` tag it builds the same four and
**publishes them as a pre-release** with the notes lifted from the changelog
section for that version, where anyone can download them. macOS is not in the
release until somebody can launch one.

```sh
git tag -a v0.0.1-prealpha -m "…" && git push origin v0.0.1-prealpha
```

There is no draft to read afterwards; the checking happens before. Everything
above this line that is a judgement rather than an assertion still has to be
made by a person -- on the artifact the pull request built, which is the same
four archives the tag will publish -- and the tag is that person saying so. It
used to stop at a draft (ADR-027) and the first outside tester was handed a
tarball by hand because nobody had pressed publish; a release nobody can
download is not a distribution, and ADR-002 says releases are the
distribution. Re-running the tag's workflow refreshes the release in place.

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
- **The macOS build has never been launched.** It exports, the bundle is
  well-formed and carries our icon, and nobody on the project has a machine to
  run it on. It ships as unverified until somebody does.
- **Cross-platform determinism is measured but not yet proven** (Lane B). The
  suite and the demo round run on Linux, Windows and macOS on every pull request
  (ADR-027). Until each leg has gone green once, the records are advertised as
  portable on the strength of a check that has not finished running.

## Why the artifacts are what they are

**Debug, not release.** Deliberate while the point of a build is to find out
what breaks: a debug build says so loudly, and there is nobody to protect from
the noise yet.

**Five targets, one host; four of them in CI.** Windows, Linux x86_64, Linux
arm64, macOS and Android, all exported by `tools/build.sh` from whichever
machine runs it -- Godot cross-exports every platform given the templates.
Linux, macOS and Linux arm64 cost one preset each and no new tooling, exactly
as this document predicted before they existed. CI builds the four it can and
leaves macOS local until somebody can open one. The x86_64 desktop packs come
out byte-identical, which is the exclusion filter proving that the same game is
in each box -- and CI `cmp`s them to say so. The arm64 pack differs by design:
it carries ETC2/ASTC textures, because that is what the Pi's GPU samples.

**macOS unsigned and un-notarized.** There is no Apple Developer identity, and
buying one to ship a debug build would decide the release question sideways.
Gatekeeper's quarantine is documented rather than worked around.

**arm64 only on Android.** Every phone worth testing on has been 64-bit for
years, and a second architecture doubles the APK for nobody.

**The Raspberry Pi 5 build starts on the Compatibility renderer, provisionally.**
The Pi's Vulkan driver is conformant and Forward Mobile starts on it, but the
GPU is a phone-class part and glow is a blur chain at window resolution. The
`override.cfg` beside `golfVs.arm64` switches renderers; deleting it tries the
other one. Nobody has measured either on a Pi yet, and until somebody has, the
file is a guess with its reasoning in its header. Never booted in CI, for the
same reason as macOS: the runner is the wrong chip.
