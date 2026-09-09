# GdUnit generated TestSuite
extends GdUnitTestSuite

## The orbit camera of ADR-001, and the thing it is most likely to break.
##
## Two halves, and the second is the one worth the suite. The first is geometry:
## the orbit is an *offset* on the hole's framing, so a centred orbit has to hand
## back exactly the transform it was given, and no amount of dragging may put the
## camera under the deck, on the pole, or somewhere the pin cannot be found.
##
## The second is the collision. `StrokeGesture` starts a stroke on a press
## anywhere on the screen -- deliberately, it is Pillar 3 -- and the orbit takes
## two fingers on the same screen. The failure that costs a player a shot is a
## second finger landing mid-drag and the stroke going off as they let go. So the
## last tests here are about which gesture wins, and they drive the two objects
## wired together exactly as the range wires them.


func _orbit() -> CameraOrbit:
	var orbit := auto_free(CameraOrbit.new()) as CameraOrbit
	add_child(orbit)
	return orbit


func _gesture() -> StrokeGesture:
	var camera := auto_free(Camera3D.new()) as Camera3D
	add_child(camera)
	camera.global_position = Vector3(0.0, 2.0, 10.0)
	camera.look_at(Vector3(0.0, 0.0, -10.0), Vector3.UP)
	var gesture := auto_free(StrokeGesture.new()) as StrokeGesture
	gesture.camera = camera
	add_child(gesture)
	return gesture


## The range's wiring, in one place, so a test cannot pass against a pairing the
## game does not actually use.
func _wired() -> Array:
	var orbit := _orbit()
	var gesture := _gesture()
	orbit.engaged.connect(gesture.abort)
	gesture.tapped.connect(orbit.recentre)
	return [orbit, gesture]


