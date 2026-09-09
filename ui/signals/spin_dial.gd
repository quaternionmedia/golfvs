class_name SpinDial
extends Node3D
## How much shape is on the shot, shown without giving the shot away.
##
## The aim ribbon deliberately draws only the first 7% of the flight, because a
## full arc solves the hole and deletes the read. That truncation costs
## something real though: the curve half of the gesture becomes almost invisible,
## since seven per cent of an arc has barely started bending. The player is
## setting a value they cannot see.
##
## This shows the value and not the consequence. It is a dial on the ground at
## the ball: a track, and a bar that grows out of centre toward the side the
## ball will bend. It says "you have three-quarters of a draw on". It says
## nothing about where that ends up -- which still depends on the wind of the
## player's own aim, the spire, and how hard they hit it.
##
## The distinction matters more than it sounds. Feedback on an input the player
## just made is not a prediction; it is the input becoming legible. A landing
## marker would be the other thing.

## Radius of the dial on the ground, in metres. Sits outside the ball without
## reaching far enough to be mistaken for a landing ring.
const RADIUS := 2.15
## Half the dial's span. A full draw or fade fills one side completely.
const SWEEP_DEG := 78.0
const SEGMENTS := 28

const CLEAR := Color("21d4ff")
const BLOCKED := Color("ff7a2f")
## The unfilled track. Dim: it is a scale, not a signal.
const TRACK := Color("2a6f86")

var _track: MeshInstance3D
var _bar: MeshInstance3D
var _ticks: MeshInstance3D


func _ready() -> void:
	_track = _line_node(TRACK, 2.2)
	_ticks = _line_node(TRACK, 3.0)
	# Brighter than anything else on the ground. The dial competes with the aim
	# ribbon for the same corner of the screen, and at equal weight the ribbon
	# wins on movement alone -- so the bar has to be the louder of the two while
	# the finger is actually moving sideways.
	_bar = _line_node(CLEAR, 7.5)
	_build_static()
	visible = false


func _line_node(colour: Color, energy: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.material_override = HoleBuilder.glow(colour, energy)
	mi.custom_aabb = AABB(Vector3(-6.0, -3.0, -6.0), Vector3(12.0, 6.0, 12.0))
	add_child(mi)
	return mi


## The track and its ticks never change, so they are built once. Only the bar is
## rebuilt as the finger moves.
func _build_static() -> void:
	_track.mesh = _arc_mesh(-SWEEP_DEG, SWEEP_DEG, RADIUS)

	var marks := PackedVector3Array()
	# Centre, quarter, half, three-quarters, full -- on both sides. Ticks give
	# the bar a scale to be read against; without them it is just a glow.
	for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
		for side in ([1.0] if fraction == 0.0 else [-1.0, 1.0]):
			var a := deg_to_rad(SWEEP_DEG * fraction * side)
			var dir := Vector3(sin(a), 0.0, -cos(a))
			var length := 0.5 if fraction == 0.0 or fraction == 1.0 else 0.28
			marks.append(dir * (RADIUS - length * 0.5))
			marks.append(dir * (RADIUS + length * 0.5))
	_ticks.mesh = _lines(marks)


func _arc_points(from_deg: float, to_deg: float, radius: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in SEGMENTS:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / float(SEGMENTS)))
		var b := deg_to_rad(lerpf(from_deg, to_deg, float(i + 1) / float(SEGMENTS)))
		points.append(Vector3(sin(a), 0.0, -cos(a)) * radius)
		points.append(Vector3(sin(b), 0.0, -cos(b)) * radius)
	return points


func _arc_mesh(from_deg: float, to_deg: float, radius: float) -> ArrayMesh:
	return _lines(_arc_points(from_deg, to_deg, radius))


func _lines(points: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


## `curve` is the schema's value: positive a fade (right), negative a draw
## (left). The dial is laid out in the shot's own frame, so "right" on the dial
## is right of the shot rather than right of the screen.
func show_spin(at: Vector3, heading: Vector3, curve: float, blocked: bool) -> void:
	global_position = at + Vector3(0.0, 0.05, 0.0)
	var flat := Vector3(heading.x, 0.0, heading.z)
	if flat.length_squared() > 1.0e-6:
		global_basis = Basis.looking_at(flat.normalized(), Vector3.UP)

	var amount := clampf(curve, -1.0, 1.0)
	var tint := BLOCKED if blocked else CLEAR
	for node in [_track, _ticks]:
		var dim: StandardMaterial3D = node.material_override
		dim.albedo_color = Color(TRACK, 0.85)
	var lit: StandardMaterial3D = _bar.material_override
	lit.albedo_color = tint
	lit.emission = tint

	if absf(amount) < 0.02:
		# Straight. The bar collapses to a mark at centre rather than vanishing,
		# so "no spin" is a reading and not an absence of one.
		_bar.mesh = _lines(PackedVector3Array([
			Vector3(-0.09, 0.0, -RADIUS + 0.3), Vector3(-0.09, 0.0, -RADIUS - 0.3),
			Vector3(0.09, 0.0, -RADIUS + 0.3), Vector3(0.09, 0.0, -RADIUS - 0.3),
		]))
	else:
		# Two concentric arcs, so the filled part is visibly thicker than the
		# track it sits on and reads at a glance rather than by comparison.
		var to := SWEEP_DEG * amount
		var thick := _arc_points(0.0, to, RADIUS)
		thick.append_array(_arc_points(0.0, to, RADIUS + 0.11))
		thick.append_array(_arc_points(0.0, to, RADIUS + 0.22))
		# A cap across the two arcs, so the bar ends in a definite edge rather
		# than fraying out where the sweep stops.
		var end := deg_to_rad(to)
		var out := Vector3(sin(end), 0.0, -cos(end))
		thick.append(out * (RADIUS - 0.16))
		thick.append(out * (RADIUS + 0.38))
		_bar.mesh = _lines(thick)
	visible = true


func hide_dial() -> void:
	visible = false
