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
