extends Node3D
## "The Handshake" -- the intro hole, and the menu screen's background state.
##
## The hole is not a level behind the menu; it IS the menu. Pillar 3 says no
## menus between the urge to play and the first swing, so the first screen has
## no buttons on it: the ball sits there pulsing, and touching it starts the
## game. Everything a first-timer needs to learn is taught by where the ground
## is and what glows, never by a word.
##
## Par 4, and three ideas -- power, then curve, then the putt -- one per lesson
## rather than one per stroke. The par is deliberately a stroke longer than the
## lesson count: PAR below says why.

const TEE_POS := Vector3(0.0, 0.35, 0.0)
const LANDING := Vector3(0.0, 0.0, -24.0)
const GREEN_POS := Vector3(9.0, 0.0, -56.0)
const CUP_POS := Vector3(9.0, 0.0, -57.0)
## Placed so the flag is visible from the tee but hidden from the landing zone.
## That asymmetry is the whole lesson: the player sees where they are going,
## walks up to the ball, and finds the straight line gone. The answer is the
## curve, and they are shown it exactly when they need it and not before.
const SPIRE_POS := Vector3(2.2, 3.5, -38.0)
const SPIRE_SIZE := Vector3(5.4, 7.0, 3.4)

## Chunky enough to follow across 56 m of fairway. A regulation 43 mm ball is a
## few pixels at this range; §5's caricatured direction is the licence to round
## it up rather than fight the camera.
const BALL_RADIUS := 0.18
const BALL_MASS := 0.045

## The hole's id in records. "<biome>/<nn>", stable for the life of the hole.
const HOLE_ID := "intro/01"

## The archer, and the edge of the world it guards (ADR-015).
##
## It stands off the right of the green, in view from most of the hole, and it
## shoots exactly one thing: a ball whose flight would carry it off the course.
## Every good shot it watches without moving. That is what makes the intro hole
## unfailable -- a beginner's characteristic disaster is spraying the ball off
## the map, and an out-of-bounds penalty is the harshest rule in golf arriving
## first.
##
## The bounds are drawn wide enough to contain every shot the hole asks for and
## the trees that frame it, and tight enough that a badly mis-aimed full drive
## reaches them: x from -19 to 29, z from -77 to 11, against a corridor 18 m
## wide and a hole 57 m long. Measured rather than guessed -- at 24 m either
## side, a full drive pulled 25 degrees off line is still in play and one pulled
## 35 degrees is not, which is about where a shot stops being recoverable.
const ARCHER_STAND := Vector3(15.5, 0.0, -49.0)
const BOUNDS_CENTRE := Vector3(5.0, 0.0, -33.0)
const BOUNDS_EXTENT := Vector2(24.0, 44.0)

## Sampling step for the arc the defenders read. Finer than the 0.075 s the
## ribbon uses, because it decides *when* a shot is fired at.
const DEFENDER_DT := 0.02

var camera: Camera3D
var ball: RigidBody3D
var cup_beacon: Beacon

var _orbit := 0.0


func _ready() -> void:
	_build_environment()
	_build_terrain()
	_build_props()
	_build_ball()
	_setup_play()


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4f9fd4")
	sky_material.sky_horizon_color = Color("cfe9f5")
	sky_material.ground_bottom_color = Color("3d5f38")
	sky_material.ground_horizon_color = Color("cfe9f5")
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# Low ambient, strong sun. The chunky low-poly forms only read if their
	# facets differ, and flat sky light erases exactly that.
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	# The beacons are additive and unshaded; glow is what turns them from bright
	# decals into light. Without it the whole signalling language falls flat.
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.85
	# Depth cue and edge-hider in one: the corridor recedes into haze instead of
	# stopping at the rim of a slab. Depth-mode with a far start, so the fog
	# hides the horizon without touching the ground the player is aiming at --
	# exponential fog washed the whole hole out.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("b9d6e6")
	env.fog_density = 0.55
	env.fog_depth_begin = 95.0
	env.fog_depth_end = 320.0
	env.fog_sky_affect = 0.0

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(38.0), 0.0)
	sun.light_energy = 1.12
	sun.light_color = Color("fff4dd")
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 58.0
	add_child(camera)


