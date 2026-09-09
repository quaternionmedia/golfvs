class_name BallFlight
extends Object
## The one flight model, used by both the shot and its preview.
##
## §2.1 promises the aim ribbon is "accurate on an empty hole". That promise is
## only keepable if the ribbon and the ball are solving the same equation, so
## the launch velocity and the curve acceleration live here and there is no
## second copy. If the ball ever stops matching its own preview, it is because
## something was added to one path and not the other -- which is the bug this
## file exists to make obvious.
##
## Airborne motion is constant-acceleration: gravity plus a fixed lateral term
## standing in for sidespin (§2.2's "Magnus-lite", no aero simulation). That is
## integrable in closed form, so the preview is exact rather than a simulation
## racing the real one.

const MIN_SPEED := 8.0
## Full power carries about 42 m at LAUNCH_DEG, against a hole that measures 57 m
## to the cup. A first-timer swinging as hard as they can should reach the
## landing zone comfortably and still have a second shot to play.
const MAX_SPEED := 25.0
const LAUNCH_DEG := 21.0
## Lateral acceleration at full curve, m/s^2. Tuned so a full-curve approach
## bends about four metres over the intro hole's 32 m second shot -- enough to
## clear the spire, not so much that a straight shot feels broken.
const CURVE_ACCEL := 7.5

## Low enough to leave a tap-in playable. A floor set for long putts makes the
## last stroke of the hole the hardest one in it.
const PUTT_MIN_SPEED := 1.15
const PUTT_MAX_SPEED := 8.4


static func gravity() -> Vector3:
	return Vector3(0.0, -float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)), 0.0)


static func launch_velocity(heading: Vector3, power: float, putting := false) -> Vector3:
	var flat := Vector3(heading.x, 0.0, heading.z).normalized()
	if putting:
		return flat * lerpf(PUTT_MIN_SPEED, PUTT_MAX_SPEED, clampf(power, 0.0, 1.0))
	var speed := lerpf(MIN_SPEED, MAX_SPEED, clampf(power, 0.0, 1.0))
	# flat x UP is the shot's own right-hand side, and a positive rotation about
	# it lifts the ball. Negating here fires the stroke into the turf, which the
	# ball survives by skipping -- close enough to a golf shot to hide the bug.
	var axis := flat.cross(Vector3.UP).normalized()
	return flat.rotated(axis, deg_to_rad(LAUNCH_DEG)) * speed


## Sidespin pushes perpendicular to the line of flight, on the horizontal plane.
## Positive curve bends right, which is the direction the player dragged.
static func curve_acceleration(heading: Vector3, curve: float) -> Vector3:
	var flat := Vector3(heading.x, 0.0, heading.z).normalized()
	var right := flat.cross(Vector3.UP).normalized()
	return right * (-clampf(curve, -1.0, 1.0) * CURVE_ACCEL)


## The arc, sampled until it returns to the ground. Closed form, so this costs
## nothing to call every frame while the player is aiming.
static func sample_arc(origin: Vector3, velocity: Vector3, accel: Vector3,
		ground_y: float, max_points := 48, dt := 0.075) -> PackedVector3Array:
	var points := PackedVector3Array()
	var total := gravity() + accel
	for i in max_points:
		var t := float(i) * dt
		var p := origin + velocity * t + 0.5 * total * t * t
		points.append(p)
		if i > 0 and p.y <= ground_y:
			break
	return points
