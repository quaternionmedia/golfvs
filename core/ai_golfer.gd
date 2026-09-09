class_name AIGolfer
extends RefCounted
## A shot generator, not an opponent (§6.3).
##
## Given a lie and a target it produces a ShotIntent, by searching the same
## analytic flight model the player's aim ribbon draws and scoring each
## candidate on where it would finish. It has no privileged information: it sees
## the ball, the target and whatever the hole says is in the way, which is
## exactly what the player sees.
##
## Three things in 1.0 need one. Defense Range needs a golfer to defend against
## (§4 mode 6). The demo round needs a player that can actually get round the
## hole without shot numbers being hand-tuned into it -- which is how this came
## to be written, after a scripted golfer aimed at the flag four times and hit
## the same rock four times. And every hole needs a cheap answer to "is this
## reachable at all", which is the Scottish Rules par check (§4).
##
## Deterministic: the search is a fixed grid and the only randomness is the
## skill wobble, drawn from the seed it is given. The same golfer on the same
## lie with the same seed plays the same shot, so a Defense Range session is
## reproducible from its record like any other.

## Search grid. Coarse on purpose, twice over. A finer grid finds shots no human
## would play, and the point is a plausible golfer rather than a solver -- and
## the whole search runs between two physics ticks, so it has a budget. 5 x 8 x 3
## is 120 candidate arcs, which is a few milliseconds; the 7 x 12 x 5 grid this
## started as took long enough to stall a headless run.
const AIM_STEPS := 5
const AIM_SPREAD_DEG := 34.0
const POWER_STEPS := 8
const CURVE_STEPS := 3

## Sampling for the candidate arcs. Coarser than the defenders' 0.02 s: this is
## deciding where a shot lands, not when it is fired at.
const SEARCH_DT := 0.08
const SEARCH_SAMPLES := 130

## How much of the shot the ball is expected to do on the ground.
##
## BallFlight answers where a shot *lands*; the rigid body then bounces and
## rolls, and on a mown fairway it keeps going a long way. A golfer scoring
## candidates on the landing point alone therefore plays every full shot through
## the back of the green -- which is what the first run of the demo round did,
## finishing 38 m past a target 27 m away.
##
## So the search aims at a point short of the target, the way a golfer picks a
## landing spot rather than aiming at the flag. This is an estimate and it is
## deliberately crude: the honest fix is to score against the *simulated* rest
## position, which needs the stepped sim Lane B is for. Until then, a golfer
## that lands it short and runs it up is a much better wrong answer than one
## that airmails everything.
const ROLL_ALLOWANCE := 0.24


## The shot this golfer would play.
##
## `blocked` is called with a PackedVector3Array and answers whether that arc
## runs into the scenery. Passing it in rather than reaching for the hole keeps
## the golfer independent of any particular level's geometry.
##
## `skill` in 0..1. At 1.0 the best candidate is played exactly; below that the
## aim and power are nudged off it, so a weaker golfer misses in the ordinary
## ways rather than by picking a worse plan.
## `club` is the club actually in the golfer's hands. Passing the wrong one -- or
## none, and getting the default -- makes the search solve for a flight the shot
## will not take, and the golfer comes up short of everything by exactly the
## ratio between the two clubs. That is how this parameter came to exist.
static func choose(from: Vector3, target: Vector3, ground_y: float,
		blocked: Callable, putting: bool, skill: float, rng_seed: int,
		club: ClubProfile = null) -> ShotIntent:
	var held := club if club != null else (
		ClubProfile.putter() if putting else BallFlight.default_club())
	var to_target := Vector3(target.x - from.x, 0.0, target.z - from.z)
	if to_target.length() < 0.01:
		to_target = Vector3.FORWARD
	var straight := to_target.normalized()

	# A putt is already on the ground, so all of it is roll and the allowance
	# would double-count. Everything else gets landed short.
	var spot := target if putting else from + to_target * (1.0 - ROLL_ALLOWANCE)

	var best_power := 0.5
	var best_curve := 0.0
	var best_heading := straight
	var best_score := INF
	var found := false

	for a in AIM_STEPS:
		var offset := 0.0 if AIM_STEPS <= 1 \
			else lerpf(-AIM_SPREAD_DEG, AIM_SPREAD_DEG, float(a) / float(AIM_STEPS - 1))
		var heading := straight.rotated(Vector3.UP, deg_to_rad(offset))

		for p in POWER_STEPS:
			var power := lerpf(0.12, 1.0, float(p) / float(POWER_STEPS - 1))

			for c in CURVE_STEPS:
				var curve := 0.0 if putting else lerpf(-1.0, 1.0, float(c) / float(CURVE_STEPS - 1))
				var velocity := BallFlight.launch_velocity(heading, power, putting, held)
				var accel := BallFlight.curve_acceleration(heading, curve, held)
				var arc := BallFlight.sample_arc(
					from, velocity, accel, ground_y, SEARCH_SAMPLES, SEARCH_DT)
				if arc.size() < 2:
					continue
				if blocked.is_valid() and blocked.call(arc):
					continue

				var landing := arc[arc.size() - 1]
				var score := Vector2(landing.x - spot.x, landing.z - spot.z).length()
				# Among shots that finish equally close, prefer the straighter
				# one. A golfer that bends every ball for no reason reads as
				# broken even when it scores well.
				score += absf(curve) * 0.35
				if score < best_score:
					best_score = score
					best_power = power
					best_curve = curve
					best_heading = heading
					found = true

	if not found:
		# Every line is blocked. Play the straight shot and take the rock -- a
		# real golfer in that position is also just going to have to hit it.
		best_heading = straight
		best_power = 0.6
		best_curve = 0.0

	# Skill wobble. Applied to the shot, never to the choice: a weak golfer has
	# the right idea and executes it badly, which is what makes watching one
	# feel like golf rather than like a search failing.
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var slop := 1.0 - clampf(skill, 0.0, 1.0)
	var aim_error := rng.randfn(0.0, 4.5 * slop)
	var power_error := rng.randfn(0.0, 0.09 * slop)

	return ShotIntent.make(
		held.to_intent_club(),
		clampf(best_power + power_error, 0.05, 1.0),
		best_curve,
		best_heading.rotated(Vector3.UP, deg_to_rad(aim_error)))


## The club the golfer would reach for at a given distance, when nobody has
## handed it one. Defense Range needs this -- an AI golfer playing a hole picks
## its own club -- and it is the closest thing to a caddie the game has.
static func club_for_distance(metres: float) -> ClubProfile:
	for candidate in [ClubProfile.wedge(), ClubProfile.iron(), ClubProfile.driver()]:
		if metres <= candidate.carry() * 0.98:
			return candidate
	return ClubProfile.driver()
