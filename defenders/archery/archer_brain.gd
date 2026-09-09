class_name ArcherBrain
extends DefenderBrain
## The archer's trigger: the moment the ball leaves the course (ADR-015).
##
## Everything else — the Idle → Tell → Act → Cooldown machine, the seeded
## accuracy draw, the record entry — is the base class's and is unchanged. Only
## the question "which sample do I act on" differs, which is exactly the seam
## §6.1 wants a new sport to fit through.
##
## The archer is a *safety net*, and that is a deliberate departure from §3's
## framing of defenders as adversaries. The intro hole is the one hole that must
## not be failable; a beginner's characteristic disaster is spraying the ball
## off the map, and an out-of-bounds penalty is the harshest rule in golf
## arriving first. So the archer shoots exactly the shots that were about to be
## lost, and nothing else.
##
## It is also the most legible defender in the game, because of what it does
## *not* do. It never acts on a good shot. The first time it acts, the player
## learns where the course ends without being told — the world teaching, which
## is the cheapest layer in §2.6's hierarchy.


## The last sample still on the course before the ball leaves it.
##
## Pinning at the last in-bounds point rather than the first out-of-bounds one
## is the whole difference between a safety net and a formality: the ball has to
## come to rest somewhere playable, or the archer has saved the player from a
## penalty and left them unable to continue.
func _target_index(arc: PackedVector3Array) -> int:
	if not profile.guards_bounds:
		# Configured as an ordinary adversarial archer near the green. Fall back
		# to the apex trigger rather than silently never acting.
		return super._target_index(arc)

	for i in arc.size():
		if profile.in_bounds(arc[i]):
			continue
		# Leaving on the very first sample means the ball started out of bounds,
		# which is a bug upstream rather than a shot to save.
		if i == 0:
			return -1
		var pin := i - 1
		return pin if profile.covers(arc[pin], tier) else -1
	return -1


## True when this shot would have gone out of bounds and the archer is going to
## stop it. Used by the hole to decide whether to show the player anything at
## all, and by tests to say what the archer is for in one call.
func saves_this_shot() -> bool:
	return is_committed() and will_connect()