func _build_terrain() -> void:
	var ground := StaticBody3D.new()
	add_child(ground)
	HoleBuilder.slab(ground, Vector3(420.0, 1.0, 460.0), HoleBuilder.ROUGH, Vector3(0.0, -0.5, -40.0))
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(420.0, 1.0, 460.0)
	ground_shape.shape = box
	ground_shape.position = Vector3(0.0, -0.5, -40.0)
	ground.add_child(ground_shape)

	HoleBuilder.slab(self, Vector3(18.0, 0.08, 58.0), HoleBuilder.FAIRWAY, Vector3(0.0, 0.02, -27.0))
	# Mown stripes. Almost free, and they do real work: they give the corridor a
	# sense of distance and make the fairway read as tended ground rather than a
	# green rectangle.
	for i in 10:
		var z := -2.5 - float(i) * 5.6
		HoleBuilder.slab(self, Vector3(18.0, 0.02, 2.8), HoleBuilder.FAIRWAY_MOWN,
			Vector3(0.0, 0.07, z))
	# Two centimetres proud of the fairway: enough that its collider, not the
	# rough beneath it, is what the ball putts on, and low enough that a ball
	# rolls onto it instead of stopping against its edge.
	HoleBuilder.green(self, 9.0, GREEN_POS)
	# A short apron linking the corridor to the off-axis green, so the dogleg
	# reads as one hole rather than two disconnected patches of mown grass.
	var apron := HoleBuilder.slab(self, Vector3(14.0, 0.08, 17.0), HoleBuilder.FAIRWAY,
		Vector3(6.0, 0.02, -48.0))
	apron.rotation.y = deg_to_rad(-20.0)
	HoleBuilder.disc(self, 2.2, 0.16, HoleBuilder.TEE, Vector3(0.0, 0.05, 0.0), 20)
	HoleBuilder.disc(self, 3.6, 0.10, HoleBuilder.SAND, Vector3(1.5, 0.03, -54.0), 20)
	HoleBuilder.disc(self, 0.5, 0.10, HoleBuilder.CUP, CUP_POS + Vector3(0.0, 0.06, 0.0), 16)


func _build_props() -> void:
	HoleBuilder.spire(self, SPIRE_POS, SPIRE_SIZE)

	# Trees frame the corridor and hide the world's edge. Asymmetric on purpose:
	# a corridor that reads as hand-placed rather than as a tunnel.
	var spots := [
		[-13.0, -8.0, 4.6, 0.05], [-15.0, -19.0, 5.4, -0.04], [-12.5, -31.0, 4.0, 0.07],
		[-16.0, -44.0, 6.0, 0.0], [-13.5, -57.0, 4.8, -0.06],
		[13.0, -6.0, 5.0, -0.05], [15.5, -17.0, 4.2, 0.06], [13.5, -29.0, 5.8, 0.0],
		[21.0, -42.0, 4.4, -0.07], [22.5, -56.0, 5.2, 0.04], [21.0, -68.0, 6.2, 0.0],
		[-9.0, -62.0, 5.0, -0.05], [-4.0, -72.0, 5.6, 0.03], [13.0, -78.0, 4.8, -0.03],
	]
	for s in spots:
		HoleBuilder.tree(self, Vector3(s[0], 0.0, s[1]), s[2], s[3])

	HoleBuilder.flag(self, CUP_POS)

	cup_beacon = Beacon.new()
	cup_beacon.radius = 1.9
	cup_beacon.color = Beacon.CUP
	cup_beacon.position = CUP_POS
	add_child(cup_beacon)


func _build_ball() -> void:
	ball = RigidBody3D.new()
	ball.mass = BALL_MASS
	ball.continuous_cd = true
	ball.position = TEE_POS
	add_child(ball)

	var sphere := SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("fdfdf6")
	mat.roughness = 0.35
	# A little self-emission keeps the ball readable against the dark boulder
	# and in the shadow of the trees, without turning it into a lamp.
	mat.emission_enabled = true
	mat.emission = Color("fdfdf6")
	mat.emission_energy_multiplier = 0.25
	mi.material_override = mat
	ball.add_child(mi)

	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = BALL_RADIUS
	shape.shape = sphere_shape
	ball.add_child(shape)


# ---------------------------------------------------------------- state ------

enum State { ATTRACT, AIM, FLIGHT, HOLED }
## Which idea this stroke is about. Chosen from where the ball actually lies,
## never from a step counter -- see _lesson_for().
enum Lesson { POWER, CURVE, PUTT }

signal lesson_changed(lesson: Lesson)
signal state_changed(state: State)
signal stroke_began
signal stroke_taken(strokes: int)
signal holed(strokes: int)

