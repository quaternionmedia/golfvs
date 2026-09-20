# GdUnit generated TestSuite
extends GdUnitTestSuite

## The range as a whole: three pins, three clubs, and nothing that can be lost.
##
## Most of what matters here is a *relationship* between numbers in different
## files -- a pin's distance against its club's carry, the pins against the
## boundary, the boundary against the archer. Those are the things that drift
## when one of them is retuned, and this project has already shipped two bugs of
## exactly that shape.

const Walkthrough := preload("res://tests/walkthrough/walkthrough.gd")


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
	# The range as this suite sees it -- without the menu's flat layer, which
	# is the difference between this picture and the first run's.
	Walkthrough.hold_still(here)
	await Walkthrough.capture(self, "the-range", "the-range")


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


# ---------------------------------------------------------- the other side ---
#
# The contested range: an archer halfway to the pin, a golfer with a backswing,
# and a switch that puts the player on either end of it. What is worth pinning
# here is the *placement rule* and the fairness of the hand-played defender --
# the two things a later hole will get wrong first.


func _contested() -> Node3D:
	var scene := preload("res://holes/range/practice_range.tscn")
	var here := auto_free(scene.instantiate()) as Node3D
	here.contested = true
	add_child(here)
	return here


func test_the_first_run_has_exactly_one_defender_and_it_is_on_the_rock() -> void:
	# ADR-022. The tutorial meets one defender and it is a safety net (ADR-015);
	# an adversary on the same screen is a second idea arriving at the same time
	# as the first. Contesting the line is opt-in and belongs to later holes.
	var here := _range()
	assert_object(here._contender).is_null()
	assert_int(here._defenders.size()).is_equal(1)

	var only: Node3D = here._defenders[0]
	assert_bool(only.brain.profile.guards_bounds) 		.override_failure_message("the tutorial's one defender is not the boundary guard") 		.is_true()
	# And it is standing on the rock, where ADR-016 put it.
	assert_vector(only.global_position).is_equal_approx(
		here.ARCHER_STAND, Vector3.ONE * 0.01)


func test_the_contender_can_be_stood_up_and_taken_away() -> void:
	# The flag is a switch, not a note: a later hole turns this on at runtime, so
	# there must be no state where the range says contested and nothing is there.
	var here := _range()
	here.set_contested(true)
	assert_object(here._contender).is_not_null()
	assert_int(here._defenders.size()).is_equal(2)

	here.set_contested(false)
	assert_object(here._contender).is_null()
	assert_int(here._defenders.size()).is_equal(1)


func test_the_first_run_defends_with_the_archer_on_the_rock() -> void:
	# The tutorial's one defender is the safety net, and the player can pick it
	# up. That is a better lesson than an adversary: the ball you are asked to
	# shoot is the one that was about to be lost, so working this side is
	# learning where the course ends by patrolling it.
	var here := _range()
	assert_object(here._contender).is_null()
	assert_bool(here.can_defend()).is_true()
	assert_object(here.held()).is_same(here._guard)

	here.set_defending(true)
	assert_bool(here.defending()).is_true()


func test_taking_the_bow_leaves_the_attract_screen() -> void:
	# The attract screen waits for the golfer's first touch. On defence the game
	# is the golfer, and it only ever swings in AIM -- so a range left in ATTRACT
	# with the player holding a bow is a golfer who never addresses the ball.
	# This was reachable from the side switch all along; it became the first
	# thing every player met the day the first run opened on defence (ADR-028).
	var here := _range()
	assert_int(here.state).is_equal(here.State.ATTRACT)
	here.set_defending(true)
	assert_int(here.state) 		.override_failure_message("took the bow and the range stayed in ATTRACT, "
			+ "where the game's golfer never plays") 		.is_equal(here.State.AIM)


func test_a_range_told_to_open_on_defence_does_so() -> void:
	# `start_defending` goes through `set_defending` like any switch, so it has
	# to land in the same place a switch would: defending, in AIM, bow in hand.
	var scene := preload("res://holes/range/practice_range.tscn")
	var here := auto_free(scene.instantiate()) as Node3D
	here.start_defending = true
	add_child(here)
	assert_bool(here.defending()).is_true()
	assert_int(here.state).is_equal(here.State.AIM)
	assert_bool(here._gesture.enabled).is_true()
	assert_bool(here._gesture.locks_line) 		.override_failure_message("opened on defence with a gesture that locks its line, "
			+ "which is the stroke's second phase and a bow has none") 		.is_false()


