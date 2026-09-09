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

## The club used when a caller does not name one.
##
## Every full shot in the game used to be this, under whatever name the record
## happened to store -- so it stays the fallback, and it stays the iron, which is
## the club those numbers always were. Callers that care about the difference
## pass a ClubProfile; callers that only want *a* ball flight need not.
static func default_club() -> ClubProfile:
	return ClubProfile.iron()


static func _resolve(club: ClubProfile) -> ClubProfile:
	return club if club != null else default_club()


static func gravity() -> Vector3:
	return Vector3(0.0, -float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)), 0.0)


## `putting` is kept for callers that only know "this is a putt" and not which
## club that is; naming a putter ClubProfile does the same thing. Both routes
## end at the same numbers.
static func launch_velocity(heading: Vector3, power: float, putting := false,
		club: ClubProfile = null) -> Vector3:
	var profile := _resolve(club)
	if putting and not profile.is_putter:
		profile = ClubProfile.putter()
	var flat := Vector3(heading.x, 0.0, heading.z).normalized()
	var speed := lerpf(profile.min_speed, profile.max_speed, clampf(power, 0.0, 1.0))
	if profile.is_putter:
		return flat * speed
	# flat x UP is the shot's own right-hand side, and a positive rotation about
	# it lifts the ball. Negating here fires the stroke into the turf, which the
	# ball survives by skipping -- close enough to a golf shot to hide the bug.
	var axis := flat.cross(Vector3.UP).normalized()
	return flat.rotated(axis, deg_to_rad(profile.launch_deg)) * speed


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
static func curve_acceleration(heading: Vector3, curve: float,
		club: ClubProfile = null) -> Vector3:
	var profile := _resolve(club)
	var flat := Vector3(heading.x, 0.0, heading.z).normalized()
	var right := flat.cross(Vector3.UP).normalized()
	return right * (clampf(curve, -1.0, 1.0) * profile.curve_accel)


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
