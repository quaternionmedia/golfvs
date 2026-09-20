extends RefCounted
## The one way a test records a picture for the walkthrough (ADR-031).
##
## A picture the walkthrough shows is taken *by the test that asserts the
## behaviour in it*, from the real scene that assertion ran against, in the same
## execution -- not by a separate harness that instantiates the scene again and
## poses it (that is what `tools/shoot_range.gd` is, and why it is on its way
## out). The assertion is the regression protection; the picture is output.
## Recorded, never compared: a test that diffed images would fail on a font, or
## on the difference between a laptop's GPU and the runner's llvmpipe, and get
## switched off.
##
##     const Walkthrough := preload("res://tests/walkthrough/walkthrough.gd")
##     ...
##     await Walkthrough.capture(self, "the-first-thing-you-see", "opens-on-defence")
##
## The page id and the shot name are the registry's (`registry.gd`), which is
## how the picture and the page that embeds it can never disagree on a name.
##
## Headless, nothing is drawn -- the viewport texture is empty -- so this does
## nothing and says so, and the picture committed from the last run with a
## display stands. `test_walkthrough.gd` asserts every declared shot is there,
## and CI's walkthrough job deletes them all first and runs the suite under a
## virtual display, so "there" means "recorded by a run", not "left over".

const SHOTS_DIR := "res://walkthrough/shots"

## The range's camera eases toward its framing a little every frame, so a
## picture read on frame N is mid-blend and one read on frame N+3 is a
## different picture -- the first two recordings of the first run were taken
## from two different places. For a recording the camera is put where it is
## going: the range stops taking real frames, the game's golfer's clock is put
## back so it does not swing in the picture, and one frame is stepped by hand,
## long enough for the ease to clamp and the camera to arrive. Nothing then
## moves between this and the read-back. Call it on the range (`menu.range_`,
## or the range itself) before `capture`.
static func hold_still(here: Node) -> void:
	here.set_process(false)
	here._ai_beat = here.AI_ADDRESS
	here._process(0.35)

## Pictures are shrunk to this width. They are committed, so they are kept
## small; they illustrate, and the assertion beside them is the evidence.
const WIDTH := 768


static func capture(suite: Node, page: String, shot: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Let the scene the test built reach the screen before reading it back.
	await suite.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := suite.get_viewport().get_texture().get_image()
	var height := int(round(float(WIDTH) * image.get_height() / image.get_width()))
	image.resize(WIDTH, height, Image.INTERPOLATE_LANCZOS)
	var dir := "%s/%s" % [SHOTS_DIR, page]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/%s.png" % [dir, shot]
	var err := image.save_png(path)
	assert(err == OK, "walkthrough: could not write %s (%s)" % [path, error_string(err)])
