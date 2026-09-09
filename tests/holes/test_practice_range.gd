# GdUnit generated TestSuite
extends GdUnitTestSuite

## The range as a whole: three pins, three clubs, and nothing that can be lost.
##
## Most of what matters here is a *relationship* between numbers in different
## files -- a pin's distance against its club's carry, the pins against the
## boundary, the boundary against the archer. Those are the things that drift
## when one of them is retuned, and this project has already shipped two bugs of
## exactly that shape.


func _range(defended := true) -> Node3D:
	var scene := preload("res://holes/range/practice_range.tscn")
	var here := auto_free(scene.instantiate()) as Node3D
	here.defended = defended
	add_child(here)
	return here


func test_there_is_a_pin_for_each_club() -> void:
	var here := _range()
	assert_int(here.PINS.size()).is_equal(3)
	var clubs := []
	for spec in here.PINS:
		clubs.append(String(spec["suggests"]))
	assert_array(clubs).contains_exactly(["putt", "short", "long"])


func test_each_pin_is_reachable_by_its_own_club_and_not_by_a_full_swing() -> void:
	# The relationship the whole range is built on. A pin further than its
	# club's carry cannot be made; one at exactly the carry is made by mashing
	# it, and there is nothing to judge. Short of the carry means a full swing
	# is slightly too much, which is the entire lesson.
	var here := _range()
	for spec in here.PINS:
		var at: Vector3 = spec["at"]
		var distance := Vector2(at.x, at.z).length()
		var club := ClubProfile.for_id(String(spec["suggests"]))
		var reach: float = club.rolls() if club.is_putter else club.carry()
		assert_float(distance) \
			.override_failure_message(
				"the %s pin at %.1f m is not inside its club's %.1f m reach"
				% [club.id, distance, reach]) \
			.is_between(reach * 0.45, reach * 0.98)


func test_the_pins_get_further_away() -> void:
	# They are met in order, so they have to be in order.
	var here := _range()
	var last := 0.0
	for spec in here.PINS:
		var at: Vector3 = spec["at"]
		var distance := Vector2(at.x, at.z).length()
		assert_float(distance).is_greater(last)
		last = distance


func test_the_pins_are_off_axis_from_each_other() -> void:
	# Three targets in a line differ only by distance, and distance is the
	# hardest thing to read on a flat plane. Fanned, each is a different aim as
	# well as a different club.
	var here := _range()
	var headings := []
	for spec in here.PINS:
		var at: Vector3 = spec["at"]
		headings.append(rad_to_deg(atan2(at.x, -at.z)))
	for i in headings.size():
		for j in range(i + 1, headings.size()):
			assert_float(absf(headings[i] - headings[j])) \
				.override_failure_message("pins %d and %d share a line" % [i, j]) \
				.is_greater(6.0)


func test_each_pin_suggests_a_club_but_does_not_impose_it() -> void:
	# The pin only ever suggests. Finding out what the long club does to the
	# putting pin is a perfectly good way to learn what the long club is, and a
	# range that refused would be teaching obedience rather than golf.
	var here := _range()
	for i in here.PINS.size():
		here.pin = i
		here.set_club(here.suggested_club_index())
		assert_str(here.club().id).is_equal(String(here.PINS[i]["suggests"]))

	# And it can be overridden, at any pin, at any time.
	here.pin = 0
	here.set_club(0)
	assert_str(here.club().id).is_equal("long")


func test_changing_club_is_announced_once() -> void:
	# The selector mirrors the range rather than keeping its own state, so a
	# change that is not announced leaves the two disagreeing, and a change
	# announced twice makes it flicker.
	var here := _range()
	here.set_club(0)
	var seen := []
	here.club_changed.connect(func(index: int) -> void: seen.append(index))
	here.set_club(2)
	here.set_club(2)
	here.set_club(1)
	assert_array(seen).contains_exactly([2, 1])


func test_a_club_index_out_of_range_is_clamped_rather_than_crashing() -> void:
	var here := _range()
	here.set_club(99)
	assert_int(here.club_index).is_equal(ClubProfile.all().size() - 1)
	here.set_club(-4)
	assert_int(here.club_index).is_equal(0)


