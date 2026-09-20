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


# ------------------------------------------------------------- the putter ----

# Reported in the first pre-alpha feedback as "the putter doesn't have the
# aiming graphic when winding up". It did, and it was about six centimetres
# long: a putt was previewed as a projectile, and a projectile launched at zero
# degrees from ball height lands within a metre, so VISIBLE_FRACTION of it came
# to nothing. The club whose entire skill is distance had no distance preview.


func _length_of(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
	return total


func test_a_putt_previewed_as_a_projectile_is_invisible() -> void:
	# The bug, kept as a test so nobody restores it by "simplifying" show_roll
	# back into show_arc.
	var putter := ClubProfile.putt()
	var velocity := BallFlight.launch_velocity(Vector3.FORWARD, 1.0, false, putter)
	var arc := BallFlight.sample_arc(
		Vector3(0.0, 0.18, 0.0), velocity, Vector3.ZERO, 0.18)
	var stub: PackedVector3Array = _ribbon()._leading_fraction(
		arc, AimRibbon.VISIBLE_FRACTION)
	assert_float(_length_of(stub)).override_failure_message(
		"a ballistic putt preview is %.2f m long -- if this is now visible, the "
		% _length_of(stub) + "reason show_roll exists has changed"
	).is_less(0.2)


func test_a_putt_previewed_as_roll_can_actually_be_seen() -> void:
	var putter := ClubProfile.putt()
	var ribbon := _ribbon()
	add_child(ribbon)
	ribbon.show_roll(Vector3(0.0, 0.18, 0.0), Vector3.FORWARD, putter.rolls())

	assert_bool(ribbon.visible).is_true()
	# Comfortably longer than a ball is wide, which the ballistic version was not.
	var shown := AimRibbon.VISIBLE_FRACTION * putter.rolls()
	assert_float(shown).override_failure_message(
		"the roll stub is %.2f m" % shown).is_greater(0.4)


func test_the_roll_preview_keeps_the_same_bargain_as_the_arc() -> void:
	# It is still a stub. A putt that drew its whole roll would be a dotted line
	# to the hole, which is the one thing §2.1 refuses to draw.
	var putter := ClubProfile.putt()
	assert_float(AimRibbon.VISIBLE_FRACTION * putter.rolls()) \
		.is_less(putter.rolls() * 0.2)


func test_the_direction_line_says_which_way_and_not_how_far() -> void:
	# Fixed length on purpose: it exists to be legible at a low camera angle,
	# where a short arc in the air is a smudge. If it grew with power it would
	# be leaking the distance the ribbon is careful not to give away.
	assert_float(AimRibbon.GROUND_REACH).is_greater(1.0)
	assert_int(AimRibbon.GROUND_DOTS).is_greater(2)
