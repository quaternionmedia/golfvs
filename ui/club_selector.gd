class_name ClubSelector
extends Control
## Three clubs, drawn as the distances they reach.
##
## The one control in the game, and it still has no words on it. Each club is a
## bar as long as that club is far: the putt is a stub, the short club a third of
## the strip, the long one the whole of it. A player who has never held a golf
## club can see which one goes further without being told, and a player who has
## can see it faster than they could read "wedge".
##
## It sits along the bottom of the screen because that is where a thumb already
## is, and it is deliberately large: ADR-007 makes touch the reference input, and
## a 40-pixel target is a menu with extra steps (Pillar 3).
##
## Presses inside it are marked handled, which is the whole reason it is a
## Control rather than something drawn into the world. StrokeGesture listens on
## `_unhandled_input`, so a tap that lands here never reaches it and cannot start
## a stroke -- no rectangle checks, no ordering, no special case in the gesture.

signal club_chosen(index: int)

const HEIGHT := 104.0
const PAD := 18.0
const GAP := 10.0

const INK := Color("9fd8e8")
const LIVE := Color("21d4ff")
const DIM := Color("2f7f97")
const PUTT_INK := Color("8dffa1")

## Reach of each club in metres, longest first, so the bars can be drawn to
## scale against each other. Filled from ClubProfile so a retuned club changes
## the picture without anyone editing this file.
var _reach: PackedFloat32Array = PackedFloat32Array()
var _ids: PackedStringArray = PackedStringArray()

var selected := 0:
	set(value):
		selected = value
		queue_redraw()
## Fades in with the rest of the flat layer, so an untouched attract screen is
## still just a range.
var shown := 0.0:
	set(value):
		shown = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for club in ClubProfile.all():
		_ids.append(club.id)
		# A putt has no carry, so its reach is roll. Without this the putt draws
		# as a bar of zero length and reads as a disabled control.
		_reach.append(club.rolls() if club.is_putter else club.carry())
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	custom_minimum_size = Vector2(0.0, HEIGHT)


func _cells() -> Array[Rect2]:
	var cells: Array[Rect2] = []
	var count := _ids.size()
	if count == 0:
		return cells
	var top := size.y - HEIGHT
	var usable := size.x - PAD * 2.0 - GAP * float(count - 1)
	var width := usable / float(count)
	for i in count:
		cells.append(Rect2(
			PAD + (width + GAP) * float(i), top + PAD,
			width, HEIGHT - PAD * 2.0))
	return cells


func _gui_input(event: InputEvent) -> void:
	var pressed := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if not pressed or shown < 0.5:
		return
	var at: Vector2 = event.position
	var cells := _cells()
	for i in cells.size():
		if cells[i].has_point(at):
			selected = i
			club_chosen.emit(i)
			accept_event()
			return
	# A press anywhere else along the strip is still the selector's, not a
	# stroke. Half the bar's height is dead space and a thumb finds it often.
	accept_event()


func _draw() -> void:
	if shown <= 0.01 or _ids.is_empty():
		return
	var cells := _cells()
	var longest := 0.0
	for r in _reach:
		longest = maxf(longest, r)
	if longest <= 0.0:
		return

	for i in cells.size():
		var cell := cells[i]
		var live := i == selected
		var putting := _ids[i] == "putt"
		var ink := (PUTT_INK if putting else LIVE) if live else DIM

		# The tray the bar sits in. Always drawn, so the three clubs read as a
		# set of choices rather than as one thing that appears when chosen.
		draw_rect(cell, Color(ink, 0.10 * shown), true)
		draw_rect(cell, Color(ink, (0.85 if live else 0.35) * shown), false, 2.5 if live else 1.5)

		# The bar: as long as the club is far. This is the whole label.
		var fraction := clampf(_reach[i] / longest, 0.08, 1.0)
		var bar := Rect2(
			cell.position + Vector2(10.0, cell.size.y * 0.5 - 5.0),
			Vector2((cell.size.x - 20.0) * fraction, 10.0))
		draw_rect(bar, Color(ink, (0.95 if live else 0.45) * shown), true)

		# A tick at the far end of the tray, so a short bar reads as "short of
		# the others" rather than as "not finished drawing".
		var tick_x := cell.position.x + cell.size.x - 10.0
		draw_line(
			Vector2(tick_x, cell.position.y + cell.size.y * 0.5 - 12.0),
			Vector2(tick_x, cell.position.y + cell.size.y * 0.5 + 12.0),
			Color(ink, 0.3 * shown), 1.5)
