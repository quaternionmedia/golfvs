class_name AimRibbon
extends MultiMeshInstance3D
## The aim ribbon: the first breath of the shot, and nothing more.
##
## §2.1 wants a preview that tells the truth about physics. It does not want a
## dotted line into the cup -- a full arc turns every hole into a solved
## equation and deletes the read, which is the part worth playing. So the ribbon
## draws only the opening VISIBLE_FRACTION of the flight and fades to nothing
## inside that.
##
## What survives the truncation is exactly what the gesture is choosing: the
## line it leaves on, how hard, and which way it is starting to bend. Where it
## lands stays the player's problem.
##
## The stub is a fraction of arc *length*, not of time, so a harder shot shows a
## longer streak. Power is legible without a number attached to it.

const VISIBLE_FRACTION := 0.07
## What an archer gets instead. A golfer is denied the landing point on purpose
## -- judging distance is the game -- but an archer *sights*, and a bow whose
## line stops a metre past the arrow is a bow with no sights on it. It is still
## not the whole flight, and it still says nothing about where the ball will be,
## which is the read that actually decides the shot.
const SIGHTED_FRACTION := 0.62
const DOTS := 16
const SAMPLE_DT := 0.012
const MAX_SAMPLES := 900

## A flat line in the aim plane, saying which way and nothing else.
##
## The stub above says *shape*, and shape is drawn in the air, where perspective
## is doing the most work -- at a low camera angle a short 3D arc is a smudge
## pointing at nothing in particular. The first pre-alpha feedback asked for
## "more live side-to-side feedback", and this is it: a line lying in the same
## plane the aim lives in cannot be foreshortened out of legibility, because the
## player is looking at that plane already.
##
## **Fixed length on purpose.** It says direction and refuses to say distance,
## which keeps §2.1's bargain -- where it lands stays the player's problem.
const GROUND_DOTS := 10
const GROUND_REACH := 4.2

## How far a putt would run, previewed as roll rather than as flight.
##
## A putt has no arc. Sampled as a projectile it lands within a metre, so the
## VISIBLE_FRACTION stub of it came to about six centimetres and the club that
## most needs a distance read had no preview at all -- reported in the first
## pre-alpha feedback as simply missing. Rolling it out along the ground applies
## exactly the same rule, "a fraction of the path travelled", to a path that is
## a line instead of a parabola.
const ROLL_SAMPLES := 48

const CLEAR := Color("21d4ff")
const BLOCKED := Color("ff7a2f")

var _blocked := false


func _ready() -> void:
	var dot := SphereMesh.new()
	dot.radius = 0.17
	dot.height = 0.34
	dot.radial_segments = 8
	dot.rings = 4

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Not additive. Added light disappears against a sunlit fairway, which is
	# exactly where the ribbon has to be readable.
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 1.6
	dot.material = mat

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = dot
	multimesh.instance_count = DOTS + GROUND_DOTS
	# The dots are written in world space while this node sits at the origin, so
	# the automatically-derived bounds do not contain them and the whole batch
	# gets frustum-culled. A generous manual box is the documented way out.
	custom_aabb = AABB(Vector3(-500.0, -50.0, -500.0), Vector3(1000.0, 200.0, 1000.0))
	visible = false


## `blocked` is decided by the caller against the real world, then said in
## colour. With only a stub on screen, colour is the only channel left for "this
## line does not get there" -- which is how the curve beat teaches itself.
func show_arc(origin: Vector3, velocity: Vector3, accel: Vector3, ground_y: float,
		blocked := false, fraction := VISIBLE_FRACTION, ground_line := true) -> void:
	var path := _dense_arc(origin, velocity, accel, ground_y)
	_show_path(origin, path, blocked, fraction, ground_line)


