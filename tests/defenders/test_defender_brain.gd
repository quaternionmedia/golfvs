# GdUnit generated TestSuite
extends GdUnitTestSuite

## The fairness rules of §3, as tests rather than as prose.
##
## "Defenders are fair" is the load-bearing claim of the whole defense design:
## §9 rates "defenders feel random or unfair" as a High risk, and the mitigation
## it names is the fairness rules plus determinism. Prose cannot enforce either.
## Each rule below is one test, and each one should fail loudly if a later sport
## or a difficulty pass quietly breaks it.

const DT := 0.05


func _arc(power: float, launch_from := Vector3(0.0, 0.2, 0.0),
		heading := Vector3(0.0, 0.0, -1.0), curve := 0.0) -> PackedVector3Array:
	var velocity := BallFlight.launch_velocity(heading, power)
	var accel := BallFlight.curve_acceleration(heading, curve)
	return BallFlight.sample_arc(launch_from, velocity, accel, 0.0, 400, DT)


## A shooter watching the middle of the corridor, where a full drive peaks.
func _shooter(tier := DifficultyTier.standard()) -> DefenderBrain:
	var arc := _arc(1.0)
	var apex := Vector3.ZERO
	for point in arc:
		if point.y > apex.y:
			apex = point
	var brain := DefenderBrain.new()
	brain.configure(DefenderProfile.skeet(apex + Vector3(6.0, 0.0, 0.0), apex), tier, "skeet_0")
	return brain


func _run(brain: DefenderBrain, arc: PackedVector3Array, stroke_seed := 12345) -> Array:
	## Steps the brain through a whole flight and returns the states it passed
	## through, in order, with repeats collapsed.
	brain.read_shot(arc, DT, stroke_seed)
	var seen := [brain.state]
	for i in arc.size():
		brain.advance(DT)
		if brain.state != seen[-1]:
			seen.append(brain.state)
	return seen


# ------------------------------------------------------- the state machine ---

func test_a_defender_telegraphs_before_it_acts() -> void:
	# Pillar 2, readable chaos: the player always knows why a shot was stopped.
	# A defender that went straight from idle to act would be exactly the
	# "feels random" failure §9 is worried about.
	var brain := _shooter()
	var states := _run(brain, _arc(1.0))
	assert_array(states).contains_exactly([
		DefenderBrain.State.IDLE,
		DefenderBrain.State.TELL,
		DefenderBrain.State.ACT,
		DefenderBrain.State.COOLDOWN,
	])


func test_the_tell_lasts_as_long_as_the_profile_promises() -> void:
	var brain := _shooter()
	var arc := _arc(1.0)
	brain.read_shot(arc, DT, 1)
	var tell := brain.profile.tell_for(brain.tier)
	var telling := 0.0
	for i in arc.size():
		brain.advance(DT)
		if brain.state == DefenderBrain.State.TELL:
			telling += DT
	assert_float(telling).is_equal_approx(tell, DT * 1.5)


func test_no_tier_can_shorten_the_tell_below_the_readable_floor() -> void:
	# Difficulty tuning touches reaction, accuracy and coverage -- and reaction
	# shortens the warning. A warning too short to read is not a warning, so the
	# floor is a hard one and not a guideline.
	var profile := DefenderProfile.skeet(Vector3.ZERO, Vector3.ZERO)
	var absurd := DifficultyTier.make(1000.0, 1.0, 1.0)
	assert_float(profile.tell_for(absurd)).is_equal(DefenderProfile.MIN_TELL)
	assert_float(profile.tell_for(DifficultyTier.ferocious())) \
		.is_greater_equal(DefenderProfile.MIN_TELL)


func test_a_defender_cannot_act_twice_without_cooling_down() -> void:
	var brain := _shooter()
	var arc := _arc(1.0)
	_run(brain, arc)
	assert_that(brain.state).is_equal(DefenderBrain.State.COOLDOWN)

	# The next lie arrives while it is still reloading.
	brain.rest()
	brain.read_shot(arc, DT, 999)
	assert_bool(brain.is_committed()).is_false()
	var fired := false
	for i in arc.size():
		fired = fired or brain.advance(DT)
	assert_bool(fired).is_false()