## Set from what the hole actually plays, not from its length: tee shot,
## approach around the spire, pitch on, one putt. §2.4 makes the scorecard the
## only result in the game, so the first one a player ever sees should read par
## for playing it the way it was designed to be played -- not punish them for
## the two-putt every beginner takes.
const PAR := 4
const SETTLE_SPEED := 0.5
const SETTLE_TIME := 0.35
const CUP_CATCH_RADIUS := 1.0
const CUP_CATCH_SPEED := 3.2
const GREEN_RADIUS := 9.0
## Light. The green's own friction does most of the stopping now, and a heavy
## damp on top of it made every putt dribble.
const ROLL_DAMP := 0.45

var state := State.ATTRACT
var lesson := Lesson.POWER
var strokes := 0

var _gesture: StrokeGesture
var _ribbon: AimRibbon
var _target: Beacon
var _spire_aabb: AABB
var _still_for := 0.0
var _cam_target := Transform3D.IDENTITY
var _aiming := false
var _curve_accel := Vector3.ZERO

## Set false to play the hole as plain golf -- the Scottish Rules control group
## (§4). Every hole must be a good golf hole before it is a good golfVs hole,
## and this is the switch that lets someone check.
@export var defended := true

var _defenders: Array[Node3D] = []
var _round: Array[StrokeRecord] = []
var _record: StrokeRecord = null
var _round_seed := 0
var _stroke_seed := 0

## Where the finished round was written. Empty until the ball drops.
var round_path := ""


func _setup_play() -> void:
	_spire_aabb = AABB(SPIRE_POS - SPIRE_SIZE * 0.5, SPIRE_SIZE).grow(BALL_RADIUS)
	# Drawn once per round and written into every Stroke Record, so a round can
	# be replayed exactly and a shared one plays the same on the other phone.
	_round_seed = randi()
	_build_defenders()

	_ribbon = AimRibbon.new()
	add_child(_ribbon)

	_target = Beacon.new()
	_target.radius = 3.2
	add_child(_target)

	_gesture = StrokeGesture.new()
	_gesture.camera = camera
	add_child(_gesture)
	_gesture.began.connect(_on_gesture_began)
	_gesture.aim_updated.connect(_on_aim_updated)
	_gesture.fired.connect(_on_fired)
	_gesture.cancelled.connect(_on_cancelled)

	_enter_aim()
	# The first press both starts the game and starts the stroke. Nothing sits
	# between the two -- Pillar 3.
	state = State.ATTRACT


func _on_cancelled() -> void:
	_ribbon.hide_arc()


func _enter_aim() -> void:
	state = State.AIM
	_aiming = true
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	_gesture.enabled = true

	lesson = _lesson_for(ball.global_position)
	_target.position = _aim_point()
	_target.resume()
	_target.radius = 1.3 if lesson == Lesson.PUTT else 3.2
	_target.visible = lesson != Lesson.PUTT
	lesson_changed.emit(lesson)
	state_changed.emit(state)


## The hole reads the lie and decides what this stroke is for. A player who tops
## the tee shot gets the power lesson again; one who somehow drives the green
## skips to the putt. The tutorial cannot fall out of step with the player,
## because there is no step to fall out of.
func _lesson_for(from: Vector3) -> Lesson:
	if Vector2(from.x - GREEN_POS.x, from.z - GREEN_POS.z).length() <= GREEN_RADIUS:
		return Lesson.PUTT
	if _line_blocked(from, CUP_POS):
		return Lesson.CURVE
	return Lesson.POWER


## Where this stroke is asking to be sent. The power lesson points at a landing
## zone short of the spire; everything else points at the flag.
func _aim_point() -> Vector3:
	if lesson == Lesson.POWER and ball.global_position.z > LANDING.z + 6.0:
		return LANDING
	return CUP_POS


func _line_blocked(from: Vector3, to: Vector3) -> bool:
	var a := Vector3(from.x, 1.0, from.z)
	var b := Vector3(to.x, 1.0, to.z)
	# intersects_segment answers with the hit point, or null for a miss -- it is
	# not a predicate, however much its name reads like one.
	return _spire_aabb.intersects_segment(a, b) != null


func _arc_blocked(points: PackedVector3Array) -> bool:
	for i in range(1, points.size()):
		if _spire_aabb.intersects_segment(points[i - 1], points[i]) != null:
			return true
	return false


# -------------------------------------------------------------- defenders ----

