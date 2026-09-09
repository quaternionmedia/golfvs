class_name Beacon
extends Node3D
## A place the player should look at, said without words.
##
## Concentric rings ripple outward from a point on the ground, staggered in
## phase so the motion always reads as "outward from here" rather than "a thing
## that throbs". Optionally a soft column above it, for a target far enough away
## that the rings alone are a few pixels tall.
##
## Colour is the whole vocabulary: cyan asks, gold is the cup, green confirms.
## Nothing here is ever red -- a beacon marks an invitation, never a mistake.

const ASK := Color("6ef0ff")
const CUP := Color("ffd46b")
const DONE := Color("8dffa1")

const RING_COUNT := 3
const CYCLE := 1.9

@export var radius := 1.6:
	set(value):
		radius = value
		_rebuild()
@export var color := ASK:
	set(value):
		color = value
		_retint()
@export var column := false:
	set(value):
		column = value
		_rebuild()

var _rings: Array[MeshInstance3D] = []
var _column: MeshInstance3D = null
var _elapsed := 0.0
var _live := true


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in _rings:
		child.queue_free()
	_rings.clear()
	if _column != null:
		_column.queue_free()
		_column = null

	for i in RING_COUNT:
		var torus := TorusMesh.new()
		torus.inner_radius = radius * 0.90
		torus.outer_radius = radius
		torus.rings = 10
		torus.ring_segments = 56
		var mi := MeshInstance3D.new()
		mi.mesh = torus
		mi.material_override = HoleBuilder.glow(color, 4.5)
		mi.position.y = 0.06
		add_child(mi)
		_rings.append(mi)

	if column:
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius * 0.16
		cyl.bottom_radius = radius * 0.3
		cyl.height = 9.0
		cyl.radial_segments = 10
		_column = MeshInstance3D.new()
		_column.mesh = cyl
		_column.material_override = HoleBuilder.glow(color, 1.1)
		_column.position.y = 4.5
		add_child(_column)


func _retint() -> void:
	for mi in _rings:
		(mi.material_override as StandardMaterial3D).albedo_color = color
		(mi.material_override as StandardMaterial3D).emission = color
	if _column != null:
		(_column.material_override as StandardMaterial3D).albedo_color = color
		(_column.material_override as StandardMaterial3D).emission = color


func _process(delta: float) -> void:
	if not _live:
		return
	_elapsed += delta
	for i in _rings.size():
		# Each ring sits a third of a cycle behind the one before it.
		var phase: float = fposmod(_elapsed / CYCLE + float(i) / float(RING_COUNT), 1.0)
		var mi := _rings[i]
		# Ease-out on the spread so the ripple leaves quickly and lingers wide,
		# which reads as radiating rather than as a bouncing ball.
		var spread := 0.45 + 0.85 * (1.0 - pow(1.0 - phase, 2.4))
		mi.scale = Vector3(spread, 1.0, spread)
		var mat := mi.material_override as StandardMaterial3D
		var fade := clampf(phase / 0.18, 0.0, 1.0) * pow(1.0 - phase, 1.5)
		mat.albedo_color = Color(color, fade)

	if _column != null:
		var breathe := 0.5 + 0.5 * sin(_elapsed * 2.2)
		var mat := _column.material_override as StandardMaterial3D
		mat.albedo_color = Color(color, 0.10 + 0.10 * breathe)


## Confirms without a word: the rings snap green, flare once, and stop asking.
func confirm() -> void:
	color = DONE
	_live = false
	for mi in _rings:
		mi.scale = Vector3.ONE
		var mat := mi.material_override as StandardMaterial3D
		var tween := create_tween()
		tween.tween_property(mi, "scale", Vector3(2.6, 1.0, 2.6), 0.55) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(mat, "albedo_color", Color(DONE, 0.0), 0.55)
	if _column != null:
		var mat := _column.material_override as StandardMaterial3D
		create_tween().tween_property(mat, "albedo_color", Color(DONE, 0.0), 0.35)


func resume() -> void:
	_live = true
	color = ASK
