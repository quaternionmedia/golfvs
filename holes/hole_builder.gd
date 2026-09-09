class_name HoleBuilder
extends Object
## Builds the intro hole as a holodeck blueprint, in code.
##
## The tutorial does not pretend to be a golf course. It is openly a simulation:
## a dark deck, a grid, and glowing outlines that say where things are without
## claiming to be those things. That is a deliberate rejection of the sunlit
## manicured fairway -- a look that sells an image of golf, thirty million
## litres of irrigation a year per course, that this game has no interest in
## promoting and no budget to render.
##
## It also happens to be the honest look for what the intro hole *is*. The hole
## teaches by geometry, a coloured trajectory stub and a ghost hand; a blueprint
## is what that already was, drawn on grass for no reason. And every surface in
## the game already carries meaning by colour rather than by texture (ADR-003's
## vertex-colour pipeline), so a diagram costs nothing extra to render.
##
## The palette is the game's own signal language, from `aim_ribbon.gd` and
## `ui/signals/beacon.gd`: cyan is clear, amber is blocked, gold is the cup,
## green is done. Nothing new was invented for the scenery.
##
## Terrain is a GridMap of authored tiles from M3 on (§2.3). This hole predates
## those tiles, so it is assembled procedurally and swapped when the set exists.

## Beyond the deck: the unlit volume the simulation has not drawn. Near-black
## rather than black, so glow has something to bloom against.
const VOID := Color("05080c")

## The deck floor itself. Solid, neutral, and clearly a *surface* -- a ground
## that fades to black leaves every object apparently hovering in nothing, and
## the ball's height above it becomes unreadable. Grey rather than tinted, so
## the cyan and amber laid on top are the only colours carrying meaning.
const DECK := Color("23272b")
## The deck grid, far from the play corridor.
const GRID_FAINT := Color("113d4a")
## The grid inside a play surface.
const GRID := Color("2a8fb0")
## Outlines. The ribbon's own CLEAR: this line is in play.
const EDGE := Color("21d4ff")
## The fill of a play surface: a shade up from the deck and slightly cool, so
## the corridor reads as a panel laid on the floor rather than a hole in it.
const SURFACE := Color("2c353b")
## The wider in-play area outside the mown corridor. Between the deck and the
## fairway in value, so the hole reads as three tiers -- floor, in play, mown --
## rather than as a strip stranded in a void.
const SURFACE_ROUGH := Color("262e33")
## Its grid and outline. Dimmer than the fairway: still in play, still measured,
## but not where you meant to be.
const EDGE_ROUGH := Color("2f7f97")
## The putting surface. The scorecard's DONE colour.
const PUTTING := Color("8dffa1")
## Sand, and the boundary. The ribbon's BLOCKED amber: this costs you.
const HAZARD := Color("ff7a2f")
## The cup. Beacon gold.
const CUP := Color("ffd46b")
## Anything solid enough to stop a ball.
const SOLID := Color("9fd8e8")
## Its body: darker than the deck, so an obstacle reads as an object sitting on
## the floor rather than a hole cut in it.
const SOLID_FILL := Color("171b1f")


## A flat, evenly-lit surface: the albedo is what you see, everywhere.
##
## The deck and every panel on it use this rather than `opaque`. A lit material
## under this hole's deliberately dim key light renders a mid-grey as near-black
## and puts a gradient across the floor, which is the opposite of what a deck is
## for -- it should read as one continuous surface so that objects standing on
## it are obviously standing on something. Lighting is reserved for the things
## that are actually solid: the ball and the archer.
static func flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


