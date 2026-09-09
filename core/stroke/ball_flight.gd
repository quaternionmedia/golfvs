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

const MIN_SPEED := 9.2
## Full power carries about 57 m at LAUNCH_DEG, against a hole that measures 77 m
## to the cup. A first-timer swinging as hard as they can should reach the
## landing zone comfortably and still have a second shot to play.
##
## Range goes as the square of launch speed, so the hole and this constant have
## to move together: the hole was lengthened by a third and the speed by a sixth.
## Getting that backwards makes a longer hole play as a shorter one with more
## walking.
const MAX_SPEED := 29.0
const LAUNCH_DEG := 21.0
## Lateral acceleration at full curve, m/s^2. Tuned so a full-curve approach
## bends about five metres over the intro hole's 45 m second shot -- enough to
## clear the spire, not so much that a straight shot feels broken. Scaled with
## the hole: a longer ball in the air for longer bends further for free, so this
## rose by less than the distance did.
const CURVE_ACCEL := 8.2

## Low enough to leave a tap-in playable. A floor set for long putts makes the
## last stroke of the hole the hardest one in it.
const PUTT_MIN_SPEED := 1.15
const PUTT_MAX_SPEED := 9.7


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
##
## **Positive curve bends right: a fade. Negative bends left: a draw.** That is
## RECORD_SCHEMA.md §2.1's definition, and it is the one that has to win,
## because `intent.curve` goes on disk and a stored number whose sign means the
## opposite of what the schema says is a bug that only shows up on somebody
## else's phone. This function used to negate here and StrokeGesture used to
## hand it a value of the opposite sign; the two cancelled, so the ball flew
## correctly and the recorded number was inverted. The negation now lives in the
## gesture alone, where it belongs -- screen space is the thing with a flipped
## axis, not the golf.
static func curve_acceleration(heading: Vector3, curve: float) -> Vector3:
	var flat := Vector3(heading.x, 0.0, heading.z).normalized()
	var right := flat.cross(Vector3.UP).normalized()
	return right * (clampf(curve, -1.0, 1.0) * CURVE_ACCEL)


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
