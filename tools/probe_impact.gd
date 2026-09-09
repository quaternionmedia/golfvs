extends Node
## Diagnostic: does the ball behave like something that was hit?
##
## The previous pin assigned the ball a velocity and a position, so it stopped
## in the air on the frame the archer acted -- zero travel, zero tumble, no
## settle. This measures the three numbers that distinguish a struck ball from a
## switched-off one: how far it goes after the arrow lands, how long it takes to
## come to rest, and how fast it is spinning while it does.

const SHOTS := [40.0, 46.0, 52.0, 58.0]
const MAX_TICKS := 900

var _range: Node3D


func _ready() -> void:
	_range = preload("res://holes/range/practice_range.tscn").instantiate()
	add_child(_range)
	await get_tree().process_frame
	await _run()
	get_tree().quit()


func _run() -> void:
	print("  aim | speed at hit | travel after | settle | spin | rest")
	print("  ----+--------------+--------------+--------+------+-----")
	for degrees in SHOTS:
		_reset()
		_range._on_gesture_began()
		_range._on_fired(
			Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(degrees)), 1.0, 0.0)

		var hit_at := Vector3.ZERO
		var speed_at_hit := 0.0
		var spin_after := 0.0
		var ticks_after := 0
		var struck := false
		var ticks := 0
		while _range.state == _range.State.FLIGHT and ticks < MAX_TICKS:
			var before: float = _range.ball.linear_velocity.length()
			var was: Vector3 = _range.ball.global_position
			await get_tree().physics_frame
			ticks += 1
			if not struck:
				for d in _range._defenders:
					if d.brain.state == DefenderBrain.State.ACT:
						struck = true
						hit_at = was
						speed_at_hit = before
						spin_after = _range.ball.angular_velocity.length()
			else:
				ticks_after += 1

		if not struck:
			print("  %3.0f | never struck" % degrees)
			continue
		var rest: Vector3 = _range.ball.global_position
		print("  %3.0f | %8.1f m/s | %9.2f m | %5.2f s | %4.0f | (%.1f, %.1f)" % [
			degrees, speed_at_hit, hit_at.distance_to(rest),
			float(ticks_after) / 60.0, spin_after, rest.x, rest.z])


func _reset() -> void:
	_range.pin = 2
	_range.strokes = 0
	_range._record = null
	_range._round.clear()
	for d in _range._defenders:
		d.brain._cooldown_left = 0.0
		d.rest()
	_range._enter_aim()
