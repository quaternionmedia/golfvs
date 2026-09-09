extends Node
## Diagnostic: what actually happens to a ball hit off the range?
##
## Plays a spread of shots from the mat through the real physics and reports,
## for each, whether the archer committed, whether it fired, and where the ball
## came to rest. Answers one question: is the safety net reachable by the shots
## a player actually produces, or only by the one the demo scripts?

const DEG := [-55.0, -45.0, -35.0, -27.0, -20.0, 0.0, 20.0, 27.0, 35.0, 45.0, 55.0]
const POWERS := [0.45, 1.0]
const MAX_TICKS := 900

var _range: Node3D


func _ready() -> void:
	_range = preload("res://holes/range/practice_range.tscn").instantiate()
	add_child(_range)
	await get_tree().process_frame
	await _sweep()
	get_tree().quit()


func _sweep() -> void:
	var profile := DefenderProfile.archer(
		_range.ARCHER_STAND, _range.BOUNDS_CENTRE, _range.BOUNDS_EXTENT)
	print("bounds: x %.0f..%.0f   z %.0f..%.0f" % [
		_range.BOUNDS_CENTRE.x - _range.BOUNDS_EXTENT.x,
		_range.BOUNDS_CENTRE.x + _range.BOUNDS_EXTENT.x,
		_range.BOUNDS_CENTRE.z - _range.BOUNDS_EXTENT.y,
		_range.BOUNDS_CENTRE.z + _range.BOUNDS_EXTENT.y])
	print("")
	print("  club   aim   pwr | archer | rests at            | lie     | verdict")
	print("  -------------------+--------+---------------------+---------+--------")

	var escaped := 0
	var tested := 0
	# Every club, because they reach very different distances and the boundary
	# is only interesting to the ones that can get near it.
	for which in ClubProfile.all().size():
		for power in POWERS:
			for degrees in DEG:
				tested += 1
				_reset(which)
				var heading := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(degrees))
				_range._on_gesture_began()
				_range._on_fired(heading, power, 0.0)

				var fired := false
				var ticks := 0
				while _range.state == _range.State.FLIGHT and ticks < MAX_TICKS:
					await get_tree().physics_frame
					ticks += 1
					for d in _range._defenders:
						if d.brain.state == DefenderBrain.State.ACT:
							fired = true

				# From the record, not the ball: a settled stroke returns the
				# ball to the mat before anything can look at it, which is right
				# for a range and useless for measuring one.
				var rest: Vector3 = _range._round[-1].after_pos if not _range._round.is_empty() 					else _range.ball.global_position
				var lie: String = _range._lie_at(rest)
				var lost := lie == "ob"
				if lost:
					escaped += 1
				print("  %-6s %4.0f  %.2f | %-6s | %-19s | %-7s | %s" % [
					_range.club().id, degrees, power,
					"FIRED" if fired else "-",
					"(%.1f, %.1f)" % [rest.x, rest.z],
					lie,
					"LOST -- no hindrance" if lost else "in play"])

	print("")
	print("  %d of %d shots came to rest out of bounds with nothing stopping them." % [
		escaped, tested])


func _reset(which: int) -> void:
	# Sweep by *club*, not by pin: the boundary only cares how far a shot can be
	# hit, and that is the club's business.
	_range.pin = mini(which, _range.PINS.size() - 1)
	_range.club_index = which
	_range.strokes = 0
	_range._record = null
	_range._round.clear()
	for d in _range._defenders:
		d.brain._cooldown_left = 0.0
		d.rest()
	_range._enter_aim()
