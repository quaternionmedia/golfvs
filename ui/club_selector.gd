class_name ClubSelector
extends Control
## Three clubs, drawn as the shots they hit.
##
## The one control in the game, and it still has no words on it. Each club is its
## own trajectory: the putt is a flat line because it rolls, the short club a
## small steep arc, the long club a long shallow one. Both halves of that picture
## come from the club itself -- the span from `carry()`, the height from the
## `launch_deg` the ball is genuinely struck at -- so a retuned club redraws
## itself and cannot end up illustrating something it no longer does.
##
## It began as three flat bars, one per club, each as long as the club was far.
## That was legible and it threw away the more useful half of the difference: the
## short club and the long club differ in *shape* long before they differ in
## reach, and a beginner who needs to get a ball over something has no way to
## read "goes up steeply" off a horizontal line. A player who has never held a
## golf club can see which shot clears a lip and which one runs, without being
## told, and faster than they could read "wedge".
##
## It sits in the **top-left corner**, quietly. It began as a full-width bar
## along the bottom, sized for a thumb and drawn like one -- three filled trays
## with outlines, ticks and a bar inside each. That was legible and it was the
## loudest thing on the screen, which is the wrong ranking: the range is the
## thing being looked at and the club in hand is a note in the margin. Ranked the
## other way round, it reads as a menu the game is asking you to deal with first
## (Pillar 3). The corner is where a note in the margin goes, and it is the one
## part of the frame nothing else in the game draws into -- the scorecard is
## bottom-centre, the ghost is on the ball, and the ball is never up there.
##
## Subtle is a claim about *ink*, not about the target. The rows are still a
## finger tall (ADR-007 makes touch the reference input) and only what is drawn
## inside them got quiet: no trays, no ticks, thin strokes, and the two clubs not
## in hand at about a third of the live one's alpha.
##
## The one thing it does draw solid is its own background. Everything else in the
## game is a line over the range, and this panel is the exception, because at a
## third alpha over a lit deck the two clubs not in hand were a guess rather than
## a reading -- a control quiet enough to be unreadable has been made quiet in the
## wrong place. Blacking out only the corner it occupies buys the contrast back
## without putting a bar across the frame.
##
## Presses inside it are marked handled, which is the whole reason it is a
## Control rather than something drawn into the world. StrokeGesture listens on
## `_unhandled_input`, so a tap that lands here never reaches it and cannot start
## a stroke -- no rectangle checks, no ordering, no special case in the gesture.
##
## That cuts both ways, and it shipped broken once. `set_anchors_preset` left the
## control at the full size of the screen, so a selector that stopped presses
## stopped *every* press: no stroke could be played anywhere, and because it was
## also faded out there was nothing on screen to blame. The rect is set by
## explicit offsets now, and `test_club_selector.gd` asserts it stays a corner --
## a control that consumes input has to be exactly as big as it looks.

signal club_chosen(index: int)

## Clear of the screen edge, and of a rounded corner or a notch.
const MARGIN := 18.0
## One row per club. As tall as a fingertip and nowhere near as tall as the
## ink drawn in it -- the two numbers are allowed to disagree, and the reason
## the strip could shrink at all is that only one of them had to stay big.
const ROW := 36.0
const GAP := 2.0
## The long club's rule at full length. Everything else is a fraction of it.
const REACH_PX := 116.0
## Left of the rules: the rail they all start from, and the gutter it sits in.
const RAIL := 7.0

const HEIGHT := ROW * 3.0 + GAP * 2.0
const WIDTH := RAIL + REACH_PX + 12.0

## Segments per arc. Sixteen is past the point where another one is visible at
## this size, and an arc drawn with too few reads as a tent.
const ARC_STEPS := 16
## The arcs are drawn taller than the physics says, by this much. A long club
## launches at sixteen degrees, which over a hundred pixels is an apex of eight
## -- true, and indistinguishable from a straight line. The exaggeration is
## uniform, so the *comparison* between two clubs stays honest even though
## neither is to scale vertically.
const ARC_LIFT := 2.2

## The one opaque thing the game draws. Everything else is a line over the range;
## this is a panel the lines sit on, because at a quarter alpha over a lit deck
## the two dim clubs were a guess rather than a reading.
const PANEL := Color("000000")

const LIVE := Color("21d4ff")
const DIM := Color("2f7f97")
const PUTT_INK := Color("8dffa1")

