# golfVs — Art Pipeline

**Status:** DRAFT (M0 deliverable, Appendix A step 4). Ratified content becomes ADRs in `DECISIONS.md`.
**Governs:** every mesh, material and animation that ships in the game.
**Derived from:** `DESIGN.md` §5 and ADR-003. Where this file and §5 disagree, §5 wins until this file is ratified.

Everything is modelled in-house in Blender. `.blend` sources live in this repository under Git LFS, so a
contributor can open the source of any asset in the game, change it, and re-export it with the settings
below and get the same result (ADR-003). Placeholders and finals go through the same pipeline — there is no
"we will redo this properly later" path.

---

## 1. The rule that shapes everything: no textures in 1.0

Colour is carried by **vertex colours only**. No albedo maps, no normal maps, no atlases.

That single constraint buys: tiny builds, trivial mobile performance, no UV work, no texel-density
arguments, and art that is diffable — a colour change is a few floats in a `.blend`, not a repainted PNG.
The cost is that surface detail must come from silhouette and geometry. That is the intended look
(DESIGN.md §5), not a compromise.

The only shader on top is a subtle outline for readability on phones. No other post-processing.

---

## 2. Budgets

| Asset | Triangles | Notes |
|---|---|---|
| Defender character | 600–1200 | Includes the silhouette prop. |
| Silhouette prop (of that total) | ≤ 300 | Must read at 64 px. |
| Golfer | 600–1200 | Same budget as a defender. |
| Terrain tile (`GridMap` cell) | ≤ 100 | Hundreds are on screen. |
| Course prop (tree, bench, sign) | ≤ 250 | |
| Ball | ≤ 200 | Squash-and-stretch is animated, not modelled. |

Bones per character: ≤ 24. No IK rigs in exported assets — bake to FK on export.

A model that misses its budget is not merged. Budgets are checked by eye at review until an automated check
lands; the numbers above are the ones a reviewer quotes.

---

## 3. Palette

One **32-colour ramp per biome**: Parkland, Links, Desert, Snow. Defenders draw from the same ramp as the
ground they stand on, so a defender can never clash with its course.

- Ramps live in `art/palettes/<biome>.blend` as a material library, and as a swatch PNG in `art/palettes/`
  for reference.
- A character's art card names its **palette slots** by index, not by hex. Re-skinning a defender for a new
  biome is then a matter of pointing the same slots at a different ramp.
- Colours are authored in **sRGB** in Blender and exported as sRGB vertex colours. Godot's importer is
  configured to match; see §5.

---

## 4. Blender conventions

**Units and orientation.** Metric, 1 Blender unit = 1 metre. Model facing **−Y** in Blender, which becomes
**−Z forward** in Godot after the glTF axis conversion. Apply all transforms before export (`Ctrl+A` →
All Transforms): a non-uniform scale that survives export will fight the physics.

**Origin.** At the point the object rests on: feet for characters, base for props, centre for the ball.

**Naming.** `snake_case`, with the sport or set as the prefix.

```
skeet_shooter          # armature + mesh
skeet_shotgun          # silhouette prop
parkland_tile_fairway  # GridMap tile
```

**Vertex colours.** One colour attribute per mesh, named `Col`, `BYTE_COLOR`, on the **corner** domain.
More than one attribute is an error — the exporter picks the first and the mismatch will not be obvious
until it is in the game.

**Materials.** One material per mesh, named `vcol_base`, using the vertex-colour attribute directly.
Materials carry no textures and no per-material colour; the mesh carries the colour.

**Modifiers.** Apply everything except Armature before export.

---

## 5. Export settings — Blender to glTF to Godot

Export as **glTF 2.0 Binary (`.glb`)** into the same directory as the `.blend`.