func test_the_range_opens_with_the_club_its_first_pin_wants() -> void:
	var here := _range()
	assert_str(here.club().id).is_equal(String(here.PINS[0]["suggests"]))


func test_everything_the_range_asks_for_is_inside_the_boundary() -> void:
	# The archer fires at anything crossing it, so a pin or a mat outside the
	# line would be a target the game shoots you for aiming at.
	var here := _range()
	var profile := DefenderProfile.archer(
		here.ARCHER_STAND, here.BOUNDS_CENTRE, here.BOUNDS_EXTENT)
	var must_fit := [here.BAY_POS, here.ARCHER_STAND]
	for spec in here.PINS:
		var at: Vector3 = spec["at"]
		var radius := float(spec["radius"])
		must_fit.append(at + Vector3(radius, 0.0, 0.0))
		must_fit.append(at - Vector3(radius, 0.0, 0.0))
		must_fit.append(at + Vector3(0.0, 0.0, radius))
		must_fit.append(at - Vector3(0.0, 0.0, radius))
	for spot in must_fit:
		assert_bool(profile.in_bounds(spot)) \
			.override_failure_message("the range's own %v is out of bounds" % spot) \
			.is_true()


func test_a_full_driver_stays_on_the_range() -> void:
	# The longest shot the range can produce has to fit inside it, or the archer
	# ends up firing at a good swing. Roll adds about a quarter to the carry on
	# this surface -- measured with tools/probe_clubs.tscn, where a full driver
	# carries 78 m and finishes at 96 m, rather than assumed.
	var here := _range()
	var down_range := absf(here.BOUNDS_CENTRE.z - here.BOUNDS_EXTENT.y)
	var longest := ClubProfile.long_club().carry() * 1.25
	assert_float(down_range) \
		.override_failure_message(
			"the range is %.0f m deep; a full driver carries and rolls about %.0f m"
			% [down_range, longest]) \
		.is_greater(longest)


func test_the_lie_detector_agrees_with_the_range_it_is_built_from() -> void:
	var here := _range()
	assert_str(here._lie_at(here.BAY_POS)).is_equal("tee")
	for spec in here.PINS:
		assert_str(here._lie_at(spec["at"])).is_equal("green")
	assert_str(here._lie_at(Vector3(
		here.BOUNDS_CENTRE.x - here.BOUNDS_EXTENT.x - 5.0, 0.0, -20.0))).is_equal("ob")
	assert_str(here._lie_at(Vector3(20.0, 0.0, -12.0))).is_equal("fairway")


func test_the_archer_watches_the_range_when_it_is_defended() -> void:
	var here := _range(true)
	assert_int(here._defenders.size()).is_equal(1)
	var brain: DefenderBrain = here._defenders[0].brain
	assert_str(brain.profile.sport).is_equal("archery")
	assert_bool(brain.profile.guards_bounds).is_true()


func test_it_can_be_played_without_one() -> void:
	assert_int(_range(false)._defenders.size()).is_equal(0)


func test_the_camera_is_placed_before_anything_can_look_through_it() -> void:
	# The regression from the intro hole, carried forward: MainMenu._process runs
	# before this node's, so a camera left at the origin renders the first frame
	# from under the floor and makes unproject_position degenerate.
	var here := _range()
	assert_vector(here.camera.global_position).is_not_equal(Vector3.ZERO)
	assert_vector(here.camera.unproject_position(here.ball.global_position)) \
		.is_not_equal(Vector2.ZERO)


func test_a_defended_range_is_a_different_range() -> void:
	assert_str(_range(true)._layout_hash()).is_not_equal(_range(false)._layout_hash())


## Frames per simulated second, for the camera tests below. They step `_process`
## by hand rather than waiting: what is being measured is how far the camera
## moves *per frame*, and a test that waited on real frames would measure the
## machine it is running on instead.
const CAM_DT := 1.0 / 60.0


