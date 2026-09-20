# GdUnit generated TestSuite
extends GdUnitTestSuite

## The gesture end to end: screen drag in, world shot out.
##
## This suite exists because of a bug it would have caught. BallFlight negated
## the curve and StrokeGesture handed it a value of the opposite sign. The two
## cancelled, so the ball flew exactly where the player expected -- and the
## number written into `intent.curve` meant the opposite of what
## RECORD_SCHEMA.md §2.1 says it means. Every test in the suite passed, because
## every test looked at one half of the pair.
##
## The lesson generalises past the sign: a preview, a gesture and a flight model
## that are only ever tested apart can each be individually wrong in ways that
## agree. So these tests start at a pixel and finish at a world vector.


func _camera_looking_down_the_fairway() -> Camera3D:
	var camera := auto_free(Camera3D.new()) as Camera3D
	add_child(camera)
	camera.global_position = Vector3(0.0, 2.0, 10.0)
	camera.look_at(Vector3(0.0, 0.0, -10.0), Vector3.UP)
	return camera


func _gesture(camera: Camera3D) -> StrokeGesture:
	var gesture := auto_free(StrokeGesture.new()) as StrokeGesture
	gesture.camera = camera
	add_child(gesture)
	return gesture


## Drags from `at` through each of `points`, and reports the last aim update.
##
## The handler *mutates* `last` rather than reassigning it. GDScript lambdas
## capture locals by value, so an assignment inside one is invisible to the
## caller; a Dictionary is a reference, so writing through it is not. Getting
## this wrong makes every test here fail with an empty result rather than a
## wrong one, which at least fails loudly.
func _drag(gesture: StrokeGesture, at: Vector2, points: Array) -> Dictionary:
	var last := {}
	gesture.aim_updated.connect(
		func(heading: Vector3, power: float, curve: float) -> void:
			last["heading"] = heading
			last["power"] = power
			last["curve"] = curve)
	gesture._start(at)
	for point in points:
		gesture._track(point)
	return last


func test_pulling_back_sends_the_ball_away_like_a_slingshot() -> void:
	var camera := _camera_looking_down_the_fairway()
	# Pull down the screen, toward the player. The shot should leave away from
	# them, down the fairway -- that reading is meant to need no explaining.
	var aim := _drag(_gesture(camera), Vector2(500.0, 300.0), [Vector2(500.0, 420.0)])
	assert_vector(aim["heading"]).is_not_null()
	assert_float(aim["heading"].dot(Vector3.FORWARD)).is_greater(0.9)
	assert_float(aim["heading"].y).is_equal(0.0)


func test_dragging_right_across_the_line_produces_a_fade() -> void:
	# The invariant the sign bug hid: the *number* has to agree with the schema,
	# and the *ball* has to agree with the finger. Asserting both together is
	# the only way to catch two errors that cancel.
	var camera := _camera_looking_down_the_fairway()
	var aim := _drag(_gesture(camera), Vector2(500.0, 300.0),
		[Vector2(500.0, 420.0), Vector2(570.0, 420.0)])

	# Positive is a fade, per RECORD_SCHEMA.md §2.1.
	assert_float(aim["curve"]).is_greater(0.0)

	# And a fade really does push the ball toward the camera's right.
	var accel := BallFlight.curve_acceleration(aim["heading"], aim["curve"])
	var camera_right := camera.global_basis.x
	assert_float(accel.dot(camera_right)).is_greater(0.0)


func test_dragging_left_across_the_line_produces_a_draw() -> void:
	var camera := _camera_looking_down_the_fairway()
	var aim := _drag(_gesture(camera), Vector2(500.0, 300.0),
		[Vector2(500.0, 420.0), Vector2(430.0, 420.0)])

	assert_float(aim["curve"]).is_less(0.0)
	var accel := BallFlight.curve_acceleration(aim["heading"], aim["curve"])
	assert_float(accel.dot(camera.global_basis.x)).is_less(0.0)