static func opaque(color: Color, roughness := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic_specular = 0.1
	return m


## Unshaded and additive: reads as light rather than as a painted surface, which
## is the whole basis of the look. Every line in the hole uses this.
static func glow(color: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func _mesh(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	parent.add_child(mi)
	return mi


# ------------------------------------------------------------------ lines ----

## A line list. `points` is consecutive pairs: 0-1, 2-3, and so on.
##
## PRIMITIVE_LINES rather than thin boxes. A line is two vertices and one pixel
## wide at any distance, which is exactly what a blueprint wants and what a
## phone can afford — the whole deck grid below is cheaper than one of the trees
## it replaced.
static func lines(parent: Node3D, points: PackedVector3Array, color: Color,
		energy := 2.4, at := Vector3.ZERO) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return _mesh(parent, mesh, glow(color, energy), at)


## A flat rectangular grid on the XZ plane, centred on `at`.
static func grid(parent: Node3D, size: Vector2, spacing: float, color: Color,
		at: Vector3, energy := 1.4) -> MeshInstance3D:
	var points := PackedVector3Array()
	var half := size * 0.5
	var x := -half.x
	while x <= half.x + 0.001:
		points.append(Vector3(x, 0.0, -half.y))
		points.append(Vector3(x, 0.0, half.y))
		x += spacing
	var z := -half.y
	while z <= half.y + 0.001:
		points.append(Vector3(-half.x, 0.0, z))
		points.append(Vector3(half.x, 0.0, z))
		z += spacing
	return lines(parent, points, color, energy, at)


static func outline_rect(parent: Node3D, size: Vector2, color: Color, at: Vector3,
		energy := 2.6) -> MeshInstance3D:
	var h := size * 0.5
	var corners := [
		Vector3(-h.x, 0.0, -h.y), Vector3(h.x, 0.0, -h.y),
		Vector3(h.x, 0.0, h.y), Vector3(-h.x, 0.0, h.y),
	]
	var points := PackedVector3Array()
	for i in 4:
		points.append(corners[i])
		points.append(corners[(i + 1) % 4])
	return lines(parent, points, color, energy, at)


static func outline_circle(parent: Node3D, radius: float, color: Color, at: Vector3,
		sides := 48, energy := 2.6) -> MeshInstance3D:
	var points := PackedVector3Array()
	for i in sides:
		var a := TAU * float(i) / float(sides)
		var b := TAU * float(i + 1) / float(sides)
		points.append(Vector3(cos(a) * radius, 0.0, sin(a) * radius))
		points.append(Vector3(cos(b) * radius, 0.0, sin(b) * radius))
	return lines(parent, points, color, energy, at)


## The twelve edges of a box. What a solid object looks like on a deck.
static func wire_box(parent: Node3D, size: Vector3, color: Color, at: Vector3,
		energy := 2.2) -> MeshInstance3D:
	var h := size * 0.5
	var c := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var edges := [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7],
	]
	var points := PackedVector3Array()
	for e in edges:
		points.append(c[e[0]])
		points.append(c[e[1]])
	return lines(parent, points, color, energy, at)


# --------------------------------------------------------------- surfaces ----

## A play surface: a dark fill, an outline, and a grid inside it.
##
## Returns the root, so a caller can still rotate the whole thing — the apron
## does. The fill sits a hair below the lines so they are never z-fought.
static func slab(parent: Node3D, size: Vector3, color: Color, at: Vector3,
		spacing := 2.8, fill := SURFACE, grid_colour := GRID, grid_energy := 1.1) -> Node3D:
	var root := Node3D.new()
	root.position = at
	parent.add_child(root)
	var box := BoxMesh.new()
	box.size = size
	_mesh(root, box, flat(fill), Vector3.ZERO)
	var top := Vector3(0.0, size.y * 0.5 + 0.01, 0.0)
	grid(root, Vector2(size.x, size.z), spacing, grid_colour, top, grid_energy)
	outline_rect(root, Vector2(size.x, size.z), color, top)
	return root


## The deck: one unlit, unmarked ground plane.
##
## Deliberately not gridded. A grid out here competed with the corridor's own
## grid and with the boundary, and three overlapping line systems make it harder
## to tell which lines mean something -- which is the whole job of the palette.
## Grids are for surfaces that are in play. The floor beyond them is just floor.
static func deck(parent: Node3D, size: Vector2, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	parent.add_child(root)
	var plane := BoxMesh.new()
	plane.size = Vector3(size.x, 1.0, size.y)
	_mesh(root, plane, flat(DECK), Vector3(0.0, -0.5, 0.0))
	return root


## A putting surface: a disc that is also a collider, with its own low-friction
## material. Without this the ball putts on whatever is underneath the green,
## and every putt dies short for reasons the player cannot see.
##
## `at` positions the disc's *top*, and the disc stands only LIP proud of the
## ground. That is load-bearing: a green raised by anything near the ball's
## radius presents a vertical wall at its rim, and a ball putted into that wall
## stops dead. The collider and every dimension here are unchanged from the
## grass version — the blueprint is paint, and physics is not paint.
static func green(parent: Node3D, radius: float, at: Vector3) -> StaticBody3D:
	const LIP := 0.02
	const THICKNESS := 0.5
	var body := StaticBody3D.new()
	body.position = at + Vector3(0.0, LIP - THICKNESS * 0.5, 0.0)
	var surface := PhysicsMaterial.new()
	surface.friction = 0.34
	surface.bounce = 0.12
	body.physics_material_override = surface
	parent.add_child(body)

	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = THICKNESS
	cyl.radial_segments = 48
	_mesh(body, cyl, flat(SURFACE), Vector3.ZERO)

	var top := Vector3(0.0, THICKNESS * 0.5 + 0.01, 0.0)
	# Concentric rings rather than a square grid: a putting surface is read
	# radially, from the hole outwards.
	for ring in [0.28, 0.55, 0.82]:
		outline_circle(body, radius * ring, PUTTING, top, 40, 0.9)
	outline_circle(body, radius, PUTTING, top, 64, 2.4)

	var shape := CollisionShape3D.new()
	var col := CylinderShape3D.new()
	col.radius = radius
	col.height = THICKNESS
	shape.shape = col
	body.add_child(shape)
	return body


static func disc(parent: Node3D, radius: float, height: float, color: Color, at: Vector3,
		sides := 24) -> Node3D:
	var root := Node3D.new()
	root.position = at
	parent.add_child(root)
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = sides
	_mesh(root, cyl, flat(SURFACE), Vector3.ZERO)
	outline_circle(root, radius, color, Vector3(0.0, height * 0.5 + 0.01, 0.0), sides)
	return root


# ------------------------------------------------------------------ props ----

## The course boundary, drawn where it actually is.
##
## This exists because the archer (ADR-015) shoots anything crossing this line,
## and until it was drawn the player had no way to know where it was — a rule
## enforced invisibly, which is the opposite of Pillar 2. On a deck it is simply
## the edge of the deck, in the amber that means "this costs you".
static func boundary(parent: Node3D, centre: Vector3, extent: Vector2,
		post_height := 2.2) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(centre.x, 0.0, centre.z)
	parent.add_child(root)
	var size := extent * 2.0
	outline_rect(root, size, HAZARD, Vector3(0.0, 0.03, 0.0), 3.0)

	# Uprights at intervals, so the boundary reads from a low camera as well as
	# from above. A line on the floor vanishes when you stand on it.
	var points := PackedVector3Array()
	var step := 9.0
	var x := -extent.x
	while x <= extent.x + 0.001:
		for z in [-extent.y, extent.y]:
			points.append(Vector3(x, 0.0, z))
			points.append(Vector3(x, post_height, z))
		x += step
	var z2 := -extent.y + step
	while z2 <= extent.y - step + 0.001:
		for xx in [-extent.x, extent.x]:
			points.append(Vector3(xx, 0.0, z2))
			points.append(Vector3(xx, post_height, z2))
		z2 += step
	lines(root, points, HAZARD, 1.8)
	return root


## The most-understood object in golf, drawn rather than sewn. Nothing else has
## to say "aim here" in any language, which is why the hole leans on it.
static func flag(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	parent.add_child(root)
	lines(root, PackedVector3Array([Vector3.ZERO, Vector3(0.0, 2.6, 0.0)]), CUP, 3.0)
	var banner := PackedVector3Array([
		Vector3(0.0, 2.6, 0.0), Vector3(1.0, 2.32, 0.0),
		Vector3(1.0, 2.32, 0.0), Vector3(0.0, 2.04, 0.0),
		Vector3(0.0, 2.04, 0.0), Vector3(0.0, 2.6, 0.0),
	])
	lines(root, banner, CUP, 3.4)
	return root


## The obstacle for the curve beat: tall and narrow rather than a long wall.
## A wall invites going over it, which is a power answer to a shaping problem.
## A spire you cannot loft and cannot barge is only ever answered by going
## round — Pillar 1, expressed as geometry instead of as a rule.
##
## The tiers now stack to a flat cap whose top face is exactly `size.y * 0.5`
## above the centre, so the archer standing on it has something to stand on.
static func spire(parent: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	parent.add_child(body)

	var tiers := [
		[Vector3(size.x, size.y * 0.5, size.z), Vector3(0.0, -size.y * 0.25, 0.0), 0.0],
		[Vector3(size.x * 0.8, size.y * 0.32, size.z * 0.85), Vector3(0.1, size.y * 0.16, -0.08), 0.5],
		[Vector3(size.x * 0.55, size.y * 0.18, size.z * 0.6), Vector3(-0.15, size.y * 0.41, 0.12), -0.35],
	]
	for tier in tiers:
		var box := BoxMesh.new()
		box.size = tier[0]
		var fill := _mesh(body, box, flat(SOLID_FILL), tier[1])
		fill.rotation.y = tier[2]
		var wire := wire_box(body, tier[0], SOLID, tier[1])
		wire.rotation.y = tier[2]

	# One convex box for collision. The tiers are silhouette, not physics: a
	# compound collider here would buy nothing and cost determinism. Unchanged.
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	return body
