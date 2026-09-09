# GdUnitTestSuite
extends GdUnitTestSuite

## The two physics guarantees §6.4 states, asserted rather than assumed.
##
## M0 step 5 confirmed both by hand in core/m0_physics_smoke.tscn. These tests
## are what keeps them true afterwards. Determinism is the reason: a tick rate
## that quietly changes, or a ball that quietly loses CCD, does not announce
## itself -- it shows up much later as a Stroke Record that no longer replays,
## and by then the cause is months of commits back.

const SMOKE_SCENE := "res://core/m0_physics_smoke.tscn"

## A driver launches a ball at roughly 75 m/s. m0_physics_smoke.tscn measures
## the bare solver letting the ball through a 20 mm wall from 50 m/s, which is
## under that -- so on this engine CCD is load-bearing, not a safety margin.
const REALISTIC_BALL_SPEED := 80.0


func test_the_tick_is_a_fixed_60_hz() -> void:
	assert_int(Engine.physics_ticks_per_second) \
		.override_failure_message(
			"The physics tick is %d Hz, not 60. §6.4 fixes it at 60 and the " % Engine.physics_ticks_per_second +
			"determinism requirement (§6.6) is written against that rate: " +
			"change it and every recorded Stroke Record replays differently."
		) \
		.is_equal(60)


func test_the_physics_engine_is_the_one_we_tuned_against() -> void:
	# Godot Physics and Jolt disagree about restitution and about how much CCD
	# the solver does for free. The bounce values in §2.2 were read off Jolt.
	var engine_name: String = ProjectSettings.get_setting("physics/3d/physics_engine", "")
	assert_str(engine_name) \
		.override_failure_message(
			"physics/3d/physics_engine is '%s'. The surface bounce values in " % engine_name +
			"§2.2 and the CCD headroom measured at M0 were both taken on Jolt."
		) \
		.is_equal("Jolt Physics")


func test_the_ball_has_continuous_collision_detection() -> void:
	var scene: PackedScene = load(SMOKE_SCENE)
	assert_object(scene) \
		.override_failure_message("%s is missing." % SMOKE_SCENE) \
		.is_not_null()

	var root: Node = auto_free(scene.instantiate())
	var ball := root.get_node_or_null("Ball") as RigidBody3D
	assert_object(ball) \
		.override_failure_message("%s has no RigidBody3D named Ball." % SMOKE_SCENE) \
		.is_not_null()

	assert_bool(ball.continuous_cd) \
		.override_failure_message(
			"The ball has CCD off. Without it the bare solver lets the ball " +
			"through a 20 mm wall at 50 m/s -- below the ~%.0f m/s " % REALISTIC_BALL_SPEED +
			"a driver produces. The ball would leave the course."
		) \
		.is_true()