## Reach of each club in metres, longest first, so the rules can be drawn to
## scale against each other. Filled from ClubProfile so a retuned club changes
## the picture without anyone editing this file.
var _reach: PackedFloat32Array = PackedFloat32Array()
## How high each club's arc stands relative to how far it goes. A ballistic arc
## over a range R at launch angle theta peaks at R·tan(theta)/4, so this is
## tan(theta)/4 and the apex is one multiplication away from the span. It comes
## from the same `launch_deg` the ball is actually hit with, which is the whole
## point: the picture is the club, not an illustration of it.
var _climb: PackedFloat32Array = PackedFloat32Array()
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
		# as a mark of zero length and reads as a disabled control.
		_reach.append(club.rolls() if club.is_putter else club.carry())
		# And no arc, because it never leaves the ground. That falls out of a
		# launch angle of zero anyway, but a putt is drawn as a line because a
		# putt *is* a line, not because the arithmetic happened to flatten.
		_climb.append(0.0 if club.is_putter else tan(deg_to_rad(club.launch_deg)) / 4.0)

	# Pinned to the top-left corner by explicit offsets. A preset plus a minimum
	# size is not enough: the control kept the full-screen rect it was given
	# before it entered the tree, and then swallowed every press on it.
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = MARGIN
	offset_right = MARGIN + WIDTH
	offset_top = MARGIN
	offset_bottom = MARGIN + HEIGHT


## The three tap targets, in the control's own coordinates. One row per club,
## full width, stacked down the corner. Each is the whole row and not just the
## rule drawn in it -- a putt's stub is twelve pixels long and aiming at it
## would be a worse control than the bottom strip ever was.
func _cells() -> Array[Rect2]:
	var cells: Array[Rect2] = []
	var count := _ids.size()
	if count == 0 or size.x <= 0.0:
		return cells
	for i in count:
		cells.append(Rect2(0.0, (ROW + GAP) * float(i), size.x, ROW))
	return cells


func _gui_input(event: InputEvent) -> void:
	var pressed := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if not pressed:
		return
	var at: Vector2 = event.position
	var cells := _cells()
	for i in cells.size():
		if cells[i].has_point(at):
			selected = i
			club_chosen.emit(i)
			accept_event()
			return
	# A press in the gaps between rows is still the selector's, not a stroke.
	accept_event()


## A parabola from `tee` running `span` to the right and peaking `apex` above the
## ground line. Sampled rather than drawn as an arc primitive because it is a
## trajectory and not a circle: a shot's shape is steeper at both ends than a
## circular arc of the same span and height, and at this size that difference is
## most of what separates the short club from the long one.
func _flight(tee: Vector2, span: float, apex: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in ARC_STEPS + 1:
		var t := float(i) / float(ARC_STEPS)
		points.append(tee + Vector2(span * t, -4.0 * apex * t * (1.0 - t)))
	return points


func _draw() -> void:
	if shown <= 0.01 or _ids.is_empty():
		return
	var cells := _cells()
	var longest := 0.0
	for r in _reach:
		longest = maxf(longest, r)
	if longest <= 0.0:
		return

	# The ground the three shots leave from, blacked out behind them. It is
	# exactly the control's own rect, which keeps the rule this file was rebuilt
	# around: a control that consumes presses is exactly as big as it looks.
	draw_rect(Rect2(Vector2.ZERO, size), Color(PANEL, 0.9 * shown), true)

	# The tee line all three leave from, and the only mark here that is not a
	# club. It is what makes them one control rather than three loose scratches.
	draw_line(
		Vector2(RAIL, cells[0].position.y + ROW * 0.34),
		Vector2(RAIL, cells[cells.size() - 1].position.y + ROW * 0.86),
		Color(DIM, 0.30 * shown), 1.0)

	for i in cells.size():
		var cell := cells[i]
		var live := i == selected
		var putting := _ids[i] == "putt"
		var ink := (PUTT_INK if putting else LIVE) if live else DIM
		# The two clubs not in hand can afford more ink than they could over the
		# bare deck, because the panel underneath is now a known quantity. Quiet
		# was always meant to be a ranking against the live club, not a dare to
		# find them at all.
		var alpha := (0.95 if live else 0.45) * shown
		var weight := 2.6 if live else 1.4

		# The shot itself: as long as the club is far, and as high as the club
		# launches. Two clubs that carry the same distance would still not draw
		# the same, which is the reading the old flat bars could not give.
		var tee := Vector2(RAIL, cell.position.y + ROW * 0.72)
		var span := REACH_PX * clampf(_reach[i] / longest, 0.10, 1.0)
		var apex := minf(span * _climb[i] * ARC_LIFT, ROW * 0.46)

		if putting:
			# It rolls. A putt drawn with any lift at all would be claiming the
			# one thing about it that is not true.
			draw_line(tee, tee + Vector2(span, 0.0), Color(ink, alpha), weight)
		else:
			draw_polyline(_flight(tee, span, apex), Color(ink, alpha), weight, true)

		# A dot on the tee marking the club in hand. A brighter line alone is
		# ambiguous at this alpha -- the dot is what makes "this one" a statement
		# rather than a difference the eye has to measure.
		if live:
			draw_circle(tee, 3.0, Color(ink, 0.95 * shown))