func test_a_range_left_to_its_default_opens_as_the_golfer() -> void:
	# The component's base case, which every other test in this file assumes.
	# If this flips, the tutorial's choice has leaked into the range.
	var here := _range()
	assert_bool(here.start_defending).is_false()
	assert_bool(here.defending()).is_false()
	assert_int(here.state).is_equal(here.State.ATTRACT)


func test_the_contender_is_held_in_preference_when_there_is_one() -> void:
	var here := _contested()
	assert_object(here.held()).is_same(here._contender)
	here.set_contested(false)
	assert_object(here.held()).is_same(here._guard)


func test_a_range_with_no_defenders_offers_no_side_to_switch_to() -> void:
	# Otherwise the control hands the player an empty bow.
	var here := _range(false)
	assert_bool(here.can_defend()).is_false()
	here.set_defending(true)
	assert_bool(here.defending()).is_false()
	assert_bool(here._gesture.enabled).is_true()


func test_a_held_guard_stops_guarding_by_itself() -> void:
	# Taking the bow means the saving is now your job. A net that keeps catching
	# balls while the player aims it themselves is doing their job for them, and
	# the shot they just missed would read as one they made.
	var here := _range()
	here.set_defending(true)
	here._enter_aim()
	here.state = here.State.FLIGHT
	here.ball.freeze = false
	# Parked well outside the boundary, where the guard would normally act.
	here.ball.global_position = Vector3(
		here.BOUNDS_CENTRE.x + here.BOUNDS_EXTENT.x + 6.0, 2.0, here.BOUNDS_CENTRE.z)
	here._guard_the_boundary()
	assert_bool(here._guard.brain.is_committed()) 		.override_failure_message("the guard saved a ball the player was aiming at") 		.is_false()


func test_the_contender_stands_at_twice_the_distance_to_the_pin() -> void:
	# Mirrored through the hole: as far beyond the pin as the player is short of
	# it, on the same line. So the archer guards the ground *past* the target
	# rather than the flight to it, and going long is what it punishes.
	var here := _contested()
	here.pin = 0
	var tee := Vector3(here.BAY_POS.x, 0.0, here.BAY_POS.z)
	var stand: Vector3 = here.defender_stand()

	assert_vector(stand).is_equal_approx(
		here.pin_position() * 2.0 - tee, Vector3.ONE * 0.01)
	# And the node actually went there, rather than the rule merely saying so.
	here._place_the_contender()
	assert_vector(here._contender.position).is_equal_approx(stand, Vector3.ONE * 0.01)


func test_a_close_putt_is_the_players_to_lose() -> void:
	# The reason the rule doubles rather than halves. §3 says defenders never
	# enter the tee box and the first swing is always yours, and halving a
	# six-metre pin put one at the player's elbow. Doubling puts it well behind
	# the hole, which is what makes the first stroke of a first run the easiest
	# thing the game ever asks anybody for.
	var here := _contested()
	here.pin = 0
	var tee := Vector3(here.BAY_POS.x, 0.0, here.BAY_POS.z)
	var stand: Vector3 = here.defender_stand()
	var reach := stand.distance_to(tee)
	assert_float(reach).override_failure_message(
		"the archer is standing on the mat").is_greater(here.MAT_RADIUS + 4.0)
	# Further from the player than the hole is, which is the whole claim.
	assert_float(reach).is_greater(tee.distance_to(here.pin_position()))


func test_the_contender_never_stands_outside_the_fence() -> void:
	# Twice the far pin is a hundred and forty metres and the range stops at
	# sixty-two. The arithmetic is right and the place it points at is the void.
	var here := _contested()
	for i in here.PINS.size():
		here.pin = i
		var stand: Vector3 = here.defender_stand()
		# Against the *range's* fence, not the contender's own -- a contesting
		# archer guards a zone rather than a boundary, so its profile carries no
		# bounds worth asking about.
		assert_float(absf(stand.x - here.BOUNDS_CENTRE.x)).override_failure_message(
			"pin %d puts the archer at %v" % [i, stand]).is_less_equal(here.BOUNDS_EXTENT.x)
		assert_float(absf(stand.z - here.BOUNDS_CENTRE.z)).override_failure_message(
			"pin %d puts the archer at %v" % [i, stand]).is_less_equal(here.BOUNDS_EXTENT.y)


