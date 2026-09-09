class_name Archer
extends Node3D
## Elf-ish, overly serious, and on this hole entirely on your side (ADR-015).
##
## Stands near the green with a longbow and shoots exactly one thing: a ball on
## its way off the course. The arrow pins it where it lands, no penalty. Every
## other shot it watches without moving, which is the point — a defender that
## acts only on your disasters teaches you where the course ends without a word,
## and makes the intro hole unfailable.
##
## Silent, per ADR-004. The bow drawing is the tell; the arrow having travel time
## is what makes the act readable rather than instantaneous.

## Drawn, not photographed. The intro hole is a holodeck blueprint, so its one
## inhabitant is a dark form with lit edges rather than a painted figure -- the
## same vocabulary as the spire it stands on.
const CLOTH := Color("0e2530")
const CLOTH_EDGE := Color("4fb8d6")
const SKIN := Color("15384a")
const BOW := Color("9fd8e8")
const STRING := Color("21d4ff")
## The archer's thread is green, not the ribbon's amber. Amber means "this line
## does not get there" and applies to the player's shot; the archer is not a
## warning about the shot, it is an announcement that the shot has already gone
## wrong and is being saved.
const THREAD := Color("8dffa1")

## How much bigger than a person the figure is drawn.
##
## §5 asks for caricatured proportions and ART_PIPELINE for a silhouette that
## reads at 64 px. Built at human scale the archer stood 2.4 m on top of a 7 m
## spire, seen from a tee 38 m away, and rendered as a smudge -- which is half
## of why it went unnoticed. At 1.6x it is a landmark instead.
const SCALE := 1.6

var brain: ArcherBrain = ArcherBrain.new()

## The colour the arrow, the thread and the tracer are drawn in.
##
## Green by default, and the comment on THREAD says why: on this range an arrow
## means a shot has gone wrong and is being saved. An archer *contesting* the
## line is not saving anybody, so it takes the ribbon's amber instead -- the
## colour the game already uses for "this line does not get there". One sport,
## two jobs, and the player is told which is which without a word.
var ink := THREAD

## True while a person is aiming this archer rather than the game. The AI decides
## where to point once, before the tell; a human has decided nothing yet and
## needs the bow drawn and the thread following the ball while they make up their
## mind. It is also the only thing they have to judge the shot by.
var _tracked := false
var _on_target := false

var _bow: Node3D
var _nock: Marker3D
var _arrow: MeshInstance3D
var _thread: MeshInstance3D
var _trail: MeshInstance3D
var _draw := 0.0
var _watching := Vector3.ZERO
var _sweep := 0.0
var _streak := -1.0
var _from := Vector3.ZERO
## Held separately from `_watching`, which `rest()` clears at the end of a
## stroke -- an arrow still in the air would otherwise turn and fly to the world
## origin on its last few frames.
var _to := Vector3.ZERO


static func with_profile(profile: DefenderProfile, tier: DifficultyTier, id: String) -> Archer:
	var node := Archer.new()
	node.brain.configure(profile, tier, id)
	node.position = profile.stand
	return node


func _ready() -> void:
	_build_body()
	brain.state_changed.connect(_on_state_changed)


