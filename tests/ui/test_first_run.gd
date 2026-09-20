# GdUnit generated TestSuite
extends GdUnitTestSuite

## What a new player is looking at, before they have touched anything.
##
## `main_menu.tscn` is the first run, and the range inside it is a component
## that opens as the golfer unless told otherwise. This suite pins the telling:
## the first run opens on **defence** (ADR-028), so the first thing a new player
## sees is the game's golfer addressing a ball and a bow in their own hands.
## That is a decision about the tutorial, and it lives in the tutorial's scene
## rather than in the range -- which is why the assertion instantiates the
## menu and not the range.

const Walkthrough := preload("res://tests/walkthrough/walkthrough.gd")


func _menu() -> Node:
	var scene := preload("res://ui/menu/main_menu.tscn")
	var menu := auto_free(scene.instantiate()) as Node
	add_child(menu)
	return menu


func test_the_first_run_opens_on_defence() -> void:
	var menu := _menu()
	await await_idle_frame()
	assert_bool(menu.range_.defending()) \
		.override_failure_message("the first run opened as the golfer; ADR-028 says it opens on defence") \
		.is_true()
	# And with somebody to be: the archer on the rock, not an empty bow.
	assert_object(menu.range_.held()).is_not_null()
	# The walkthrough's first picture is this frame, from this scene, once the
	# flat layer has faded up -- stepped by hand, as the selector suite does,
	# so a slow machine does not photograph a half-faded corner.
	for i in 20:
		menu._process(0.1)
	await Walkthrough.capture(self, "the-first-thing-you-see", "opens-on-defence")


func test_the_first_run_is_not_waiting_for_a_golfer_who_is_the_game() -> void:
	# Opening on defence in ATTRACT would leave the game's golfer standing over
	# the ball forever -- it only swings in AIM. See the range suite for why.
	var menu := _menu()
	await await_idle_frame()
	assert_int(menu.range_.state).is_equal(menu.range_.State.AIM)


func test_the_side_switch_agrees_with_the_range_from_the_first_frame() -> void:
	# The switch in the corner draws whichever side the range says it is on. If
	# the two disagree, the control shows the golfer while the drag draws a bow.
	var menu := _menu()
	await await_idle_frame()
	assert_bool(menu._side.defending).is_equal(menu.range_.defending())


func test_the_ghost_has_nothing_to_show_a_defender() -> void:
	# The ghost demonstrates a stroke. Opening on defence, the thing worth
	# watching is the game's golfer, and a ghost swinging over it would be two
	# lessons at once -- exactly what ADR-022 kept the first run clear of.
	var menu := _menu()
	# Past GHOST_DELAY, which is when the ghost would have resumed for a golfer.
	menu._process(menu.GHOST_DELAY + 0.5)
	assert_bool(menu._ghost._suppressed) \
		.override_failure_message("the ghost was demonstrating a stroke to a player holding a bow") \
		.is_true()
