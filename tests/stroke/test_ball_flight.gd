# GdUnitTestSuite
extends GdUnitTestSuite

## The flight model, and the promise the aim ribbon makes about it.
##
## Two of these guard mistakes that were actually made while building the intro
## hole, and that a screenshot does not catch. The launch angle was applied with
## the wrong sign, firing every stroke into the turf: the ball still travelled,
## by skipping along the ground, so the hole looked playable and the bug lived
## behind a plausible-looking shot until the preview was instrumented.

const EPS := 0.0001


func test_the_ball_leaves_the_ground() -> void:
	# The sign regression. A shot launched downward still carries -- it skips --
	# so "the ball moved" is not evidence that this is right.
	for power in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var v := BallFlight.launch_velocity(Vector3.FORWARD, power)
		assert_float(v.y) \
			.override_failure_message(
				"Launch at power %.2f has vertical velocity %.3f. " % [power, v.y] +
				"A negative or zero value fires the stroke into the ground."
			) \
			.is_greater(0.0)


func test_the_shot_goes_where_it_was_aimed() -> void:
	for heading in [Vector3.FORWARD, Vector3.RIGHT, Vector3(1.0, 0.0, 1.0).normalized()]:
		var v := BallFlight.launch_velocity(heading, 0.7)
		var flat := Vector3(v.x, 0.0, v.z).normalized()
		assert_float(flat.dot(heading.normalized())).is_greater(0.999)


func test_more_power_carries_further() -> void:
	var last := -1.0
	for power in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]:
		var carry := _carry(BallFlight.launch_velocity(Vector3.FORWARD, power), Vector3.ZERO)
		assert_float(carry).is_greater(last)
		last = carry


func test_full_power_does_not_overshoot_the_hole() -> void:
	# The intro hole measures 77 m to the cup and wants three strokes. A driver
	# that carries the whole thing turns it into a one-shot hole by accident.
	# The bounds move with the hole: range goes as the square of launch speed,
	# so lengthening one without the other silently changes how the hole plays.
	var carry := _carry(BallFlight.launch_velocity(Vector3.FORWARD, 1.0), Vector3.ZERO)
	assert_float(carry).is_between(45.0, 68.0)


func test_curve_signs_match_the_record_schema() -> void:
	# RECORD_SCHEMA.md §2.1: "Negative is a draw (left), positive a fade
	# (right), for a right-handed golfer." `intent.curve` goes on disk, so this
	# is not a matter of taste -- a stored number whose sign means the opposite
	# of what the schema says is a bug that surfaces on somebody else's phone,
	# after the schema has frozen and can no longer be corrected.
	#
	# Both signs used to be inverted, here and in StrokeGesture, and cancelled:
	# the ball flew correctly and the recorded value was backwards.
	var heading := Vector3.FORWARD
	var right_of_flight := heading.cross(Vector3.UP).normalized()

	var fade := BallFlight.curve_acceleration(heading, 1.0)
	assert_float(fade.dot(right_of_flight)).is_greater(0.0)

	var draw := BallFlight.curve_acceleration(heading, -1.0)
	assert_float(draw.dot(right_of_flight)).is_less(0.0)

	assert_float(BallFlight.curve_acceleration(heading, 0.0).length()).is_less(EPS)


func test_a_putt_stays_on_the_deck() -> void:
	for power in [0.0, 0.5, 1.0]:
		var v := BallFlight.launch_velocity(Vector3.FORWARD, power, true)
		assert_float(absf(v.y)).is_less(EPS)


## Time to return to the launch height, times horizontal speed.
func _carry(velocity: Vector3, accel: Vector3) -> float:
	var g := BallFlight.gravity().y + accel.y
	var flight := -2.0 * velocity.y / g
	return Vector2(velocity.x, velocity.z).length() * flight
