#!/usr/bin/env bash
#
# Build golfVs for Windows, Linux, macOS and Android.
#
#   tools/build.sh                # all four
#   tools/build.sh windows
#   tools/build.sh linux
#   tools/build.sh macos
#   tools/build.sh android
#
# What this exists for: M0's exit is "the APK launches on a phone", and that has
# been recorded as "blocked on hardware" since the first handoff. Most of it was
# not hardware. It was three pieces of setup nobody had written down -- export
# templates, a Java path, and a keystore -- and a setup step that is not in a
# script is a setup step that blocks the next person too.
#
# Everything here is idempotent and safe to re-run. It never touches a release
# keystore, because there isn't one and a release build is a different decision.
#
# Environment, all optional:
#   GODOT_BIN     the editor binary. Guessed from the usual install paths.
#   JAVA_HOME     a JDK 17+. Guessed from Android Studio's bundled runtime.
#   ANDROID_HOME  the Android SDK. Only needed if a Gradle build is turned on.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

target="${1:-all}"
version="$(tr -d '[:space:]' < .godot-version)"   # e.g. 4.7.2-stable
series="${version%.*}"                            # e.g. 4.7
series="${series%-*}"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
die() { printf '\n\033[31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }

# Git Bash hands out MSYS paths (/c/Program Files/...) and Godot is a native
# Windows binary that cannot read one. Every path that leaves this script for
# the engine -- editor settings, keystore -- goes through here first.
#
# This cost an afternoon, because the error Godot gives is "A valid Java SDK
# path is required in Editor Settings", which is true and says nothing about the
# one that was provided being unreadable rather than absent.
winpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

# --------------------------------------------------------------- the engine --

if [ -z "${GODOT_BIN:-}" ]; then
  for guess in \
    "/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe" \
    "$HOME/godot/Godot_v${version}_linux.x86_64" \
    "$(command -v godot || true)"
  do
    if [ -n "$guess" ] && [ -x "$guess" ]; then GODOT_BIN="$guess"; break; fi
  done
fi
[ -n "${GODOT_BIN:-}" ] && [ -x "$GODOT_BIN" ] || die "no Godot binary; set GODOT_BIN"

# The suite already asserts the running engine matches the pin (ADR-008). This
# is the same check one step earlier, because an export against the wrong
# templates fails in a much less obvious way than a test does.
running="$("$GODOT_BIN" --version | head -1)"
case "$running" in
  "${version%-stable}.stable"*) ;;
  *) die "engine is $running, pinned is $version (.godot-version)" ;;
esac
say "Godot $running"

# ------------------------------------------------------------ the templates --

data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot"
[ -d "$HOME/AppData/Roaming/Godot" ] && data_dir="$HOME/AppData/Roaming/Godot"
[ -d "$HOME/Library/Application Support/Godot" ] && data_dir="$HOME/Library/Application Support/Godot"

# Self-contained mode. A `._sc_` file beside the binary moves the whole of
# Godot's user data next to the executable, and the Steam build ships with one.
#
# That is why the templates this project needed were already installed and
# invisible, why a settings file written to the usual place did nothing at all,
# and why the export kept insisting the Java path was unset while a perfectly
# good one sat in a file Godot was never going to read. If an export complains
# about something you can see is configured, this is the first thing to check.
bindir="$(cd "$(dirname "$GODOT_BIN")" && pwd)"
if [ -f "$bindir/._sc_" ] || [ -f "$bindir/_sc_" ]; then
  data_dir="$bindir/editor_data"
  say "Self-contained Godot: editor data is $data_dir"
fi

templates="$data_dir/export_templates/${version%-stable}.stable"
if [ ! -f "$templates/version.txt" ]; then
  say "Fetching export templates for $version (about 1.3 GB, once)"
  tpz="$(mktemp -t godot-templates-XXXXXX.tpz)"
  curl -fL --retry 3 --retry-delay 5 -o "$tpz" \
    "https://github.com/godotengine/godot/releases/download/${version}/Godot_v${version}_export_templates.tpz"
  work="$(mktemp -d)"
  unzip -oq "$tpz" -d "$work"
  mkdir -p "$templates"
  cp -r "$work/templates/." "$templates/"
  rm -rf "$tpz" "$work"