## A putt, previewed as what it is. Straight, in the plane the ball is already
## rolling in, and truncated by the same fraction as everything else.
func show_roll(origin: Vector3, heading: Vector3, distance: float,
		blocked := false) -> void:
	var flat := Vector3(heading.x, 0.0, heading.z)
	if flat.length() < 0.0001 or distance <= 0.0:
		visible = false
		return
	flat = flat.normalized()
	var path := PackedVector3Array()
	for i in ROLL_SAMPLES + 1:
		path.append(origin + flat * (distance * float(i) / float(ROLL_SAMPLES)))
	_show_path(origin, path, blocked, VISIBLE_FRACTION, true)


func _show_path(origin: Vector3, path: PackedVector3Array, blocked: bool,
		fraction: float, ground_line: bool) -> void:
	_blocked = blocked
	if path.size() < 2:
		visible = false
		return

	var stub := _leading_fraction(path, fraction)
	if stub.size() < 2:
		visible = false
		return

	var tint := BLOCKED if blocked else CLEAR
	for i in DOTS:
		# Resample the stub evenly so the dots are spaced by distance, not by
		# the integrator's timestep.
		var along := float(i) / float(DOTS - 1)
		var point := _at_fraction(stub, along)
		var xform := Transform3D(Basis.IDENTITY, point)
		# Taper: fat and bright at the ball, gone by the end of the stub.
		var taper := 1.0 - along
		xform = xform.scaled_local(Vector3.ONE * (0.45 + 0.55 * taper))
		multimesh.set_instance_transform(i, xform)
		multimesh.set_instance_color(i, Color(tint, pow(taper, 1.35)))
	# The direction line, in the aim plane, after the arc's own dots.
	var heading := stub[stub.size() - 1] - origin
	heading.y = 0.0
	for i in GROUND_DOTS:
		var slot := DOTS + i
		if not ground_line or heading.length() < 0.0001:
			# Parked at zero scale rather than left holding the last frame's
			# transform: a multimesh has no way to draw fewer instances.
			multimesh.set_instance_transform(slot, Transform3D().scaled(Vector3.ZERO))
			continue
		var along := float(i + 1) / float(GROUND_DOTS)
		var point := origin + heading.normalized() * (GROUND_REACH * along)
		var mark := Transform3D(Basis.IDENTITY, point)
		mark = mark.scaled_local(Vector3.ONE * (0.42 - 0.22 * along))
		multimesh.set_instance_transform(slot, mark)
		multimesh.set_instance_color(slot, Color(tint, 0.5 * (1.0 - along * 0.7)))

	visible = true
	if OS.is_stdout_verbose():
		print("ribbon: %d pts, stub %d, first %v" % [path.size(), stub.size(), stub[0]])


func hide_arc() -> void:
	visible = false


func _dense_arc(origin: Vector3, velocity: Vector3, accel: Vector3,
		ground_y: float) -> PackedVector3Array:
	return BallFlight.sample_arc(origin, velocity, accel, ground_y, MAX_SAMPLES, SAMPLE_DT)


## The leading slice of a polyline, measured by distance travelled along it.
func _leading_fraction(path: PackedVector3Array, fraction: float) -> PackedVector3Array:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
	var budget := total * fraction
	var out := PackedVector3Array([path[0]])
	var walked := 0.0
	for i in range(1, path.size()):
		var step := path[i].distance_to(path[i - 1])
		if walked + step >= budget:
			var t := 0.0 if step == 0.0 else (budget - walked) / step
			out.append(path[i - 1].lerp(path[i], t))
			break
		walked += step
		out.append(path[i])
	return out


func _at_fraction(path: PackedVector3Array, fraction: float) -> Vector3:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
	if total <= 0.0:
		return path[0]
	var target := total * clampf(fraction, 0.0, 1.0)
	var walked := 0.0
	for i in range(1, path.size()):
		var step := path[i].distance_to(path[i - 1])
		if walked + step >= target:
			var t := 0.0 if step == 0.0 else (target - walked) / step
			return path[i - 1].lerp(path[i], t)
		walked += step
	return path[path.size() - 1]
