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
