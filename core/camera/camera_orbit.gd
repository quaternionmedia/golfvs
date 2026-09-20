class_name CameraOrbit
extends Node
## The free orbit camera of ADR-001, as an offset on whatever the hole framed.
##
## The hole still decides where the camera belongs -- behind the ball on the line
## to the pin, trailing a flight, wide on a defender making its move. This node
## never replaces that framing. It holds three numbers the player owns -- a
## bearing, an elevation and a zoom -- and `apply()` swings the framed eye around
## the framed focus by them. So a player who has orbited to the left is still
## behind the ball on the next stroke, still trailing the next flight, and still
## looking at whatever the hole thought was worth looking at. That is what
## ADR-001 means by *decoupled from aim*: not a second camera, a rotation of the
## first.
##
## **Two fingers, never one.** ADR-007 makes touch the reference input and the
## one-finger drag is already spoken for -- it is the stroke, and it starts
## anywhere on the screen on purpose. So the orbit takes the second finger and
## nothing else, which is why this listens on `_input` rather than
## `_unhandled_input`: it has to see the second touch land *before* StrokeGesture
## reads it as a stroke, and mark it handled so it never gets there. When it does
## take hold it says so with `engaged`, and the hole aborts the stroke in
## progress -- a one-finger drag that became a two-finger one was a player
## reaching to look around, not a shot they wanted played.
##
## Mouse adapts from touch, as ADR-007 asks: right-drag orbits, the wheel zooms.
## Neither collides with the left button the stroke is built on.
##
## Two limits, and both are about not losing the hole. The elevation is clamped
## out of the deck and short of straight down, so there is no angle from which
## the range is edge-on or the up vector degenerate; the zoom is clamped to a
## little under half and a little over double, which is ADR-001's "zoom limited
## so the cup is always findable" written as a number.

## The player took hold of the camera. The hole listens for this to drop a stroke
## that was mid-drag when the second finger landed.
signal engaged

## Screen pixels to radians. Tuned so a drag across a third of the screen swings
## about a quarter turn -- enough to get behind the ball's other shoulder in one
## movement, gentle enough that a two-finger tap which drifts a few pixels does
## not visibly move anything.
const YAW_PER_PX := 0.006
const PITCH_PER_PX := 0.004

## Elevation is clamped rather than the pitch offset, so the limit is a property
## of where the camera ends up and not of how it got there. Three degrees keeps
## it out of the deck; seventy-eight keeps `looking_at` away from the pole, where
## a world-up basis has no answer.
const MIN_ELEVATION := deg_to_rad(3.0)
const MAX_ELEVATION := deg_to_rad(78.0)

const MIN_ZOOM := 0.55
const MAX_ZOOM := 2.2
## Pinching, and the wheel, in the units the zoom is stored in.
const ZOOM_PER_PX := 0.004
const ZOOM_PER_NOTCH := 0.12
## However close the hole framed from, never closer than this. A frame that puts
## the camera inside the ball is not a zoom limit anybody meant.
const MIN_DISTANCE := 2.0

## Below this the camera counts as centred, and an attract screen is free to go
## back to drifting on its own.
const CENTRED := 0.001

var yaw := 0.0
var pitch := 0.0
var zoom := 1.0

## Off while the hole is not accepting input. Unlike StrokeGesture this keeps its
## angle when switched off: the camera the player chose is still the camera they
## chose on the next stroke.
var enabled := true

var _touches := {}
var _centre := Vector2.ZERO
var _spread := 0.0
var _gripping := false
var _mousing := false


## The framed eye, swung around the framed focus by what the player has done.
## Pure: nothing here changes state, so a hole can call it every frame from
## whichever framing its current state produced.
func apply(eye: Vector3, focus: Vector3) -> Vector3:
	var offset := eye - focus
	var distance := offset.length()
	if distance < 0.001:
		return eye

	# Spherical about the focus. Bearing is measured off +Z so that a centred
	# orbit returns exactly the eye that came in, which is the property the whole
	# "offset, not replacement" idea rests on.
	var bearing := atan2(offset.x, offset.z) + yaw
	var elevation := clampf(
		asin(clampf(offset.y / distance, -1.0, 1.0)) + pitch,
		MIN_ELEVATION, MAX_ELEVATION)
	distance = maxf(distance * zoom, MIN_DISTANCE)

	var flat := cos(elevation) * distance
	return focus + Vector3(
		sin(bearing) * flat, sin(elevation) * distance, cos(bearing) * flat)


