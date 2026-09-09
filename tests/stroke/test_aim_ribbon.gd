# GdUnitTestSuite
extends GdUnitTestSuite

## The ribbon shows the start of the shot and then gets out of the way.
##
## A preview that draws the whole arc turns every hole into a solved equation:
## the player stops reading the ground and starts following a dotted line to the
## cup. The truncation is the design, not a performance measure, so it is worth
## a test that fails loudly if someone "fixes" the ribbon by showing all of it.


func _ribbon() -> AimRibbon:
	return auto_free(AimRibbon.new())


func test_the_visible_stub_is_a_small_head_of_the_arc() -> void:
	assert_float(AimRibbon.VISIBLE_FRACTION) \
		.override_failure_message(
			"The ribbon is showing %.0f%% of the flight. It is meant to show a " %
			(AimRibbon.VISIBLE_FRACTION * 100.0) +
			"stub and fade out, not to draw the landing."
		) \
		.is_between(0.02, 0.15)


func test_the_stub_is_measured_off_the_front_of_the_arc() -> void:
	var arc := BallFlight.sample_arc(
		Vector3.ZERO, BallFlight.launch_velocity(Vector3.FORWARD, 0.8), Vector3.ZERO, 0.0)
	var stub: PackedVector3Array = _ribbon()._leading_fraction(arc, AimRibbon.VISIBLE_FRACTION)

	assert_int(stub.size()).is_greater(1)
	# It starts at the ball...
	assert_float(stub[0].distance_to(arc[0])).is_less(0.001)
	# ...and stops well short of where the ball actually lands.
	var full := _length(arc)
	var shown := _length(stub)
	assert_float(shown).is_less(full * 0.2)
	assert_float(shown).is_greater(0.0)


func test_a_harder_shot_shows_a_longer_stub() -> void:
	# Power has no number attached to it anywhere on screen, so the length of
	# the streak is the only thing telling the player how hard they just pulled.
	var soft := _stub_length(0.3)
	var hard := _stub_length(0.9)
	assert_float(hard).is_greater(soft)


func _stub_length(power: float) -> float:
	var arc := BallFlight.sample_arc(
		Vector3.ZERO, BallFlight.launch_velocity(Vector3.FORWARD, power), Vector3.ZERO, 0.0)
	return _length(_ribbon()._leading_fraction(arc, AimRibbon.VISIBLE_FRACTION))


func _length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
	return total
