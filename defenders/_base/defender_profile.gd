class_name DefenderProfile
extends Resource
## What a sport is, as data (§6.1: "a new sport is content, not code").
##
## A zone it patrols, a tell, an action, and the cooldown and blind spot that
## make it beatable. Everything a defender does is decided by these fields plus
## a DifficultyTier, so two sports differ by their numbers and their animation,
## not by their code path.

## What connecting actually does to the ball. Data, not a subclass: §3 lists
## twelve sports across four action types, and a new sport that deflects or
## captures should be a `.tres` rather than a new script (§6.1).
enum Action {
	KNOCK_DOWN,  ## Skeet. Horizontal motion stops; gravity does the rest.
	PIN,         ## Archery. The ball stops dead where the arrow reaches it.
	BLOCK,       ## Hockey, basketball. Reflected back along its own line.
	CAPTURE,     ## Baseball, soccer. Out of play; the golfer replays the stroke.
}

@export var action: Action = Action.KNOCK_DOWN

## Schema id, e.g. "skeet". Appears in records as the prefix of a defender id
## ("skeet_0") and in §4.1 notation, so it is frozen with the schema.
@export var sport := "skeet"

## Where the defender stands. Its zone is centred ahead of it, not on it.
@export var stand := Vector3.ZERO

## The patrolled volume: a vertical cylinder, because every zone in §3 is
## "air over here" or "ground over there" and a cylinder expresses both.
@export var zone_centre := Vector3.ZERO
@export var zone_radius := 12.0
## The altitude band the defender can reach. Skeet owns the air and cannot
## touch a ball that never leaves the ground -- which is precisely the counter
## §3 gives it ("keep it low").
@export var zone_min_y := 2.5
@export var zone_max_y := 40.0

## A boundary guard watches the edge of the course rather than a patch of it,
## so its trigger is "this shot is leaving" and not "this shot is overhead".
## `zone_centre` and `zone_radius` are unused when this is set.
@export var guards_bounds := false
## The playable region, as an XZ rectangle. Only meaningful for a bounds guard.
@export var bounds_centre := Vector3.ZERO
@export var bounds_extent := Vector2(40.0, 40.0)

## Seconds of visible warning before the action lands. ADR-004 makes defenders
## silent, so the tell is the only thing carrying the threat; it is a gameplay
## signal first and characterisation second.
##
## Measured against the flight, not chosen for comfort. A full-power shot is
## airborne for about 1.8 s and peaks at 0.9 s, so a tell of 0.9 s cannot fit
## before the apex at all -- and at the gentle tier, which *lengthens* the
## warning, it came to 1.29 s and the shooter simply never fired. That was the
## first thing running the hole end to end turned up.
##
## The tell is for legibility, not for reaction: by the time it appears the ball
## has already been struck and the player cannot answer it. The answer is played
## before the stroke, by reading where the shooter is standing. So it needs to
## be long enough to see and no longer.
@export var tell_lead := 0.45

## The pause between noticing a shot and being able to answer it, at tier
## reaction 1.0.
##
## A defender that acts on the frame it becomes able to is a tripwire. People
## are not: there is a beat between seeing and moving, it is roughly a quarter of
## a second, and it is most of what makes a human opponent feel like one. It is
## also what a good player learns to exploit -- a fast flat shot beats a slow
## defender, and that is a skill rather than a dice roll.
##
## Deterministic: the jitter around it is drawn from the stroke seed, so the same
## record replays with the same hesitation.
@export var reaction_time := 0.26
## How much the pause varies, as a fraction. Enough to stop it reading as a
## metronome.
@export var reaction_jitter := 0.3

## No tier may shorten a tell below this. A warning too short to read is not a
## warning, and "readable chaos" is Pillar 2.
const MIN_TELL := 0.35

## Seconds after acting during which the defender cannot act again. Every
## defender has one and it is visible in the idle (§3).
@export var cooldown := 2.5

## Chance of connecting at tier accuracy 1.0, when the ball passes dead through
## the middle of the zone. Falls off toward the rim -- the blind spot.
@export var base_accuracy := 0.7

## What lands in `after.events` when this defender acts. Readers ignore events
## they do not know (§2.1), so a new sport adding its own is not a schema
## change.
func event_acted() -> String:
	return "%s_fired" % sport


func event_hit() -> String:
	return "%s_hit" % sport


func event_missed() -> String:
	return "%s_miss" % sport


## The tell, shortened by reaction but never below MIN_TELL.
func tell_for(tier: DifficultyTier) -> float:
	return maxf(MIN_TELL, tell_lead / maxf(0.01, tier.reaction))


## How long this defender takes to register a shot, for a given stroke.
##
## `roll` is a 0..1 value the caller draws from the stroke's seed, so two
## replays of one record hesitate identically.
func reaction_for(tier: DifficultyTier, roll: float) -> float:
	var base := reaction_time / maxf(0.01, tier.reaction)
	return maxf(0.0, base * (1.0 + (roll * 2.0 - 1.0) * reaction_jitter))


func reach(tier: DifficultyTier) -> float:
	return zone_radius * maxf(0.0, tier.coverage)


## Is this point still on the course? Bounds guards only.
func in_bounds(point: Vector3) -> bool:
	return absf(point.x - bounds_centre.x) <= bounds_extent.x \
		and absf(point.z - bounds_centre.z) <= bounds_extent.y


