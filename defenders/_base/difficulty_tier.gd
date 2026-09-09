class_name DifficultyTier
extends Resource
## The three axes every sport scales on (§3).
##
## Difficulty tuning touches these and nothing else. A tier never invents an
## ability, never shortens a tell below the point where it can be read, and
## never lets a defender act outside its zone -- it only makes the defender
## quicker to commit, more likely to connect, and able to cover more of the zone
## it already had.
##
## Keeping the axes to three is what makes a new sport content rather than code:
## a designer tuning skeet and a designer tuning curling are turning the same
## three knobs, and a fairness argument made once holds for both.

## How much of the tell the defender spends deciding. Above 1.0 it commits
## later, which leaves the player less time to read it -- so this shortens the
## warning, and never removes it. DefenderProfile.MIN_TELL is the floor.
@export var reaction := 1.0

## Multiplies the profile's base chance of connecting once it has acted.
@export var accuracy := 1.0

## Multiplies the zone radius. A defender still cannot act outside its zone;
## coverage decides how much of the zone it can actually reach.
@export var coverage := 1.0


static func make(reaction_: float, accuracy_: float, coverage_: float) -> DifficultyTier:
	var tier := DifficultyTier.new()
	tier.reaction = reaction_
	tier.accuracy = accuracy_
	tier.coverage = coverage_
	return tier


## The four bundled tiers. Named rather than numbered so a record that stores
## one stays readable, and so adding a fifth is not a renumbering.
static func gentle() -> DifficultyTier:
	return make(0.7, 0.45, 0.8)


static func standard() -> DifficultyTier:
	return make(1.0, 0.7, 1.0)


static func keen() -> DifficultyTier:
	return make(1.25, 0.85, 1.15)


static func ferocious() -> DifficultyTier:
	return make(1.5, 0.95, 1.3)
