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
