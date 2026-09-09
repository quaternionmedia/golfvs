class_name DefenderArt
extends Object
## The blocks every defender body is built from, until the Blender meshes exist.
##
## `ART_PIPELINE.md` governs the real assets: vertex colours only, 600–1200
## triangles a character, a silhouette prop under 300 that reads at 64 px. None
## of that exists yet, and hand-writing a `.tscn` for proportions still being
## tuned costs more than it returns — the same reasoning that keeps the intro
## hole's geometry in `hole_builder.gd`.
##
## What matters now is the silhouette. When a mesh replaces one of these bodies
## it has to match these proportions, or the hole plays differently: how far a
## shooter's barrel reaches and how tall an archer stands are both things a
## player reads at distance.

static func matte(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


## Unshaded and additive: reads as light rather than as a painted surface, which
## is what the tell needs to stay legible against both a sunlit fairway and the
## sky.
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


static func box(parent: Node3D, size: Vector3, color: Color, at: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = matte(color)
	mi.position = at
	parent.add_child(mi)
	return mi


## An arbitrary line list, as consecutive pairs. The escape hatch from boxes:
## a silhouette that has to be recognised at 64 px needs at least one shape
## nothing else on the hole has, and a box is not it.
static func lines(parent: Node3D, points: PackedVector3Array, color: Color,
		energy := 2.0, at := Vector3.ZERO) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = glow(color, energy)
	mi.position = at
	parent.add_child(mi)
	return mi


## A polyline through `points`, as line pairs.
static func polyline(parent: Node3D, points: PackedVector3Array, color: Color,
		energy := 2.0) -> MeshInstance3D:
	var pairs := PackedVector3Array()
	for i in range(1, points.size()):
		pairs.append(points[i - 1])
		pairs.append(points[i])
	return lines(parent, pairs, color, energy)


## The twelve edges of a box, as lines. A body built from dark fills plus these
## reads as something the simulation drew rather than something it photographed,
## which is what the intro hole's deck asks of anything standing on it.
static func wire_box(parent: Node3D, size: Vector3, color: Color, at: Vector3,
		energy := 2.0) -> MeshInstance3D:
	var h := size * 0.5
	var c := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var points := PackedVector3Array()
	for e in [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]:
		points.append(c[e[0]])
		points.append(c[e[1]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = glow(color, energy)
	mi.position = at
	parent.add_child(mi)
	return mi


## A box with a dark fill and a glowing outline. The default body part.
static func lit_box(parent: Node3D, size: Vector3, fill: Color, edge: Color,
		at: Vector3) -> void:
	box(parent, size, fill, at)
	wire_box(parent, size, edge, at)


## A dashed line from one world point to another, as a triangle strip.
##
## Dashes rather than a solid beam: a continuous line from a defender to the
## ball reads as *already connected*, which is a different and much more
## alarming statement than "this is where I am about to act".
static func dashed_line(into: MeshInstance3D, from: Vector3, to: Vector3,
		width := 0.05, dashes := 7.0, steps := 14) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var along := to - from
	var side := along.cross(Vector3.UP).normalized() * width
	if side.length_squared() < 1.0e-8:
		side = Vector3(width, 0.0, 0.0)
	for i in steps + 1:
		var t := float(i) / float(steps)
		var on := 0.0 if fposmod(t * dashes, 1.0) > 0.55 else 1.0
		var point := from + along * t
		mesh.surface_add_vertex(into.to_local(point + side * on))
		mesh.surface_add_vertex(into.to_local(point - side * on))
	mesh.surface_end()
	into.mesh = mesh


## Bounds wide enough that a world-space immediate mesh drawn from a node at the
## origin is not frustum-culled. The documented way out of that trap.
static func generous_aabb() -> AABB:
	return AABB(Vector3(-500.0, -80.0, -500.0), Vector3(1000.0, 260.0, 1000.0))
