class_name HoleBuilder
extends Object
## Builds the intro hole's geometry in code.
##
## Terrain is a GridMap of authored tiles from M3 on (§2.3). The intro hole
## predates those tiles, and hand-writing a few hundred lines of .tscn for a
## shape that is still being tuned costs more than it returns -- so this hole is
## assembled procedurally and swapped for real tiles when the set exists.

# Chunky and bright, per §5's caricatured low-poly direction. Vertex colour
# comes with the art pipeline; these are stand-in albedos.
const ROUGH := Color("2f5c28")
const FAIRWAY := Color("6ba641")
const FAIRWAY_MOWN := Color("77b249")
const GREEN := Color("b6dc63")
const TEE := Color("8cc254")
const SAND := Color("dcc489")
const ROCK := Color("6b6660")
const ROCK_DARK := Color("55514c")
const TRUNK := Color("5c3f28")
const LEAF := Color("2d5424")
const LEAF_LIGHT := Color("3c6b2e")
const CUP := Color("0d0f12")


static func opaque(color: Color, roughness := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


## Unshaded and additive: reads as light rather than as a painted surface, and
## stays legible against both the fairway and the sky.
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


static func slab(parent: Node3D, size: Vector3, color: Color, at: Vector3) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(parent, box, opaque(color), at)


## A putting surface: a disc that is also a collider, with its own low-friction
## material. Without this the ball putts on whatever is underneath the green --
## here, rough grass -- and every putt dies two metres short for reasons the
## player cannot see.
##
## `at` positions the disc's *top*, and the disc stands only LIP proud of the
## ground. That is deliberate and load-bearing: a green raised by anything near
## the ball's radius presents a vertical wall at its rim, and a ball putted into
## that wall stops dead on the spot. The player sees a putt that did nothing.
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
	cyl.radial_segments = 32
	_mesh(body, cyl, opaque(GREEN), Vector3.ZERO)

	var shape := CollisionShape3D.new()
	var col := CylinderShape3D.new()
	col.radius = radius
	col.height = THICKNESS
	shape.shape = col
	body.add_child(shape)
	return body


static func disc(parent: Node3D, radius: float, height: float, color: Color, at: Vector3,
		sides := 24) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = sides
	return _mesh(parent, cyl, opaque(color), at)


## A cone on a stick. Six sides keeps the silhouette faceted rather than smooth,
## which is the whole point of the low-poly look.
static func tree(parent: Node3D, at: Vector3, height := 4.0, tilt := 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.rotation.z = tilt
	parent.add_child(root)

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.22
	trunk.height = height * 0.35
	trunk.radial_segments = 6
	_mesh(root, trunk, opaque(TRUNK), Vector3(0.0, height * 0.175, 0.0))

	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = height * 0.3
	crown.height = height * 0.8
	crown.radial_segments = 6
	_mesh(root, crown, opaque(LEAF), Vector3(0.0, height * 0.72, 0.0))
	return root


## The most-understood object in golf. Nothing else has to say "aim here", in
## any language, which is exactly why the hole leans on it instead of a glyph.
static func flag(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	parent.add_child(root)

	var pole := CylinderMesh.new()
	pole.top_radius = 0.045
	pole.bottom_radius = 0.055
	pole.height = 2.6
	pole.radial_segments = 6
	_mesh(root, pole, opaque(Color("f4f4ee"), 0.6), Vector3(0.0, 1.3, 0.0))

	var cloth := PrismMesh.new()
	cloth.size = Vector3(1.0, 0.62, 0.04)
	var banner := _mesh(root, cloth, opaque(Color("e8443f"), 0.85), Vector3(0.52, 2.25, 0.0))
	banner.rotation = Vector3(0.0, 0.0, deg_to_rad(-90.0))
	banner.name = "Cloth"
	return root


## The obstacle for the curve beat: tall and narrow rather than a long wall.
## A wall invites going over it, which is a power answer to a shaping problem.
## A spire you cannot loft and cannot barge is only ever answered by going
## round -- Pillar 1, expressed as geometry instead of as a rule.
static func spire(parent: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	parent.add_child(body)

	# Three stacked slabs, each turned a little, so the silhouette breaks up and
	# reads as rock instead of as a crate.
	var tiers := [
		[Vector3(size.x, size.y * 0.5, size.z), Vector3(0.0, -size.y * 0.24, 0.0), 0.0, ROCK],
		[Vector3(size.x * 0.82, size.y * 0.42, size.z * 0.86), Vector3(0.12, size.y * 0.12, -0.1), 0.55, ROCK_DARK],
		[Vector3(size.x * 0.5, size.y * 0.34, size.z * 0.54), Vector3(-0.2, size.y * 0.4, 0.16), -0.4, ROCK],
	]
	for tier in tiers:
		var box := BoxMesh.new()
		box.size = tier[0]
		var mi := _mesh(body, box, opaque(tier[3], 0.9), tier[1])
		mi.rotation.y = tier[2]

	# One convex box for collision. The tiers are silhouette, not physics: a
	# compound collider here would buy nothing and cost determinism.
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	return body
