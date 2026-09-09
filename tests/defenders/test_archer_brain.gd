# GdUnit generated TestSuite
extends GdUnitTestSuite

## ADR-015's archer: it acts on balls leaving the course and on nothing else.
##
## The archer inverts the usual defender test. For skeet the question is "does
## it act when it should", and the failure mode that matters is acting unfairly.
## Here the failure mode that matters is the opposite: an archer that acts on a
## good shot is not a safety net, it is an ambush on the tutorial hole. So most
## of what follows asserts that it does **nothing**.

const DT := 0.02

## The intro hole's real bounds: x from -19 to 29, z from -77 to 11.
const CENTRE := Vector3(5.0, 0.0, -33.0)
const EXTENT := Vector2(24.0, 44.0)


func _archer(tier := DifficultyTier.unerring()) -> ArcherBrain:
	var brain := ArcherBrain.new()
	brain.configure(DefenderProfile.archer(Vector3(15.5, 0.0, -49.0), CENTRE, EXTENT),
		tier, "archery_0")
	return brain


func _arc(heading: Vector3, power := 1.0, from := Vector3(0.0, 0.35, 0.0)) -> PackedVector3Array:
	return BallFlight.sample_arc(
		from, BallFlight.launch_velocity(heading, power), Vector3.ZERO, 0.0, 900, DT)


# ------------------------------------------------- it leaves good shots alone -

func test_a_shot_down_the_fairway_is_ignored() -> void:
	var brain := _archer()
	brain.read_shot(_arc(Vector3(0.0, 0.0, -1.0)), DT, 1)
	assert_bool(brain.is_committed()).is_false()
	assert_bool(brain.saves_this_shot()).is_false()


func test_it_does_nothing_across_a_whole_spread_of_playable_shots() -> void:
	# The tutorial hole would be ruined by an archer that fires at anything
	# reasonable, so this sweeps the shots the hole actually asks for rather
	# than trusting the one straight case above.
	var brain := _archer()
	# Plus or minus 20 degrees at full power still finishes on the course; at 35
	# it does not, and that shot is genuinely gone rather than merely bad. The
	# bounds were widened to 24 m a side to put the line there.
	for degrees in [-20, -12, -5, 0, 5, 12, 20]:
		for power in [0.3, 0.55, 0.8, 1.0]:
			var heading := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(degrees))
			brain.rest()
			brain._cooldown_left = 0.0
			brain.read_shot(_arc(heading, power), DT, 7)
			assert_bool(brain.is_committed()) \
				.override_failure_message(
					"the archer fired at a playable shot: %d deg at power %.2f"
					% [degrees, power]) \
				.is_false()


# ------------------------------------------------------ it catches the wild ---

func test_a_ball_leaving_the_course_is_shot() -> void:
	# Struck hard across the corridor, well past the left boundary at x = -19.
	var brain := _archer()
	brain.read_shot(_arc(Vector3(-1.0, 0.0, -0.15)), DT, 1)
	assert_bool(brain.is_committed()).is_true()
	assert_bool(brain.saves_this_shot()).is_true()


func test_the_ball_is_pinned_while_it_is_still_on_the_course() -> void:
	# The point of the exercise. Pinning at the first *out of bounds* sample
	# would save the player a penalty and leave them unable to play on, which is
	# a worse outcome than the penalty.
	var brain := _archer()
	brain.read_shot(_arc(Vector3(-1.0, 0.0, -0.15)), DT, 1)
	var pin := brain.act_point()
	assert_bool(brain.profile.in_bounds(pin)).is_true()

	# And close to the edge rather than somewhere arbitrary in the middle.
	var to_edge := minf(
		EXTENT.x - absf(pin.x - CENTRE.x),
		EXTENT.y - absf(pin.z - CENTRE.z))
	assert_float(to_edge).is_less(1.0)


func test_the_safety_net_does_not_fail() -> void:
	# base_accuracy is 1.0 on purpose: a player cannot tell "the archer missed"
	# from "the archer does not cover that", so an archer that misses one time
	# in twenty reads as an archer that is broken.
	var brain := _archer()
	for stroke_seed in range(200):
		brain.rest()
		brain._cooldown_left = 0.0
		brain.read_shot(_arc(Vector3(-1.0, 0.0, -0.15)), DT, stroke_seed)
		assert_bool(brain.saves_this_shot()).is_true()


func test_it_telegraphs_like_every_other_defender() -> void:
	# Being helpful is not an excuse for acting invisibly. Pillar 2 holds.
	var brain := _archer()
	var arc := _arc(Vector3(-1.0, 0.0, -0.15))
	brain.read_shot(arc, DT, 1)
	var seen := [brain.state]
	for i in arc.size():
		brain.advance(DT)
		if brain.state != seen[-1]:
			seen.append(brain.state)
	# The first four transitions. A long arc can run past the 1.2 s cooldown and
	# return to IDLE, which is correct and not part of what this asserts.
	assert_array(seen.slice(0, 4)).contains_exactly([
		DefenderBrain.State.IDLE,
		DefenderBrain.State.TELL,
		DefenderBrain.State.ACT,
		DefenderBrain.State.COOLDOWN,
	])


