extends Node
## Renders the intro hole from fixed vantage points, and from two live states.
##
## A look change that nobody looks at is a guess. This is the cheapest way to
## put eyes on one without a person launching the game and walking around it.
##
## The last two shots are not static: one dials curve into the gesture so the
## spin dial is on screen, and one plays a shot off the course so the archer's
## interception can be caught mid-impact. Those are the two moments most likely
## to be wrong and least likely to be noticed, because neither exists at rest.
##
##   godot --path . --resolution 1280x720 res://tools/shoot_range.tscn
##
## Writes into user://shots/ and prints the absolute paths.

const SHOTS := [
	{"name": "1-attract", "eye": Vector3(0.0, 7.5, 15.0), "at": Vector3(2.0, 1.4, -44.0)},
	{"name": "2-mat", "eye": Vector3(0.0, 4.4, 9.0), "at": Vector3(3.0, 1.0, -22.0)},
	{"name": "3-down-range", "eye": Vector3(-2.0, 16.0, 6.0), "at": Vector3(0.0, 0.0, -50.0)},
	{"name": "4-tower", "eye": Vector3(6.0, 7.0, -18.0), "at": Vector3(22.0, 6.0, -30.0)},
	{"name": "5-far-pin", "eye": Vector3(2.0, 5.0, -52.0), "at": Vector3(10.0, 0.5, -70.0)},
]

var _range: Node3D


func _ready() -> void:
	_range = preload("res://holes/range/practice_range.tscn").instantiate()
	add_child(_range)
	await _shoot()
	get_tree().quit()


func _shoot() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	for i in 20:
		await get_tree().process_frame

	for shot in SHOTS:
		_range.set_process(false)
		_range.camera.global_transform = Transform3D(Basis.IDENTITY, shot["eye"]) \
			.looking_at(shot["at"], Vector3.UP)
		await _save(shot["name"])

	await _shoot_spin_dial()
	await _shoot_impact()


## The dial only exists while a finger is down, so the gesture has to be driven.
func _shoot_spin_dial() -> void:
	_range.set_process(false)
	_range._on_gesture_began()
	_range._on_aim_updated(Vector3(0.0, 0.0, -1.0), 0.85, -0.7)
	_range.camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(-3.5, 3.0, 6.5)) \
		.looking_at(Vector3(0.0, 0.4, -8.0), Vector3.UP)
	await _save("6-spin-dial")


## The interception, caught on the frame the arrow lands. Plays a shot far
## enough off line to leave the course, then steps physics until the archer
## acts.
func _shoot_impact() -> void:
	_range.set_process(true)
	_range.pin = 2
	_range._enter_aim()
	_range._on_gesture_began()
	_range._on_fired(
		Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(46.0)), 1.0, 0.0)

	var acted := false
	for i in 900:
		await get_tree().physics_frame
		for d in _range._defenders:
			if d.brain.state == DefenderBrain.State.ACT:
				acted = true
		if acted:
			break
	if not acted:
		print("  (the archer never acted -- nothing to photograph)")
		return

	# Two frames past the hit: the flash is gone and the rings are open.
	for i in 2:
		await get_tree().physics_frame
	_range.set_process(false)
	await _save("7-impact")


func _save(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "user://shots/%s.png" % name
	get_viewport().get_texture().get_image().save_png(path)
	print("  %s  ->  %s" % [name, ProjectSettings.globalize_path(path)])
