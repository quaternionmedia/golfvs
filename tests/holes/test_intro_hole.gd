# GdUnit generated TestSuite
extends GdUnitTestSuite

## The intro hole as a whole: the things that are only wrong once it is built.
##
## Every other suite tests a piece in isolation, which is why a clean rebuild
## found something none of them could. `MainMenu._process` runs before
## `IntroHole._process` — a parent's before its child's — so on frame 0 the menu
## unprojected the ball against a camera still sitting at the origin, inside the
## tee. One console error, a ghost hand in the corner for a frame, and a first
## rendered frame looking out from under the ground: on the first screen a
## player ever sees.
##
## The suite is deliberately small. Instantiating the hole builds a few hundred
## nodes, so it earns its place only for assertions that need the real thing.


func _hole(defended := true) -> Node3D:
	var scene := preload("res://holes/intro/intro_hole.tscn")
	var hole := auto_free(scene.instantiate()) as Node3D
	hole.defended = defended
	add_child(hole)
	return hole


func test_the_camera_is_placed_before_anything_can_look_through_it() -> void:
	# The regression. A camera left at the origin is not merely untidy: it is
	# inside the tee, so the first frame renders from under the ground, and
	# unproject_position against it is degenerate.
	var hole := _hole()
	assert_vector(hole.camera.global_position).is_not_equal(Vector3.ZERO)
	assert_float(hole.camera.global_position.y).is_greater(1.0)


func test_the_ball_can_be_unprojected_on_the_very_first_frame() -> void:
	# What the menu actually does, on the frame it actually does it.
	var hole := _hole()
	var at: Vector2 = hole.camera.unproject_position(hole.ball.global_position)
	assert_vector(at).is_not_equal(Vector2.ZERO)


func test_the_hole_starts_on_the_tee_and_knows_it() -> void:
	var hole := _hole()
	assert_str(hole._lie_at(hole.ball.global_position)).is_equal("tee")
	assert_int(hole.strokes).is_equal(0)
	assert_that(hole.state).is_equal(hole.State.ATTRACT)


func test_the_lie_detector_agrees_with_the_geometry() -> void:
	# _lie_at reads the same constants the terrain is built from, so the two
	# cannot drift. This is what checks that claim.
	var hole := _hole()
	assert_str(hole._lie_at(hole.CUP_POS)).is_equal("green")
	assert_str(hole._lie_at(hole.LANDING)).is_equal("fairway")
	assert_str(hole._lie_at(hole.SAND_POS)).is_equal("sand")
	assert_str(hole._lie_at(Vector3(-14.0, 0.0, -30.0))).is_equal("rough")
	assert_str(hole._lie_at(
		Vector3(hole.BOUNDS_CENTRE.x - hole.BOUNDS_EXTENT.x - 4.0, 0.0, -30.0))).is_equal("ob")


func test_a_ball_in_the_bunker_is_not_on_the_green() -> void:
	# The greenside bunker is 7.8 m from the green's centre against a 9 m radius,
	# so it sits inside the green's circle. Reading the green first made a ball
	# in the sand a ball on the putting surface -- and _lesson_for, which asked
	# the same question separately and got the same wrong answer, handed the
	# player a putter in a bunker.
	var hole := _hole()
	assert_str(hole._lie_at(hole.SAND_POS)).is_equal("sand")
	assert_that(hole._lesson_for(hole.SAND_POS)).is_not_equal(hole.Lesson.PUTT)

	# And the green itself is still the green.
	assert_str(hole._lie_at(hole.CUP_POS)).is_equal("green")
	assert_that(hole._lesson_for(hole.CUP_POS)).is_equal(hole.Lesson.PUTT)


func test_the_archer_is_there_when_the_hole_is_defended() -> void:
	var hole := _hole(true)
	assert_int(hole._defenders.size()).is_equal(1)
	var brain: DefenderBrain = hole._defenders[0].brain
	assert_str(brain.profile.sport).is_equal("archery")
	assert_that(brain.profile.action).is_equal(DefenderProfile.Action.PIN)
	assert_bool(brain.profile.guards_bounds).is_true()


