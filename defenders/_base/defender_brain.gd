class_name DefenderBrain
extends RefCounted
## Idle → Tell → Act → Cooldown, for every sport (§6.3).
##
## Pure logic: no nodes, no scene tree, no clock of its own. The brain is
## stepped by whoever owns it and answers with a state and, once, a verdict.
## That is what makes a defender testable headless and replayable from a record
## -- an animation can lag a frame without changing what happened.
##
## **Fairness is structural here, not a convention.** `read_shot()` takes a
## sampled arc and a seed. It cannot see a ShotIntent, a gesture, a club or an
## input event, because none of them is in the signature. §3 requires that
## defenders "act on the ball's actual state, never on input before release";
## the arc is derived from the ball's position and velocity *at* release, so
## reading it is reading the ball, and there is no code path by which a defender
## could learn the shot early.
##
## The arc is the analytic flight (BallFlight), which is exact while the ball is
## airborne -- and airborne is the only time a skeet, a tennis player or a
## basketball blocker can act at all. A ground sport gets its own predicate; it
## does not get to see the future either.
##
## Randomness comes from the stroke's seed and nowhere else. `randf()` in here
## would make a defender unreplayable and take every async mode with it.

enum State { IDLE, TELL, ACT, COOLDOWN }

## Emitted as the state changes, for animation and audio to follow. The brain
## does not care whether anyone is listening.
signal state_changed(state: State)

var profile: DefenderProfile
var tier: DifficultyTier
var state := State.IDLE

## Defender id as it appears in a record: "skeet_0".
var id := "skeet_0"

## Seconds since the ball was struck.
var _elapsed := 0.0
## When this defender will act, in seconds after launch. Negative means it has
## read the shot and decided it cannot reach it.
var _act_at := -1.0
var _act_point := Vector3.ZERO
var _will_connect := false
var _acted := false
var _cooldown_left := 0.0


func configure(profile_: DefenderProfile, tier_: DifficultyTier, id_: String) -> void:
	profile = profile_
	tier = tier_
	id = id_


## Decide, once, what this shot means. Everything the defender will do is fixed
## here, which is what makes the tell honest: the commitment happens before the
## warning is shown, not after the player has stopped being able to react.
##
## `arc` is sampled at `dt` seconds per point.
func read_shot(arc: PackedVector3Array, dt: float, stroke_seed: int) -> void:
	_elapsed = 0.0
	_acted = false
	_act_at = -1.0
	_will_connect = false
	_set_state(State.COOLDOWN if _cooldown_left > 0.0 else State.IDLE)

	if _cooldown_left > 0.0 or arc.size() < 2:
		return

	# _target_index owns the whole question of whether and where this defender
	# acts. The base class deliberately does not second-guess it with a zone
	# test of its own: §3's twelve sports trigger on entirely different things
	# -- an apex, a crossing, a landing, a boundary -- and a shared predicate
	# that fitted all of them would fit none of them well.
	var index := _target_index(arc)
	if index < 0 or index >= arc.size():
		return

	var point := arc[index]
	var when := float(index) * dt
	# A defender that would have to act before its own tell could finish has
	# been beaten by a fast, flat shot. It does not get to act late, and it
	# does not get to shorten the warning -- it simply misses this one.
	if when < profile.tell_for(tier):
		return

	_act_at = when
	_act_point = point

	# One draw, from the stroke's seed mixed with the defender's id, so two
	# defenders on one hole roll independently and both replay identically.
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for(stroke_seed)
	_will_connect = rng.randf() < profile.accuracy_at(point, tier)


## Which sample this defender acts on, or -1 for "cannot reach this shot".
##
## The default is the apex, which is skeet's trigger and the one most air sports
## share. Override it for anything else -- a ground sport picks a crossing, and
## ArcherBrain picks the moment the ball leaves the course.
func _target_index(arc: PackedVector3Array) -> int:
	var best := -1
	var highest := -INF
	for i in arc.size():
		if arc[i].y > highest:
			highest = arc[i].y
			best = i
	if best < 0 or not profile.covers(arc[best], tier):
		return -1
	return best


func _seed_for(stroke_seed: int) -> int:
	return hash("%d:%s" % [stroke_seed, id])


## Step the brain. Returns true on the tick it acts, so the caller can apply the
## action's impulse -- §6.4 is explicit that a defender hit is an impulse from
## the action, never a rigid collision with an animated mesh.
func advance(delta: float) -> bool:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
		# Reloading is a state the player can see, and §3 requires the cooldown
		# to be visible in the idle. Leaving the state on ACT for the whole
		# cooldown -- which an earlier version of this function did -- hides the
		# one window in which the defender is harmless.
		_set_state(State.IDLE if _cooldown_left == 0.0 else State.COOLDOWN)
		return false

	_elapsed += delta
	if _act_at < 0.0:
		_set_state(State.IDLE)
		return false

	if _acted:
		return false

	if _elapsed >= _act_at:
		_acted = true
		_cooldown_left = profile.cooldown
		_set_state(State.ACT)
		return true

	_set_state(State.TELL if _elapsed >= _act_at - profile.tell_for(tier) else State.IDLE)
	return false


## Ready for the next lie. Cooldown deliberately survives -- a defender that
## just fired is still reloading when the golfer walks up to the ball.
func rest() -> void:
	_elapsed = 0.0
	_act_at = -1.0
	_acted = false
	_will_connect = false
	_set_state(State.COOLDOWN if _cooldown_left > 0.0 else State.IDLE)


func will_connect() -> bool:
	return _will_connect


func act_point() -> Vector3:
	return _act_point


func act_time() -> float:
	return _act_at


func is_committed() -> bool:
	return _act_at >= 0.0


## The events this defender contributes to `after.events`, in order.
func events() -> PackedStringArray:
	if not _acted:
		return PackedStringArray()
	return PackedStringArray([
		profile.event_acted(),
		profile.event_hit() if _will_connect else profile.event_missed(),
	])


## This defender's entry in `before.defenders[]`.
func to_record_entry() -> Dictionary:
	return {
		"id": id,
		"pos": Canonical.vec3_array(profile.stand),
		"state": ["idle", "tell", "act", "cooldown"][state],
		"cooldown": Canonical.quantize(_cooldown_left, Canonical.SCALAR_DECIMALS),
	}


func _set_state(next: State) -> void:
	if state == next:
		return
	state = next
	state_changed.emit(state)
