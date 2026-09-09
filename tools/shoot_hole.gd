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
##   godot --path . --resolution 1280x720 res://tools/shoot_hole.tscn
##
## Writes into user://shots/ and prints the absolute paths.

const SHOTS := [
	{"name": "1-attract", "eye": Vector3(0.0, 7.5, 15.0), "at": Vector3(3.0, 1.4, -46.0)},
	{"name": "2-tee", "eye": Vector3(0.0, 4.4, 9.0), "at": Vector3(0.0, 1.0, -26.0)},
	{"name": "3-spire", "eye": Vector3(-8.0, 6.0, -30.0), "at": Vector3(2.2, 5.5, -51.0)},
	{"name": "4-green", "eye": Vector3(5.0, 3.4, -64.0), "at": Vector3(11.0, 0.4, -77.0)},
	{"name": "5-boundary", "eye": Vector3(-17.0, 11.0, -8.0), "at": Vector3(-4.0, 0.0, -40.0)},
]

var _hole: Node3D


func _ready() -> void:
	_hole = preload("res://holes/intro/intro_hole.tscn").instantiate()
	add_child(_hole)
	await _shoot()
	get_tree().quit()


func _shoot() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	for i in 20:
		await get_tree().process_frame

	for shot in SHOTS:
		_hole.set_process(false)
		_hole.camera.global_transform = Transform3D(Basis.IDENTITY, shot["eye"]) \
			.looking_at(shot["at"], Vector3.UP)
		await _save(shot["name"])

	await _shoot_spin_dial()
	await _shoot_impact()


## The dial only exists while a finger is down, so the gesture has to be driven.
func _shoot_spin_dial() -> void:
	_hole.set_process(false)
	_hole._on_gesture_began()
	_hole._on_aim_updated(Vector3(0.0, 0.0, -1.0), 0.85, -0.7)
	_hole.camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(-3.5, 3.0, 6.5)) \
		.looking_at(Vector3(0.0, 0.4, -8.0), Vector3.UP)
	await _save("6-spin-dial")


## The interception, caught on the frame the arrow lands. Plays a shot far
## enough off line to leave the course, then steps physics until the archer
## acts.
func _shoot_impact() -> void:
	_hole.set_process(true)
	_hole._on_gesture_began()
	_hole._on_fired(
		Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(46.0)), 1.0, 0.0)

	var acted := false
	for i in 900:
		await get_tree().physics_frame
		for d in _hole._defenders:
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
	_hole.set_process(false)
	await _save("7-impact")


func _save(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "user://shots/%s.png" % name
	get_viewport().get_texture().get_image().save_png(path)
	print("  %s  ->  %s" % [name, ProjectSettings.globalize_path(path)])