fi
[ -f "$templates/version.txt" ] || die "export templates missing at $templates"
say "Templates $(cat "$templates/version.txt")"

# ---------------------------------------------------------------- the JDK ----

if [ -z "${JAVA_HOME:-}" ]; then
  for guess in \
    "/c/Program Files/Android/Android Studio/jbr" \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
    "/usr/lib/jvm/default-java"
  do
    if [ -x "$guess/bin/java" ] || [ -x "$guess/bin/java.exe" ]; then
      JAVA_HOME="$guess"; break
    fi
  done
fi

# Godot reads the Java and SDK paths from *editor settings*, even for a template
# build that runs no Gradle -- it still has to sign the APK. There is no
# command-line flag for either, so the settings file is where they have to go.
settings="$data_dir/editor_settings-${series}.tres"
MARKER='; written by tools/build.sh'

set_editor_path() {
  key="$1"; value="$2"
  [ -n "$value" ] || return 0
  if [ ! -f "$settings" ]; then
    mkdir -p "$data_dir"
    printf '[gd_resource type="EditorSettings" format=3]\n\n%s\n[resource]\n' "$MARKER" > "$settings"
  elif [ ! -f "$settings.golfvs.bak" ]; then
    # These are a person's editor preferences. One backup, kept, before this
    # script is ever the reason a line in them changed.
    cp "$settings" "$settings.golfvs.bak"
  fi
  existing="$(sed -n "s|^${key} = \"\(.*\)\"$|\1|p" "$settings" | head -1)"
  if [ -n "$existing" ] && ! grep -qF "$MARKER" "$settings"; then
    # Somebody set this in the editor by hand. Their value wins, and saying so
    # is the difference between a build that respects it and one that ignores
    # it silently.
    printf '  keeping your %s = %s\n' "$key" "$existing"
    return 0
  fi
  grep -v "^${key} = " "$settings" > "$settings.tmp" && mv "$settings.tmp" "$settings"
  printf '%s = "%s"\n' "$key" "$value" >> "$settings"
}

# --------------------------------------------------------------- the keys ----
#
# The Android debug keystore is not a secret -- its password is "android" and
# has been since 2008 -- but it does have to exist, and Godot will not make one.

keystore="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$HOME/.android/debug.keystore}"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-androiddebugkey}"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-android}"

# ---------------------------------------------------------------- icons ------
#
# Rendered from the SVGs every build. They are cheap, and an icon that has
# quietly stopped matching its source is exactly the kind of thing nobody
# notices until it is on a store page.

say "Rendering icons"
"$GODOT_BIN" --headless --path . --script tools/make_icons.gd >/dev/null

# ---------------------------------------------------------------- exports ----

export_one() {
  preset="$1"; out="$2"
  mkdir -p "$(dirname "$out")"
  say "Exporting $preset -> $out"
  # --export-debug, not --export-release: a release build wants a release
  # keystore and a decision about signing that nothing has needed yet.
  "$GODOT_BIN" --headless --path . --export-debug "$preset" "$out"
  [ -f "$out" ] || die "$preset produced no file at $out"
  printf '  %s  (%s)\n' "$out" "$(du -h "$out" | cut -f1)"
}