func test_a_longer_pull_is_more_power() -> void:
	var camera := _camera_looking_down_the_fairway()
	var gentle := _drag(_gesture(camera), Vector2(500.0, 300.0), [Vector2(500.0, 360.0)])
	var hard := _drag(_gesture(camera), Vector2(500.0, 300.0), [Vector2(500.0, 480.0)])
	assert_float(hard["power"]).is_greater(gentle["power"])
	assert_float(hard["power"]).is_between(0.0, 1.0)


func test_a_pull_shorter_than_the_lock_is_not_a_stroke() -> void:
	# Pressing anywhere starts a stroke (Pillar 3), so a stray tap on the menu
	# must not cost the player a shot.
	var camera := _camera_looking_down_the_fairway()
	var aim := _drag(_gesture(camera), Vector2(500.0, 300.0), [Vector2(506.0, 308.0)])
	assert_float(aim["power"]).is_equal(0.0)
	assert_float(aim["curve"]).is_equal(0.0)


func test_the_line_locks_so_the_sideways_half_is_read_as_curve() -> void:
	# Once the line is committed, sliding across it must bend the shot rather
	# than re-aim it. Without the lock there is no second half to the gesture.
	var camera := _camera_looking_down_the_fairway()
	var gesture := _gesture(camera)
	var straight := _drag(gesture, Vector2(500.0, 300.0), [Vector2(500.0, 420.0)])
	var locked_heading: Vector3 = straight["heading"]

	var bent := _drag(gesture, Vector2(500.0, 300.0),
		[Vector2(500.0, 420.0), Vector2(600.0, 420.0)])
	assert_vector(bent["heading"]).is_equal(locked_heading)
	assert_float(bent["curve"]).is_not_equal(0.0)


func test_a_released_stroke_reports_what_it_was_aiming() -> void:
	var camera := _camera_looking_down_the_fairway()
	var gesture := _gesture(camera)
	var fired := {}
	gesture.fired.connect(
		func(heading: Vector3, power: float, curve: float) -> void:
			fired["heading"] = heading
			fired["power"] = power
			fired["curve"] = curve)

	gesture._start(Vector2(500.0, 300.0))
	gesture._track(Vector2(500.0, 420.0))
	gesture._track(Vector2(570.0, 420.0))
	gesture._release()

	assert_bool(fired.is_empty()).is_false()
	assert_float(fired["power"]).is_greater(0.0)
	assert_float(fired["curve"]).is_greater(0.0)


func test_a_tap_cancels_instead_of_firing() -> void:
	var camera := _camera_looking_down_the_fairway()
	var gesture := _gesture(camera)
	var cancelled := [false]
	gesture.cancelled.connect(func() -> void: cancelled[0] = true)
	gesture.fired.connect(func(_h: Vector3, _p: float, _c: float) -> void:
		fail("a tap fired a stroke"))

	gesture._start(Vector2(500.0, 300.0))
	gesture._release()
	assert_bool(cancelled[0]).is_true()


# ----------------------------------------- the aim is what the drag looked like

# The first pre-alpha feedback, and the reason these exist:
#
#   "From straight top down it works pretty straightforward, but with the camera
#    at a lower angle, it starts to feel like it's not responding to the
#    direction I'm choosing."
#
# It was not. The heading used to be built by mixing the camera's *flattened*
# right and forward vectors, which is exact only when the camera looks straight
# down. Everywhere else the ground is foreshortened, so a diagonal drag came out
# far more "away from the camera" than it looked -- and the error grew as the
# angle got shallower, which ADR-001's orbit made reachable.
#
# So the property worth pinning is not a formula, it is the player's experience
# of one: **the shot should leave opposite the way the finger moved, on screen,
# at every camera angle.** These check exactly that, by projecting the resulting
# heading back onto the screen and comparing bearings.


func _camera_at(pitch_degrees: float) -> Camera3D:
	var camera := auto_free(Camera3D.new()) as Camera3D
	add_child(camera)
	# Looking at the origin from `pitch` above the horizon, from +Z.
	var pitch := deg_to_rad(pitch_degrees)
	var back := 24.0
	camera.global_position = Vector3(0.0, sin(pitch) * back, cos(pitch) * back)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	return camera


