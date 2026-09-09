# GdUnit generated TestSuite
extends GdUnitTestSuite

## Three clubs that are actually three clubs.
##
## Until the range, `BallFlight` held one set of numbers for every full shot, so
## every stroke in the game was the same club wearing whichever name the record
## happened to store. These tests are what stops that quietly coming back: the
## thing worth asserting is not any particular carry but that the clubs are
## *separated*, that there are exactly three of them, and that every name the
## record can hold resolves back to a flight.


func test_the_clubs_reach_clearly_different_distances() -> void:
	# The whole point of having clubs. Two that reach within a few metres of each
	# other are one club with two labels.
	var putt := ClubProfile.putt().rolls()
	var short_ := ClubProfile.short_club().carry()
	var long_ := ClubProfile.long_club().carry()

	assert_float(putt).is_greater(4.0)
	assert_float(short_).is_greater(putt * 1.5)
	assert_float(long_).is_greater(short_ * 1.5)


func test_the_short_club_goes_up_and_the_long_one_goes_out() -> void:
	# A short club that launched like a long one would reach a near pin and run
	# straight through it.
	assert_float(ClubProfile.short_club().launch_deg) \
		.is_greater(ClubProfile.long_club().launch_deg)
	assert_float(ClubProfile.long_club().launch_deg).is_greater(0.0)


func test_the_long_club_bends_more() -> void:
	# In metres, not in the constant: a ball in the air longer bends further for
	# the same acceleration, so the numbers rise with the club to keep the
	# *shape* of a full-curve shot comparable between them.
	assert_float(ClubProfile.long_club().curve_accel) \
		.is_greater(ClubProfile.short_club().curve_accel)


func test_a_putt_rolls_and_cannot_be_shaped() -> void:
	var putt := ClubProfile.putt()
	assert_bool(putt.is_putter).is_true()
	assert_float(putt.launch_deg).is_equal(0.0)
	assert_float(putt.carry()).is_equal(0.0)
	assert_float(putt.rolls()).is_greater(0.0)
	# No shaping at all. A spin dial that could be turned on a putt would be a
	# control promising something the simulation does not do.
	assert_float(putt.curve_accel).is_equal(0.0)
	assert_float(putt.max_speed).is_less(ClubProfile.short_club().max_speed)


func test_there_are_exactly_three() -> void:
	# "Simplify to short, long and putt" is the decision, and a fourth appearing
	# quietly is the thing worth catching.
	assert_int(ClubProfile.all().size()).is_equal(3)
	assert_int(ShotIntent.CLUB_NAMES.size()).is_equal(3)


func test_every_club_the_schema_names_resolves() -> void:
	# `intent.club` is a frozen enum (RECORD_SCHEMA.md §2.1). A reader has to be
	# able to turn any of its names back into a flight, or a stored record
	# becomes unplayable.
	for name in ShotIntent.CLUB_NAMES:
		var club := ClubProfile.for_id(name)
		assert_str(club.id).is_equal(name)
		assert_str(ShotIntent.CLUB_NAMES[club.to_intent_club()]).is_equal(name)


func test_the_notation_letters_are_distinct() -> void:
	# §4.1 writes a club as its first letter. Two clubs sharing one would make
	# the notation ambiguous, and it is meant to be dictatable down a phone.
	var letters := {}
	for name in ShotIntent.CLUB_NAMES:
		letters[name.substr(0, 1).to_upper()] = true
	assert_int(letters.size()).is_equal(ShotIntent.CLUB_NAMES.size())


func test_the_flight_model_uses_the_club_it_is_given() -> void:
	var heading := Vector3.FORWARD
	var short_ := BallFlight.launch_velocity(heading, 1.0, false, ClubProfile.short_club())
	var long_ := BallFlight.launch_velocity(heading, 1.0, false, ClubProfile.long_club())
	assert_float(long_.length()).is_greater(short_.length())
	# And the short club leaves at a steeper angle, which is what stops it
	# running on.
	assert_float(short_.normalized().y).is_greater(long_.normalized().y)


func test_a_caller_that_names_no_club_still_gets_a_ball_flight() -> void:
	var plain := BallFlight.launch_velocity(Vector3.FORWARD, 1.0)
	var short_ := BallFlight.launch_velocity(Vector3.FORWARD, 1.0, false, ClubProfile.short_club())
	assert_vector(plain).is_equal(short_)
	assert_str(BallFlight.default_club().id).is_equal("short")


func test_asking_for_a_putt_gets_a_putt_whichever_way_you_ask() -> void:
	var by_flag := BallFlight.launch_velocity(Vector3.FORWARD, 1.0, true)
	var by_club := BallFlight.launch_velocity(Vector3.FORWARD, 1.0, false, ClubProfile.putt())
	assert_vector(by_flag).is_equal(by_club)
	assert_float(by_flag.y).is_equal(0.0)


# --------------------------------------------------------- the AI golfer -----

func test_the_ai_golfer_plays_the_club_it_was_handed() -> void:
	# It used to search with the default club whatever was actually in the
	# golfer's hands, so it solved for a flight the shot would not take and came
	# up short of everything by the ratio between the two.
	var clear := func(_arc: PackedVector3Array) -> bool: return false
	var from := Vector3(0.0, 0.35, 0.0)
	for club in [ClubProfile.short_club(), ClubProfile.long_club()]:
		var target := Vector3(0.0, 0.0, -club.carry() * 0.85)
		var intent := AIGolfer.choose(from, target, 0.18, clear, false, 1.0, 7, club)
		var played := ShotIntent.CLUB_NAMES[intent.club]
		assert_str(played).override_failure_message(
			"handed a %s, played a %s" % [club.id, played]).is_equal(club.id)

		var velocity := BallFlight.launch_velocity(intent.direction, intent.power, false, club)
		var arc := BallFlight.sample_arc(from, velocity, Vector3.ZERO, 0.18, 400, 0.05)
		var landing := arc[arc.size() - 1]
		var out := Vector2(landing.x, landing.z).length()
		assert_float(out).override_failure_message(
			"the %s was played to land %.1f m out for a %.1f m target"
			% [club.id, out, target.length()]).is_between(
			club.carry() * 0.45, club.carry() * 0.95)


func test_the_caddie_reaches_for_a_club_that_can_get_there() -> void:
	# Defense Range needs an AI golfer that picks its own club, and nothing
	# should be handed one it cannot reach the target with.
	assert_str(ClubProfile.for_distance(3.0).id).is_equal("putt")
	assert_str(ClubProfile.for_distance(18.0).id).is_equal("short")
	assert_str(ClubProfile.for_distance(60.0).id).is_equal("long")
	assert_str(ClubProfile.for_distance(500.0).id).is_equal("long")