# ------------------------------------------------------- the golf counters ---

func test_a_low_shot_goes_under_the_shooter() -> void:
	# §3 gives skeet the counter "keep it low". That has to be a real property
	# of the zone, not a difficulty setting -- a putt must be untouchable by an
	# air defender at every tier.
	var brain := _shooter(DifficultyTier.ferocious())
	var putt := BallFlight.launch_velocity(Vector3(0.0, 0.0, -1.0), 1.0, true)
	var flat := BallFlight.sample_arc(Vector3(0.0, 0.2, 0.0), putt, Vector3.ZERO, 0.0, 400, DT)
	brain.read_shot(flat, DT, 1)
	assert_bool(brain.is_committed()).is_false()


func test_a_shot_that_peaks_outside_the_zone_is_not_reachable() -> void:
	var brain := _shooter()
	brain.read_shot(_arc(1.0), DT, 1)
	assert_bool(brain.is_committed()).is_true()

	# Struck across the corridor instead of down it, so the apex is nowhere near
	# the sky this shooter watches.
	var away := _shooter()
	away.read_shot(_arc(1.0, Vector3(0.0, 0.2, 0.0), Vector3(1.0, 0.0, 0.0)), DT, 1)
	assert_bool(away.is_committed()).is_false()


func test_curve_does_not_move_the_apex_out_of_the_zone_it_spoils_the_aim() -> void:
	# Measured, because the intuition is wrong. §3's second counter for skeet is
	# "curve so the lead is wrong", and at full curve the apex shifts about
	# three metres -- nothing like the eleven-metre zone radius. So curving does
	# not put the ball out of reach; it pushes the apex off the middle of the
	# zone, where accuracy_at() falls away. The counter is real, but it works
	# through the blind spot rather than through the zone edge.
	#
	# This matters for hole design: a hole that expects curve alone to beat a
	# shooter will play as unfair, because it very nearly does not.
	var brain := _shooter()
	var straight := _arc(1.0)
	var bent := _arc(1.0, Vector3(0.0, 0.2, 0.0), Vector3(0.0, 0.0, -1.0), 1.0)

	var apex_of := func(arc: PackedVector3Array) -> Vector3:
		var best := Vector3.ZERO
		for point in arc:
			if point.y > best.y:
				best = point
		return best

	var shift: float = apex_of.call(straight).distance_to(apex_of.call(bent))
	assert_float(shift).is_between(1.5, 6.0)

	var straight_chance: float = brain.profile.accuracy_at(apex_of.call(straight), brain.tier)
	var bent_chance: float = brain.profile.accuracy_at(apex_of.call(bent), brain.tier)
	assert_float(bent_chance).is_less(straight_chance)
	assert_float(bent_chance).is_greater(0.0)


func test_accuracy_falls_off_toward_the_rim_of_the_zone() -> void:
	# Every defender has a blind spot visible in its idle (§3). Here it is a
	# number: dead centre is the full chance, the rim is nothing.
	var profile := DefenderProfile.skeet(Vector3.ZERO, Vector3(0.0, 10.0, 0.0))
	var tier := DifficultyTier.standard()
	var centre := profile.accuracy_at(Vector3(0.0, 10.0, 0.0), tier)
	var midway := profile.accuracy_at(Vector3(5.5, 10.0, 0.0), tier)
	var rim := profile.accuracy_at(Vector3(10.9, 10.0, 0.0), tier)
	assert_float(centre).is_greater(midway)
	assert_float(midway).is_greater(rim)
	assert_float(profile.accuracy_at(Vector3(20.0, 10.0, 0.0), tier)).is_equal(0.0)