func test_the_contender_cannot_touch_a_putt() -> void:
	# The range teaches the defender in the order it teaches the clubs, and this
	# is why: an archer owns the air above 2.5 m, a putt never leaves the ground,
	# so a beginner's first stroke is untouchable without anything saying so.
	var here := _contested()
	here.pin = 0
	here._place_the_contender()
	var brain: DefenderBrain = here._contender.brain
	assert_bool(brain.profile.covers(Vector3(0.0, 0.1, -3.0), brain.tier)).is_false()
	assert_bool(brain.can_reach(Vector3(0.0, 0.1, -3.0))).is_false()


func test_the_ball_is_held_for_the_backswing() -> void:
	# The golfer's tell, and the thing that makes defending possible at all. If
	# the ball leaves on the frame the stroke is committed, a defender learns the
	# shot is coming by watching it already gone.
	var here := _contested()
	here._enter_aim()
	here._on_fired(Vector3.FORWARD, 0.8, 0.0)
	assert_bool(here._held).is_true()
	assert_int(here.state).is_equal(here.State.FLIGHT)
	assert_float(here.ball.linear_velocity.length()).is_equal(0.0)

	# Stepped past the backswing, the club arrives and the ball goes.
	for i in 40:
		here._physics_process(GolferFigure.windup() / 20.0)
	assert_bool(here._held).is_false()
	assert_float(here.ball.linear_velocity.length()).is_greater(0.0)


func test_the_defence_is_the_same_gesture_as_the_stroke() -> void:
	# The claim ADR-021 makes. Both sides pull, aim and release; what changes is
	# what is in your hands. A defender who has to learn a second control scheme
	# is not playing the same game from the other end, they are playing a
	# minigame -- which is what Pillar 1 rules out for the golfer and Pillar 5
	# should have been ruling out here.
	var here := _contested()
	here.set_defending(true)
	here._enter_aim()
	assert_bool(here._gesture.enabled) \
		.override_failure_message("the drag was taken away from the defender") \
		.is_true()
	# And it survives the ball going, because the defence happens during flight.
	here._on_fired(Vector3.FORWARD, 0.8, 0.0)
	assert_bool(here._gesture.enabled).is_true()


func test_letting_go_looses_an_arrow_that_has_to_travel() -> void:
	# Not a press that resolves on the frame it arrives. The arrow leaves the bow
	# and crosses the gap, which is the only reason leading the ball is a skill.
	var here := _contested()
	here.pin = 2
	here._place_the_contender()
	here.set_defending(true)
	here._enter_aim()

	here._on_fired(Vector3(0.0, 0.0, -1.0), 0.9, 0.0)
	assert_bool(here._arrow_live).is_true()
	var from: Vector3 = here._arrow_at
	here._physics_process(1.0 / 60.0)
	assert_float(here._arrow_at.distance_to(from)) \
		.override_failure_message("the arrow did not move").is_greater(0.1)


func test_one_arrow_per_stroke() -> void:
	# The cooldown starts when the string is let go, not when the arrow lands: a
	# bow you have already loosed is empty whatever the arrow is doing.
	var here := _contested()
	here.set_defending(true)
	here._enter_aim()
	assert_bool(here._contender.brain.commit_by_hand()).is_true()
	assert_bool(here._contender.brain.commit_by_hand()).is_false()


func test_an_arrow_that_hits_nothing_is_simply_gone() -> void:
	# A miss has to end. An arrow that lingered would eventually wander into the
	# ball and read as the game firing on the player's behalf.
	var here := _contested()
	here.set_defending(true)
	here._enter_aim()
	here._on_fired(Vector3(1.0, 0.0, 0.0), 1.0, 0.0)
	assert_bool(here._arrow_live).is_true()
	for i in 400:
		here._physics_process(1.0 / 60.0)
	assert_bool(here._arrow_live) \
		.override_failure_message("the arrow is still in the air").is_false()


