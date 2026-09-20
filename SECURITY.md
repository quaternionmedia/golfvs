# Security

## Reporting a vulnerability

Use GitHub's **private vulnerability reporting** on this repository
(Security → Report a vulnerability). It keeps the report private until there is
a fix, and it does not require anybody's email address to be published here.

Please do not open a public issue for a vulnerability.

## What is worth reporting

golfVs is an offline, single-player game with a deliberately small attack
surface, and the honest thing to say is that most of it does not exist yet:

- **No network.** Pillar 4 makes the game offline by default. The Android build
  declares **no permissions at all** — `aapt2 dump badging` on a release
  artifact should show no `uses-permission` lines, and if it ever does, that
  itself is worth reporting.
- **No accounts, no telemetry, no analytics.** Nothing is collected and nothing
  is transmitted.
- **Local writes are confined to `user://`** — the platform's own save
  directory. Nothing under `res://` is written at runtime.

The parts most likely to matter as the project grows are **records**: every
stroke is written as a portable, hash-verified file, and §11 of `DESIGN.md`
designs a future in which those are exchanged between players. A record is data,
not code, and a reader that could be made to execute one would be a real
finding. So would a path traversal through a record's fields, or a hash
collision that lets a modified record verify.

## Supported versions

Pre-1.0 and pre-tag. Only the tip of `main` is supported, and builds published
before v0.1.0 are debug builds meant for testing rather than for use.