func _build_defenders() -> void:
	if not defended:
		return
	var profile := DefenderProfile.archer(ARCHER_STAND, BOUNDS_CENTRE, BOUNDS_EXTENT)
	# Unerring, not standard. `standard()` carries an accuracy multiplier of 0.7,
	# which quietly turned the safety net into a coin flip -- the profile's own
	# base_accuracy of 1.0 was being multiplied down and the archer missed three
	# wild shots in ten. A player cannot tell "the archer missed" from "the
	# archer does not cover that", so it does not miss.
	var archer := Archer.with_profile(profile, DifficultyTier.unerring(), "archery_0")
	add_child(archer)
	_defenders.append(archer)


func _defender_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for shooter in _defenders:
		entries.append(shooter.brain.to_record_entry())
	return entries


## What connecting does to the ball, by the profile's action. Applied as an
## impulse from the action rather than as a collision with the defender's mesh,
## per §6.4 -- animated colliders are flaky and nondeterministic, and
## determinism is what the whole record format rests on.
func _on_defender_acted(defender: Node3D) -> void:
	var brain: DefenderBrain = defender.brain
	if not brain.will_connect():
		return
	_curve_accel = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	match brain.profile.action:
		DefenderProfile.Action.PIN:
			# "Stops dead where the arrow reaches it" (§3). The ball is moved to
			# the point the archer committed to rather than left where the tick
			# happens to have put it, so what the player saw the thread pointing
			# at is where the ball ends up.
			ball.global_position = brain.act_point()
			ball.linear_velocity = Vector3.ZERO
		_:
			# KNOCK_DOWN: horizontal motion stops and gravity does the rest.
			ball.linear_velocity = Vector3(0.0, minf(ball.linear_velocity.y, 0.0), 0.0)


# ---------------------------------------------------------------- records ----

## A different hole is a different hash whatever the id says (§2.1), so this
## covers the geometry a stroke's outcome actually depends on.
func _layout_hash() -> String:
	return Canonical.hash_of({
		"tee": Canonical.vec3_array(TEE_POS),
		"cup": Canonical.vec3_array(CUP_POS),
		"green": [Canonical.vec3_array(GREEN_POS), GREEN_RADIUS],
		"spire": [Canonical.vec3_array(SPIRE_POS), Canonical.vec3_array(SPIRE_SIZE)],
		"bounds": [Canonical.vec3_array(BOUNDS_CENTRE), BOUNDS_EXTENT.x, BOUNDS_EXTENT.y],
		"par": PAR,
		"defended": defended,
	}).substr(0, 16)


## One seed per stroke, derived from the round's. Storing the derivation rather
## than a fresh draw means a whole round replays from a single number, and a
## fork from stroke 3 gets the same defender rolls the original did.
func _seed_for_stroke(number: int) -> int:
	return hash("%d:%d" % [_round_seed, number])


## Which surface the ball is sitting on, in the schema's vocabulary. Read off
## the same constants the geometry is built from, so the two cannot drift.
func _lie_at(at: Vector3) -> String:
	if absf(at.x - BOUNDS_CENTRE.x) > BOUNDS_EXTENT.x 			or absf(at.z - BOUNDS_CENTRE.z) > BOUNDS_EXTENT.y:
		return "ob"
	if Vector2(at.x - GREEN_POS.x, at.z - GREEN_POS.z).length() <= GREEN_RADIUS:
		return "green"
	if Vector2(at.x - 1.5, at.z + 54.0).length() <= 3.6:
		return "sand"
	if Vector2(at.x, at.z).length() <= 2.2:
		return "tee"
	if absf(at.x) <= 9.0 and at.z <= 2.0 and at.z >= -56.0:
		return "fairway"
	return "rough"


## Close the open record with where the ball finished and what the defenders
## did. Called once per stroke, whether it settled or went in.
func _finish_stroke(extra := "") -> void:
	if _record == null:
		return
	var events := PackedStringArray()
	for shooter in _defenders:
		events.append_array(shooter.brain.events())
	if extra != "":
		events.append(extra)
	_record.resolve(ball.global_position, _lie_at(ball.global_position), events)
	_round.append(_record)
	_record = null
	for shooter in _defenders:
		shooter.rest()


func _save_round() -> String:
	if _round.is_empty():
		return ""
	return RecordStore.save_round(HOLE_ID, _layout_hash(), _round_seed, PAR, _round)