func test_the_camera_stands_behind_the_archer_when_defending() -> void:
	# Third person on whichever figure the player is holding. The first version
	# handed the defender the golfer's camera, which made the lead unjudgeable:
	# a direction cannot be read from a viewpoint pointed the other way.
	var here := _contested()
	here.pin = 2
	here._place_the_contender()
	here.set_defending(true)
	here._enter_aim()

	var stand: Vector3 = here._contender.global_position
	var eye: Vector3 = here._frame_defend().origin
	var golfing: Vector3 = here._frame_aim().origin
	assert_float(eye.distance_to(stand)) \
		.override_failure_message("the defence camera is not on the archer") \
		.is_less(golfing.distance_to(stand))
	# Behind it, not in front: further from the ball than the archer is.
	assert_float(eye.distance_to(here.ball.global_position)) \
		.is_greater(stand.distance_to(here.ball.global_position))


func test_a_hand_played_defender_is_never_told_it_was_unlucky() -> void:
	# Deterministic on purpose. A person who timed it right and was told "the
	# dice said no" has been given no way to improve, which fails Pillar 2 harder
	# than any amount of chaos -- and there would be a roll to record.
	var here := _contested()
	here.pin = 2
	here._place_the_contender()
	var brain: DefenderBrain = here._contender.brain
	var centre: Vector3 = here.defender_stand() + Vector3.UP * 12.0
	assert_bool(brain.can_reach(centre)).is_true()
	# Out at the rim it is a real blind spot rather than a worse chance.
	var rim: Vector3 = centre + Vector3(brain.profile.zone_radius * 0.95, 0.0, 0.0)
	assert_bool(brain.can_reach(rim)).is_false()


func test_holding_the_archer_stops_it_playing_itself() -> void:
	# Both sides may not act on one stroke. While the player holds the archer it
	# gets no prediction to commit to, because its commitment is now the release
	# -- and the shot it is being held against is the game's, not the player's.
	var here := _contested()
	here.pin = 2
	here.set_club(here.suggested_club_index())
	here.set_defending(true)
	here._enter_aim()
	here._play_the_games_shot()
	assert_bool(here._contender.brain.is_committed()) 		.override_failure_message("the archer read a shot the player is defending") 		.is_false()


func test_switching_sides_changes_what_the_drag_means() -> void:
	# The gesture is live on both sides; what it does is what moves. Golfing it
	# hits a ball, defending it looses an arrow, and nothing in between.
	var here := _contested()
	here._enter_aim()
	here._on_fired(Vector3.FORWARD, 0.8, 0.0)
	assert_bool(here._held) \
		.override_failure_message("golfing, the drag did not play a stroke").is_true()
	assert_bool(here._arrow_live).is_false()

	here._enter_aim()
	here.set_defending(true)
	here._on_fired(Vector3.FORWARD, 0.8, 0.0)
	assert_bool(here._arrow_live) \
		.override_failure_message("defending, the drag did not loose an arrow").is_true()
	assert_bool(here._held).is_false()


# ------------------------------------------------------ can it be defended ---
#
# The question that matters about the other side, and it is not rhetorical: the
# gesture reads a heading on the *ground plane*, and the target is in the air.
# With a fixed launch angle that combination can only hit a ball that happens to
# be at the right height at the right range, which is not a hard shot, it is an
# unaimable one. The archer solves the elevation for exactly that reason, and
# these two tests are what says so -- one that a good lead connects, and one that
# a bad lead does not, because a test that only proves the first would pass just
# as well if every arrow hit.


const DEFEND_DT := 1.0 / 60.0


## The bearing a competent player would take: at where the ball is going to be,
## not where it is. Solved the same way the bow solves its elevation, which is
## the point -- the read is available to the player, it is just theirs to make.
func _lead_on(here: Node3D, speed: float) -> Vector3:
	var from: Vector3 = here.held().nock_at()
	var target: Vector3 = here.ball.global_position
	for i in 3:
		var t: float = from.distance_to(target) / speed
		target = here.ball.global_position + here.ball.linear_velocity * t \
			+ BallFlight.gravity() * t * t * 0.5
	var flat := target - from
	flat.y = 0.0
	return flat.normalized()


