class_name SideSwitch
extends Control
## Which end of the swing you are on, and the only way to change it.
##
## Pillar 5 says offense and defense are each a complete game and a pure defender
## never has to swing. That has been true on paper since the first draft and
## there has never been a way to *do* it -- §4's Defense Range is a whole mode at
## M5, and modes are expensive. This is the cheap version, and it earns its place
## by being the smallest thing that answers the question the pillar poses: can
## you play the other side at all?
##
## Two marks, no words, same language as the club selector in the opposite
## corner. The top one is a shot leaving -- the same arc the long club draws over
## there, because it is the same thing: a ball going out. The bottom one is that
## arc with a zone under it and a line reaching up into it, which is what a
## defender is: a patch of sky somebody owns and a shot crossing it.
##
## It mirrors the selector deliberately, in position, in size and in ink. Two
## controls that are the same kind of thing should look the same and sit
## symmetrically; a player who has worked out the corner on the left has already
## been taught how to read the corner on the right.

signal side_chosen(defending: bool)

const MARGIN := 18.0
## Finger-sized, exactly as the selector's rows are, and for the same reason:
## ADR-007 makes touch the reference input and subtle is a claim about ink.
const ROW := 36.0
const GAP := 2.0
const SPAN := 84.0
const RAIL := 7.0

const HEIGHT := ROW * 2.0 + GAP
const WIDTH := RAIL + SPAN + 12.0

const ARC_STEPS := 16
const PANEL := Color("000000")
const LIVE := Color("21d4ff")
const DIM := Color("2f7f97")
## The defending side is drawn in the threat amber, which is what the contesting
## archer's arrow is drawn in. The colour says which side you are picking before
## the shapes do.
const HELD := Color("ff7a2f")

var defending := false:
	set(value):
		defending = value
		queue_redraw()
var shown := 0.0:
	set(value):
		shown = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -(MARGIN + WIDTH)
	offset_right = -MARGIN
	offset_top = MARGIN
	offset_bottom = MARGIN + HEIGHT


## Two rows: golfing on top, defending below. Full width, finger tall, exactly
## like the selector's -- a control that consumes presses is exactly as big as it
## looks, which is the rule the corner opposite was rebuilt around.
func _cells() -> Array[Rect2]:
	var cells: Array[Rect2] = []
	if size.x <= 0.0:
		return cells
	for i in 2:
		cells.append(Rect2(0.0, (ROW + GAP) * float(i), size.x, ROW))
	return cells


func _gui_input(event: InputEvent) -> void:
	var pressed := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if not pressed:
		return
	var cells := _cells()
	for i in cells.size():
		if cells[i].has_point(event.position):
			# Emitted even when it is already the live side. The signal says
			# "this is the side I want", not "this is a change" -- a control that
			# silently does nothing on a press reads as broken.
			defending = i == 1
			side_chosen.emit(defending)
			accept_event()
			return
	accept_event()


func _flight(tee: Vector2, span: float, apex: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in ARC_STEPS + 1:
		var t := float(i) / float(ARC_STEPS)
		points.append(tee + Vector2(span * t, -4.0 * apex * t * (1.0 - t)))
	return points


func _draw() -> void:
	if shown <= 0.01:
		return
	var cells := _cells()
	if cells.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(PANEL, 0.9 * shown), true)

	for i in cells.size():
		var cell := cells[i]
		var live := (i == 1) == defending
		var ink := (HELD if i == 1 else LIVE) if live else DIM
		var alpha := (0.95 if live else 0.45) * shown
		var weight := 2.6 if live else 1.4
		var tee := Vector2(RAIL, cell.position.y + ROW * 0.74)

		# Both rows draw the same shot. What differs is what else is on the row,
		# which is the honest picture of the two sides: one range, one ball, and
		# a defender that is either yours or in your way.
		draw_polyline(_flight(tee, SPAN, ROW * 0.4), Color(ink, alpha), weight, true)

		if i == 1:
			# The zone, and the line reaching up into it. Drawn under the apex
			# because that is exactly where an archer at the midpoint meets a
			# full shot -- the mark is a diagram of the mechanic, not a badge.
			var mid := tee + Vector2(SPAN * 0.5, 0.0)
			draw_line(mid, mid - Vector2(0.0, ROW * 0.4), Color(ink, alpha * 0.75), weight)
			draw_arc(mid, ROW * 0.2, PI, TAU, 12, Color(ink, alpha * 0.6), weight, true)

		if live:
			draw_circle(tee, 3.0, Color(ink, 0.95 * shown))