func test_scottish_rules_removes_it_entirely() -> void:
	# §4 makes "is this still a good golf hole with the defender gone" the
	# sign-off for every hole, so turning it off has to actually work.
	var hole := _hole(false)
	assert_int(hole._defenders.size()).is_equal(0)


func test_a_defended_hole_is_a_different_hole() -> void:
	# `hole.layout_hash` exists so that a different hole is a different hash
	# whatever the id says (RECORD_SCHEMA.md §2.1). A round played against the
	# archer is not comparable with one played without it.
	assert_str(_hole(true)._layout_hash()).is_not_equal(_hole(false)._layout_hash())


func test_the_bounds_contain_the_hole_it_is_asked_to_play() -> void:
	# The archer fires at anything leaving these bounds, so a boundary that cut
	# through the green or the tee would make the hole unplayable.
	var hole := _hole()
	var profile := DefenderProfile.archer(
		hole.ARCHER_STAND, hole.BOUNDS_CENTRE, hole.BOUNDS_EXTENT)
	for spot in [hole.TEE_POS, hole.LANDING, hole.GREEN_POS, hole.CUP_POS, hole.ARCHER_STAND]:
		assert_bool(profile.in_bounds(spot)) \
			.override_failure_message("the hole's own %v is out of bounds" % spot) \
			.is_true()


# ----------------------------------------------------- the defensive action --

func test_the_arrow_carries_enough_momentum_to_arrest_a_golf_ball() -> void:
	# The tuning invariant, and the one most likely to be broken by accident.
	# The archer works because an arrow and a struck golf ball carry momentum of
	# the same order -- so the hole's launch speed and the arrow cannot be tuned
	# independently. Raise MAX_SPEED without raising the arrow and the archer
	# quietly stops arresting anything; lower it and every save fires the ball
	# into the deck like a nail. The upper bound is deliberately past 1.0: the
	# blow is meant to reverse the ball, not merely stop it.
	#
	# This project has already shipped one bug of exactly this shape, between
	# the hole's length and MAX_SPEED, so the relationship gets an assertion
	# rather than a comment.
	var hole := _hole()
	var delta_v: float = hole.ARROW_MASS * hole.ARROW_SPEED / hole.BALL_MASS
	assert_float(delta_v).is_between(BallFlight.MAX_SPEED * 0.9, BallFlight.MAX_SPEED * 2.1)


func test_a_struck_ball_is_hit_rather_than_switched_off() -> void:
	# The pin used to assign the ball a position and a velocity, so it stopped
	# dead in mid-air on the frame the archer acted. Momentum is added now, and
	# what the ball does next is the solver answering a collision.
	var hole := _hole()
	hole.ball.freeze = false
	hole.ball.linear_velocity = Vector3(0.0, 4.0, -20.0)
	var before: Vector3 = hole.ball.global_position

	var defender: Node3D = hole._defenders[0]
	_let_it_react(defender.brain)
	defender.brain.intercept(hole.ball.global_position)
	hole._on_defender_acted(defender)

	# Still moving, and now spinning.
	assert_float(hole.ball.linear_velocity.length()).is_greater(5.0)
	assert_float(hole.ball.angular_velocity.length()).is_greater(1.0)
	# Driven into the deck: that is what pins it, and what stops the transfer
	# from simply deflecting the ball onward.
	assert_float(hole.ball.linear_velocity.y).is_less(0.0)
	# And not teleported. Where the ball was hit is where it was.
	assert_vector(hole.ball.global_position).is_equal(before)


func test_the_shaft_keeps_dragging_until_the_next_stroke() -> void:
	# Without this the usual roll damp wins on the next physics tick and a
	# struck ball runs on as though nothing had hit it.
	var hole := _hole()
	var defender: Node3D = hole._defenders[0]
	_let_it_react(defender.brain)
	defender.brain.intercept(hole.ball.global_position)
	hole._on_defender_acted(defender)
	assert_bool(hole._pinned).is_true()


## Steps a defender past its reaction delay. Nothing can act before it has
## registered the shot, so a test that skips this is testing a defender that
## does not exist.
func _let_it_react(brain: DefenderBrain) -> void:
	for i in 200:
		if brain.has_reacted():
			return
		brain.advance(0.02)