## The round so far, as §4.1 notation. Derived; never parsed back.
func round_notation() -> String:
	return RecordStore.notation(_round)


# ----------------------------------------------------------------- input -----

func _on_gesture_began() -> void:
	stroke_began.emit()
	if state == State.ATTRACT:
		state = State.AIM
		state_changed.emit(state)


func _on_aim_updated(heading: Vector3, power: float, curve: float) -> void:
	if not _aiming:
		return
	if power <= 0.0:
		_ribbon.hide_arc()
		return
	var putting := lesson == Lesson.PUTT
	var origin := ball.global_position
	var velocity := BallFlight.launch_velocity(heading, power, putting)
	var accel := BallFlight.curve_acceleration(heading, curve)
	var arc := BallFlight.sample_arc(origin, velocity, accel, BALL_RADIUS)
	_ribbon.show_arc(origin, velocity, accel, BALL_RADIUS, _arc_blocked(arc))


func _on_fired(heading: Vector3, power: float, curve: float) -> void:
	if not _aiming:
		return
	_aiming = false
	_gesture.enabled = false
	_ribbon.hide_arc()
	_target.confirm()

	var putting := lesson == Lesson.PUTT
	# The gesture's raw numbers stop here. From this line on the stroke is
	# played from the intent's quantized ones, which are also the ones written
	# to disk -- so a replay feeds the simulation the identical inputs rather
	# than ones that merely round to the same text (records/canonical.gd).
	# The club is a placeholder. `intent.club` is in the frozen schema and has to
	# hold *something*, but three clubs plus an auto-putter is still unratified
	# and `ClubProfile` does not exist -- BallFlight has one set of speeds for
	# every full shot. So every non-putt records as an iron, which is honest
	# about there being one club rather than inventing a mapping from power to
	# club name that no simulation is behind. A caller that passes a different
	# club is deliberately ignored, not silently honoured.
	var intent := ShotIntent.make(
		ShotIntent.Club.PUTTER if putting else ShotIntent.Club.IRON,
		power, curve, heading)

	var origin := ball.global_position
	var velocity := BallFlight.launch_velocity(intent.direction, intent.power, putting)
	_curve_accel = BallFlight.curve_acceleration(intent.direction, intent.curve)

	strokes += 1
	_stroke_seed = _seed_for_stroke(strokes)
	_record = StrokeRecord.opened(
		HOLE_ID, _layout_hash(), _stroke_seed, strokes, origin, _lie_at(origin), intent)
	_record.defenders = _defender_entries()

	# The defenders read the flight the ball is *about* to take. That arc is
	# computed from the ball's position and velocity at release and from nothing
	# else -- no intent, no club, no gesture -- which is how §3's "act on the
	# ball's actual state, never on input before release" is kept true while
	# still leaving time for a tell.
	var arc := BallFlight.sample_arc(
		origin, velocity, _curve_accel, BALL_RADIUS, 900, DEFENDER_DT)
	for shooter in _defenders:
		shooter.read_shot(arc, DEFENDER_DT, _stroke_seed)

	ball.freeze = false
	ball.linear_damp = ROLL_DAMP if putting else 0.0
	ball.angular_damp = 1.4
	ball.linear_velocity = velocity

	stroke_taken.emit(strokes)
	state = State.FLIGHT
	_still_for = 0.0
	state_changed.emit(state)


func _physics_process(delta: float) -> void:
	if state != State.FLIGHT:
		return

	# Stepped on the physics tick, not on the frame, so what the defender does
	# is a function of the same fixed 60 Hz the ball is integrated on and does
	# not change with frame rate.
	for shooter in _defenders:
		if shooter.advance(delta):
			_on_defender_acted(shooter)

	var airborne := ball.global_position.y > BALL_RADIUS * 1.8
	if airborne:
		# Sidespin, as a constant lateral push while the ball is in the air --
		# exactly what the ribbon integrated, so the shot goes where it said.
		ball.apply_central_force(_curve_accel * ball.mass)
		ball.linear_damp = 0.0
	else:
		ball.linear_damp = ROLL_DAMP

	if _try_hole_out():
		return

	if ball.linear_velocity.length() < SETTLE_SPEED:
		_still_for += delta
		if _still_for >= SETTLE_TIME:
			_finish_stroke()
			_enter_aim()
	else:
		_still_for = 0.0