func _touch(index: int, at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	return event


func _slide(index: int, at: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	return event


func _wheel(up: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	return event


# ------------------------------------------------------------- geometry ------

func test_a_centred_orbit_hands_the_framing_straight_back() -> void:
	# The property everything else rests on. If a centred orbit perturbs the eye
	# even slightly, every camera in the game moves the day this node is added,
	# and none of the framings mean what their own comments say.
	var orbit := _orbit()
	var eye := Vector3(3.0, 5.6, 12.0)
	var focus := Vector3(2.0, 1.4, -40.0)
	assert_bool(orbit.is_centred()).is_true()
	assert_vector(orbit.apply(eye, focus)).is_equal_approx(eye, Vector3.ONE * 0.0001)


func test_yaw_walks_around_the_focus_without_leaving_it() -> void:
	# An orbit that changes the distance while turning is a dolly wearing an
	# orbit's name, and the framing's careful "far enough back that the pin is in
	# frame" stops holding at every angle but one.
	var orbit := _orbit()
	var focus := Vector3(0.0, 1.0, -20.0)
	var eye := focus + Vector3(0.0, 4.0, 12.0)
	orbit.yaw = 0.9

	var moved := orbit.apply(eye, focus)
	assert_float(moved.distance_to(focus)).is_equal_approx(eye.distance_to(focus), 0.001)
	assert_float(moved.y).is_equal_approx(eye.y, 0.001)
	# Dragging right walks the camera to its own right, so the world slides left
	# under the finger. The eye leaves the centre line to +x.
	assert_float(moved.x).is_greater(0.0)


func test_it_never_drops_under_the_deck() -> void:
	# A camera below the floor sees the range through it, and on a blueprint
	# deck that is not a glitch anybody can read -- the world simply vanishes.
	var orbit := _orbit()
	var focus := Vector3(0.0, 1.0, -20.0)
	var eye := focus + Vector3(0.0, 4.0, 12.0)
	orbit.pitch = -4.0

	var moved := orbit.apply(eye, focus)
	assert_float(moved.y).is_greater(focus.y)
	assert_float(asin((moved.y - focus.y) / moved.distance_to(focus))) \
		.is_greater_equal(CameraOrbit.MIN_ELEVATION - 0.0001)


func test_it_never_reaches_the_pole() -> void:
	# Straight down has no bearing, and `looking_at` with a world up-vector has
	# no answer there: the camera spins on its own axis for a frame and then
	# faces somewhere arbitrary.
	var orbit := _orbit()
	var focus := Vector3(0.0, 1.0, -20.0)
	var eye := focus + Vector3(0.0, 4.0, 12.0)
	orbit.pitch = 4.0

	var moved := orbit.apply(eye, focus)
	assert_float(asin((moved.y - focus.y) / moved.distance_to(focus))) \
		.is_less_equal(CameraOrbit.MAX_ELEVATION + 0.0001)


func test_zoom_stops_at_both_ends() -> void:
	# ADR-001 asks for zoom "limited so the cup is always findable", which cuts
	# both ways: far enough out and the pin is a pixel, close enough in and the
	# camera is inside the ball.
	var orbit := _orbit()
	for i in 60:
		orbit._on_mouse_button(_wheel(true))
	assert_float(orbit.zoom).is_equal_approx(CameraOrbit.MIN_ZOOM, 0.0001)
	for i in 120:
		orbit._on_mouse_button(_wheel(false))
	assert_float(orbit.zoom).is_equal_approx(CameraOrbit.MAX_ZOOM, 0.0001)


func test_a_close_framing_zoomed_in_still_leaves_room() -> void:
	var orbit := _orbit()
	orbit.zoom = CameraOrbit.MIN_ZOOM
	var focus := Vector3.ZERO
	var moved := orbit.apply(Vector3(0.0, 1.0, 3.0), focus)
	assert_float(moved.distance_to(focus)).is_greater_equal(CameraOrbit.MIN_DISTANCE - 0.0001)


func test_recentring_restores_the_framing_exactly() -> void:
	var orbit := _orbit()
	var eye := Vector3(3.0, 5.6, 12.0)
	var focus := Vector3(2.0, 1.4, -40.0)
	orbit.yaw = 1.2
	orbit.pitch = 0.4
	orbit.zoom = 1.8
	assert_bool(orbit.is_centred()).is_false()

	orbit.recentre()
	assert_bool(orbit.is_centred()).is_true()
	assert_vector(orbit.apply(eye, focus)).is_equal_approx(eye, Vector3.ONE * 0.0001)


# ------------------------------------------------------------- two fingers ---

func test_one_finger_leaves_the_camera_alone() -> void:
	# The control case, and the one that matters most on a phone: the stroke is a
	# one-finger drag that starts anywhere, so a camera that moved on one finger
	# would move on every shot in the game.
	var orbit := _orbit()
	orbit._input(_touch(0, Vector2(400.0, 300.0), true))
	orbit._input(_slide(0, Vector2(560.0, 380.0)))
	orbit._input(_touch(0, Vector2(560.0, 380.0), false))
	assert_bool(orbit.is_centred()).is_true()


func test_two_fingers_turn_the_camera() -> void:
	var orbit := _orbit()
	orbit._input(_touch(0, Vector2(400.0, 300.0), true))
	orbit._input(_touch(1, Vector2(500.0, 300.0), true))
	orbit._input(_slide(0, Vector2(480.0, 300.0)))
	orbit._input(_slide(1, Vector2(580.0, 300.0)))

	assert_bool(orbit.is_centred()).is_false()
	assert_float(orbit.yaw).is_greater(0.0)


func test_pinching_apart_comes_closer() -> void:
	var orbit := _orbit()
	orbit._input(_touch(0, Vector2(400.0, 300.0), true))
	orbit._input(_touch(1, Vector2(500.0, 300.0), true))
	# Same centroid, further apart: a pinch with no pan in it.
	orbit._input(_slide(0, Vector2(300.0, 300.0)))
	orbit._input(_slide(1, Vector2(600.0, 300.0)))

	assert_float(orbit.zoom).is_less(1.0)
	assert_float(absf(orbit.yaw)).is_less(0.001)


func test_a_second_finger_drops_the_stroke_instead_of_playing_it() -> void:
	# The bug this suite exists for. The player has pulled back, then reaches in
	# with a second finger to look around the shot -- and lets go. Without the
	# abort, letting go plays the ball.
	var pair := _wired()
	var orbit: CameraOrbit = pair[0]
	var gesture: StrokeGesture = pair[1]
	gesture.fired.connect(func(_h: Vector3, _p: float, _c: float) -> void:
		fail("a two-finger camera drag played a stroke"))

	orbit._input(_touch(0, Vector2(500.0, 300.0), true))
	gesture._start(Vector2(500.0, 300.0))
	gesture._track(Vector2(500.0, 460.0))

	orbit._input(_touch(1, Vector2(300.0, 300.0), true))
	orbit._input(_slide(1, Vector2(360.0, 300.0)))
	gesture._release()

	assert_bool(orbit.is_centred()).is_false()


func test_taking_hold_of_the_camera_does_not_also_recentre_it() -> void:
	# `abort` reports `cancelled` so the ribbon comes down, and must not report
	# `tapped` -- which is wired to `recentre`. Getting that wrong makes the
	# camera snap back the instant the second finger lands, which reads as the
	# orbit being broken rather than as two signals being confused.
	var pair := _wired()
	var orbit: CameraOrbit = pair[0]
	var gesture: StrokeGesture = pair[1]

	orbit._input(_touch(0, Vector2(500.0, 300.0), true))
	gesture._start(Vector2(500.0, 300.0))
	gesture._track(Vector2(500.0, 460.0))
	orbit._input(_touch(1, Vector2(300.0, 300.0), true))
	orbit._input(_slide(1, Vector2(400.0, 300.0)))

	var turned := orbit.yaw
	assert_float(turned).is_not_equal(0.0)
	gesture._release()
	assert_float(orbit.yaw).is_equal_approx(turned, 0.0001)


func test_a_tap_puts_the_camera_back_on_the_line_of_play() -> void:
	# ADR-001's one-tap reset. A press that goes down and comes up without ever
	# leaving the deadzone is the one screen-wide gesture nothing else claims.
	var pair := _wired()
	var orbit: CameraOrbit = pair[0]
	var gesture: StrokeGesture = pair[1]
	orbit.yaw = 1.1
	orbit.zoom = 1.7

	gesture._start(Vector2(500.0, 300.0))
	gesture._release()
	assert_bool(orbit.is_centred()).is_true()


func test_a_stroke_that_was_taken_back_is_not_a_tap() -> void:
	# Pulled past the lock and released short of MIN_POWER: the player changed
	# their mind about a shot, which is not them asking for the camera back.
	var pair := _wired()
	var orbit: CameraOrbit = pair[0]
	var gesture: StrokeGesture = pair[1]
	orbit.yaw = 1.1

	gesture._start(Vector2(500.0, 300.0))
	gesture._track(Vector2(500.0, 330.0))
	gesture._release()
	assert_float(orbit.yaw).is_equal_approx(1.1, 0.0001)
