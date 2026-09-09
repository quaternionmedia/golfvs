extends Node
## Renders the first run from fixed vantage points, and from three live states.
##
## A look change that nobody looks at is a guess. This is the cheapest way to
## put eyes on one without a person launching the game and walking around it.
##
## It loads the **menu** rather than the range, which is the difference between
## photographing the game and photographing half of it: the club selector, the
## scorecard and the ghost are all on a flat layer the menu owns, so a tool that
## instantiated `practice_range.tscn` could never see the one control the game
## has. It did exactly that for four shots while claiming otherwise in a comment
## two lines from the `preload` that proved it wrong.
##
## The last three shots are not static: one dials curve into the gesture so the
## spin dial is on screen, one swings the orbit camera off the line of play, and
## one plays a shot off the course so the archer's interception can be caught
## mid-impact. Those are the moments most likely to be wrong and least likely to
## be noticed, because none of them exists at rest.
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

var _menu: Node
var _range: Node3D


func _ready() -> void:
	_menu = preload("res://ui/menu/main_menu.tscn").instantiate()
	add_child(_menu)
	_range = _menu.range_
	await _shoot()
	get_tree().quit()


func _shoot() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	for i in 20:
		await get_tree().process_frame
	# The flat layer fades up over its first second. Stepping it by hand rather
	# than waiting a number of frames keeps the tool from photographing a
	# half-faded selector on a slow machine and a solid one on a fast machine.
	for i in 20:
		_menu._process(0.1)

	for shot in SHOTS:
		_range.set_process(false)
		_range.camera.global_transform = Transform3D(Basis.IDENTITY, shot["eye"]) \
			.looking_at(shot["at"], Vector3.UP)
		await _save(shot["name"])

	await _shoot_spin_dial()
	await _shoot_orbit()
	await _shoot_swing()
	await _shoot_defending()
	await _shoot_impact()


## The whole flat layer at once: the club selector in its corner, and the spin
## dial mid-gesture. Neither exists at rest, so a static shot of the range shows
## neither the one control the game has nor the only reading it gives back.
func _shoot_spin_dial() -> void:
	_range.set_process(false)
	_range._on_gesture_began()
	_range._on_aim_updated(Vector3(0.0, 0.0, -1.0), 0.85, -0.7)
	_range.camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(-3.5, 3.0, 6.5)) \
		.looking_at(Vector3(0.0, 0.4, -8.0), Vector3.UP)
	await _save("6-spin-dial")


## The orbit, off the line of play. The point of the shot is that the framing
## underneath is unchanged -- still behind the ball, still holding the pin -- and
## only the angle onto it has moved. If this looks like a different camera rather
## than the same one from elsewhere, `CameraOrbit.apply` is doing too much.
func _shoot_orbit() -> void:
	_range.set_process(true)
	_range.pin = 1
	# The pin hands over its club on the way in, so the shot also shows the
	# selector reading something other than its opening putt.
	_range.set_club(_range.suggested_club_index())
	_range._enter_aim()
	_range._look.yaw = -0.85
	_range._look.pitch = 0.16
	_range._look.zoom = 0.8
	# Long enough for the camera easing to settle onto the orbited framing.
	for i in 60:
		await get_tree().process_frame
	_range.set_process(false)
	await _save("7-orbit")
	_range._look.recentre()


## The top of the backswing: the golfer's tell, and the one frame that proves the
## ball is genuinely being held rather than the animation being decorative.
func _shoot_swing() -> void:
	_range.set_process(false)
	_range.pin = 2
	_range.set_club(_range.suggested_club_index())
	_range._enter_aim()
	_range._golfer.aim = Vector3(0.12, 0.0, -1.0).normalized()
	_range._golfer.swing = GolferFigure.TOP_AT
	_range.camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(-4.2, 2.4, 5.0)) 		.looking_at(Vector3(0.0, 1.1, -6.0), Vector3.UP)
	await _save("9-backswing")


## Defending: over the archer's shoulder, bow drawn, with the golfer's own aim
## ribbon showing where the arrow goes. The point of the shot is that it is the
## same picture as the stroke -- a figure, a pull, and an honest preview -- taken
## from the other end of the hole.
func _shoot_defending() -> void:
	_range.set_process(true)
	# No contesting archer: this is the first run's own defence, played with the
	# archer on the rock (ADR-022). Photographing the version the player actually
	# meets matters more than photographing the one with more in it.
	_range.pin = 2
	_range.set_club(_range.suggested_club_index())
	_range.set_defending(true)
	_menu._side.defending = true
	_range._enter_aim()
	_range._play_the_games_shot()

	# Far enough into the flight that the ball is up in the archer's air.
	for i in 78:
		await get_tree().physics_frame
	# And the bow drawn at it, which is what the player would be looking at.
	var lead: Vector3 = _range.ball.global_position - _range.held().nock_at()
	lead.y = 0.0
	_range._on_aim_updated(lead.normalized(), 0.8, 0.0)
	_range.set_process(false)
	await _save("10-defending")
	_range._ribbon.hide_arc()
	_range.set_defending(false)
	_menu._side.defending = false


## The interception, caught on the frame the arrow lands. Plays a shot far
## enough off line to leave the course, then steps physics until the archer
## acts.
func _shoot_impact() -> void:
	_range.set_process(true)
	_range.pin = 2
	_range.club_index = 0
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
	await _save("8-impact")


func _save(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "user://shots/%s.png" % name
	get_viewport().get_texture().get_image().save_png(path)
	print("  %s  ->  %s" % [name, ProjectSettings.globalize_path(path)])