## Puts a ball in the air on a known flight and hands the archer to the player.
## The ball is flown by hand rather than by the physics server so the test
## measures the interception and not the engine.
func _ball_in_flight(here: Node3D) -> Vector3:
	here.set_defending(true)
	here._enter_aim()
	here.state = here.State.FLIGHT
	here.ball.freeze = true
	here.ball.global_position = Vector3(2.0, 9.0, -26.0)
	var vel := Vector3(4.0, 2.0, -26.0)
	here.ball.linear_velocity = vel
	return vel


func _fly_until_the_arrow_is_spent(here: Node3D, vel: Vector3) -> void:
	var moving := vel
	for i in 500:
		if not here._arrow_live:
			return
		here.ball.global_position += moving * DEFEND_DT
		moving += BallFlight.gravity() * DEFEND_DT
		here.ball.linear_velocity = moving
		here._physics_process(DEFEND_DT)


func test_a_good_lead_actually_stops_the_ball() -> void:
	# The whole claim of the defending side. If this cannot pass, the side is
	# decorative.
	var here := _range()
	var vel := _ball_in_flight(here)
	here._on_fired(_lead_on(here, here.BOW_MAX_SPEED), 1.0, 0.0)
	assert_bool(here._arrow_live).is_true()

	_fly_until_the_arrow_is_spent(here, vel)
	assert_bool(here._contender == null and here._guard.brain.will_connect()) \
		.override_failure_message("a correctly led arrow missed") \
		.is_true()
	assert_bool(here._pinned) \
		.override_failure_message("the arrow connected and the ball flew on") \
		.is_true()


func test_aiming_at_where_the_ball_is_misses_it() -> void:
	# And the other half. An arrow takes a third of a second to cross the range,
	# so the ball has moved eight or ten metres by the time it arrives -- if
	# shooting at the ball's present position worked, there would be no read.
	var here := _range()
	var vel := _ball_in_flight(here)
	var straight: Vector3 = here.ball.global_position - here.held().nock_at()
	straight.y = 0.0
	here._on_fired(straight.normalized(), 1.0, 0.0)

	_fly_until_the_arrow_is_spent(here, vel)
	assert_bool(here._guard.brain.will_connect()) \
		.override_failure_message("no lead was needed, so there is no shot to make") \
		.is_false()
	assert_bool(here._pinned).is_false()


func test_a_harder_draw_needs_less_lead() -> void:
	# What the power half of the gesture buys on this side. A faster arrow
	# arrives sooner, so the ball has moved less -- which is a choice with a
	# cost, exactly like hitting a golf shot harder.
	var here := _range()
	_ball_in_flight(here)
	var slow := _lead_on(here, here.BOW_MIN_SPEED)
	var fast := _lead_on(here, here.BOW_MAX_SPEED)
	var straight: Vector3 = here.ball.global_position - here.held().nock_at()
	straight.y = 0.0
	straight = straight.normalized()

	assert_float(fast.angle_to(straight)) \
		.override_failure_message("the draw did not change the lead") \
		.is_less(slow.angle_to(straight))


# ------------------------------------------------------------ the sequence ---
#
# The range never ends (ADR-029): a round of three is a file, not a stop, and
# the pin that comes up next is the next ternary digit of pi. These pin the
# arithmetic, the endlessness, and the camera that goes for a walk when nobody
# is holding it.


func _make_the_pin(here: Node3D) -> void:
	# The shortest honest route to a made pin: the ball is on it and has come to
	# rest. No record is opened, so nothing is written -- the demo round covers
	# the disk; this covers what the range does next.
	here.state = here.State.FLIGHT
	here.ball.global_position = here.pin_position() + Vector3(0.2, 0.0, 0.0)
	here._settle()


