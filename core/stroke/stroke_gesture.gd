class_name StrokeGesture
extends Node
## §2.1's "pull, curve, release" as one continuous gesture.
##
## The gesture has two phases and no modes. Dragging away from the ball sets the
## line and the power; once the line is committed, sliding across it bends the
## shot. Both are the same unbroken drag, so a first-timer who only ever pulls
## straight back never learns that the second half exists until the hole asks
## for it.
##
## The gesture is anchored where the finger lands, not on the ball. Measuring
## the pull from the ball instead looks equivalent and is not: it makes the shot
## depend on where you first touched, so a player who reaches in from the left
## and pulls straight back watches the ball leave to the right for no reason
## they can see. Anchoring at the press point means "drag back" is drag back
## from wherever you started, which is what the gesture looks like it promises.
##
## Pressing anywhere also starts a stroke -- asking a new player to find and hit
## a 40-pixel target before the game responds is a menu with extra steps
## (Pillar 3).

signal began
signal aim_updated(heading: Vector3, power: float, curve: float)
signal fired(heading: Vector3, power: float, curve: float)
signal cancelled

## Screen distance at which the line stops following the finger and locks, so
## that the sideways half of the gesture is read as curve and not as re-aiming.
const LOCK_PX := 26.0
const MAX_PULL_PX := 190.0
const MAX_CURVE_PX := 120.0
## Below this, the release was a tap, not a stroke. Without it every stray touch
## on the menu costs the player a shot.
const MIN_POWER := 0.05

var camera: Camera3D
var enabled := false:
	set(value):
		enabled = value
		if not enabled:
			_reset()

var _dragging := false
var _locked := false
var _anchor := Vector2.ZERO
var _axis := Vector2.ZERO
var _heading := Vector3.FORWARD
var _power := 0.0
var _curve := 0.0


func _reset() -> void:
	_dragging = false
	_locked = false
	_power = 0.0
	_curve = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or camera == null:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_start(touch.position)
		else:
			_release()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_start((event as InputEventMouseButton).position)
		else:
			_release()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_track((event as InputEventScreenDrag).position)
	elif event is InputEventMouseMotion and _dragging:
		_track((event as InputEventMouseMotion).position)


func _start(at: Vector2) -> void:
	_anchor = at
	_dragging = true
	_locked = false
	_power = 0.0
	_curve = 0.0
	began.emit()


func _track(pointer: Vector2) -> void:
	if not _dragging:
		return
	var pull := pointer - _anchor
	if pull.length() < LOCK_PX:
		_locked = false
		_power = 0.0
		_curve = 0.0
		aim_updated.emit(_heading, 0.0, 0.0)
		return

	if not _locked:
		_locked = true
		_axis = pull.normalized()
		_heading = _screen_pull_to_heading(_axis)

	# With the line locked, the drag splits into a component along it (power)
	# and one across it (curve). One gesture, two readings.
	var along := pull.dot(_axis)
	var across := _axis.cross(pull)
	_power = clampf((along - LOCK_PX) / (MAX_PULL_PX - LOCK_PX), 0.0, 1.0)
	# Sign works out so that sliding the finger right bends the ball right; see
	# BallFlight.curve_acceleration, which negates once more.
	_curve = clampf(across / MAX_CURVE_PX, -1.0, 1.0)
	aim_updated.emit(_heading, _power, _curve)


## Screen-space pull -> a world heading on the ground plane. The shot leaves
## opposite the pull, like a slingshot; that reading is near-universal and needs
## no explaining, which is the point.
func _screen_pull_to_heading(axis: Vector2) -> Vector3:
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	# Screen y grows downward, so dragging down the screen is pulling toward the
	# camera, which is -forward.
	var pull_world := right * axis.x - forward * axis.y
	return (-pull_world).normalized()


func _release() -> void:
	if not _dragging:
		return
	_dragging = false
	if not _locked or _power < MIN_POWER:
		_reset()
		cancelled.emit()
		return
	var heading := _heading
	var power := _power
	var curve := _curve
	_reset()
	fired.emit(heading, power, curve)
