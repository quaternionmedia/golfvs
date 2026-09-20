class_name GolferFigure
extends Node3D
## The golfer, and the only tell the golfer has.
##
## Until now the ball simply left. That is fine while the only thing watching is
## the person who swung -- they pressed, so they know -- and it falls apart the
## moment somebody is playing the other side. §3 requires every defender to
## telegraph, and defence is a whole way to play (Pillar 5), so the symmetric
## requirement was always implied and never built: **the golfer has to telegraph
## too.** A defender who learns a shot is coming by watching the ball already
## leave has been given nothing to read.
##
## So there is a backswing, and the ball does not move during it. `windup()` is
## how long the range holds the ball for, and it is deliberately the *same*
## number the figure animates against rather than a second one kept in step --
## a tell that disagrees with the thing it is telling about is worse than none.
##
## The clock lives here and the range asks for it, which is the opposite of the
## split used for defenders (brain decides, body follows). It is the right way
## round for this one: nothing about the swing is a game decision. The shot was
## decided when the player let go; this is the drawing of it.
##
## Silent, like everything else (ADR-004). Built from the same boxes the
## defenders are, so the golfer and the shooter read as belonging to one world.

const CLOTH := Color("13303d")
const CLOTH_EDGE := Color("4fb8d6")
const SKIN := Color("15384a")
const SHAFT := Color("9fd8e8")

## How long the whole swing takes, address to finish.
const SWING_TIME := 0.62
## Where in that the ball is struck. Everything before it is the warning; the
## rest is follow-through and costs the defender nothing.
const IMPACT_AT := 0.62
## Top of the backswing, as a fraction of the swing.
const TOP_AT := 0.44

## Club angle at the three poses, in degrees about the swing plane. Zero is the
## club hanging at the ball.
const TOP_DEG := -168.0
const FINISH_DEG := 152.0

const SCALE := 1.15


## How long the ball is held after the stroke is committed. The range reads this
## rather than keeping a constant of its own, so the backswing and the pause are
## the same fact told twice.
static func windup() -> float:
	return SWING_TIME * IMPACT_AT


## 0 at address, 1 at the finish. Driven by the range so that one clock governs
## the figure, the held ball and the defenders watching it.
var swing := 0.0:
	set(value):
		swing = value
		_pose()

## The direction the shot is going, on the ground plane. The figure stands square
## to it, which is what makes the swing plane read as a swing rather than as an
## arm rotating.
var aim := Vector3.FORWARD:
	set(value):
		if value.length_squared() > 0.0001:
			aim = value.normalized()
			_face()

var _club: Node3D
var _body: Node3D


func _ready() -> void:
	_build()
	_face()
	_pose()


func _build() -> void:
	var s := SCALE
	_body = Node3D.new()
	add_child(_body)

	DefenderArt.lit_box(_body, Vector3(0.62, 0.82, 0.42) * s, CLOTH, CLOTH_EDGE,
		Vector3(0.0, 1.16, 0.0) * s)
	DefenderArt.lit_box(_body, Vector3(0.4, 0.4, 0.38) * s, SKIN, CLOTH_EDGE,
		Vector3(0.0, 1.74, 0.0) * s)
	DefenderArt.box(_body, Vector3(0.26, 0.66, 0.28) * s, CLOTH, Vector3(-0.16, 0.4, 0.0) * s)
	DefenderArt.box(_body, Vector3(0.26, 0.66, 0.28) * s, CLOTH, Vector3(0.16, 0.4, 0.0) * s)
	DefenderArt.box(_body, Vector3(0.5, 0.14, 0.4) * s, CLOTH, Vector3(0.0, 0.05, 0.02) * s)

	# The club pivots about the line of the shot, so the swing happens in the
	# plane a golfer's swing actually happens in -- side-on to the target. Seen
	# from behind the ball, which is where the camera stands at address, that is
	# the arc everybody recognises.
	_club = Node3D.new()
	_club.position = Vector3(0.0, 1.32, 0.0) * s
	_body.add_child(_club)
	DefenderArt.polyline(_club, PackedVector3Array([
		Vector3.ZERO, Vector3(0.0, -1.28 * s, 0.0),
	]), SHAFT, 2.6)
	DefenderArt.box(_club, Vector3(0.24, 0.1, 0.14) * s, SHAFT,
		Vector3(0.0, -1.33 * s, 0.03 * s))


## The figure stands square to the shot, a little behind the ball and off to the
## side the club comes through from.
func _face() -> void:
	if _body == null:
		return
	_body.global_basis = Basis.looking_at(aim, Vector3.UP)
	_body.position = -aim.cross(Vector3.UP).normalized() * (0.62 * SCALE)


## Address, top, impact, finish -- eased so the downswing is the fast part. A
## backswing and a downswing at one speed reads as a metronome, and the whole
## value of this to a defender is that the fast part says *now*.
func _pose() -> void:
	if _club == null:
		return
	var t := clampf(swing, 0.0, 1.0)
	var degrees := 0.0
	if t <= TOP_AT:
		# Back, decelerating into the top.
		degrees = TOP_DEG * sin(t / TOP_AT * PI * 0.5)
	elif t <= IMPACT_AT:
		# Down, accelerating into the ball.
		var k := (t - TOP_AT) / (IMPACT_AT - TOP_AT)
		degrees = TOP_DEG * (1.0 - k * k)
	else:
		var k := (t - IMPACT_AT) / maxf(0.001, 1.0 - IMPACT_AT)
		degrees = FINISH_DEG * sin(k * PI * 0.5)
	# Rotating about local Z, which `looking_at` has pointing back down the line
	# of the shot -- so the club travels through the ball rather than across it.
	_club.rotation = Vector3(0.0, 0.0, deg_to_rad(degrees))