# ------------------------------------------------------------- the machinery -

func test_the_action_is_to_pin() -> void:
	assert_that(_archer().profile.action).is_equal(DefenderProfile.Action.PIN)


func test_a_bounds_guard_has_no_blind_spot() -> void:
	# The rim falloff models a defender being worse at the edge of a circle it
	# stands in the middle of. A boundary has no middle, so applying it would
	# make the archer arbitrarily bad at arbitrary places along the edge.
	var brain := _archer()
	var near := brain.profile.accuracy_at(Vector3(-15.0, 5.0, -33.0), brain.tier)
	var far := brain.profile.accuracy_at(Vector3(25.0, 5.0, -70.0), brain.tier)
	assert_float(near).is_equal(far)
	assert_float(near).is_greater(0.0)


func test_without_bounds_it_falls_back_to_the_apex_trigger() -> void:
	# An adversarial archer near the green is the same class with a zone. It
	# must not silently never act just because it is not guarding a boundary.
	var brain := ArcherBrain.new()
	var profile := DefenderProfile.skeet(Vector3(6.0, 0.0, -21.0), Vector3(0.0, 4.4, -21.0))
	brain.configure(profile, DifficultyTier.unerring(), "archery_0")
	brain.read_shot(_arc(Vector3(0.0, 0.0, -1.0)), DT, 1)
	assert_bool(brain.is_committed()).is_true()


func test_the_verdict_is_reproducible_from_the_seed() -> void:
	var arc := _arc(Vector3(-1.0, 0.0, -0.15))
	var first := _archer()
	first.read_shot(arc, DT, 4242)
	for i in 20:
		var again := _archer()
		again.read_shot(arc, DT, 4242)
		assert_float(again.act_time()).is_equal(first.act_time())
		assert_vector(again.act_point()).is_equal(first.act_point())


# ----------------------------------------------------- guarding it live ------

func test_it_intercepts_a_ball_the_prediction_never_saw() -> void:
	# The bug this exists for. A ball that lands in play and rolls off the course
	# never crosses the boundary in the air, so the predicted arc shows nothing
	# and the archer used to let it go. Measured against the real hole, that was
	# most of the balls that were lost.
	var brain := _archer()
	brain.read_shot(_arc(Vector3(0.0, 0.0, -1.0)), DT, 1)
	assert_bool(brain.is_committed()).is_false()

	var last_in_play := Vector3(-18.9, 0.18, -20.0)
	assert_bool(brain.intercept(last_in_play)).is_true()
	assert_vector(brain.act_point()).is_equal(last_in_play)
	assert_bool(brain.will_connect()).is_true()
	assert_that(brain.state).is_equal(DefenderBrain.State.ACT)


func test_an_interception_pins_the_ball_somewhere_playable() -> void:
	var brain := _archer()
	brain.read_shot(_arc(Vector3(0.0, 0.0, -1.0)), DT, 1)
	brain.intercept(Vector3(-18.9, 0.18, -20.0))
	assert_bool(brain.profile.in_bounds(brain.act_point())).is_true()


func test_it_only_intercepts_once_per_stroke() -> void:
	# Otherwise a ball nudged back and forth across the line would be shot every
	# tick, and the cooldown -- which every defender has, per §3 -- would mean
	# nothing.
	var brain := _archer()
	brain.read_shot(_arc(Vector3(0.0, 0.0, -1.0)), DT, 1)
	assert_bool(brain.intercept(Vector3(-18.9, 0.18, -20.0))).is_true()
	assert_bool(brain.intercept(Vector3(-18.5, 0.18, -21.0))).is_false()


func test_an_interception_is_reproducible_from_the_stroke_seed() -> void:
	# It draws from the stroke's own seed, not from the global generator, so a
	# replayed round intercepts identically.
	seed(99)
	var before := randi()
	seed(99)
	var brain := _archer()
	brain.read_shot(_arc(Vector3(0.0, 0.0, -1.0)), DT, 8123481)
	brain.intercept(Vector3(-18.9, 0.18, -20.0))
	assert_int(randi()).is_equal(before)


func test_watching_holds_the_draw_without_committing() -> void:
	# The ball is near the edge but has not crossed it. The archer draws, so the
	# save is readable rather than the ball simply stopping -- but it has not
	# fired, and if the ball stays in play it never does.
	var brain := _archer()
	brain.read_shot(_arc(Vector3(0.0, 0.0, -1.0)), DT, 1)
	brain.watch(Vector3(-17.0, 0.18, -20.0))
	assert_bool(brain.alerted).is_true()
	brain.advance(DT)
	assert_that(brain.state).is_equal(DefenderBrain.State.TELL)
	assert_bool(brain.is_committed()).is_false()