func _in_flight(here: Node3D, velocity: Vector3) -> void:
	here.state = here.State.FLIGHT
	here.ball.freeze = false
	here.ball.linear_velocity = velocity
	var away := Vector3(velocity.x, 0.0, velocity.z)
	here._trail = -away.normalized()
	for i in 5:
		here._process(CAM_DT)


func test_the_camera_does_not_whip_round_when_the_arrow_reverses_the_ball() -> void:
	# The reported bug, and the reason `_trail` exists. The archer's arrow does
	# not stop the ball, it *reverses* it -- so a camera that recomputes "behind
	# the ball" from the raw velocity every frame teleports to the far side of it
	# on the frame the arrow lands. Off screen, with a shake on top, that reads
	# as the camera breaking rather than as a defender having done something.
	var here := _range()
	_in_flight(here, Vector3(0.0, 6.0, -30.0))
	var before: Vector3 = here._frame_flight().origin

	# What the arrow does: velocity against the flight, and the ball pinned.
	here.ball.linear_velocity = Vector3(0.0, -4.0, 26.0)
	here._pinned = true
	here._process(CAM_DT)

	assert_float(here._frame_flight().origin.distance_to(before)) \
		.override_failure_message("the flight camera jumped %.1f m in one frame"
			% here._frame_flight().origin.distance_to(before)) \
		.is_less(1.0)


func test_the_camera_turns_rather_than_cuts_when_the_ball_changes_line() -> void:
	# The same guarantee without the arrow: any reversal has to be a turn. It is
	# bounded by TRAIL_TURN, so one frame can only ever be a slice of it.
	var here := _range()
	_in_flight(here, Vector3(0.0, 6.0, -30.0))
	var before: Vector3 = here._trail

	here.ball.linear_velocity = Vector3(0.0, 6.0, 30.0)
	here._process(CAM_DT)
	assert_float(before.angle_to(here._trail)) \
		.is_less_equal(here.TRAIL_TURN * CAM_DT + 0.001)
	# And it does turn: a limit that never moves is just a frozen camera.
	assert_float(before.angle_to(here._trail)).is_greater(0.0)


func test_a_defender_is_blended_into_frame_and_not_cut_to() -> void:
	# The other half of the same jump. The defender framing used to be a branch:
	# present or absent, with the whole width of the range between the two.
	var here := _range()
	_in_flight(here, Vector3(0.0, 6.0, -30.0))
	assert_float(here._threat).is_equal(0.0)

	# Stand a defender up mid-act and let one frame pass.
	var archer: Node3D = here._defenders[0]
	archer.brain.state = DefenderBrain.State.ACT
	var before: Vector3 = here._frame_flight().origin
	here._process(CAM_DT)

	assert_float(here._threat).is_greater(0.0)
	assert_float(here._threat).is_less(1.0)
	assert_float(here._frame_flight().origin.distance_to(before)) \
		.override_failure_message("cutting to the defender moved the camera %.1f m"
			% here._frame_flight().origin.distance_to(before)) \
		.is_less(3.0)


func test_the_defender_framing_is_capped_however_far_away_it_is() -> void:
	# Uncapped, the pull-back was proportional to the gap between ball and
	# defender, so a strike at the far end of the range threw the camera sixty
	# metres backwards. The cap is what keeps a distant hit from being a
	# different shot to a near one.
	var here := _range()
	_in_flight(here, Vector3(0.0, 6.0, -30.0))
	here._threat = 1.0

	here._threat_at = here.ball.global_position + Vector3(12.0, 4.0, 0.0)
	var near: Vector3 = here._frame_flight().origin
	here._threat_at = here.ball.global_position + Vector3(240.0, 4.0, 0.0)
	var far: Vector3 = here._frame_flight().origin

	# The midpoint moves with the defender and that is intended; what must not
	# grow without limit is how far back the camera stands from it.
	var near_back := near.distance_to(
		(here.ball.global_position + here.ball.global_position
			+ Vector3(12.0, 4.0, 0.0)) * 0.5)
	var far_back := far.distance_to(
		(here.ball.global_position + here.ball.global_position
			+ Vector3(240.0, 4.0, 0.0)) * 0.5)
	assert_float(far_back).is_less(near_back + here.THREAT_SPREAD)
