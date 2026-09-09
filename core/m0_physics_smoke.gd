extends Node3D
## M0 step 5 — the physics smoke scene.
##
## Confirms the two physics guarantees §6.4 depends on before any gameplay is
## built on them: a fixed 60 Hz tick, and continuous collision detection on the
## ball. Everything here is a placeholder; M1 replaces it with the Practice
## Range. See docs/DESIGN.md Appendix A step 5.
##
## Interactive:  Space fires the ball, R resets, C toggles CCD.
## Headless:     runs the CCD probe and exits non-zero if the guarantees fail.

## A real golf ball: 42.67 mm across, 45.93 g.
const BALL_RADIUS := 0.021335
const BALL_MASS := 0.04593

## A driver launches a ball at roughly 75 m/s. Anything at or under this is a
## speed the game will really produce, and nothing may tunnel there.
const REALISTIC_SPEED := 80.0
## What the Space key fires, for eyeballing the scene.
const PROBE_SPEED := 70.0
## The sweep climbs until the ball beats the solver, which is the only way to
## show CCD is carrying any weight: Jolt's speculative contacts already stop the
## ball far above realistic speeds, so a single fast shot proves nothing.
const PROBE_SPEEDS: Array[float] = [50.0, 80.0, 200.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0]
const PROBE_TICKS := 60
const WALL_Z := -6.0
const WALL_THICKNESS := 0.02

@onready var _ball: RigidBody3D = $Ball
@onready var _camera: Camera3D = $Camera
@onready var _readout: Label = $HUD/Readout

var _spawn := Vector3(0.0, 0.5, 4.0)


func _ready() -> void:
	_camera.look_at(Vector3(0.0, 0.5, -1.0))
	_spawn = _ball.global_position
	_print_diagnostics()
	if _is_headless():
		await _run_ccd_probe()


func _print_diagnostics() -> void:
	print("=== golfVs M0 physics smoke ===")
	print("engine            : %s" % Engine.get_version_info().string)
	print("pinned            : %s" % ProjectSettings.get_setting("golfvs/engine/pinned_godot_version"))
	print("physics engine    : %s" % ProjectSettings.get_setting("physics/3d/physics_engine"))
	print("physics ticks/s   : %d" % Engine.physics_ticks_per_second)
	print("max steps/frame   : %d" % Engine.max_physics_steps_per_frame)
	print("ball CCD          : %s" % _ball.continuous_cd)
	print("ball mass         : %.5f kg" % _ball.mass)


func _process(_delta: float) -> void:
	if _readout == null:
		return
	_readout.text = "\n".join([
		"physics %d Hz   CCD %s" % [
			Engine.physics_ticks_per_second,
			"on" if _ball.continuous_cd else "OFF",
		],
		"ball z %+.2f   speed %.1f m/s" % [
			_ball.global_position.z,
			_ball.linear_velocity.length(),
		],
		"",
		"[space] fire   [R] reset   [C] toggle CCD",
	])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_SPACE:
			_teleport(_spawn, Vector3(0.0, 0.0, -PROBE_SPEED))
		KEY_R:
			_teleport(_spawn, Vector3.ZERO)
		KEY_C:
			_ball.continuous_cd = not _ball.continuous_cd
			print("ball CCD -> %s" % _ball.continuous_cd)


## Teleporting a RigidBody3D has to go through the physics server, or the body's
## own integration overwrites the new transform on the next tick.
func _teleport(position: Vector3, velocity: Vector3) -> void:
	var rid := _ball.get_rid()
	PhysicsServer3D.body_set_state(
		rid, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, position)
	)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, velocity)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_SLEEPING, false)


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless" \
		or "--ccd-probe" in OS.get_cmdline_user_args()


## Fires the ball at the thin wall and reports how far it got. Reporting the
## distance rather than a bare pass/fail is what separates "the wall stopped it"
## from "it never left the tee" — both of which leave the ball on this side.
func _probe(speed: float, use_ccd: bool) -> Dictionary:
	var restore_gravity := _ball.gravity_scale
	_ball.gravity_scale = 0.0
	_ball.continuous_cd = use_ccd
	_teleport(_spawn, Vector3(0.0, 0.0, -speed))

	var deepest := _spawn.z
	for _tick in PROBE_TICKS:
		await get_tree().physics_frame
		deepest = minf(deepest, _ball.global_position.z)

	_ball.gravity_scale = restore_gravity
	return {
		"deepest": deepest,
		"travelled": _spawn.z - deepest,
		"stopped": deepest > WALL_Z,
	}


func _run_ccd_probe() -> void:
	print("
--- CCD sweep: a %.0f mm wall, %d ticks per shot ---" % [
		WALL_THICKNESS * 1000.0, PROBE_TICKS,
	])
	print("%11s  %-22s  %-22s" % ["speed", "CCD on", "CCD off"])

	# The lowest speed at which each configuration lets the ball through. Zero
	# means it never did. Lowest rather than highest: the sweep is not monotonic
	# (a speed whose per-tick step happens to land the ball on the wall face is
	# caught by an ordinary discrete contact), so only the first failure is
	# meaningful — anything above it is luck.
	var bare_tunnels_from := 0.0
	var ccd_tunnels_from := 0.0

	for speed in PROBE_SPEEDS:
		var with_ccd := await _probe(speed, true)
		var without_ccd := await _probe(speed, false)

		print("%9.0f m/s  %-22s  %-22s" % [
			speed, _describe(with_ccd), _describe(without_ccd),
		])

		if not with_ccd["stopped"] and ccd_tunnels_from == 0.0:
			ccd_tunnels_from = speed
		if not without_ccd["stopped"] and bare_tunnels_from == 0.0:
			bare_tunnels_from = speed

	_ball.continuous_cd = true

	var ccd_holds := ccd_tunnels_from == 0.0
	# CCD has to be shown doing something. If the ball never beats the bare
	# solver, this scene cannot tell working CCD from broken CCD.
	var ccd_is_observable := bare_tunnels_from != 0.0
	var tick_ok := Engine.physics_ticks_per_second == 60

	print("")
	print("CCD holds to %.0f m/s      : %s" % [
		PROBE_SPEEDS[-1],
		_verdict(ccd_holds, "the ball tunnels at %.0f m/s even with CCD on" % ccd_tunnels_from),
	])
	print("the sweep can observe CCD : %s" % _verdict(
		ccd_is_observable, "the bare solver held everywhere, so CCD is untested here"
	))
	print("tick is a fixed 60 Hz     : %s" % _verdict(
		tick_ok, "%d Hz" % Engine.physics_ticks_per_second
	))

	if ccd_is_observable and bare_tunnels_from <= REALISTIC_SPEED:
		print("")
		print("NOTE: without CCD the ball is already through the wall at %.0f m/s," % bare_tunnels_from)
		print("      which is under the ~%.0f m/s a driver produces. CCD is not an" % REALISTIC_SPEED)
		print("      optimisation here — the ball must carry it or it leaves the course.")

	var passed := ccd_holds and ccd_is_observable and tick_ok
	print("
M0 step 5: %s" % ("PASS" if passed else "FAIL"))
	get_tree().quit(0 if passed else 1)


func _describe(result: Dictionary) -> String:
	return "stopped (z %+.3f)" % result["deepest"] if result["stopped"] else "TUNNELLED"


func _verdict(ok: bool, failure: String) -> String:
	return "yes" if ok else "NO — %s" % failure
