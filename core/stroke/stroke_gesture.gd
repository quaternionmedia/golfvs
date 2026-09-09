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
##
## It is a *one-finger* gesture, and that is now load-bearing rather than
## incidental: ADR-001's orbit camera takes two fingers, so pressing anywhere can
## keep meaning "play a shot" without the two colliding. When a second finger
## lands, CameraOrbit takes the gesture over and calls `abort()` -- see there for
## why it has to see the touch first.

signal began
signal aim_updated(heading: Vector3, power: float, curve: float)
signal fired(heading: Vector3, power: float, curve: float)
signal cancelled
## A press that went down and came up without ever becoming a stroke. Reported
## separately from `cancelled`, which also covers a pull that was taken back and
## an orbit that interrupted one: those are strokes that did not happen, and this
## is the player not having tried to play one. CameraOrbit takes it as ADR-001's
## one-tap reset to the line of play, which is the only reason it exists -- a
## deliberate tap is otherwise the one screen-wide gesture nothing was using.
signal tapped

## Screen distance at which the line stops following the finger and locks, so
## that the sideways half of the gesture is read as curve and not as re-aiming.
const LOCK_PX := 26.0
const MAX_PULL_PX := 190.0
const MAX_CURVE_PX := 120.0
## Below this, the release was a tap, not a stroke. Without it every stray touch
## on the menu costs the player a shot.
const MIN_POWER := 0.05

var camera: Camera3D

## The horizontal plane the drag is read on, in world Y. Set it to whatever the
## player is aiming *from* -- the ball for a stroke, the ball's live height for
## a bow. See `_heading_between()`: the whole point is that the drag is measured
## on the same surface the player is looking at.
var aim_plane_y := 0.0

## Whether the line locks once it is committed.
##
## True for a stroke, and that is the two-phase gesture §2.1 describes: pull to
## set the line, then slide across it to bend the shot. False for anything with
## no curve to bend -- a bow -- where locking the line means the second half of
## every drag does nothing at all, and the player is holding a control that has
## stopped responding to them. That is not a subtlety; it was the single largest
## complaint in the first pre-alpha feedback, and it read as "it is not
## responding to the direction I'm choosing" because it was not.
var locks_line := true

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

	if not _locked or not locks_line:
		_locked = true
		_axis = pull.normalized()
		_heading = _heading_between(_anchor, pointer)

	# With the line locked, the drag splits into a component along it (power)
	# and one across it (curve). One gesture, two readings.
	#
	# Unlocked, there is no across: the axis is re-read every frame, so the
	# whole drag is the line and `along` is simply its length.
	var along := pull.dot(_axis)
	var across := 0.0 if not locks_line else _axis.cross(pull)
	_power = clampf((along - LOCK_PX) / (MAX_PULL_PX - LOCK_PX), 0.0, 1.0)
	# Screen y grows downward, so a rightward slide gives a negative cross
	# product. Negating here is what makes "finger right" come out as a positive
	# curve -- a fade, per RECORD_SCHEMA.md §2.1 -- so the number that reaches
	# the record already means what the schema says it means. The flip belongs
	# here, in the one place that deals in screen coordinates, and not in
	# BallFlight, where it used to hide.
	_curve = clampf(-across / MAX_CURVE_PX, -1.0, 1.0)
	aim_updated.emit(_heading, _power, _curve)


## Screen-space pull -> a world heading on the ground plane. The shot leaves
## opposite the pull, like a slingshot; that reading is near-universal and needs
## no explaining, which is the point.
##
## **Read through the camera, not off its basis.** The first version built the
## heading by mixing the camera's flattened right and forward vectors, which is
## exact only when the camera looks straight down. At any other angle the ground
## is foreshortened -- and the shallower the angle, the more it is -- so a drag
## at forty-five degrees on screen came out far more "away from the camera" than
## it looked. The player was choosing one direction and getting another, by an
## amount that changed as they orbited.
##
## That was survivable while the camera sat at one authored angle, and ADR-001's
## orbit made every angle reachable. So the drag is now unprojected: both ends of
## it are cast onto the aim plane through the same projection the player's eye is
## using, and the heading is the line between the two points they actually see.
## Correct at every camera angle by construction rather than by tuning.
func _heading_between(from: Vector2, to: Vector2) -> Vector3:
	var a := _on_aim_plane(from)
	var b := _on_aim_plane(to)
	if a != Vector3.INF and b != Vector3.INF:
		var pull := b - a
		pull.y = 0.0
		if pull.length() > 0.0001:
			return (-pull).normalized()
	# Near the horizon a ray is parallel to the plane and meets it nowhere
	# useful. The old basis mapping is wrong by a little everywhere and right at
	# the pole, which makes it a decent thing to fall back to and a poor thing to
	# have relied on.
	return _heading_from_basis((to - from).normalized())


## Where a point on screen lands on the aim plane, or INF if the ray does not
## meaningfully reach it.
func _on_aim_plane(at: Vector2) -> Vector3:
	if camera == null:
		return Vector3.INF
	var origin := camera.project_ray_origin(at)
	var direction := camera.project_ray_normal(at)
	if absf(direction.y) < 0.05:
		return Vector3.INF
	var distance := (aim_plane_y - origin.y) / direction.y
	if distance <= 0.0:
		return Vector3.INF
	return origin + direction * distance


func _heading_from_basis(axis: Vector2) -> Vector3:
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


## Drop a drag in progress without playing it. The camera calls this the instant
## a second finger lands: a one-finger gesture that becomes a two-finger one was
## a player reaching to look around, and finishing it would launch a ball they
## were not aiming. It reports `cancelled` because that is what happened to the
## stroke -- the ribbon has to come down either way -- but never `tapped`, or
## taking hold of the camera would instantly snap it back.
func abort() -> void:
	if not _dragging:
		return
	_reset()
	cancelled.emit()


func _release() -> void:
	if not _dragging:
		return
	_dragging = false
	if not _locked or _power < MIN_POWER:
		# Never left the deadzone at all: a tap, not a fumbled stroke. A pull
		# taken back past LOCK_PX and released short is the second of those, and
		# is not somebody asking for anything.
		var was_tap := not _locked
		_reset()
		cancelled.emit()
		if was_tap:
			tapped.emit()
		return
	var heading := _heading
	var power := _power
	var curve := _curve
	_reset()
	fired.emit(heading, power, curve)
