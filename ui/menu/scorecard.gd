class_name Scorecard
extends Control
## Strokes against par, drawn rather than written.
##
## §2.4 makes the scorecard the only result in the game, so the first one a
## player ever sees is worth getting right. Par is a row of empty rings; each
## stroke fills one. Coming in on par fills the row exactly -- a shape you can
## read at a glance and across any language.
##
## Over par grows the row rather than turning it red. Nothing here scolds: a
## player who took five is shown five, in the same ink as a player who took
## three.

const DOT := 11.0
const GAP := 34.0

const PAR_INK := Color("ffffff")
const FILLED := Color("ffd46b")

var par := 3
var strokes := 0:
	set(value):
		strokes = value
		queue_redraw()
var shown := 0.0:
	set(value):
		shown = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if shown <= 0.01:
		return
	var slots := maxi(par, strokes)
	var width := float(slots - 1) * GAP
	# Bottom centre, and it has the strip to itself: the club selector used to run
	# along the bottom too and the card had to be lifted clear of it, which is
	# one of the things moving the selector into the corner bought back.
	var origin := Vector2(size.x * 0.5 - width * 0.5, size.y - 64.0)

	for i in slots:
		var at := origin + Vector2(float(i) * GAP, 0.0)
		var filled := i < strokes
		# Each dot lands in turn rather than all at once, so a finished hole
		# reads as a count being made.
		var appear := clampf(shown * float(slots) - float(i), 0.0, 1.0)
		if appear <= 0.0:
			continue
		if filled:
			draw_circle(at, DOT * appear, Color(FILLED, 0.95 * shown))
			draw_arc(at, DOT * 1.7 * appear, 0.0, TAU, 24, Color(FILLED, 0.25 * shown), 2.0, true)
		else:
			draw_arc(at, DOT * appear, 0.0, TAU, 24, Color(PAR_INK, 0.5 * shown), 2.5, true)