func test_a_harder_tier_never_widens_what_counts_as_low() -> void:
	# Coverage scales the radius, never the altitude band. Otherwise the "keep
	# it low" counter would erode as difficulty rose, and §3's promise that
	# tuning "never invents abilities" would be false.
	var profile := DefenderProfile.skeet(Vector3.ZERO, Vector3(0.0, 10.0, 0.0))
	var under := Vector3(0.0, profile.zone_min_y - 0.1, 0.0)
	for tier in [DifficultyTier.gentle(), DifficultyTier.standard(),
			DifficultyTier.keen(), DifficultyTier.ferocious()]:
		assert_bool(profile.covers(under, tier)).is_false()


# ---------------------------------------------------------- determinism ------

func test_the_same_seed_and_the_same_arc_give_the_same_verdict() -> void:
	# Without this, no record replays and every async mode is dead.
	var arc := _arc(1.0)
	var first := _shooter()
	first.read_shot(arc, DT, 8123481)
	for i in 20:
		var again := _shooter()
		again.read_shot(arc, DT, 8123481)
		assert_bool(again.will_connect()).is_equal(first.will_connect())
		assert_float(again.act_time()).is_equal(first.act_time())


func test_two_defenders_on_one_hole_roll_independently() -> void:
	# One shared draw would make a second defender a copy of the first: both hit
	# or both miss, forever. The seed is mixed with the defender id.
	var arc := _arc(1.0)
	var agreed := 0
	for stroke_seed in range(200):
		var one := _shooter()
		var other := _shooter()
		one.configure(one.profile, one.tier, "skeet_0")
		other.configure(other.profile, other.tier, "skeet_1")
		one.read_shot(arc, DT, stroke_seed)
		other.read_shot(arc, DT, stroke_seed)
		if one.will_connect() == other.will_connect():
			agreed += 1
	# Independent draws agree about as often as they disagree. Identical ones
	# would agree 200 times out of 200.
	assert_int(agreed).is_less(190)


func test_hit_rate_tracks_the_tier() -> void:
	var arc := _arc(1.0)
	var hits := {}
	for name in ["gentle", "ferocious"]:
		var tier: DifficultyTier = DifficultyTier.gentle() if name == "gentle" \
			else DifficultyTier.ferocious()
		var count := 0
		for stroke_seed in range(300):
			var brain := _shooter(tier)
			brain.read_shot(arc, DT, stroke_seed)
			if brain.will_connect():
				count += 1
		hits[name] = count
	assert_int(hits["ferocious"]).is_greater(hits["gentle"])


func test_the_brain_never_draws_from_the_global_rng() -> void:
	# A bare randf() anywhere in here would make the defender unreplayable. The
	# global generator's state must be untouched by reading a shot.
	seed(4242)
	var before := randi()
	seed(4242)
	var brain := _shooter()
	brain.read_shot(_arc(1.0), DT, 777)
	assert_int(randi()).is_equal(before)


# ---------------------------------------------------------- fairness ---------

func test_the_brain_cannot_be_told_what_the_player_intended() -> void:
	# §3: defenders "act on the ball's actual state, never on input before
	# release". That is enforced by the signature, not by discipline -- there is
	# no argument through which a ShotIntent, a club or a gesture could arrive.
	# If someone adds one, this test is what says no.
	var accepted := PackedStringArray()
	for entry in DefenderBrain.new().get_script().get_script_method_list():
		if entry["name"] in ["read_shot", "advance", "configure"]:
			for arg in entry["args"]:
				accepted.append(String(arg["name"]))
	assert_array(Array(accepted)).contains_exactly_in_any_order(
		["arc", "dt", "stroke_seed", "delta", "profile_", "tier_", "id_"])


func test_a_defender_beaten_for_speed_does_not_get_to_act_late() -> void:
	# If the ball reaches the zone before the tell could finish, the defender
	# has been beaten. It must not compensate by acting without a warning.
	var brain := _shooter()
	var arc := _arc(1.0)
	brain.read_shot(arc, DT, 1)
	var honest_time := brain.act_time()
	assert_float(honest_time).is_greater_equal(brain.profile.tell_for(brain.tier))