func test_the_pins_come_up_in_the_order_of_pi_in_ternary() -> void:
	# pi = 10.010211012222...  in base three. The digits after the point, read
	# as pin indices. If PIN_ORDER is ever regenerated, this is what checks it
	# was regenerated as pi and not as something that looked like it.
	var here := _range()
	var first_twelve := []
	for n in 12:
		first_twelve.append(here.pin_at(n))
	assert_array(first_twelve).contains_exactly([0, 1, 0, 2, 1, 1, 0, 1, 2, 2, 2, 2])
	# Putt first, as ADR-017 asked; the long pin is the fourth to come up.
	assert_int(here.pin).is_equal(0)
	assert_str(String(here.PINS[here.pin_at(0)]["suggests"])).is_equal("putt")
	assert_str(String(here.PINS[here.pin_at(3)]["suggests"])).is_equal("long")


func test_every_digit_is_a_pin() -> void:
	var here := _range()
	for n in here.PIN_ORDER.length():
		var index: int = here.pin_at(n)
		assert_bool(index >= 0 and index < here.PINS.size()) \
			.override_failure_message("digit %d of PIN_ORDER is %d, and there is no such pin" % [n, index]) \
			.is_true()
	# Past the end it wraps rather than crashing or sticking.
	assert_int(here.pin_at(here.PIN_ORDER.length())).is_equal(here.pin_at(0))


func test_the_range_never_ends() -> void:
	# Three pins made used to be DONE: gesture off, camera on a victory lap,
	# tap to start over. Now it is a round written and the fourth pin coming up.
	var here := _range()
	var rounds := []
	here.finished.connect(func(strokes: int) -> void: rounds.append(strokes))

	for n in 3:
		assert_int(here.pin).is_equal(here.pin_at(n))
		_make_the_pin(here)

	assert_int(here.pins_made).is_equal(3)
	assert_array(rounds).override_failure_message("three pins made should be exactly one round").has_size(1)
	assert_int(here.state) \
		.override_failure_message("the range stopped after three pins") \
		.is_equal(here.State.AIM)
	assert_bool(here._gesture.enabled).is_true()
	assert_int(here.pin).override_failure_message("the fourth pin is pi's fourth digit").is_equal(here.pin_at(3))

	for n in range(3, 6):
		_make_the_pin(here)
	assert_array(rounds).has_size(2)
	assert_int(here.pin).is_equal(here.pin_at(6))


func test_a_made_pin_is_the_next_line_of_play() -> void:
	# Everything a new pin resets, still reset: the club the pin suggests, the
	# orbit recentred, the contender moved to the new line.
	var here := _contested()
	here._look.yaw = 0.7
	_make_the_pin(here)
	assert_bool(here._look.is_centred()).is_true()
	assert_int(here.club_index).is_equal(here.suggested_club_index())
	assert_vector(here._contender.position).is_equal_approx(here.defender_stand(), Vector3.ONE * 0.01)


func _settle_the_camera(here: Node3D, seconds: float) -> void:
	# Frame by frame, the way the game runs it. A single large delta would let
	# move_toward and the easing take one stride each, which is not what a
	# player sees and not what these tests are about.
	var t := 0.0
	while t < seconds:
		here._process(1.0 / 60.0)
		t += 1.0 / 60.0


func test_an_idle_player_gets_the_tour() -> void:
	# A defender who is only watching, or a golfer who wandered off: after
	# IDLE_AFTER the tour fades in -- the view turns about the player and pulls
	# back -- and the first touch fades it out again.
	var here := _range()
	here.set_defending(true)
	var pivot: Vector3 = here._pivot()
	here._process(1.0 / 60.0)
	var at_rest: float = here._cam_target.origin.distance_to(pivot)

	_settle_the_camera(here, here.IDLE_AFTER + here.IDLE_FADE_IN + 0.5)
	assert_float(here._idle).is_equal_approx(1.0, 0.001)
	assert_float(absf(here._tour_yaw)).override_failure_message("idle and not turning").is_greater(0.05)
	assert_float(here._cam_target.origin.distance_to(pivot)) \
		.override_failure_message("the tour did not pull back from the player") \
		.is_greater(at_rest * 1.3)

	here._touched()
	# Less than IDLE_AFTER, or the tour begins again -- which is correct, and
	# the first version of this test found out the hard way.
	_settle_the_camera(here, here.IDLE_AFTER - 0.2)
	assert_float(here._idle).is_equal_approx(0.0, 0.001)
	assert_float(absf(here._tour_yaw)).is_less(0.01)
	assert_vector(here._cam_target.origin) \
		.override_failure_message("the player touched the screen and the tour did not come home") \
		.is_equal_approx(here._frame_defend().origin, Vector3.ONE * 0.05)