func _try_hole_out() -> bool:
	var flat := Vector2(ball.global_position.x - CUP_POS.x, ball.global_position.z - CUP_POS.z)
	if flat.length() > CUP_CATCH_RADIUS or ball.linear_velocity.length() > CUP_CATCH_SPEED:
		return false
	state = State.HOLED
	ball.freeze = true
	_gesture.enabled = false
	_ribbon.hide_arc()
	cup_beacon.confirm()
	_target.visible = false
	# Closed before the drop tween runs, so the record holds where the ball
	# actually finished rather than where the flourish puts it.
	_finish_stroke("holed")
	round_path = _save_round()
	_celebrate()

	var drop := create_tween()
	drop.tween_property(ball, "global_position", CUP_POS + Vector3(0.0, -0.25, 0.0), 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	holed.emit(strokes)
	state_changed.emit(state)
	return true


## The only flourish in the game so far, and it is spent on the one moment that
## has to land: the ball disappearing. No words, no panel -- just the cup
## throwing light back up at the player.
func _celebrate() -> void:
	var spark := SphereMesh.new()
	spark.radius = 0.09
	spark.height = 0.18
	spark.radial_segments = 6
	spark.rings = 3
	spark.material = HoleBuilder.glow(Beacon.CUP, 6.0)

	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 38.0
	process.initial_velocity_min = 5.0
	process.initial_velocity_max = 10.0
	process.gravity = Vector3(0.0, -11.0, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.4
	process.color = Beacon.CUP

	var burst := GPUParticles3D.new()
	burst.draw_pass_1 = spark
	burst.process_material = process
	burst.amount = 70
	burst.lifetime = 1.7
	burst.one_shot = true
	burst.explosiveness = 0.92
	burst.position = CUP_POS + Vector3(0.0, 0.25, 0.0)
	add_child(burst)
	burst.emitting = true


# ---------------------------------------------------------------- camera -----

func _process(delta: float) -> void:
	match state:
		State.ATTRACT:
			_orbit += delta * 0.14
			_frame_attract()
			return
		State.AIM:
			_cam_target = _frame_aim()
		State.FLIGHT:
			_cam_target = _frame_flight()
		State.HOLED:
			_orbit += delta * 0.25
			_cam_target = _frame_holed()
	# One damped follow for every played state, so a change of beat reads as the
	# camera walking up to the ball rather than as a hard cut.
	camera.global_transform = camera.global_transform.interpolate_with(
		_cam_target, clampf(delta * 3.4, 0.0, 1.0))


func _look_from(eye: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, _clear_of_scenery(eye)).looking_at(at, Vector3.UP)


## Lifts the camera over anything solid it would otherwise sit inside. The curve
## beat puts the ball close behind the spire, which is exactly where the shot
## camera wants to stand, and a viewpoint inside a rock shows the player the
## inside of a rock.
func _clear_of_scenery(eye: Vector3) -> Vector3:
	var blocked := _spire_aabb.grow(1.2)
	if not blocked.has_point(eye):
		return eye
	return Vector3(eye.x, blocked.end.y + 1.0, eye.z)


func _frame_aim() -> Transform3D:
	var to_target := _aim_point() - ball.global_position
	to_target.y = 0.0
	var dir := to_target.normalized() if to_target.length() > 0.01 else Vector3.FORWARD
	if lesson == Lesson.PUTT:
		return _look_from(
			ball.global_position - dir * 4.6 + Vector3.UP * 2.1,
			ball.global_position + dir * 3.0 + Vector3.UP * 0.15)
	return _look_from(
		ball.global_position - dir * 8.0 + Vector3.UP * 3.4,
		ball.global_position + dir * 13.0 + Vector3.UP * 1.0)


func _frame_flight() -> Transform3D:
	var vel := ball.linear_velocity
	vel.y = 0.0
	var back := -vel.normalized() if vel.length() > 0.5 else Vector3.BACK
	return _look_from(
		ball.global_position + back * 9.0 + Vector3.UP * 4.4,
		ball.global_position + Vector3.UP * 0.6)


func _frame_holed() -> Transform3D:
	var eye := CUP_POS + Vector3(sin(_orbit) * 9.0, 4.6, cos(_orbit) * 9.0)
	return _look_from(eye, CUP_POS + Vector3.UP * 1.2)


func _frame_attract() -> void:
	var drift := sin(_orbit) * 5.0
	camera.position = Vector3(drift, 5.2, 11.0)
	camera.look_at(Vector3(3.0 + drift * 0.25, 1.4, -36.0))