## Back to the line of play. ADR-001 asks for this on one tap, and a tap is
## exactly what StrokeGesture reports when a press goes down and comes up without
## ever becoming a stroke -- so the reset costs no control of its own.
func recentre() -> void:
	yaw = 0.0
	pitch = 0.0
	zoom = 1.0


func is_centred() -> bool:
	return absf(yaw) < CENTRED and absf(pitch) < CENTRED and absf(zoom - 1.0) < CENTRED


# ----------------------------------------------------------------- input -----

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _mousing:
		_turn((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()


func _on_touch(touch: InputEventScreenTouch) -> void:
	var was := _gripping
	if touch.pressed:
		_touches[touch.index] = touch.position
	else:
		_touches.erase(touch.index)

	_gripping = _touches.size() >= 2
	if _gripping:
		_measure()
	if _gripping and not was:
		engaged.emit()
	# The event that *ends* a grip is consumed too. Letting the lift of the
	# second finger through would hand StrokeGesture the tail of a gesture whose
	# head it never saw.
	if _gripping or was:
		get_viewport().set_input_as_handled()


func _on_drag(drag: InputEventScreenDrag) -> void:
	if not _touches.has(drag.index):
		return
	_touches[drag.index] = drag.position
	if not _gripping:
		return

	var centre := _centre
	var spread := _spread
	_measure()
	_turn(_centre - centre)
	# Fingers apart is closer, which every map and photo application has already
	# taught. Zoom is a scale on the framed distance, so the same pinch moves the
	# camera further from a long framing than from a short one -- which is what
	# makes it read as a zoom rather than as a fixed step.
	zoom = clampf(zoom - (_spread - spread) * ZOOM_PER_PX, MIN_ZOOM, MAX_ZOOM)
	get_viewport().set_input_as_handled()


func _on_mouse_button(button: InputEventMouseButton) -> void:
	match button.button_index:
		MOUSE_BUTTON_RIGHT:
			var was := _mousing
			_mousing = button.pressed
			if _mousing and not was:
				engaged.emit()
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_WHEEL_UP:
			if button.pressed:
				zoom = clampf(zoom - ZOOM_PER_NOTCH, MIN_ZOOM, MAX_ZOOM)
				get_viewport().set_input_as_handled()
		MOUSE_BUTTON_WHEEL_DOWN:
			if button.pressed:
				zoom = clampf(zoom + ZOOM_PER_NOTCH, MIN_ZOOM, MAX_ZOOM)
				get_viewport().set_input_as_handled()


## Screen movement into a bearing and an elevation. Dragging right walks the
## camera round to the right, so the world slides left under the finger -- the
## world is the thing being held, not the camera.
func _turn(moved: Vector2) -> void:
	yaw = wrapf(yaw + moved.x * YAW_PER_PX, -PI, PI)
	# The elevation that matters is clamped in `apply()`, against the framing the
	# hole produced. Bounding the raw offset here as well only stops it winding
	# up somewhere a single drag can never bring it back from.
	pitch = clampf(pitch + moved.y * PITCH_PER_PX, -MAX_ELEVATION, MAX_ELEVATION)


## Centroid and spread of the fingers that are down, which is all a two-finger
## gesture is: where it is, and how far apart it is.
func _measure() -> void:
	var points: Array[Vector2] = []
	var sum := Vector2.ZERO
	for at in _touches.values():
		points.append(at)
		sum += at
	_centre = sum / float(points.size())
	var far := 0.0
	for at in points:
		far = maxf(far, at.distance_to(_centre))
	_spread = far * 2.0