if [ "$target" = "all" ] || [ "$target" = "windows" ]; then
  # rcedit is how the icon and the version strings get into a Windows
  # executable. Godot will export perfectly well without it and the result keeps
  # the icon baked into Godot's own template -- which is Godot's logo, on a
  # binary that is not Godot. A 1.5 MB download is a cheap way not to ship that.
  rcedit="$data_dir/rcedit-x64.exe"
  if [ ! -f "$rcedit" ]; then
    say "Fetching rcedit (once)"
    curl -fL --retry 3 --retry-delay 5 -o "$rcedit" \
      https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe \
      || printf '  could not fetch rcedit; the exe will keep Godot\047s icon\n'
  fi
  [ -f "$rcedit" ] && set_editor_path "export/windows/rcedit" "$(winpath "$rcedit")"

  export_one "Windows Desktop" "build/windows/golfVs.exe"
  # An export that produced a file is not the same as an export that produced a
  # game: a pack missing its resources, or a main scene that no longer
  # instantiates, both come out as a perfectly ordinary .exe. Booting it
  # headless loads the pack and builds the first scene -- which on this project
  # means the whole range, the golfer and the archer -- and then quits.
  #
  # Only where it can actually run. A Windows binary cross-built on a runner is
  # not going to execute there, and pretending otherwise would fail the build
  # for the one reason that is not a problem.
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
      say "Booting the Windows build once"
      if ( cd build/windows && ./golfVs.console.exe --headless --quit ); then
        printf '  it starts
'
      else
        die "the exported Windows build would not start"
      fi
      ;;
  esac
fi

if [ "$target" = "all" ] || [ "$target" = "linux" ]; then
  export_one "Linux" "build/linux/golfVs.x86_64"
  # The same boot check the Windows build gets, on the host that can run it.
  # This is the one that actually fires in CI, because the runner is Linux --
  # so the artifact nobody here can launch is the artifact that gets proven.
  case "$(uname -s)" in
    Linux)
      say "Booting the Linux build once"
      if ( cd build/linux && ./golfVs.x86_64 --headless --quit ); then
        printf '  it starts
'
      else
        die "the exported Linux build would not start"
      fi
      ;;
  esac
fi

if [ "$target" = "all" ] || [ "$target" = "macos" ]; then
  # A .zip holding a .app. Unsigned and un-notarized -- there is no Apple
  # Developer identity and buying one to ship a debug build would be deciding
  # the release question sideways. Gatekeeper quarantines anything downloaded
  # without one, so the first thing a mac user must do is strip that attribute:
  #
  #     unzip golfVs.zip && xattr -dr com.apple.quarantine golfVs.app
  #
  # No boot check: the only host that could run it is a mac, and this project
  # has never had one. That is a gap in the proof, and saying so is better than
  # a check that silently never runs.
  export_one "macOS" "build/macos/golfVs.zip"
fi

if [ "$target" = "all" ] || [ "$target" = "android" ]; then
  [ -n "${JAVA_HOME:-}" ] || die "no JDK found; set JAVA_HOME (Android signing needs one)"
  if [ ! -f "$keystore" ]; then
    say "Creating a debug keystore at $keystore"
    mkdir -p "$(dirname "$keystore")"
    "$JAVA_HOME/bin/keytool" -genkeypair -v -keystore "$(winpath "$keystore")" \
      -storepass android -keypass android -alias androiddebugkey \
      -keyalg RSA -keysize 2048 -validity 10000 \
      -dname "CN=Android Debug,O=Android,C=US"
  fi
  export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$(winpath "$keystore")"
  set_editor_path "export/android/java_sdk_path" "$(winpath "$JAVA_HOME")"
  sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [ -n "$sdk" ]; then
    set_editor_path "export/android/android_sdk_path" "$(winpath "$sdk")"
  fi
  export_one "Android" "build/android/golfVs.apk"
fi

# The licence travels with the binaries or the distribution is not compliant:
# Godot is statically linked into both of them and MIT requires the notice to
# accompany it. Copying it here rather than remembering to at release time is
# the difference between a rule and a hope.
cp THIRDPARTY.md CHANGELOG.md build/

say "Done. Artifacts are under build/, and they are debug builds."
printf '  THIRDPARTY.md and CHANGELOG.md are beside them; ship all of it together.
'