func test_the_tour_keeps_moving_while_the_player_is_idle() -> void:
	var here := _range()
	here.set_defending(true)
	_settle_the_camera(here, here.IDLE_AFTER + here.IDLE_FADE_IN + 0.5)
	var a: Vector3 = here._cam_target.origin
	_settle_the_camera(here, 1.0)
	var b: Vector3 = here._cam_target.origin
	assert_float(a.distance_to(b)).override_failure_message("the tour is standing still").is_greater(0.5)


func test_the_tour_never_jumps() -> void:
	# The ratifier's rule for the camera: no jumps, no sudden mode shifts, just
	# input or not. So: sixty frames a second, from standing still, through the
	# idle threshold, through the fade-in, a while on tour, a touch, and all the
	# way home -- and on no frame does the camera on screen move further than a
	# bound that a cut would blow through by a hundred times. The target is
	# checked as well as the eased camera, because the target is what used to
	# jump; easing a jump is still a jump, only blurred.
	var here := _range()
	here.set_defending(true)
	# Let the side switch's own swing finish first: that is the state changing
	# because the player changed it, and it is eased the way it always was. The
	# clock is then restarted so the measured run begins from a still camera.
	_settle_the_camera(here, 2.5)
	here._touched()
	var worst_target := 0.0
	var worst_eye := 0.0
	var last_target: Vector3 = here._cam_target.origin
	var last_eye: Vector3 = here._cam_smooth.origin
	var frames := int((here.IDLE_AFTER + here.IDLE_FADE_IN + 6.0) * 60.0)
	var touch_at := int((here.IDLE_AFTER + here.IDLE_FADE_IN + 3.0) * 60.0)
	for i in frames:
		if i == touch_at:
			here._touched()
		here._process(1.0 / 60.0)
		worst_target = maxf(worst_target, here._cam_target.origin.distance_to(last_target))
		worst_eye = maxf(worst_eye, here._cam_smooth.origin.distance_to(last_eye))
		last_target = here._cam_target.origin
		last_eye = here._cam_smooth.origin
	assert_float(worst_target) \
		.override_failure_message("the camera target moved %.2f m in one frame" % worst_target) \
		.is_less(1.0)
	assert_float(worst_eye) \
		.override_failure_message("the camera moved %.2f m in one frame" % worst_eye) \
		.is_less(1.0)


func test_the_tour_turns_from_the_view_it_leaves() -> void:
	# A turn from the view, not a view of its own: on the frame the tour begins
	# the eye is where it was, and only then starts to move. There is no bearing
	# to capture and no phase to match, because there is nothing to switch to.
	var here := _range()
	here.set_defending(true)
	_settle_the_camera(here, here.IDLE_AFTER - 0.1)
	var before: Vector3 = here._cam_target.origin
	_settle_the_camera(here, 0.2)
	assert_float(here._cam_target.origin.distance_to(before)).is_less(0.5)


func test_a_player_holding_the_camera_is_never_idle() -> void:
	# The orbit and the tour are the same degree of freedom. Somebody who has
	# dragged the camera somewhere is looking at something; the tour would take
	# it away from them.
	var here := _range()
	here.set_defending(true)
	here._look.yaw = 0.5
	here._process(here.IDLE_AFTER * 4.0)
	assert_float(here._idle_for).is_equal(0.0)
	assert_vector(here._cam_target.origin).is_equal_approx(here._frame_defend().origin, Vector3.ONE * 0.01)


func test_a_new_pin_resets_the_idle_clock_as_a_touch_would_not() -> void:
	# A made pin recentres the orbit (ADR-001 generalised), and the tour does
	# not restart from zero because of it: the player is exactly as idle as
	# they were. Only the player's own input resets the clock.
	var here := _range()
	here.set_defending(true)
	here._process(here.IDLE_AFTER + 0.1)
	_make_the_pin(here)
	here._process(0.016)
	assert_float(here._idle_for).is_greater(here.IDLE_AFTER)