## The heading, as the player sees it: where it points on screen, drawn from the
## point they are aiming from.
func _heading_on_screen(camera: Camera3D, heading: Vector3) -> Vector2:
	var here := camera.unproject_position(Vector3.ZERO)
	var there := camera.unproject_position(heading * 6.0)
	return (there - here).normalized()


func _aim_with(camera: Camera3D, drag: Vector2) -> Vector3:
	var gesture := _gesture(camera)
	var anchor := camera.get_viewport().get_visible_rect().size * 0.5
	gesture._start(anchor)
	gesture._track(anchor + drag)
	return gesture._heading


func test_the_shot_leaves_opposite_the_drag_at_every_camera_angle() -> void:
	# Steep to shallow. 70 degrees is nearly the top-down view the player said
	# worked; 12 is the low angle they said stopped responding.
	for pitch in [70.0, 50.0, 30.0, 18.0, 12.0]:
		var camera := _camera_at(pitch)
		for bearing in [0.0, 45.0, 110.0, 200.0, 305.0]:
			var drag := Vector2.RIGHT.rotated(deg_to_rad(bearing)) * 120.0
			var heading := _aim_with(camera, drag)
			var on_screen := _heading_on_screen(camera, heading)
			# Slingshot: the shot goes the opposite way to the finger.
			var want := -drag.normalized()
			var off := rad_to_deg(absf(on_screen.angle_to(want)))
			assert_float(off).override_failure_message(
				"camera %.0f deg, drag bearing %.0f deg: the shot leaves %.0f deg "
				% [pitch, bearing, off] + "away from the opposite of the drag"
			).is_less(12.0)


func test_a_shallow_camera_is_no_worse_than_a_steep_one() -> void:
	# The specific complaint. Whatever error the mapping has, it must not grow
	# as the camera comes down -- that is the part that felt like the control
	# drifting rather than like the control being imprecise.
	var drag := Vector2.RIGHT.rotated(deg_to_rad(50.0)) * 130.0
	var worst := {}
	for pitch in [65.0, 15.0]:
		var camera := _camera_at(pitch)
		var on_screen := _heading_on_screen(camera, _aim_with(camera, drag))
		worst[pitch] = rad_to_deg(absf(on_screen.angle_to(-drag.normalized())))
	assert_float(worst[15.0]).override_failure_message(
		"steep camera is off by %.1f deg, shallow by %.1f" % [worst[65.0], worst[15.0]]
	).is_less(maxf(worst[65.0], 1.0) + 8.0)


func test_a_bow_can_be_re_aimed_without_letting_go() -> void:
	# The other half of the same complaint. A stroke locks its line so that
	# sliding across it bends the shot; a bow has nothing to bend, and locking
	# it means the drag stops responding halfway through -- which is exactly
	# what "not responding to the direction I'm choosing" describes.
	var camera := _camera_at(35.0)
	var gesture := _gesture(camera)
	gesture.locks_line = false
	var anchor := Vector2(560.0, 320.0)

	gesture._start(anchor)
	gesture._track(anchor + Vector2(0.0, 120.0))
	var first := gesture._heading
	gesture._track(anchor + Vector2(120.0, 120.0))
	var second := gesture._heading

	assert_float(first.angle_to(second)).override_failure_message(
		"the aim did not move when the drag did"
	).is_greater(deg_to_rad(15.0))
	# And no curve is invented out of the sideways movement.
	assert_float(gesture._curve).is_equal(0.0)


func test_a_stroke_still_locks_its_line() -> void:
	# The opposite guarantee, and the reason `locks_line` is a switch rather
	# than a deletion: §2.1's two-phase gesture depends on the line committing.
	var camera := _camera_at(35.0)
	var gesture := _gesture(camera)
	var anchor := Vector2(560.0, 320.0)

	gesture._start(anchor)
	gesture._track(anchor + Vector2(0.0, 120.0))
	var first := gesture._heading
	gesture._track(anchor + Vector2(120.0, 120.0))

	assert_vector(gesture._heading).is_equal(first)
	assert_float(gesture._curve).is_not_equal(0.0)
