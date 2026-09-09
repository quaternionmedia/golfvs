extends Node
## Diagnostic: what actually happens to a ball hit off the course?
##
## Plays a spread of tee shots through the real hole and the real physics, and
## reports for each whether the archer committed, whether it fired, and where
## the ball came to rest. Answers one question: is the safety net reachable by
## the shots a player actually produces, or only by the one the demo scripts?

const DEG := [-55.0, -45.0, -35.0, -27.0, -20.0, 0.0, 20.0, 27.0, 35.0, 45.0, 55.0]
const POWERS := [0.45, 1.0]
const MAX_TICKS := 700

var _hole: Node3D


func _ready() -> void:
	_hole = preload("res://holes/intro/intro_hole.tscn").instantiate()
	add_child(_hole)
	await get_tree().process_frame
	await _sweep()
	get_tree().quit()


func _sweep() -> void:
	var profile := DefenderProfile.archer(
		_hole.ARCHER_STAND, _hole.BOUNDS_CENTRE, _hole.BOUNDS_EXTENT)
	print("bounds: x %.0f..%.0f   z %.0f..%.0f" % [
		_hole.BOUNDS_CENTRE.x - _hole.BOUNDS_EXTENT.x,
		_hole.BOUNDS_CENTRE.x + _hole.BOUNDS_EXTENT.x,
		_hole.BOUNDS_CENTRE.z - _hole.BOUNDS_EXTENT.y,
		_hole.BOUNDS_CENTRE.z + _hole.BOUNDS_EXTENT.y])
	print("")
	print("  aim   pwr | flies OB | archer | rests at            | lie     | verdict")
	print("  ----------+----------+--------+---------------------+---------+--------")

	var escaped := 0
	var tested := 0
	for power in POWERS:
		for degrees in DEG:
			tested += 1
			var heading := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(degrees))

			# Would the *airborne* arc leave the course? This is all the archer
			# can currently see: sample_arc stops at first ground contact.
			var arc := BallFlight.sample_arc(
				_hole.TEE_POS, BallFlight.launch_velocity(heading, power),
				Vector3.ZERO, _hole.BALL_RADIUS, 900, _hole.DEFENDER_DT)
			var flies_ob := false
			for p in arc:
				if not profile.in_bounds(p):
					flies_ob = true
					break

			_reset()
			_hole._on_gesture_began()
			_hole._on_fired(heading, power, 0.0)
			var fired := false
			var ticks := 0
			while _hole.state == _hole.State.FLIGHT and ticks < MAX_TICKS:
				await get_tree().physics_frame
				ticks += 1
				for d in _hole._defenders:
					if d.brain.state == DefenderBrain.State.ACT:
						fired = true

			var rest: Vector3 = _hole.ball.global_position
			var lie: String = _hole._lie_at(rest)
			var lost := lie == "ob"
			if lost:
				escaped += 1
			print("  %4.0f  %.2f | %-8s | %-6s | %-19s | %-7s | %s" % [
				degrees, power,
				"yes" if flies_ob else "no",
				"FIRED" if fired else "-",
				"(%.1f, %.1f)" % [rest.x, rest.z],
				lie,
				"LOST — no hindrance" if lost else "in play"])

	print("")
	print("  %d of %d shots came to rest out of bounds with nothing stopping them." % [
		escaped, tested])


func _reset() -> void:
	_hole.ball.freeze = true
	_hole.ball.global_position = _hole.TEE_POS
	_hole.ball.linear_velocity = Vector3.ZERO
	_hole.ball.angular_velocity = Vector3.ZERO
	_hole.strokes = 0
	_hole._record = null
	_hole._round.clear()
	for d in _hole._defenders:
		d.brain._cooldown_left = 0.0
		d.rest()
	_hole._enter_aim()
