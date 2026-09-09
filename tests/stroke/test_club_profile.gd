# GdUnit generated TestSuite
extends GdUnitTestSuite

## Three clubs that are actually three clubs.
##
## Until the range, `BallFlight` held one set of numbers for every full shot, so
## every stroke in the game was the same club wearing whichever name the record
## happened to store. These tests are what stops that quietly coming back: the
## thing worth asserting is not any particular carry but that the three are
## *separated*, and that the record's four names all resolve.


func test_the_three_clubs_reach_three_different_distances() -> void:
	# The whole point of having clubs. Two that carry within a few metres of
	# each other are one club with two labels, and the range would be teaching
	# nothing.
	var wedge := ClubProfile.wedge().carry()
	var iron := ClubProfile.iron().carry()
	var driver := ClubProfile.driver().carry()

	assert_float(wedge).is_greater(10.0)
	assert_float(iron).is_greater(wedge * 1.5)
	assert_float(driver).is_greater(iron * 1.4)


func test_the_short_clubs_go_up_and_the_long_ones_go_out() -> void:
	# A wedge that launched like a driver would reach its pin and run straight
	# through it, and the near target would be unmakeable.
	assert_float(ClubProfile.wedge().launch_deg).is_greater(ClubProfile.iron().launch_deg)
	assert_float(ClubProfile.iron().launch_deg).is_greater(ClubProfile.driver().launch_deg)


func test_a_longer_club_bends_more() -> void:
	# In metres, not in the constant: a ball in the air longer bends further for
	# the same acceleration, so the numbers rise with the club to keep the
	# *shape* of a full-curve shot comparable between them.
	assert_float(ClubProfile.driver().curve_accel).is_greater(ClubProfile.iron().curve_accel)
	assert_float(ClubProfile.iron().curve_accel).is_greater(ClubProfile.wedge().curve_accel)


func test_the_putter_rolls() -> void:
	var putter := ClubProfile.putter()
	assert_bool(putter.is_putter).is_true()
	assert_float(putter.launch_deg).is_equal(0.0)
	assert_float(putter.carry()).is_equal(0.0)
	assert_float(putter.max_speed).is_less(ClubProfile.wedge().max_speed)


func test_every_club_the_schema_names_resolves() -> void:
	# `intent.club` is a frozen enum of four names (RECORD_SCHEMA.md §2.1). A
	# reader has to be able to turn any of them back into a flight, or a stored
	# record becomes unplayable.
	for name in ShotIntent.CLUB_NAMES:
		var club := ClubProfile.for_id(name)
		assert_str(club.id).is_equal(name)
		assert_str(ShotIntent.CLUB_NAMES[club.to_intent_club()]).is_equal(name)


func test_the_flight_model_uses_the_club_it_is_given() -> void:
	var heading := Vector3.FORWARD
	var wedge := BallFlight.launch_velocity(heading, 1.0, false, ClubProfile.wedge())
	var driver := BallFlight.launch_velocity(heading, 1.0, false, ClubProfile.driver())
	assert_float(driver.length()).is_greater(wedge.length())
	# And the wedge leaves at a steeper angle, which is what stops it running on.
	assert_float(wedge.normalized().y).is_greater(driver.normalized().y)


func test_a_caller_that_names_no_club_still_gets_a_ball_flight() -> void:
	# Every previous version of the game called these with two arguments. They
	# have to keep working, and they have to keep meaning the iron they always
	# secretly were.
	var plain := BallFlight.launch_velocity(Vector3.FORWARD, 1.0)
	var iron := BallFlight.launch_velocity(Vector3.FORWARD, 1.0, false, ClubProfile.iron())
	assert_vector(plain).is_equal(iron)
	assert_str(BallFlight.default_club().id).is_equal("iron")


func test_asking_for_a_putt_gets_a_putt_whichever_way_you_ask() -> void:
	var by_flag := BallFlight.launch_velocity(Vector3.FORWARD, 1.0, true)
	var by_club := BallFlight.launch_velocity(Vector3.FORWARD, 1.0, false, ClubProfile.putter())
	assert_vector(by_flag).is_equal(by_club)
	assert_float(by_flag.y).is_equal(0.0)


# --------------------------------------------------------- the AI golfer -----

func test_the_ai_golfer_plays_the_club_it_was_handed() -> void:
	# It used to search with the default iron whatever club was actually in the
	# golfer's hands, so on a wedge it solved for a flight the shot would not
	# take and came up short of everything by the ratio between the two clubs.
	# On the range that meant it never once reached the near pin.
	var clear := func(_arc: PackedVector3Array) -> bool: return false
	var from := Vector3(0.0, 0.35, 0.0)
	for club in [ClubProfile.wedge(), ClubProfile.iron(), ClubProfile.driver()]:
		var target := Vector3(0.0, 0.0, -club.carry() * 0.85)
		var intent := AIGolfer.choose(from, target, 0.18, clear, false, 1.0, 7, club)
		var played := ShotIntent.CLUB_NAMES[intent.club]
		assert_str(played).override_failure_message(
			"handed a %s, played a %s" % [club.id, played]).is_equal(club.id)

		# And the shot it chose actually goes somewhere near the target when
		# flown with that club, which is the part the label alone would miss.
		var velocity := BallFlight.launch_velocity(intent.direction, intent.power, false, club)
		var arc := BallFlight.sample_arc(from, velocity, Vector3.ZERO, 0.18, 400, 0.05)
		var landing := arc[arc.size() - 1]
		var out := Vector2(landing.x, landing.z).length()
		assert_float(out).override_failure_message(
			"the %s was played to land %.1f m out for a %.1f m target"
			% [club.id, out, target.length()]).is_between(club.carry() * 0.45, club.carry() * 0.95)


func test_the_caddie_reaches_for_a_club_that_can_get_there() -> void:
	# Defense Range needs an AI golfer that picks its own club. Nothing should
	# ever be handed a club it cannot reach the target with.
	for metres in [8.0, 20.0, 35.0, 46.0, 60.0, 75.0, 200.0]:
		var club := AIGolfer.club_for_distance(metres)
		assert_float(club.carry()).override_failure_message(
			"reached for a %s at %.0f m" % [club.id, metres]).is_greater(
			minf(metres, ClubProfile.driver().carry()) * 0.95)
