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


# ------------------------------------------------------------ live guarding --
#
# The predicted arc is only the *airborne* part of the shot: BallFlight stops
# sampling at first ground contact, because that is where a closed-form model
# stops being true. So the trigger above catches a ball that flies off the
# course and misses one that lands in play and rolls off it -- which measurement
# showed to be most of them. A half-power shank never even leaves the ground
# high enough to cross the line in the air, and rested out of bounds untouched.
#
# So the archer also watches the ball itself. That is not a weaker guarantee
# than the prediction, it is a stronger one: the prediction can be wrong about
# where a ball goes, and a position cannot.


## The ball is near the edge and heading for it. Hold the draw so the player can
## see the archer commit before the arrow goes, rather than have the ball stop
## dead with no warning.
func watch(at: Vector3) -> void:
	if _acted or _cooldown_left > 0.0:
		return
	alerted = true
	_act_point = at


## The ball has left the course. Pin it at `at`, which the caller supplies as the
## last place it was still in play.
##
## Fires immediately rather than after a tell. There is nothing to warn about any
## more -- the shot is already gone, and the arrow arriving *is* the feedback.
## Pillar 2 asks that the player always know why a shot stopped, and a ball that
## stops the instant it crosses a line, with an arrow in it, says that clearly.
func intercept(at: Vector3) -> bool:
	if _acted or _cooldown_left > 0.0:
		return false
	_acted = true
	alerted = false
	_act_point = at
	_act_at = _elapsed
	_cooldown_left = profile.cooldown

	# Drawn from the stroke's own seed, so a replay of this round intercepts
	# identically. The salt keeps it independent of the in-flight draw, which
	# may already have been made for the same stroke.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s:intercept" % [_stroke_seed, id])
	_will_connect = rng.randf() < profile.accuracy_at(at, tier)

	_set_state(State.ACT)
	return true