func _build_body() -> void:
	# Tall and narrow, against the shooter's squat rectangle. Two defenders that
	# read as the same blob at distance are two defenders the player cannot tell
	# apart when it matters. Every dimension is multiplied by SCALE, so the
	# proportions stay in one place and the figure resizes as a whole.
	var s := SCALE
	DefenderArt.lit_box(self, Vector3(0.72, 1.5, 0.5) * s, CLOTH, CLOTH_EDGE, Vector3(0.0, 1.15, 0.0) * s)
	DefenderArt.lit_box(self, Vector3(0.9, 0.16, 0.6) * s, CLOTH, CLOTH_EDGE, Vector3(0.0, 1.86, 0.0) * s)
	DefenderArt.lit_box(self, Vector3(0.46, 0.5, 0.44) * s, SKIN, CLOTH_EDGE, Vector3(0.0, 2.15, 0.0) * s)
	DefenderArt.box(self, Vector3(0.2, 0.34, 0.16) * s, SKIN, Vector3(-0.3, 2.2, 0.02) * s)
	DefenderArt.box(self, Vector3(0.2, 0.34, 0.16) * s, SKIN, Vector3(0.3, 2.2, 0.02) * s)
	DefenderArt.lit_box(self, Vector3(0.3, 0.75, 0.3) * s, CLOTH, CLOTH_EDGE, Vector3(0.0, 0.35, 0.0) * s)
	DefenderArt.box(self, Vector3(0.38, 0.16, 0.46) * s, CLOTH, Vector3(0.0, 0.06, 0.03) * s)

	_bow = Node3D.new()
	_bow.position = Vector3(0.0, 1.5, 0.0) * s
	add_child(_bow)

	# A real bow, drawn as one: a curve and a string. This is the silhouette
	# prop ART_PIPELINE asks for, and it is the only shape on the whole hole
	# that is not a box, a grid or a circle -- which is exactly why it reads at
	# distance when a stack of wire boxes did not.
	#
	# `_bow` rotates so local -Z points at the target, so the limbs run along
	# local Y and the belly bulges toward -Z, ahead of the string. That is how
	# a bow is actually held, and it means the D-shape is broadside to anyone
	# standing off the line of the shot -- which the player always is.
	var reach := 1.45 * s
	var belly := 0.62 * s
	var hand := 0.52 * s
	var limb := PackedVector3Array()
	for i in 21:
		var t := lerpf(-1.0, 1.0, float(i) / 20.0)
		limb.append(Vector3(hand, reach * t, -belly * cos(t * PI * 0.5)))
	DefenderArt.polyline(_bow, limb, BOW, 3.4)
	DefenderArt.lines(_bow, PackedVector3Array([
		Vector3(hand, -reach, 0.0), Vector3(hand, reach, 0.0),
	]), STRING, 3.8)

	_nock = Marker3D.new()
	_nock.position = Vector3(hand, 0.0, 0.0)
	_bow.add_child(_nock)

	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.06, 0.06, 1.3)
	_arrow = MeshInstance3D.new()
	_arrow.mesh = shaft
	_arrow.material_override = DefenderArt.glow(ink, 2.6)
	_arrow.custom_aabb = DefenderArt.generous_aabb()
	_arrow.top_level = true
	_arrow.visible = false
	add_child(_arrow)

	_thread = MeshInstance3D.new()
	_thread.material_override = DefenderArt.glow(ink, 2.0)
	_thread.custom_aabb = DefenderArt.generous_aabb()
	_thread.top_level = true
	_thread.visible = false
	add_child(_thread)

	# The tracer: the line the arrow took, for the handful of frames it is worth
	# seeing.
	_trail = MeshInstance3D.new()
	_trail.material_override = DefenderArt.glow(ink, 5.5)
	_trail.custom_aabb = DefenderArt.generous_aabb()
	_trail.top_level = true
	_trail.visible = false
	add_child(_trail)


func read_shot(arc: PackedVector3Array, dt: float, stroke_seed: int) -> void:
	brain.read_shot(arc, dt, stroke_seed)
	_watching = brain.act_point() if brain.is_committed() else Vector3.ZERO


func advance(delta: float) -> bool:
	return brain.advance(delta)


## Follow the ball, for an archer somebody is playing rather than the game.
##
## `reachable` is the brain's own answer to "would this connect", and the thread
## is drawn from it: bright and tight while the shot is on, dim and loose while
## it is not. That one difference is the whole interface for the other side --
## the defender is given the golfer's view and a line, and the line has to be
## honest, or timing it is guesswork rather than a read (Pillar 2).
func track(at: Vector3, reachable := true) -> void:
	_watching = at
	_tracked = true
	_on_target = reachable


func rest() -> void:
	brain.rest()
	_watching = Vector3.ZERO
	_tracked = false
	_on_target = false


## The ball is near the edge of the course. Draw, and look at it.
func watch(at: Vector3) -> void:
	brain.watch(at)
	if brain.alerted:
		_watching = at


