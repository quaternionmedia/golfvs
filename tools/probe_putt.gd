extends Node
## How far does a putt actually roll? Calibrates ClubProfile.rolls(), which is
## an estimate standing in for a simulation nobody wants to run in a test.
var _range: Node3D
func _ready() -> void:
	_range = preload("res://holes/range/practice_range.tscn").instantiate()
	add_child(_range)
	await get_tree().process_frame
	print("  estimate: %.1f m" % ClubProfile.putt().rolls())
	for power in [0.4, 0.7, 1.0]:
		_range.pin = 0
		_range.club_index = 2
		_range.strokes = 0
		_range._record = null
		_range._round.clear()
		for d in _range._defenders:
			d.brain._cooldown_left = 0.0
			d.rest()
		_range._enter_aim()
		_range._on_gesture_began()
		_range._on_fired(Vector3(0.0, 0.0, -1.0), power, 0.0)
		var ticks := 0
		while _range.state == _range.State.FLIGHT and ticks < 900:
			await get_tree().physics_frame
			ticks += 1
		var rest: Vector3 = _range._round[-1].after_pos if not _range._round.is_empty() else Vector3.ZERO
		print("  power %.2f -> rolled %.1f m" % [power, Vector2(rest.x, rest.z).length()])
	get_tree().quit()
