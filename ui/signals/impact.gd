class_name Impact
extends Node3D
## The moment a defender connects, made into something you can feel.
##
## A ball that simply stops is indistinguishable from a physics bug. §3 says a
## skeet hit "knocks the ball down in place" and an arrow "pins it where hit",
## and both of those are events -- but an event the player cannot see is only a
## state change. This is the see-able part: a flash, two rings thrown outward,
## and a spray of shards, all in the defender's own colour so the player knows
## which one did it without being told.
##
## Everything here is line and additive geometry, in the same vocabulary as the
## rest of the hole, and the whole thing frees itself when it is done. It is
## purely visual: nothing in here touches the ball, the simulation or the clock,
## because a record has to replay identically whether or not anyone was watching.

const LIFETIME := 0.85
## How far the ground ring travels. Big enough to register from the flight
## camera, which is eight metres back and four up.
const RING_REACH := 4.6
const SHARDS := 14

var _colour := Color("8dffa1")
var _age := 0.0
var _flash: MeshInstance3D
var _ring_flat: MeshInstance3D
var _ring_up: MeshInstance3D
var _shards: MeshInstance3D


## Fire and forget: adds itself to `parent` at `at` and frees itself.
static func at_point(parent: Node3D, at: Vector3, colour: Color) -> Impact:
	var hit := Impact.new()
	hit._colour = colour
	hit.position = at
	parent.add_child(hit)
	return hit


func _ready() -> void:
	_flash = _make(_sphere_mesh(), 6.0)
	_ring_flat = _make(_ring_mesh(1.0, 48), 4.0)
	# A second ring standing upright, so the impact reads from directly above as
	# well as from the low flight camera. One ring alone vanishes edge-on.
	_ring_up = _make(_ring_mesh(1.0, 32), 3.0)
	_ring_up.rotation.x = deg_to_rad(90.0)
	_shards = _make(_shard_mesh(), 4.5)


func _make(mesh: Mesh, energy: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = HoleBuilder.glow(_colour, energy)
	mi.custom_aabb = AABB(Vector3(-12.0, -12.0, -12.0), Vector3(24.0, 24.0, 24.0))
	add_child(mi)
	return mi


func _sphere_mesh() -> Mesh:
	var s := SphereMesh.new()
	s.radius = 0.42
	s.height = 0.84
	s.radial_segments = 10
	s.rings = 6
	return s


func _ring_mesh(radius: float, sides: int) -> Mesh:
	var points := PackedVector3Array()
	for i in sides:
		var a := TAU * float(i) / float(sides)
		var b := TAU * float(i + 1) / float(sides)
		points.append(Vector3(cos(a) * radius, 0.0, sin(a) * radius))
		points.append(Vector3(cos(b) * radius, 0.0, sin(b) * radius))
	return _lines(points)


## Shards thrown outward, as lines rather than sprites. Deterministic angles --
## the burst is decoration, and decoration that varies run to run makes two
## recordings of the same stroke look different for no reason.
func _shard_mesh() -> Mesh:
	var points := PackedVector3Array()
	for i in SHARDS:
		var yaw := TAU * float(i) / float(SHARDS)
		var pitch := lerpf(0.15, 1.0, fposmod(float(i) * 0.37, 1.0))
		var dir := Vector3(cos(yaw), pitch, sin(yaw)).normalized()
		points.append(dir * 0.35)
		points.append(dir * lerpf(1.0, 1.9, fposmod(float(i) * 0.61, 1.0)))
	return _lines(points)


func _lines(points: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / LIFETIME, 0.0, 1.0)
	if t >= 1.0:
		queue_free()
		return

	# Everything leaves fast and slows down. A burst that expands linearly reads
	# as a bubble; one that decelerates reads as something that was hit.
	var out := 1.0 - pow(1.0 - t, 3.0)
	var fade := pow(1.0 - t, 1.6)

	# The flash is the first two frames and nothing else -- it is what makes the
	# instant of contact legible, and holding it any longer turns the impact
	# into a glow.
	var punch := clampf(1.0 - t * 7.0, 0.0, 1.0)
	_flash.scale = Vector3.ONE * (0.5 + punch * 2.2)
	_set_alpha(_flash, punch)

	_ring_flat.scale = Vector3.ONE * (0.35 + out * RING_REACH)
	_set_alpha(_ring_flat, fade)

	_ring_up.scale = Vector3.ONE * (0.3 + out * RING_REACH * 0.7)
	_set_alpha(_ring_up, fade * 0.8)

	_shards.scale = Vector3.ONE * (0.6 + out * 2.4)
	_set_alpha(_shards, fade)


func _set_alpha(node: MeshInstance3D, alpha: float) -> void:
	var mat: StandardMaterial3D = node.material_override
	mat.albedo_color = Color(_colour, alpha)
	mat.emission_energy_multiplier = mat.emission_energy_multiplier
