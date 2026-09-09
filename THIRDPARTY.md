# Third-party software in golfVs

golfVs itself is Apache-2.0 (code) and CC-BY-4.0 (art and audio) — see
[`LICENSE`](LICENSE), [`art/LICENSE`](art/LICENSE), [`audio/LICENSE`](audio/LICENSE)
and [`NOTICE`](NOTICE).

This file covers everything **else** that ends up in a build or in the
repository. It exists because a distributed binary is a distribution: the engine
is statically linked into `golfVs.exe` and `golfVs.apk`, its licence requires the
copyright notice to travel with it, and until this file was written nothing
carried it.

## Redistributed in the binaries

### Godot Engine — MIT

Every shipped build is the Godot Engine plus this project's data pack. The engine
is not a build-time tool here; it is most of the executable.

Pinned to the version in [`.godot-version`](.godot-version) (ADR-008).

```
Copyright (c) 2014-present Godot Engine contributors.
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Godot's own third-party components

The engine bundles a number of permissively licensed libraries — FreeType,
Jolt Physics, ThorVG, miniz, and others — each with its own notice. They are
authoritatively listed, with full licence texts, in Godot's `COPYRIGHT.txt` for
the pinned version:

<https://github.com/godotengine/godot/blob/master/COPYRIGHT.txt>

That file is deliberately linked rather than copied. It is long, it changes
between engine versions, and a stale copy of a licence list is worse than a
pointer to the accurate one — the pin in `.godot-version` says exactly which
revision applies.

**Reproducing it locally**, for anyone who wants the exact text that goes with a
given build:

```sh
curl -fL -o COPYRIGHT.txt \
  "https://raw.githubusercontent.com/godotengine/godot/$(cat .godot-version)/COPYRIGHT.txt"
```

## In the repository, not in the builds

### gdUnit4 — MIT

The test framework, vendored under `addons/gdUnit4/` at tag v6.2.1.

```
Copyright (c) 2023 Mike Schulze
MIT License — addons/gdUnit4/LICENSE
https://github.com/MikeSchulze/gdUnit4
```

It is **excluded from every export** (`exclude_filter` in
[`export_presets.cfg`](export_presets.cfg)), so it is a development dependency
rather than a redistributed one. It is listed here anyway, because it is in the
repository and a reader should not have to work that out from a filter string.

### rcedit — MIT

Fetched by `tools/build.sh` to write the icon and version strings into the
Windows executable. Never committed, never shipped, and only ever run on the
build machine.

<https://github.com/electron/rcedit>

## What is not here

No fonts, no sound, no third-party art. The game draws every mark it makes from
primitives and carries no typeface, because nothing in it is typed (ADR-004,
ADR-014). If that changes, this file changes with it.
