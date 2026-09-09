extends Node
## Diagnostic: does each club actually reach the pin it is given?
##
## The pins are placed a little short of each club's analytic carry, so a full
## swing is slightly too much and the player has to find the shot. That is a
## relationship between two numbers in different files, which is exactly the
## kind of thing that drifts -- so it gets measured rather than assumed.

const POWERS := [0.6, 0.75, 0.9, 1.0]
const MAX_TICKS := 900

var _range: Node3D


func _ready() -> void:
	_range = preload("res://holes/range/practice_range.tscn").instantiate()
	add_child(_range)
	await get_tree().process_frame
	await _run()
	get_tree().quit()


func _run() -> void:
	print("  club   | carry | pin at | power -> rest distance (straight at the pin)")
	print("  -------+-------+--------+---------------------------------------------")
	for which in _range.PINS.size():
		var spec: Dictionary = _range.PINS[which]
		var at: Vector3 = spec["at"]
		var pin_dist := Vector2(at.x, at.z).length()
		var club: ClubProfile = ClubProfile.for_id(String(spec["club"]))
		var line := "  %-6s | %5.1f | %6.1f | " % [club.id, club.carry(), pin_dist]

		for power in POWERS:
			_reset(which)
			var heading := Vector3(at.x, 0.0, at.z).normalized()
			_range._on_gesture_began()
			_range._on_fired(heading, power, 0.0)
			var ticks := 0
			while _range.state == _range.State.FLIGHT and ticks < MAX_TICKS:
				await get_tree().physics_frame
				ticks += 1
			# Read from the record, not from the ball: a settled stroke returns
			# the ball to the mat before anything else can look at it, which is
			# right for a range and useless for measuring one.
			var rest: Vector3 = _range._round[-1].after_pos if not _range._round.is_empty() 				else _range.ball.global_position
			var made: bool = Vector2(rest.x - at.x, rest.z - at.z).length() <= float(spec["radius"])
			line += "%.2f:%5.1f%s  " % [
				power, Vector2(rest.x, rest.z).length(), "*" if made else " "]
		print(line)
	print("")
	print("  * = on the green. A club wants at least one power that makes its pin,")
	print("    and full power should overshoot, or there is nothing to judge.")


func _reset(which: int) -> void:
	_range.pin = which
	_range.strokes = 0
	_range._record = null
	_range._round.clear()
	for d in _range._defenders:
		d.brain._cooldown_left = 0.0
		d.rest()
	_range._enter_aim()
