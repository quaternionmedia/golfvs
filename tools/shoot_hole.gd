extends Node
## Renders the intro hole from a few fixed vantage points and saves PNGs.
##
## A look change that nobody looks at is a guess. This is the cheapest way to
## put eyes on one without a person having to launch the game and walk around
## it, and the vantage points are the ones a player actually gets: the attract
## drift, the tee address, the approach, and the putt.
##
##   godot --path . --resolution 1280x720 res://tools/shoot_hole.tscn
##
## Writes into user://shots/ and prints the absolute paths.

const SHOTS := [
	{"name": "1-attract", "eye": Vector3(0.0, 6.5, 13.0), "at": Vector3(2.0, 1.4, -34.0)},
	{"name": "2-tee", "eye": Vector3(0.0, 3.9, 8.0), "at": Vector3(0.0, 1.0, -20.0)},
	{"name": "3-spire", "eye": Vector3(-6.0, 5.0, -22.0), "at": Vector3(2.2, 5.0, -38.0)},
	{"name": "4-approach", "eye": Vector3(-2.0, 4.6, -30.0), "at": Vector3(8.0, 1.0, -54.0)},
	{"name": "5-green", "eye": Vector3(4.0, 3.0, -48.0), "at": Vector3(9.0, 0.4, -57.0)},
	{"name": "6-boundary", "eye": Vector3(-14.0, 9.0, -6.0), "at": Vector3(-4.0, 0.0, -30.0)},
]

var _hole: Node3D


func _ready() -> void:
	_hole = preload("res://holes/intro/intro_hole.tscn").instantiate()
	add_child(_hole)
	await _shoot()
	get_tree().quit()


func _shoot() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	# Let the hole build, the environment settle and the glow buffer fill.
	for i in 20:
		await get_tree().process_frame

	for shot in SHOTS:
		# The hole drives its own camera every frame, so it has to stop before
		# the camera will stay where it is put.
		_hole.set_process(false)
		_hole.camera.global_transform = Transform3D(Basis.IDENTITY, shot["eye"]) \
			.looking_at(shot["at"], Vector3.UP)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw

		var image := get_viewport().get_texture().get_image()
		var path: String = "user://shots/%s.png" % shot["name"]
		image.save_png(path)
		print("  %s  ->  %s" % [shot["name"], ProjectSettings.globalize_path(path)])
