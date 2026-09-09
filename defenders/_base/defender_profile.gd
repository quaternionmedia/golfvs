class_name DefenderProfile
extends Resource
## What a sport is, as data (§6.1: "a new sport is content, not code").
##
## A zone it patrols, a tell, an action, and the cooldown and blind spot that
## make it beatable. Everything a defender does is decided by these fields plus
## a DifficultyTier, so two sports differ by their numbers and their animation,
## not by their code path.

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


func reach(tier: DifficultyTier) -> float:
	return zone_radius * maxf(0.0, tier.coverage)


## True when `point` is somewhere this defender could act on at all. Position
## only -- no velocity, no intent, nothing about how the ball got there.
func covers(point: Vector3, tier: DifficultyTier) -> bool:
	if point.y < zone_min_y or point.y > zone_max_y:
		return false
	var flat := Vector2(point.x - zone_centre.x, point.z - zone_centre.z)
	return flat.length() <= reach(tier)


## Chance of connecting at `point`: full in the middle of the zone, tailing to
## nothing at the rim. The falloff is the blind spot §3 requires, and it is what
## makes "curve so the lead is wrong" a real answer rather than a slogan.
func accuracy_at(point: Vector3, tier: DifficultyTier) -> float:
	if not covers(point, tier):
		return 0.0
	var flat := Vector2(point.x - zone_centre.x, point.z - zone_centre.z)
	var edge := maxf(0.001, reach(tier))
	var falloff := 1.0 - pow(flat.length() / edge, 2.0)
	return clampf(base_accuracy * tier.accuracy * falloff, 0.0, 1.0)


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
