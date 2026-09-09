class_name Skeet
extends Node3D
## The grumpy tweed uncle: air, mid-fairway, fires at apex (§3).
##
## The first of the 1.0 roster's four. This node is only the body -- what it
## does is DefenderBrain's, and everything here follows the brain's state rather
## than deciding anything. Keeping the split that hard is what lets the same
## defender be replayed from a record with no visuals at all, and what stops an
## animation ever being the reason a shot was stopped.
##
## Silent, per ADR-004: no VO and no text. The threat is carried entirely by the
## barrel swinging up, the aim line reaching out to where the shot is going, and
## the colour of both. The one audio motif this sport is owed is a gameplay
## signal and is not built yet.

const TWEED := Color("8a7a52")
const TWEED_DARK := Color("6d5f3f")
const SKIN := Color("d7a87c")
const STEEL := Color("41474d")
## The aim line and the barrel take the ribbon's own "this line does not get
## there" amber, so the player meets one colour language and not two.
const THREAT := Color("ff7a2f")
const FLASH := Color("ffe9a8")

var brain := DefenderBrain.new()

var _barrel: Node3D
var _muzzle: Marker3D
var _line: MeshInstance3D
var _flash: MeshInstance3D
var _flash_left := 0.0
var _watching := Vector3.ZERO
var _swing := 0.0


static func with_profile(profile: DefenderProfile, tier: DifficultyTier, id: String) -> Skeet:
	var node := Skeet.new()
	node.brain.configure(profile, tier, id)
	node.position = profile.stand
	return node


func _ready() -> void:
	_build_body()
	brain.state_changed.connect(_on_state_changed)


## Chunky and readable at 64 px, per §5 and the art pipeline's silhouette rule.
## Boxes stand in for the Blender mesh that ART_PIPELINE.md will govern -- the
## proportions are the part worth getting right now, because they are what the
## final model has to match to keep the hole playing the same.
func _build_body() -> void:
	DefenderArt.box(self, Vector3(1.05, 1.25, 0.65), TWEED, Vector3(0.0, 0.95, 0.0))
	DefenderArt.box(self, Vector3(1.2, 0.22, 0.75), TWEED_DARK, Vector3(0.0, 1.5, 0.0))
	DefenderArt.box(self, Vector3(0.55, 0.5, 0.5), SKIN, Vector3(0.0, 1.85, 0.0))
	# The flat cap is most of the silhouette. Wider than the head on purpose.
	DefenderArt.box(self, Vector3(0.78, 0.12, 0.7), TWEED_DARK, Vector3(0.0, 2.12, -0.04))
	DefenderArt.box(self, Vector3(0.34, 0.62, 0.34), TWEED, Vector3(0.0, 0.28, 0.0)) # legs
	DefenderArt.box(self, Vector3(0.4, 0.42, 0.4), TWEED_DARK, Vector3(0.0, 0.05, 0.0)) # boots

	# The gun is a child of a pivot at the shoulder, so tracking is one rotation
	# and the muzzle position falls out of it for free.
	_barrel = Node3D.new()
	_barrel.position = Vector3(0.34, 1.35, 0.0)
	add_child(_barrel)
	DefenderArt.box(_barrel, Vector3(0.14, 0.14, 1.5), STEEL, Vector3(0.0, 0.0, -0.75))
	DefenderArt.box(_barrel, Vector3(0.17, 0.3, 0.5), TWEED_DARK, Vector3(0.0, -0.06, 0.22))

	_muzzle = Marker3D.new()
	_muzzle.position = Vector3(0.0, 0.0, -1.5)
	_barrel.add_child(_muzzle)

	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.34
	flash_mesh.height = 0.68
	flash_mesh.radial_segments = 8
	flash_mesh.rings = 4
	_flash = MeshInstance3D.new()
	_flash.mesh = flash_mesh
	_flash.material_override = DefenderArt.glow(FLASH, 7.0)
	_flash.visible = false
	_muzzle.add_child(_flash)

	# The aim line: an immediate-mode segment redrawn each frame while telling.
	_line = MeshInstance3D.new()
	_line.material_override = DefenderArt.glow(THREAT, 2.6)
	_line.custom_aabb = DefenderArt.generous_aabb()
	_line.visible = false
	add_child(_line)


## Everything the defender knows about this shot, decided once, before the tell.
func read_shot(arc: PackedVector3Array, dt: float, stroke_seed: int) -> void:
	brain.read_shot(arc, dt, stroke_seed)
	_watching = brain.act_point() if brain.is_committed() else Vector3.ZERO


## Returns true on the tick it fires. The caller applies the consequence -- a
## defender never touches the ball itself, because §6.4 wants the hit to be an
## impulse from the action and not a collision with an animated mesh.
func advance(delta: float) -> bool:
	return brain.advance(delta)


func rest() -> void:
	brain.rest()
	_watching = Vector3.ZERO


func _process(delta: float) -> void:
	_flash_left = maxf(0.0, _flash_left - delta)
	_flash.visible = _flash_left > 0.0

	# Idle sweeps the sky slowly; the tell locks on. The difference between a
	# barrel wandering and a barrel holding still is the tell, and it reads at a
	# distance without a single glyph.
	var aiming := brain.state == DefenderBrain.State.TELL \
		or brain.state == DefenderBrain.State.ACT
	var target := _watching
	if not aiming:
		_swing += delta * 0.6
		target = global_position + Vector3(sin(_swing) * 8.0, 6.0, -cos(_swing) * 8.0)

	var muzzle_from := _barrel.global_position
	var want := (target - muzzle_from).normalized()
	if want.length_squared() > 0.0:
		var basis := Basis.looking_at(want, Vector3.UP)
		var speed := 12.0 if aiming else 1.6
		# Basis.slerp goes through quaternions and requires both ends to be
		# orthonormal. Feeding it back its own output drifts a little off
		# orthonormal every frame, and after a few hundred frames Godot refuses
		# the conversion outright -- a stream of errors and a barrel that stops
		# tracking. Re-orthonormalising each way costs nothing here.
		_barrel.global_basis = _barrel.global_basis.orthonormalized() \
			.slerp(basis, clampf(delta * speed, 0.0, 1.0)).orthonormalized()

	_line.visible = brain.state == DefenderBrain.State.TELL
	if _line.visible:
		DefenderArt.dashed_line(_line, _muzzle.global_position, _watching, 0.05, 7.0)


func _on_state_changed(state: DefenderBrain.State) -> void:
	if state == DefenderBrain.State.ACT:
		_flash_left = 0.14
