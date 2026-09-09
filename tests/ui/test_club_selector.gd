# GdUnit generated TestSuite
extends GdUnitTestSuite

## The one control in the game, and the one that can lock the player out of it.
##
## The selector consumes presses so that a tap on it cannot also start a stroke.
## That is the right design and it shipped broken: an anchor preset left the
## control at the full size of the screen, so it consumed *every* press
## anywhere -- no stroke could be played at all -- and because it was also faded
## out there was nothing visible to blame it on.
##
## So the assertions here are mostly about size and routing rather than looks. A
## control that eats input has to be exactly as big as it appears, and the way
## to know is to measure it.


func _menu() -> Node:
	var scene := preload("res://ui/menu/main_menu.tscn")
	var menu := auto_free(scene.instantiate()) as Node
	add_child(menu)
	return menu


func _press_at(local: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = local
	return event


func test_it_covers_only_the_strip_it_draws() -> void:
	# The regression. A selector as tall as the screen swallows every press and
	# the game becomes unplayable with nothing on screen to explain why.
	var menu := _menu()
	await await_idle_frame()
	var selector: ClubSelector = menu._clubs
	var screen: Vector2 = menu._clubs.get_viewport_rect().size

	assert_float(selector.size.y).is_equal(ClubSelector.HEIGHT)
	assert_float(selector.size.y).is_less(screen.y * 0.25)
	# Pinned to the bottom edge, not floating in the middle of the play area.
	assert_float(selector.position.y + selector.size.y).is_equal_approx(screen.y, 1.0)


func test_the_play_area_is_not_covered() -> void:
	# Everything above the strip has to reach StrokeGesture. This is the same
	# fact as above, said the way the player experiences it.
	var menu := _menu()
	await await_idle_frame()
	var selector: ClubSelector = menu._clubs
	var screen: Vector2 = selector.get_viewport_rect().size
	var middle := Vector2(screen.x * 0.5, screen.y * 0.5)
	assert_bool(selector.get_global_rect().has_point(middle)) \
		.override_failure_message("the selector covers the middle of the screen") \
		.is_false()


func test_tapping_a_cell_chooses_that_club() -> void:
	var menu := _menu()
	await await_idle_frame()
	var selector: ClubSelector = menu._clubs
	var cells := selector._cells()
	assert_int(cells.size()).is_equal(ClubProfile.all().size())

	var chosen := []
	selector.club_chosen.connect(func(index: int) -> void: chosen.append(index))
	for i in cells.size():
		selector._gui_input(_press_at(cells[i].get_center()))
	assert_array(chosen).contains_exactly([0, 1, 2])


func test_choosing_a_club_reaches_the_range() -> void:
	# The selector only ever asks; the range decides. If the wiring is broken the
	# bars move and the ball does not.
	var menu := _menu()
	await await_idle_frame()
	var selector: ClubSelector = menu._clubs
	var cells := selector._cells()

	for i in cells.size():
		selector._gui_input(_press_at(cells[i].get_center()))
		assert_str(menu.range_.club().id) \
			.override_failure_message("tapped cell %d, range is holding a %s"
				% [i, menu.range_.club().id]) \
			.is_equal(ClubProfile.all()[i].id)


func test_the_bars_are_ordered_by_reach() -> void:
	# The bar *is* the label -- there is no word for "long" anywhere. If the
	# lengths did not match the clubs the control would be actively lying.
	var menu := _menu()
	await await_idle_frame()
	var selector: ClubSelector = menu._clubs
	for i in range(1, selector._reach.size()):
		assert_float(selector._reach[i]).is_less(selector._reach[i - 1])


func test_it_appears_without_waiting_for_a_stroke() -> void:
	# It used to fade in only once a stroke had been taken, which was circular:
	# the stroke could not be taken because the invisible selector was eating the
	# press that would have started it.
	#
	# The menu is stepped by hand with a known delta rather than by waiting a
	# number of frames. A test that counts frames measures the machine it is
	# running on -- this one failed only on a cold build, which is the worst way
	# to find that out.
	var menu := _menu()
	await await_idle_frame()
	assert_bool(menu._player_acted).is_false()
	for i in 20:
		menu._process(0.1)
	assert_float(menu._clubs.shown).is_greater(0.9)
	# And the card stays down: it counts pins made, and none have been.
	assert_float(menu._scorecard.shown).is_equal(0.0)


func test_the_range_and_the_selector_agree_on_what_is_in_hand() -> void:
	# The selector mirrors the range rather than keeping its own state. A pin
	# change hands over a club without anybody tapping, and the bars have to
	# follow.
	var menu := _menu()
	await await_idle_frame()
	menu.range_.pin = 2
	menu.range_.set_club(menu.range_.suggested_club_index())
	await await_idle_frame()
	assert_int(menu._clubs.selected).is_equal(menu.range_.club_index)
	assert_str(ClubProfile.all()[menu._clubs.selected].id).is_equal("long")