func test_reaching_for_a_club_is_a_touch() -> void:
	# The selector's tap never reaches the gesture -- it marks itself handled --
	# so the range has to count the club change itself.
	var here := _range()
	here.set_defending(true)
	here._process(here.IDLE_AFTER + 0.1)
	here.set_club((here.club_index + 1) % ClubProfile.all().size())
	assert_float(here._idle_for).is_equal(0.0)


func test_the_defend_view_is_seven_degrees_right_and_pulled_back() -> void:
	# The ratifier's numbers. Right is positive about UP from behind the archer,
	# which is the camera's own right: the archer ends up left of centre and the
	# ball it is aiming at is not behind its head.
	var here := _range()
	here.set_defending(true)
	here._process(1.0 / 60.0)
	var stand: Vector3 = here.held().global_position
	var to_ball: Vector3 = here.ball.global_position - stand
	to_ball.y = 0.0
	var dir := to_ball.normalized()
	var rel: Vector3 = here._frame_defend().origin - stand
	rel.y = 0.0
	var off_the_spine := (-dir).signed_angle_to(rel.normalized(), Vector3.UP)
	assert_float(rad_to_deg(off_the_spine)).is_equal_approx(7.0, 0.05)
	# Further back than the aim camera stands from the ball, because a bow is
	# aimed at something a long way off.
	var golfer_eye: float = here._frame_aim().origin.distance_to(here.ball.global_position)
	assert_float(rel.length()).is_greater(golfer_eye)


func test_the_orbit_swings_around_the_player_and_not_the_line() -> void:
	# Two fingers turn the eye about whoever the player is: the archer holding
	# the bow, the ball under the club. It used to turn about a point thirty
	# metres down the line, which put the person orbiting at the edge of their
	# own orbit.
	var here := _range()
	here.set_defending(true)
	here._process(1.0 / 60.0)
	var archer: Vector3 = here.held().global_position
	var centred: float = here._frame_defend().origin.distance_to(archer)
	here._look.yaw = 1.2
	var swung: float = here._frame_defend().origin.distance_to(archer)
	assert_float(swung).override_failure_message("the orbit changed the distance to the archer, so it is not about the archer").is_equal_approx(centred, 0.05)

	here._look.recentre()
	here.set_defending(false)
	here._process(1.0 / 60.0)
	var ball: Vector3 = here.ball.global_position
	centred = here._frame_aim().origin.distance_to(ball)
	here._look.yaw = 1.2
	swung = here._frame_aim().origin.distance_to(ball)
	assert_float(swung).is_equal_approx(centred, 0.05)


func test_a_round_the_game_played_alone_is_not_written() -> void:
	# An unattended range is the first run now: the game golfs, nobody is
	# there. Its rounds are not records of anything and are not written -- the
	# first version wrote the whole session every round, and a phone left on
	# the range overnight grew gigabytes of its own play.
	var here := _range()
	var written := []
	here.finished.connect(func(_s: int) -> void: written.append(here.round_path))
	for n in 3:
		_make_the_pin(here)
	assert_array(written).has_size(1)
	assert_str(here.round_path).override_failure_message("a round nobody played was written to disk").is_empty()
	assert_bool(here._round.is_empty()).override_failure_message("the round list did not start again").is_true()


func test_a_round_is_a_file_of_its_own_strokes_and_the_list_starts_again() -> void:
	# Bounded: after a round is written the range holds nothing, and what it
	# wrote is kept as `last_round` for whoever wants to check the file.
	var here := _range()
	here._player_struck = true
	here._round.append(StrokeRecord.opened(here.HOLE_ID, here._layout_hash(), 1, 1,
		Vector3.ZERO, "tee", ShotIntent.make(ClubProfile.all()[0].to_intent_club(), 0.5, 0.0, Vector3.FORWARD)))
	here._round[0].resolve(Vector3.ZERO, "tee", PackedStringArray())
	for n in 3:
		_make_the_pin(here)
	assert_str(here.round_path).is_not_empty()
	assert_bool(here._round.is_empty()).is_true()
	assert_int(here.last_round.size()).is_equal(1)
	assert_bool(here._player_struck).override_failure_message("the next round inherited the last one's player").is_false()