| Setting | Value | Why |
|---|---|---|
| Format | glTF Binary (`.glb`) | One file, no sidecar `.bin`. |
| Include | Selected Objects | Never export the whole scene by accident. |
| Transform → +Y Up | **on** | Godot's convention. |
| Data → Mesh → Apply Modifiers | **on** | Except Armature, which the exporter handles. |
| Data → Mesh → Vertex Colors | **on** | The whole pipeline depends on this. |
| Data → Mesh → UVs, Normals | UVs **off**, Normals **on** | No textures, so no UVs. |
| Data → Mesh → Tangents | off | No normal maps. |
| Data → Material → Materials | Export | |
| Data → Material → Images | None | Nothing should ship an image. |
| Data → Shape Keys | off | Squash-and-stretch is bone- or shader-driven. |
| Animation → Animation Mode | Actions | One action per animation (§6). |
| Animation → Sampling Rate | 30 | Sources are 12–20 frame actions; 30 Hz sampling is ample. |
| Animation → Optimize Keyframes | **off** | It silently softens the snap that makes a tell read. |
| Animation → Bake All Objects Animations | off | |
| Compression (Draco) | **off** | Meshes are already tiny; Draco costs decode time on the exact devices we care about. |

**On the Godot side**, the imported `.glb` must have:

- **Materials → Vertex Color → Use as Albedo: on.** Without this the mesh renders untinted and the whole
  pipeline looks broken.
- **Meshes → Ensure Tangents: off.**
- **Skins → Use Named Skins: on.**
- Import settings are saved next to the asset in `.import` files and **are reviewed like code**.

If an asset renders grey in Godot, check three things in this order: the colour attribute name (`Col`),
Vertex Color → Use as Albedo, and whether the exporter picked a second colour attribute.

---

## 6. The art card

Every sport ships with an **art card** in `defenders/<sport>/ART_CARD.md`. It is the contract between
design and art, and it is what a contributor reads before opening Blender.

A card names:

1. **Silhouette prop** — the one object that identifies the sport at 64 px, in shadow, from any angle.
2. **Palette slots** — indices into the biome ramp, per material zone.
3. **Four required animations**, all of them, or the defender does not ship:

| Animation | Frames | Purpose |
|---|---|---|
| `idle` | loop, 12–20 | Must show the defender's **blind spot** (DESIGN.md §3). The idle is gameplay information. |
| `tell` | 12–20 | The telegraph. Exaggerated to the point of comedy, readable from **any** camera angle (ADR-001), and paired with its 2-note audio motif. |
| `act` | 12–20 | The action itself. |
| `react` | 12–20 | Success or failure, in character. Kind comedy — a rival, not a villain (Pillar 6). |

Defenders are **silent** (ADR-004): no VO, no text bubbles. All personality lives in these four animations
and in prop gags. The tell's audio motif is a gameplay signal and an accessibility affordance, not dialogue.

**Readability check.** Before a defender is merged: render its `tell` at 64 px from four camera angles,
including directly overhead. If the read fails from any of them, the tell is not done. This is a direct
consequence of the free-orbit camera — there is no hero angle to hide behind.

---

## 7. Repository layout and LFS

```
art/
├─ LICENSE              # CC-BY-4.0 (ADR-005)
├─ palettes/            # <biome>.blend + swatch PNGs
├─ characters/<sport>/  # <sport>.blend, <sport>.glb, .import files
├─ terrain/<biome>/     # GridMap tile meshes
└─ props/
```

`.blend`, `.wav`, `.ogg` and `.png` are tracked by **Git LFS** — see `.gitattributes`. Run `git lfs install`
once per clone before adding art, or binaries land in the object store as raw blobs and the repository grows
permanently.

Both the `.blend` source and the exported `.glb` are committed. The `.blend` is the source of truth; the
`.glb` is committed so that a gameplay contributor never needs Blender installed to run the game.

All art and audio in this repository is **CC-BY-4.0** (ADR-005). Contributed assets must be original or
compatibly licensed, with provenance noted in the pull request.

---

## 8. Audio

Not a Blender concern, but it lives under the same licence and the same "one card per sport" idea.

- Every defender has a **2-note motif** played on its tell. It is a gameplay signal first and a joke second.
- The club sound is one "thwock" sample, pitch-scaled by power.
- Music is upbeat, loopable, one loop per biome. No dialogue anywhere (ADR-004).
- Format: `.wav` sources under LFS, exported to `.ogg` for the game.

---

## 9. Accessibility obligations on art

From DESIGN.md §5, and binding on every asset:

- Colourblind-safe zone overlays — zone colour is never the only signal.
- Every tell reads as **visual + audio**, with optional haptics.
- The outline shader is a readability feature, not decoration. Do not disable it for a "cleaner" look.