## The ball has left the course. Shoot it, and pin it where it was last in play.
func intercept(at: Vector3) -> bool:
	_watching = at
	return brain.intercept(at)


func _process(delta: float) -> void:
	var drawing := _tracked or brain.state == DefenderBrain.State.TELL \
		or brain.state == DefenderBrain.State.ACT
	# The draw is the tell: the bow comes up and the string goes back over the
	# tell's length, so how far it is drawn says how long is left.
	_draw = move_toward(_draw, 1.0 if drawing else 0.0, delta * (2.6 if drawing else 5.0))

	# Idle sweeps slowly across the corridor. Three things at once: it reads as
	# alive rather than as scenery, it brings the bow broadside to the player
	# periodically -- a bow seen edge-on is a stick -- and it is the same idle
	# language the shooter uses, so two defenders behave alike when doing
	# nothing.
	var target := _watching
	if not drawing:
		_sweep += delta * 0.35
		target = global_position + Vector3(sin(_sweep) * 16.0, 3.0, -12.0 - cos(_sweep) * 5.0)
	var want := (target - _bow.global_position).normalized()
	if want.length_squared() > 0.0:
		var basis := Basis.looking_at(want, Vector3.UP)
		var speed := 9.0 if drawing else 1.4
		# Re-orthonormalised both ways: slerp goes through a quaternion and
		# refuses a basis that has drifted, which is how the shooter's barrel
		# once stopped tracking mid-round.
		_bow.global_basis = _bow.global_basis.orthonormalized() \
			.slerp(basis, clampf(delta * speed, 0.0, 1.0)).orthonormalized()

	# The nock rides back along the string as the draw builds, so how far the
	# bow is drawn says how long is left before the arrow goes.
	_nock.position.z = 0.62 * SCALE * _draw

	_thread.visible = _draw > 0.02 and _watching != Vector3.ZERO
	if _thread.visible:
		var on := _on_target or not _tracked
		var mat: StandardMaterial3D = _thread.material_override
		mat.albedo_color = ink if on else Color(ink, 1.0).darkened(0.55)
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 3.4 if on else 0.7
		DefenderArt.dashed_line(_thread, _nock.global_position, _watching,
			0.05 if on else 0.02, 7.0 if on else 14.0)

	_advance_arrow(delta)


## The shot, drawn as a tracer rather than as a travelling projectile.
##
## The projectile version had the causality backwards: the pin is applied on the
## tick the archer acts, but a projectile takes a third of a second to arrive, so
## the player watched the ball stop and *then* watched an arrow reach it. Cause
## after effect reads as a glitch however good the arrow looks.
##
## A tracer arrives in the same frame as the impulse. What sells the speed is
## the streak fading over a few frames and the shaft left standing in the deck,
## not watching something cross the gap.
func _advance_arrow(delta: float) -> void:
	if _streak < 0.0:
		_arrow.visible = false
		_trail.visible = false
		return
	_streak += delta

	# The line from bow to ball: two frames at full brightness, gone by six.
	var flash := clampf(1.0 - _streak / 0.12, 0.0, 1.0)
	_trail.visible = flash > 0.0
	if _trail.visible:
		DefenderArt.dashed_line(_trail, _from, _to, 0.07 * flash, 1.0, 2)

	# The shaft stands in the deck where it landed, and fades out.
	var stay := clampf(1.0 - _streak / 0.9, 0.0, 1.0)
	_arrow.visible = stay > 0.0
	if _arrow.visible:
		_arrow.global_position = _to
		var heading := _to - _from
		if heading.length_squared() > 1.0e-6:
			_arrow.global_basis = Basis.looking_at(heading.normalized(), Vector3.UP)
		var mat: StandardMaterial3D = _arrow.material_override
		mat.albedo_color = Color(ink, stay)
	else:
		_streak = -1.0


func _on_state_changed(state: DefenderBrain.State) -> void:
	if state == DefenderBrain.State.ACT and brain.will_connect():
		_from = _nock.global_position
		_to = brain.act_point()
		_streak = 0.0
		_draw = 0.0
