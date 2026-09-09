---
name: Bug report
about: Something behaves differently from how it reads
labels: bug
---

**What happened, and what you expected instead.**

**Where.** Which build (`v0.0.1-test`, or a commit), and Windows or Android.

**The stroke, if there was one.** Every stroke is written as a record under
`user://records/` — on Windows that is
`%APPDATA%\Godot\app_userdata\golfVs\records\`, on Android it is the app's own
data directory. Attaching the round's `.json` is the single most useful thing
you can do: the sim is deterministic, so a record replays exactly and turns
"the ball did something odd" into something reproducible.

**Anything on screen at the time** — a screenshot or a clip. The game is
wordless, so what a thing looked like often *is* the bug report.
