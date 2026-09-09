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

const CLOTH := Color("3f6b4e")
const CLOTH_DARK := Color("2e5039")
const SKIN := Color("e0b68f")
const BOW := Color("8a5a2f")
const STRING := Color("d8e4dc")
## The archer's thread is green, not the ribbon's amber. Amber means "this line
## does not get there" and applies to the player's shot; the archer is not a
## warning about the shot, it is an announcement that the shot has already gone
## wrong and is being saved.
const THREAD := Color("8dffa1")

var brain: ArcherBrain = ArcherBrain.new()

var _bow: Node3D
var _nock: Marker3D
var _arrow: MeshInstance3D
var _thread: MeshInstance3D
var _draw := 0.0
var _watching := Vector3.ZERO
var _flight := -1.0
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
	# apart when it matters.
	DefenderArt.box(self, Vector3(0.72, 1.5, 0.5), CLOTH, Vector3(0.0, 1.15, 0.0))
	DefenderArt.box(self, Vector3(0.9, 0.16, 0.6), CLOTH_DARK, Vector3(0.0, 1.86, 0.0))
	DefenderArt.box(self, Vector3(0.46, 0.5, 0.44), SKIN, Vector3(0.0, 2.15, 0.0))
	DefenderArt.box(self, Vector3(0.2, 0.34, 0.16), SKIN, Vector3(-0.3, 2.2, 0.02))
	DefenderArt.box(self, Vector3(0.2, 0.34, 0.16), SKIN, Vector3(0.3, 2.2, 0.02))
	DefenderArt.box(self, Vector3(0.3, 0.75, 0.3), CLOTH_DARK, Vector3(0.0, 0.35, 0.0))
	DefenderArt.box(self, Vector3(0.38, 0.16, 0.46), CLOTH_DARK, Vector3(0.0, 0.06, 0.03))

	_bow = Node3D.new()
	_bow.position = Vector3(0.0, 1.5, 0.0)
	add_child(_bow)
	# The bow itself: three segments, so the limbs read as curved at distance
	# without a single curve in the geometry.
	DefenderArt.box(_bow, Vector3(0.1, 1.0, 0.1), BOW, Vector3(0.42, 0.0, 0.0))
	DefenderArt.box(_bow, Vector3(0.1, 0.5, 0.1), BOW, Vector3(0.36, 0.66, -0.06))
	DefenderArt.box(_bow, Vector3(0.1, 0.5, 0.1), BOW, Vector3(0.36, -0.66, -0.06))
	DefenderArt.box(_bow, Vector3(0.03, 1.72, 0.03), STRING, Vector3(0.3, 0.0, 0.0))

	_nock = Marker3D.new()
	_nock.position = Vector3(0.42, 0.0, -0.4)
	_bow.add_child(_nock)

	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.05, 0.05, 1.0)
	_arrow = MeshInstance3D.new()
	_arrow.mesh = shaft
	_arrow.material_override = DefenderArt.glow(THREAD, 2.2)
	_arrow.custom_aabb = DefenderArt.generous_aabb()
	_arrow.visible = false
	add_child(_arrow)

	_thread = MeshInstance3D.new()
	_thread.material_override = DefenderArt.glow(THREAD, 2.0)
	_thread.custom_aabb = DefenderArt.generous_aabb()
	_thread.visible = false
	add_child(_thread)


func read_shot(arc: PackedVector3Array, dt: float, stroke_seed: int) -> void:
	brain.read_shot(arc, dt, stroke_seed)
	_watching = brain.act_point() if brain.is_committed() else Vector3.ZERO


func advance(delta: float) -> bool:
	return brain.advance(delta)


func rest() -> void:
	brain.rest()
	_watching = Vector3.ZERO


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
	var drawing := brain.state == DefenderBrain.State.TELL \
		or brain.state == DefenderBrain.State.ACT
	# The draw is the tell: the bow comes up and the string goes back over the
	# tell's length, so how far it is drawn says how long is left.
	_draw = move_toward(_draw, 1.0 if drawing else 0.0, delta * (2.6 if drawing else 5.0))

	var target := _watching if drawing else global_position + Vector3(0.0, 4.0, -14.0)
	var want := (target - _bow.global_position).normalized()
	if want.length_squared() > 0.0:
		var basis := Basis.looking_at(want, Vector3.UP)
		var speed := 9.0 if drawing else 1.4
		# Re-orthonormalised both ways: slerp goes through a quaternion and
		# refuses a basis that has drifted, which is how the shooter's barrel
		# once stopped tracking mid-round.
		_bow.global_basis = _bow.global_basis.orthonormalized() \
			.slerp(basis, clampf(delta * speed, 0.0, 1.0)).orthonormalized()

	_thread.visible = _draw > 0.02 and _watching != Vector3.ZERO
	if _thread.visible:
		DefenderArt.dashed_line(_thread, _nock.global_position, _watching, 0.035, 9.0)

	_advance_arrow(delta)


## The arrow has travel time, which is §3's stated counter for archery: a fast
## low shot can beat it. Here it is mostly there to make the act readable — a
## ball that simply stopped would look like a physics bug rather than a rescue.
func _advance_arrow(delta: float) -> void:
	if _flight < 0.0:
		_arrow.visible = false
		return
	_flight += delta * 3.4
	if _flight >= 1.0:
		_flight = -1.0
		_arrow.visible = false
		return
	var at := _from.lerp(_to, _flight)
	_arrow.visible = true
	_arrow.global_position = at
	var heading := (_to - _from)
	if heading.length_squared() > 1.0e-6:
		_arrow.global_basis = Basis.looking_at(heading.normalized(), Vector3.UP)


func _on_state_changed(state: DefenderBrain.State) -> void:
	if state == DefenderBrain.State.ACT and brain.will_connect():
		_from = _nock.global_position
		_to = brain.act_point()
		_flight = 0.0
