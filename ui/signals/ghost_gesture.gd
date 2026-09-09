class_name GhostGesture
extends Control
## A hand that isn't there, doing the thing you should do.
##
## The cheapest way to teach a gesture is to perform it. This draws a looping
## ghost of the stroke, pinned to the ball's position on screen rather than
## parked in a corner of the UI, so the demonstration happens where the action
## has to happen.
##
## It yields immediately and completely: the first frame the player touches the
## screen it fades out, and it does not come back while they are still trying.
## A demo that keeps playing over the top of a player's own attempt stops being
## help and becomes interference.

enum Pattern { PULL, PULL_CURVE }

const CYCLE := 2.9
const PULL_PX := 104.0
const CURVE_PX := 62.0
const TRAIL := 22

const INK := Color("eaf7ff")
const CURVE_INK := Color("9ce8ff")

@export var pattern := Pattern.PULL

var anchor := Vector2.ZERO

var _t := 0.0
var _trail: Array[Vector2] = []
var _fade := 0.0
var _suppressed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


## Called when the player takes over. The ghost stops teaching and stays quiet
## until whoever owns it decides the lesson is worth repeating.
func suppress() -> void:
	_suppressed = true


func resume() -> void:
	if not _suppressed:
		return
	_suppressed = false
	_t = 0.0
	_trail.clear()


func _process(delta: float) -> void:
	var target := 0.0 if _suppressed else 1.0
	_fade = move_toward(_fade, target, delta * (4.0 if _suppressed else 1.6))
	if _fade <= 0.001:
		queue_redraw()
		return

	_t = fposmod(_t + delta / CYCLE, 1.0)
	_trail.push_front(anchor + _head_offset(_t) * _room_below())
	while _trail.size() > TRAIL:
		_trail.pop_back()
	queue_redraw()


## The gesture, as a function of loop position: settle, pull back, slide across
## if this lesson is about curve, hold so the shape is readable, then release.
func _head_offset(t: float) -> Vector2:
	var pull := 0.0
	var across := 0.0
	if t < 0.12:
		pull = 0.0
	elif t < 0.46:
		pull = ease_out(inverse_lerp(0.12, 0.46, t))
	else:
		pull = 1.0

	if pattern == Pattern.PULL_CURVE:
		if t >= 0.46 and t < 0.68:
			across = ease_out(inverse_lerp(0.46, 0.68, t))
		elif t >= 0.68:
			across = 1.0

	# Screen y grows downward, so pulling "back" toward the player is +y.
	return Vector2(across * CURVE_PX, pull * PULL_PX)


## A golf camera keeps the ball low in frame, which is right, and leaves the
## demonstration little room to pull back into. Rather than let the ghost run
## off the bottom of the screen, shrink the whole gesture to whatever room there
## is: a smaller version of the right motion still reads, a clipped one does not.
func _room_below() -> float:
	var room := size.y - anchor.y - 28.0
	if room >= PULL_PX:
		return 1.0
	return clampf(room / PULL_PX, 0.45, 1.0)


static func ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 2.6)


func _draw() -> void:
	if _fade <= 0.001 or _trail.is_empty():
		return

	# Released: the head is gone and a ring leaves the ball. This is the only
	# part of the loop that says "let go", so it gets the whole beat to itself.
	var releasing := _t > 0.86
	var release_t := inverse_lerp(0.86, 1.0, _t) if releasing else 0.0

	var tint := CURVE_INK if pattern == Pattern.PULL_CURVE else INK

	if not releasing:
		for i in _trail.size():
			var k := 1.0 - float(i) / float(_trail.size())
			var r := 2.0 + 5.0 * k
			draw_circle(_trail[i], r, Color(tint, 0.30 * k * k * _fade))
		var head: Vector2 = _trail[0]
		draw_circle(head, 16.0, Color(tint, 0.16 * _fade))
		draw_circle(head, 9.0, Color(tint, 0.85 * _fade))
		# The line back to the ball is the thing being set: length is power,
		# offset is shape.
		draw_line(anchor, head, Color(tint, 0.30 * _fade), 2.0, true)
	else:
		var radius := 10.0 + 46.0 * ease_out(release_t)
		draw_arc(anchor, radius, 0.0, TAU, 40, Color(tint, (1.0 - release_t) * 0.8 * _fade), 3.0, true)

	draw_circle(anchor, 5.0, Color(tint, 0.55 * _fade))