## True when `point` is somewhere this defender could act on at all. Position
## only -- no velocity, no intent, nothing about how the ball got there.
func covers(point: Vector3, tier: DifficultyTier) -> bool:
	if point.y < zone_min_y or point.y > zone_max_y:
		return false
	if guards_bounds:
		# A boundary guard's business is the whole course, so anything inside
		# the altitude band is reachable. What it *acts* on is decided by
		# ArcherBrain, which looks for the ball leaving.
		return true
	var flat := Vector2(point.x - zone_centre.x, point.z - zone_centre.z)
	return flat.length() <= reach(tier)


## How well placed `point` is within the zone, on its own: 1 straight through the
## middle, tailing to 0 at the rim. This is the blind spot §3 requires, and it is
## what makes "curve so the lead is wrong" a real answer rather than a slogan.
##
## Separated from `accuracy_at` because a defender played *by a person* is scored
## on this and nothing else. The tier's accuracy is a stand-in for an opponent's
## aim; a human supplied their own, and rolling dice on top of it would be
## marking them down for a throw they did not make.
func falloff_at(point: Vector3, tier: DifficultyTier) -> float:
	if not covers(point, tier):
		return 0.0
	if guards_bounds:
		# No rim to fall off: a boundary has no middle, so there is no
		# geometric blind spot to model. A bounds guard is as good everywhere
		# along the edge as its tier makes it.
		return 1.0
	var flat := Vector2(point.x - zone_centre.x, point.z - zone_centre.z)
	var edge := maxf(0.001, reach(tier))
	return clampf(1.0 - pow(flat.length() / edge, 2.0), 0.0, 1.0)


## Chance of connecting at `point`, for a defender the game is playing.
func accuracy_at(point: Vector3, tier: DifficultyTier) -> float:
	return clampf(
		base_accuracy * tier.accuracy * falloff_at(point, tier), 0.0, 1.0)


## The same sport as `archer()`, doing the other half of its §3 job: "air, near
## green, arrow pins ball where hit". No boundary, a zone, and an apex trigger --
## which `ArcherBrain._target_index` already falls back to when `guards_bounds`
## is false, so an adversarial archer needed no new brain and never did.
##
## `zone_min_y` is the counter and the teacher at once. An archer that owns the
## air above 2.5 m cannot touch a ball that stays under it, so "keep it low" is a
## real answer -- and a putt, which never leaves the ground at all, is untouchable
## by construction. On a range whose first pin is a putt, that means the defender
## introduces itself exactly when the player starts flying the ball, and not one
## stroke sooner. Nothing has to say so.
static func contesting_archer(at: Vector3, zone := 11.0) -> DefenderProfile:
	var profile := DefenderProfile.new()
	profile.sport = "archery"
	profile.action = Action.PIN
	profile.stand = at
	profile.zone_centre = at
	profile.zone_radius = zone
	profile.zone_min_y = 2.5
	profile.zone_max_y = 45.0
	profile.tell_lead = 0.45
	profile.cooldown = 2.2
	profile.base_accuracy = 0.7
	return profile


## The 1.0 roster's first sport (§3): air, mid-fairway, fires at apex.
static func skeet(at: Vector3, watching: Vector3) -> DefenderProfile:
	var profile := DefenderProfile.new()
	profile.sport = "skeet"
	profile.stand = at
	profile.zone_centre = watching
	profile.zone_radius = 11.0
	# A ball under 2.5 m never enters the shooter's sky. That floor is the
	# whole counter: a punched low iron goes under the zone, and the player who
	# works that out has been taught something about golf, not about golfVs.
	profile.zone_min_y = 2.5
	profile.zone_max_y = 45.0
	profile.tell_lead = 0.45
	profile.cooldown = 2.5
	profile.base_accuracy = 0.72
	return profile


## §3's archer: air, near the green, "arrow pins ball where hit (stops dead, no
## penalty)". This factory builds the ADR-015 variant -- one that acts *only* on
## balls leaving the course, which makes it a safety net rather than an
## adversary. An ordinary adversarial archer is the same profile with
## `guards_bounds` false and a zone.
##
## `base_accuracy` is 1.0 on purpose. A safety net that silently fails one time
## in twenty is worse than no safety net, because the player cannot tell the
## difference between "the archer missed" and "the archer does not cover that".
static func archer(at: Vector3, centre: Vector3, extent: Vector2) -> DefenderProfile:
	var profile := DefenderProfile.new()
	profile.sport = "archery"
	profile.action = Action.PIN
	profile.stand = at
	profile.guards_bounds = true
	profile.bounds_centre = centre
	profile.bounds_extent = extent
	# Anything airborne at all, including a topped ball skidding for the trees.
	profile.zone_min_y = 0.0
	profile.zone_max_y = 60.0
	# Short: a ball on its way off the course does not give much warning, and a
	# tell that cannot fit is a defender that never acts (which is how skeet's
	# 0.9 s tell was found to be broken).
	profile.tell_lead = 0.4
	profile.cooldown = 1.2
	# Quicker than the roster average, and it has to be: it is watching an entire
	# boundary rather than a patch of sky, and a ball crossing the line does not
	# wait. Still a beat, though, and a low flat shank can still beat it.
	profile.reaction_time = 0.22
	profile.base_accuracy = 1.0
	return profile
