class_name PracticeRange
extends Node3D
## A private range with three pins, one for each club.
##
## This replaces "The Handshake", the par-4 dogleg that used to be the first
## thing a player saw. That hole taught power, then shaping, then the putt, and
## it taught them all with one club -- because until now there *was* only one
## club, wearing three different names in the record.
##
## A range teaches the thing the game actually turns on. Three pins at three
## distances, a club that changes with the pin, and unlimited balls: the player
## learns what each club does by hitting it at something, which is how anybody
## has ever learned it. It also puts the first screen squarely on M1's gate --
## *is it fun to hit balls at nothing, on a phone?* -- rather than on a hole
## that answers a later question.
##
## Nothing here is scored against par. A range is not a hole: you are done with
## a pin when you have put a ball on it, and the strokes it took are counted but
## never held against you. The one failure state golf has -- losing a ball -- is
## caught by the archer (ADR-015), so the range cannot be failed either.

const BAY_POS := Vector3(0.0, 0.35, 0.0)
const BALL_RADIUS := 0.18
const BALL_MASS := 0.045

const HOLE_ID := "range/01"

## The three pins, one for each club, met in the order a beginner meets them:
## a putt you cannot miss, a pitch, and a full swing.
##
## Fanned to alternating sides on purpose: three targets in a line differ only by
## distance, and distance is the hardest thing to read on a flat plane. Off-axis,
## each one is a different *aim* as well as a different club, and they stop
## reading as one target at three sizes.
##
## `suggests` is the club the range hands you when the pin comes up. It is a
## suggestion and not a rule -- the player can change club at any time, and
## finding out what happens when you take the long club to the putting pin is a
## perfectly good way to learn what the long club is.
##
## Distances sit a little short of each club's reach, so a full swing is slightly
## too much and there is something to judge. `test_practice_range.gd` asserts
## that relationship rather than these numbers, because the numbers move whenever
## a club is retuned.
const PINS := [
	{"suggests": "putt", "at": Vector3(2.5, 0.0, -6.0), "radius": 2.6},
	{"suggests": "short", "at": Vector3(-6.0, 0.0, -21.0), "radius": 5.0},
	{"suggests": "long", "at": Vector3(9.0, 0.0, -70.0), "radius": 9.0},
]

## The order the pins come up in: **the ternary digits of π, after the point.**
## π = 10.010211012222…₃, so the range plays the putt, the short pin, the putt
## again, then the long one, and never the same three in a row twice.
##
## Why a constant and not a die (ADR-029). The range no longer ends — the golfer
## keeps golfing, and on the first run the golfer is the game — so *something*
## has to choose the next pin forever, and a random choice would be the one
## thing on this range that a record could not replay. π is deterministic, never
## repeats, is balanced across the three digits, and needs no seed to carry.
## Three hundred and sixty digits is about an hour of pins; past the end it
## wraps, which nobody will sit through and which is said here so that it is
## not a surprise when they do.
##
## Fractional digits rather than "10.", because the leading 1 is the number
## three and not a pin. The first digit is 0 — the putt — so a beginner still
## meets the pins putt-first, as ADR-017 asked; the long pin arrives fourth
## rather than third, which is the whole of what that decision gave up.
const PIN_ORDER := (
	"010211012222010211002111110221222220111201212121200121100100" +
	"101222022212012012111210121011200220120210000101022010020111" +
	"120002221022201100101110121101201010001000222021220110022122" +
	"210112222212102022011020121022202201202222120121200201112210" +
	"000112022001212201101110122210211002112122121211222122110212" +
	"212110100221202121011001210210011011102222020021111121010210"
)

## The mat, and the boundary the archer keeps.
const MAT_RADIUS := 3.0
const BOUNDS_CENTRE := Vector3(0.0, 0.0, -46.0)
const BOUNDS_EXTENT := Vector2(34.0, 62.0)
const PLAY_INSET := 2.0

## The contested range stands a shooter **halfway between the ball and the pin**
## rather than anywhere a designer picked. That is the whole mechanic: the
## defender is always on the line of play, at half the distance, so it cannot be
## walked around and it cannot be ignored. What it can be is gone under -- an
## archer owns the air above 2.5 m and nothing below it -- or shaped around,
## because accuracy falls off toward the rim of its zone.
##
## It is an **archer** and not the skeet, for reasons past the fact that this
## range already has one and the two should look like one another. ADR-015 keeps
## skeet as the M2 defender, and putting it here would settle that by accident.
## And archery is the sport §3 already gives two jobs -- "air, near green" as an
## adversary, and ADR-015's boundary net -- so contesting the line needed no new
## sport, no new brain and no new decision: `ArcherBrain` falls back to the apex
## trigger on its own as soon as it is not guarding a boundary.
##
## It also teaches itself in the order the range teaches the clubs. The first pin
## is a putt, a putt never leaves the ground, and a defender that owns only the
## air cannot touch the first shot a beginner ever plays. It introduces itself
## exactly when the player starts flying the ball, and not one stroke sooner.
const CONTEST_ZONE := 11.0
## Clear of the mat, whatever the arithmetic says. See `defender_stand()`.
const TEE_CLEARANCE := 2.0

## The bow, in the same three numbers a club is: the speed band a full draw
## spans, and the angle it leaves at. It goes through `BallFlight` exactly as a
## stroke does, which is not a shortcut -- it is the point. Both sides pull,
## release, and watch a thing they aimed travel under the same gravity, so the
## defence is learnable by anybody who has already learned the stroke.
##
## Fast, because the whole shot is a lead and a lead nobody can judge is a
## guess. At these speeds an arrow crosses forty metres in a third of a second,
## so the ball moves eight to twelve metres in the time it takes -- enough to be
## a real read, little enough to see.
##
## The draw is the *speed*, which makes it the lead: a harder pull arrives sooner
## and needs less lead. That is the choice this side of the game has, and it is
## the same shape as the golfer's -- how hard, and where.
const BOW_MIN_SPEED := 48.0
const BOW_MAX_SPEED := 104.0
## How near the arrow has to pass. Generous against a 0.18 m ball, because the
## blind spot is already modelled -- `can_reach` still has to agree, so the
## tolerance here is about the thickness of an arrow and not about the difficulty
## of the shot.
const ARROW_HIT := 1.6
## An arrow that hits nothing is gone. Longer than any flight it could catch, so
## the miss is always the player's and never the clock's.
const ARROW_LIFE := 3.0

## Where the marshal stands. On a tower off to the side, high enough to see the
## whole range and impossible to miss from the mat -- the same reasoning that
## put the archer on the spire, minus the spire.
const TOWER_POS := Vector3(22.0, 3.5, -30.0)
const TOWER_SIZE := Vector3(5.0, 7.0, 5.0)
const ARCHER_STAND := Vector3(TOWER_POS.x, TOWER_POS.y + TOWER_SIZE.y * 0.5, TOWER_POS.z)

const GUARD_MARGIN := 11.0
const STRIKE_MARGIN := 3.0
const DEFENDER_DT := 0.02

## The arrow, as a physical object: 26 g at 82 m/s. Against a 45 g ball that is
## a velocity change of about 47 m/s -- comfortably past the ball's own top
## speed, so the arrow does not merely arrest the shot, it reverses and buries
## it. These two numbers are where the weight of the hit lives.
const ARROW_MASS := 0.026
const ARROW_SPEED := 82.0
## Weighted toward the flight rather than the floor: burying the ball straight
## down spends the whole blow in one frame and it barely moves, while sending it
## back along its own line spends it as travel and carries the ball toward the
## middle of the range.
const ARROW_AGAINST_FLIGHT := 0.88
const ARROW_DOWNWARD := 0.48
const PINNED_DAMP := 2.1
const SHAKE_ON_HIT := 0.62

## How fast the flight camera may swing round to a new direction, in radians per
## second. It needs a limit because the ball can *reverse*: an arrow does exactly
## that, and a camera that recomputes "behind the ball" from the raw velocity
## teleports to the far side of it on the frame the arrow lands.
const TRAIL_TURN := 2.4
## How fast a defender is admitted into frame, and let go of again. Asymmetric on
## purpose: quick enough in that the tell is seen, slow enough out that coming
## back is not a second cut.
const THREAT_IN := 2.6
const THREAT_OUT := 0.9
## However far apart the ball and the defender actually are, the camera pulls
## back as though they were at most this far. Uncapped, a strike at the far end
## of the range threw the camera sixty metres backwards and then hauled it in
## again, which is most of what made an off-screen hit feel like a malfunction.
const THREAT_SPREAD := 30.0

const SETTLE_SPEED := 0.5
const SETTLE_TIME := 0.35
const ROLL_DAMP := 0.45
## Close enough to the pin to have actually holed it, rather than merely landed
## on the green. Worth its own celebration; worth nothing extra on the card.
const CUP_RADIUS := 1.1

enum State { ATTRACT, AIM, FLIGHT }

signal state_changed(state: State)
signal stroke_began
signal stroke_taken(strokes: int)
signal pin_changed(index: int)
signal club_changed(index: int)
signal pin_made(index: int, holed: bool)
signal finished(strokes: int)
## Which side the player is on. Emitted so the flat layer can follow rather than
## keep its own copy -- the same arrangement the club selector already has.
signal side_changed(defending: bool)

var camera: Camera3D
var ball: RigidBody3D

var state := State.ATTRACT
var strokes := 0
var pin := 0
## Pins made this session, and the cursor into `PIN_ORDER`. Every `PINS.size()`
## of them is a round: written to disk, then played straight through.
var pins_made := 0
## What is in the player's hands right now. Changed by them, suggested by the
## pin -- see `set_club()`.
var club_index := 0

## Where the last round a person played was written. A new file every
## `PINS.size()` pins; empty until the first one, and the range does not stop
## for any of them (ADR-029).
var round_path := ""

var _gesture: StrokeGesture
## The golfer, and the backswing that warns a defender a shot is coming. See
## `GolferFigure`: the ball is genuinely held for it.
var _golfer: GolferFigure
## The archer contesting the line, or null. Repositioned every lie by
## `_place_the_contender()`.
var _contender: Archer
## The boundary archer on the rock (ADR-015, ADR-016). A safety net, and the only
## defender the first run has -- and the player can pick it up, which is what
## `held()` is for.
var _guard: Archer
## ADR-001's orbit, as an offset on whatever the state below framed. The range
## still chooses what is worth looking at; this is the player choosing from
## where. See `_framed()`.
var _look: CameraOrbit
var _ribbon: AimRibbon
var _spin: SpinDial
var _beacons: Array[Beacon] = []
var _defenders: Array[Node3D] = []

## The strokes of the round in progress. Cleared when the round is written, so
## a file holds a round and not a session (ADR-029, revised): the first version
## wrote the whole session every round and an unattended range grew its own
## records quadratically -- gigabytes overnight.
var _round: Array[StrokeRecord] = []
## The round last written, for whoever wants to check the file against it.
var last_round: Array[StrokeRecord] = []
## Whether a person struck a ball in the round in progress. A round the game
## played against nobody is not written: the records are the player's, and an
## idle range writing files is a phone filling up for no one.
var _player_struck := false
var _record: StrokeRecord = null
var _round_seed := 0
var _stroke_seed := 0
var _last_in_bounds := Vector3.ZERO
var _pinned := false

## The struck-but-not-yet-launched ball. Between the stroke being committed and
## the club reaching it there is a real pause, and this is what is waiting in it.
var _held := false
var _pending := Vector3.ZERO
## Seconds into the swing, or -1 between swings.
var _swing_t := -1.0

## True when the player is the shooter and the game is the golfer. Both sides
## play the same range, against the same shooter, in the same view -- switching
## changes which end of the swing you are on and nothing else at all.
var _defending := false
## The hand-played arrow, mid-flight. Advanced on the physics tick with the ball,
## because the two have to be compared on the same clock or leading the target is
## a lie.
var _arrow_live := false
var _arrow_at := Vector3.ZERO
var _arrow_vel := Vector3.ZERO
var _arrow_from := Vector3.ZERO
var _arrow_age := 0.0

## Seconds until the game's golfer plays. It addresses the ball for a moment
## first, because a defender who is not given a still frame before the backswing
## has been given the shot and not the read.
var _ai_beat := 0.0
## True only while `_play_the_games_shot` is inside `_on_fired`. Both sides come
## through that one door and it has to know which is knocking.
var _ai_is_playing := false

var _still_for := 0.0
## Seconds since the player last touched anything: a drag, an orbit, a tap, a
## switch. Past `IDLE_AFTER` the camera stops standing where they left it and
## goes round the player instead (ADR-029, ADR-030). See `_framed()`.
var _idle_for := 0.0
## How far into the tour the camera is, 0 to 1, and how far round it has turned.
## Both continuous, both applied inside `_framed()`, so there is no frame on
## which the camera is anywhere the previous frame was not heading.
var _idle := 0.0
var _tour_yaw := 0.0
var _aiming := false
var _curve_accel := Vector3.ZERO
var _cam_target := Transform3D.IDENTITY
var _cam_smooth := Transform3D.IDENTITY
var _shake := 0.0
var _shake_t := 0.0
var _drift := 0.0
## Which way the flight camera is trailing from, eased rather than read straight
## off the velocity. See `_ease_the_flight_camera()`.
var _trail := Vector3.BACK
## How much of the frame the acting defender currently owns, 0 to 1, and where it
## was when it last owned any. The position is remembered so that letting go of a
## defender does not also lose the point the blend is easing away from.
var _threat := 0.0
var _threat_at := Vector3.ZERO

@export var defended := true
## Whether a second archer contests the line, in front of the boundary guard.
##
## **Off on the first run** (ADR-022). The tutorial has exactly one defender, the
## archer on the rock, and it is a safety net -- that is ADR-015's whole point,
## and a beginner meeting an adversary on the same screen meets two ideas at
## once. The contesting archer and the defence side it makes playable are for
## later holes, where the player already knows what a defender is.
##
## Toggle it with `set_contested()` rather than writing it after `_ready`: the
## archer is built, placed and torn down by that call, so the flag and the world
## cannot disagree.
@export var contested := false

## Which end of the swing the range opens on.
##
## Off here, because the range is a component and the golfer is its base case:
## every test and the demo round read it that way, and a range that woke up on
## defence would have made all of them lie. **The first run turns it on** in
## `main_menu.tscn` (ADR-028), because which side a *tutorial* opens on is the
## tutorial's decision and not the range's -- the scene that owns the first run
## is the scene that says how it starts.
##
## Applied at the end of `_setup_play`, once there is an archer to be. It goes
## through `set_defending` like any other switch, so opening on defence and
## switching to it are the same code path and cannot drift apart.
@export var start_defending := false


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_pins()
	_build_ball()
	_setup_play()


# ------------------------------------------------------------------ world ----

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = HoleBuilder.VOID
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("2a3d4a")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 1.35
	env.glow_bloom = 0.35
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.55
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("101418")
	env.fog_density = 1.0
	env.fog_depth_begin = 100.0
	env.fog_depth_end = 280.0
	env.fog_sky_affect = 0.0

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-58.0), deg_to_rad(34.0), 0.0)
	key.light_energy = 0.45
	key.light_color = Color("9fd8e8")
	key.shadow_enabled = false
	add_child(key)

	camera = Camera3D.new()
	camera.fov = 58.0
	add_child(camera)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	add_child(ground)
	HoleBuilder.deck(ground, Vector2(420.0, 460.0), Vector3(0.0, 0.0, -46.0))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(420.0, 1.0, 460.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, -46.0)
	ground.add_child(shape)

	# The range floor, out to just inside the boundary.
	HoleBuilder.slab(self,
		Vector3((BOUNDS_EXTENT.x - PLAY_INSET) * 2.0, 0.05, (BOUNDS_EXTENT.y - PLAY_INSET) * 2.0),
		HoleBuilder.EDGE_ROUGH, Vector3(BOUNDS_CENTRE.x, 0.01, BOUNDS_CENTRE.z),
		7.0, HoleBuilder.SURFACE_ROUGH, HoleBuilder.EDGE_ROUGH, 0.75)

	# Distance markers across the range, every twenty metres. The one piece of
	# information a range exists to give you, and the only way to read distance
	# on a flat plane without writing a number on it.
	for metres in [20, 40, 60, 80]:
		HoleBuilder.lines(self, PackedVector3Array([
			Vector3(-BOUNDS_EXTENT.x + PLAY_INSET, 0.03, -float(metres)),
			Vector3(BOUNDS_EXTENT.x - PLAY_INSET, 0.03, -float(metres)),
		]), HoleBuilder.GRID, 1.6)

	HoleBuilder.boundary(self, BOUNDS_CENTRE, BOUNDS_EXTENT)
	HoleBuilder.disc(self, MAT_RADIUS, 0.16, HoleBuilder.EDGE, Vector3(0.0, 0.05, 0.0), 32)


func _build_pins() -> void:
	for i in PINS.size():
		var spec: Dictionary = PINS[i]
		var at: Vector3 = spec["at"]
		HoleBuilder.green(self, float(spec["radius"]), at)
		HoleBuilder.disc(self, 0.5, 0.10, HoleBuilder.CUP, at + Vector3(0.0, 0.06, 0.0), 20)
		HoleBuilder.flag(self, at)

		var beacon := Beacon.new()
		beacon.radius = float(spec["radius"]) * 0.4
		beacon.color = Beacon.CUP
		beacon.position = at
		add_child(beacon)
		_beacons.append(beacon)

	HoleBuilder.spire(self, TOWER_POS, TOWER_SIZE)


func _build_ball() -> void:
	ball = RigidBody3D.new()
	ball.mass = BALL_MASS
	ball.continuous_cd = true
	ball.position = BAY_POS
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
	mat.emission_enabled = true
	mat.emission = Color("fdfdf6")
	mat.emission_energy_multiplier = 0.9
	mi.material_override = mat
	ball.add_child(mi)

	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = BALL_RADIUS
	shape.shape = sphere_shape
	ball.add_child(shape)


# ------------------------------------------------------------------ play -----

func _setup_play() -> void:
	_round_seed = randi()

	_ribbon = AimRibbon.new()
	add_child(_ribbon)
	_spin = SpinDial.new()
	add_child(_spin)

	_golfer = GolferFigure.new()
	_golfer.position = Vector3(BAY_POS.x, 0.0, BAY_POS.z)
	add_child(_golfer)

	if defended:
		var profile := DefenderProfile.archer(ARCHER_STAND, BOUNDS_CENTRE, BOUNDS_EXTENT)
		_guard = Archer.with_profile(profile, DifficultyTier.unerring(), "archery_0")
		add_child(_guard)
		_defenders.append(_guard)

	if contested:
		_build_the_contender()

	_gesture = StrokeGesture.new()
	_gesture.camera = camera
	add_child(_gesture)
	_gesture.began.connect(_on_gesture_began)
	_gesture.aim_updated.connect(_on_aim_updated)
	_gesture.fired.connect(_on_fired)
	_gesture.cancelled.connect(_on_cancelled)

	_look = CameraOrbit.new()
	add_child(_look)
	# The two halves of keeping one finger and two fingers out of each other's
	# way. A second finger landing mid-drag drops the stroke rather than playing
	# it, and a press that never became a stroke is ADR-001's one-tap reset --
	# the gesture reports the two separately so that neither has to guess.
	_look.engaged.connect(_gesture.abort)
	_gesture.tapped.connect(_look.recentre)
	# Anything the player does resets the idle clock. Listed rather than polled:
	# the gesture marks its own presses handled, so nothing downstream would see
	# them, and the orbit reports engagement on the same terms.
	_look.engaged.connect(_touched)
	_gesture.began.connect(_touched)
	_gesture.aim_updated.connect(func(_h: Vector3, _p: float, _c: float) -> void: _touched())
	_gesture.tapped.connect(_touched)

	pin = pin_at(0)
	club_index = suggested_club_index()
	_enter_aim()
	state = State.ATTRACT
	_frame_attract()
	if start_defending:
		set_defending(true)


## What is in the player's hands. Not what the pin says it should be: the pin
## only ever suggests, and the difference between the two is where the learning
## is. There is no word for "short" anywhere on screen -- the selector draws the
## three clubs as the distances they reach, and the ball does the explaining.
func club() -> ClubProfile:
	return ClubProfile.all()[clampi(club_index, 0, ClubProfile.all().size() - 1)]


## Put a club in the player's hands. Safe to call at any time; the aim preview
## redraws itself against the new flight on the next drag.
##
## This is the player's door -- the selector comes through here -- so it counts
## as a touch for the idle camera. A new pin handing over its suggested club
## goes through `_hand_club` instead: the player is exactly as idle as they were.
func set_club(index: int) -> void:
	_touched()
	_hand_club(index)


func _hand_club(index: int) -> void:
	var next := clampi(index, 0, ClubProfile.all().size() - 1)
	if next == club_index:
		return
	club_index = next
	_ribbon.hide_arc()
	_spin.hide_dial()
	club_changed.emit(club_index)


## The club this pin comes with. A suggestion the player is free to ignore.
func suggested_club_index() -> int:
	var id := String(PINS[mini(pin, PINS.size() - 1)]["suggests"])
	var clubs := ClubProfile.all()
	for i in clubs.size():
		if clubs[i].id == id:
			return i
	return 0


## Put a contesting archer on the range, or take it away.
##
## Not just a flag: it builds and frees the figure, so there is no state in which
## the range says it is contested and nothing is standing there. A later hole
## turns this on; the first run never does (ADR-022).
func set_contested(value: bool) -> void:
	if contested == value:
		return
	contested = value
	if contested:
		_build_the_contender()
		return

	# Going quiet. Anything the player was holding goes with it, or the range is
	# left defending with a bow that no longer exists.
	_stow_the_arrow()
	_defenders.erase(_contender)
	_contender.queue_free()
	_contender = null


func _build_the_contender() -> void:
	# Placed at the midpoint on the next line rather than here, so there is
	# exactly one piece of code that knows where a defender stands.
	_contender = Archer.with_profile(
		DefenderProfile.contesting_archer(Vector3.ZERO, CONTEST_ZONE),
		DifficultyTier.gentle(), "archery_1")
	# Amber, not the safety net's green: this one is not on your side.
	_contender.ink = Skeet.THREAT
	add_child(_contender)
	_defenders.append(_contender)
	_place_the_contender()


## The archer the player has hold of when defending.
##
## The contesting one if the hole has stood one up, and otherwise **the archer on
## the rock** -- the safety net itself. That is the first run's whole defence
## side, and it is a better lesson than an adversary would be: the ball you are
## being asked to shoot is the one that was about to be lost, so playing this
## side is learning where the course ends by patrolling it. Pillar 6 is kind
## comedy, and the funniest version of a safety net is one somebody has to work.
##
## It also has a consequence worth saying out loud: while the player holds the
## guard, the guard stops guarding by itself (`_guard_the_boundary` skips it).
## Taking the bow means the saving is now your job, and missing means the ball
## is gone. Nothing is lost by it -- a range charges nothing for a lost ball --
## but it is the difference between watching a net work and being one.
func held() -> Archer:
	return _contender if _contender != null else _guard


## The pin that comes up after `made` pins have been made: a digit of π.
func pin_at(made: int) -> int:
	return PIN_ORDER.unicode_at(made % PIN_ORDER.length()) - 48


## Is there anything to defend with? The flat layer asks before offering the
## switch, because a control that changes nothing is worse than an absent one.
func can_defend() -> bool:
	return held() != null


## Which side the player is on, and the only thing that changes when it flips.
##
## Deliberately not a separate scene, a separate mode or a separate camera. §4's
## Defense Range is a whole mode at M5; this is the cheap version of the thing it
## is for, which is that **you cannot defend a shot you have never had to play**.
## Switching in place, against the same shooter on the same range, is what makes
## the two halves teach each other -- and it is why the defender is given exactly
## the view the golfer had rather than a better one.
func set_defending(value: bool) -> void:
	if _defending == value:
		return
	# There has to be somebody to be. Asking to defend a range with no defender
	# on it is not an error, it is simply nothing, and it leaves the player
	# holding a bow that was never built.
	if value and held() == null:
		return
	_touched()
	_defending = value
	_gesture.enabled = true
	_aim_the_gesture()
	_ribbon.hide_arc()
	_spin.hide_dial()
	_stow_the_arrow()
	_ai_beat = AI_ADDRESS
	# The attract screen is the range waiting for the golfer's first touch. When
	# the player takes the bow, the game is the golfer and there is nothing to
	# wait for -- and nothing else would ever leave ATTRACT, because the drag
	# that normally does is the one `_on_gesture_began` ignores on this side.
	# Found the day the first run started on defence (ADR-028): before that it
	# was a deadlock the switch could reach and nobody had.
	if _defending and state == State.ATTRACT:
		state = State.AIM
		state_changed.emit(state)
	side_changed.emit(_defending)


func defending() -> bool:
	return _defending


## How long the game's golfer stands over the ball before swinging.
const AI_ADDRESS := 1.1

## How long a player has to be idle before the camera goes for a walk, and how
## fast it walks. Three seconds is longer than any pause inside a stroke and
## shorter than the game's golfer takes to address and play one, so a defender
## who is only watching gets the tour and a defender who is about to shoot does
## not have the view pulled out from under them.
const IDLE_AFTER := 3.0
const IDLE_ORBIT_RATE := 0.16
## The tour is not a second camera. It is the state's own framing, turned about
## the active player and pulled back, by an amount that fades in over
## `IDLE_FADE_IN` seconds once the clock has run out and fades out over
## `IDLE_FADE_OUT` the moment anything is touched. At zero it *is* the framing,
## exactly -- which is what makes leaving and returning a change of speed and
## never a change of shot. `IDLE_PULL_BACK` is how much further out the eye ends
## up; `IDLE_RISE` how much higher. `TOUR_RETURN` is the rate, in radians a
## second, at which the turn unwinds when the player comes back -- a rate and
## not a proportion, so a tour that had got half way round comes back at the
## same speed as one that had barely started, and never as a whip.
const IDLE_FADE_IN := 2.5
const IDLE_FADE_OUT := 1.0
const IDLE_PULL_BACK := 0.55
const IDLE_RISE := 3.0
const TOUR_RETURN := 0.9

## The defender's camera sits this far round to the right of the archer, rather
## than straight up the spine. An angle and not a lateral offset, because the
## eye orbits the archer and an angle survives the orbit where a sideways nudge
## would not. Seven degrees is the ratifier's number.
const DEFEND_YAW := deg_to_rad(7.0)


## The game plays a shot at the pin, so that the player has something to defend.
##
## `AIGolfer` has no privileged information -- §6.3 is explicit that it sees the
## ball, the target and whatever the hole says is in the way, which is what the
## player sees. That matters more here than it does in the demo round: the whole
## claim of this mode is that both sides are looking at the same thing.
func _play_the_games_shot() -> void:
	if not _aiming:
		return
	_ai_beat = AI_ADDRESS
	# `_on_fired` is the one door both sides come through, so the game's golfer
	# has to say which of them it is on the way in.
	_ai_is_playing = true
	var intent := AIGolfer.choose(
		ball.global_position, pin_position(), 0.0, Callable(),
		club().is_putter, 0.78, _seed_for_stroke(strokes + 1), club())
	stroke_began.emit()
	_on_fired(intent.direction, intent.power, intent.curve)
	_ai_is_playing = false


## Tell the gesture what it is reading a drag against.
##
## Two facts, and both of them were assumptions until the first pre-alpha
## feedback found them. The **plane** is what the drag is unprojected onto, so it
## has to be whatever the player is aiming at -- the ball, or the ball's live
## height when it is in the air and being shot at. The **lock** is the second
## half of the stroke gesture, which bends the shot; a bow has nothing to bend,
## so locking its line means the drag stops responding halfway through.
func _aim_the_gesture() -> void:
	_gesture.locks_line = not _defending
	_gesture.aim_plane_y = ball.global_position.y


## The bow, drawn. Reuses the golfer's own preview: §2.1 makes the ribbon
## "accurate on an empty hole and blind to defenders", and an arrow's arc is
## exactly as honest a thing to draw as a ball's.
func _aim_the_bow(heading: Vector3, power: float) -> void:
	var archer := held()
	if archer == null or power <= 0.0:
		_ribbon.hide_arc()
		return
	# The ball is the thing being aimed at and it is moving, so the plane the
	# drag is measured on follows it.
	_gesture.aim_plane_y = ball.global_position.y
	var from := archer.nock_at()
	_ribbon.show_arc(from, _arrow_velocity(heading, power), Vector3.ZERO, 0.0, false,
		AimRibbon.SIGHTED_FRACTION, false)
	archer.aim_at(from + heading * 14.0 + Vector3.UP * 2.0)


## Let go. One arrow per stroke, and the cooldown starts here rather than when it
## arrives -- a bow you have already loosed is empty whatever the arrow is doing.
func _loose(heading: Vector3, power: float) -> void:
	_ribbon.hide_arc()
	var archer := held()
	if archer == null or not archer.brain.commit_by_hand():
		return
	_arrow_from = archer.nock_at()
	_arrow_at = _arrow_from
	_arrow_vel = _arrow_velocity(heading, power)
	_arrow_age = 0.0
	_arrow_live = true
	archer.fly(_arrow_from, _arrow_at)


## Bearing and draw from the player; **elevation from the archer**.
##
## The gesture reads a heading on the ground plane, because that is what a golf
## stroke needs -- a club supplies the launch angle, so the drag only has to
## supply a compass bearing. An arrow has no club to supply it, and the target is
## in the air, so a planar aim with a fixed launch angle can only hit a ball that
## happens to be at the right height at the right range. It is not a hard shot,
## it is an unaimable one.
##
## So the archer elevates. The player says *which way* and *how hard*, and the
## bow solves the angle that reaches the range the ball is at -- the ordinary
## ballistic solution, taking the flatter of its two roots, because an archer
## lobbing over the range and waiting is not what anybody meant. That leaves the
## horizontal lead and the timing as the whole of the skill, which is the right
## half to keep: it is the half the player can see, judge and get better at.
##
## The target is where the ball *will be*, found by two passes -- guess the
## flight time from the present distance, move the ball, guess again. A third
## changes the answer by centimetres. Note this only sets the elevation: the
## bearing stays the player's, so a lead that is wrong is still a miss, and it
## misses by the amount they were wrong.
func _arrow_velocity(heading: Vector3, power: float) -> Vector3:
	var speed := lerpf(BOW_MIN_SPEED, BOW_MAX_SPEED, clampf(power, 0.0, 1.0))
	var archer := held()
	var from := archer.nock_at() if archer != null else ball.global_position
	var flat := Vector3(heading.x, 0.0, heading.z)
	flat = flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD

	var target := ball.global_position
	for i in 2:
		var t := from.distance_to(target) / maxf(speed, 0.001)
		target = ball.global_position + ball.linear_velocity * t \
			+ BallFlight.gravity() * t * t * 0.5

	var to := target - from
	var range_ := Vector2(to.x, to.z).length()
	var rise := to.y
	var g := absf(BallFlight.gravity().y)
	var elevation := deg_to_rad(45.0)
	if range_ > 0.01:
		var vv := speed * speed
		var disc := vv * vv - g * (g * range_ * range_ + 2.0 * rise * vv)
		if disc >= 0.0:
			elevation = atan((vv - sqrt(disc)) / (g * range_))
	return flat * (cos(elevation) * speed) + Vector3.UP * (sin(elevation) * speed)


## Fly the arrow, on the ball's own tick. Whether it connects is decided here and
## nowhere else: near enough to the ball, and inside the zone the archer actually
## covers, which is the blind spot doing its job on a shot a person aimed.
func _advance_the_arrow(delta: float) -> void:
	if not _arrow_live:
		return
	_arrow_age += delta
	var was := _arrow_at
	_arrow_vel += BallFlight.gravity() * delta
	_arrow_at += _arrow_vel * delta
	var archer := held()
	if archer == null:
		_stow_the_arrow()
		return
	archer.fly(_arrow_from, _arrow_at)

	# Against the *segment* the arrow swept, not the point it landed on. At a
	# hundred metres a second an arrow covers nearly two metres between physics
	# ticks, so a point test steps straight over a ball it went through -- which
	# is a miss the player cannot tell from a bad shot, and the worst kind there
	# is. This is the same reason the ball itself uses continuous collision.
	var near := Geometry3D.get_closest_point_to_segment(
		ball.global_position, was, _arrow_at)
	if near.distance_to(ball.global_position) <= ARROW_HIT:
		_stow_the_arrow()
		if archer.brain.connected_at(near):
			_on_defender_acted(archer)
		return
	if _arrow_age >= ARROW_LIFE or _arrow_at.y < 0.0:
		_stow_the_arrow()


func _stow_the_arrow() -> void:
	_arrow_live = false
	if _contender != null:
		_contender.stow()
	if _guard != null:
		_guard.stow()


## Kept inside the fence. Twice the distance to the far pin is a hundred and
## forty metres, which is past the boundary and into the void -- the arithmetic
## is right and the place it points at is not on the range.
func _inside_the_range(at: Vector3) -> Vector3:
	var limit := BOUNDS_EXTENT - Vector2.ONE * PLAY_INSET
	return Vector3(
		clampf(at.x, BOUNDS_CENTRE.x - limit.x, BOUNDS_CENTRE.x + limit.x), 0.0,
		clampf(at.z, BOUNDS_CENTRE.z - limit.y, BOUNDS_CENTRE.z + limit.y))


## Twice the distance to the pin, on the ground. The one rule that
## decides where a defender stands, so that moving it is a one-line change and
## not a hunt through a level file.
func defender_stand() -> Vector3:
	var tee := Vector3(BAY_POS.x, 0.0, BAY_POS.z)
	var to_pin := pin_position() - tee
	to_pin.y = 0.0
	if to_pin.length() < 0.01:
		return tee
	to_pin = _inside_the_range(tee + to_pin * 2.0) - tee
	# **Twice the distance to the hole**, mirrored through it: the archer stands
	# as far beyond the pin as the player is short of it, on the same line.
	#
	# Halving was the first rule and it was wrong at the near end. The putting
	# pin is six metres away across a three-metre mat, so half of it put a
	# defender at the player's elbow -- against §3, which says defenders never
	# enter the tee box and the first swing is always yours, and against the
	# grain of the range, where a short putt ought to be the easiest thing the
	# player is ever asked to do.
	#
	# Mirroring keeps what the midpoint was chosen for -- on the line of play,
	# and not something that can be walked around -- and it moves what the archer
	# is *for*. It no longer contests the flight to the pin; it guards the ground
	# beyond it. Going long is the shot it punishes, which is the one mistake a
	# range cannot otherwise cost you anything for.
	return tee + to_pin


## Walk the shooter to the midpoint of the lie it is now guarding. Called on
## every pin change, which is ADR-009's "exactly one defender moves per lie" with
## the choice of where taken out of anybody's hands.
func _place_the_contender() -> void:
	if _contender == null:
		return
	var at := defender_stand()
	_contender.position = at
	_contender.brain.profile.stand = at
	_contender.brain.profile.zone_centre = at


func pin_position() -> Vector3:
	return PINS[mini(pin, PINS.size() - 1)]["at"]


func pin_radius() -> float:
	return float(PINS[mini(pin, PINS.size() - 1)]["radius"])


func _enter_aim() -> void:
	state = State.AIM
	_aiming = true
	_pinned = false
	_held = false
	_swing_t = -1.0
	ball.freeze = true
	ball.global_position = BAY_POS
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	# Live on both sides now. Defending, the same drag draws a bow instead of a
	# club, which is the whole of ADR-021.
	_gesture.enabled = true
	_aim_the_gesture()
	_ai_beat = AI_ADDRESS
	_light_pins()
	state_changed.emit(state)


## The live pin pulses; the ones behind you go quiet. One target at a time is
## the whole of the range's instruction.
func _light_pins() -> void:
	for i in _beacons.size():
		if i == pin:
			_beacons[i].resume()
		else:
			_beacons[i].confirm()


func _on_gesture_began() -> void:
	if _defending:
		# Drawing a bow is not taking a stroke, and the flat layer listens to
		# this to know the player has started golfing.
		return
	stroke_began.emit()
	if state == State.ATTRACT:
		state = State.AIM
		state_changed.emit(state)


func _on_cancelled() -> void:
	_ribbon.hide_arc()
	_spin.hide_dial()


func _on_aim_updated(heading: Vector3, power: float, curve: float) -> void:
	if _defending:
		_aim_the_bow(heading, power)
		return
	if not _aiming:
		return
	if power <= 0.0:
		_ribbon.hide_arc()
		_spin.hide_dial()
		return
	var profile := club()
	var origin := ball.global_position
	# A putt cannot be shaped, so the dial has nothing to report and showing an
	# empty one would read as a control that is broken rather than absent. It
	# also has no arc: previewed as a projectile it lands within a metre and the
	# stub came to six centimetres, which is why it read as having no preview.
	if profile.is_putter:
		_spin.hide_dial()
		_ribbon.show_roll(origin, heading, profile.rolls() * power)
		return
	var velocity := BallFlight.launch_velocity(heading, power, false, profile)
	var accel := BallFlight.curve_acceleration(heading, curve, profile)
	_ribbon.show_arc(origin, velocity, accel, BALL_RADIUS, false)
	_spin.show_spin(origin, heading, curve, false)


func _on_fired(heading: Vector3, power: float, curve: float) -> void:
	if _defending and not _ai_is_playing:
		_loose(heading, power)
		return
	if not _aiming:
		return
	_aiming = false
	if not _ai_is_playing:
		_player_struck = true
	# Defending, the drag is the defence and does not stop when the ball goes.
	_gesture.enabled = _defending
	_ribbon.hide_arc()
	_spin.hide_dial()

	var profile := club()
	var intent := ShotIntent.make(profile.to_intent_club(), power, curve, heading)
	var origin := ball.global_position
	var velocity := BallFlight.launch_velocity(intent.direction, intent.power, false, profile)
	_curve_accel = BallFlight.curve_acceleration(intent.direction, intent.curve, profile)

	strokes += 1
	_stroke_seed = _seed_for_stroke(strokes)
	_record = StrokeRecord.opened(
		HOLE_ID, _layout_hash(), _stroke_seed, strokes, origin, "tee", intent)
	_record.defenders = _defender_entries()

	var arc := BallFlight.sample_arc(
		origin, velocity, _curve_accel, BALL_RADIUS, 900, DEFENDER_DT)
	for defender in _defenders:
		# An archer the player is holding does not get to read the shot. That
		# prediction is the AI's commitment, and the whole point of the other
		# side is that the commitment is now the player's release.
		if _defending and defender == held():
			defender.read_shot(PackedVector3Array(), DEFENDER_DT, _stroke_seed)
			continue
		defender.read_shot(arc, DEFENDER_DT, _stroke_seed)
	_last_in_bounds = origin

	# The stroke is decided and the ball has not been hit yet. Everything above
	# has already happened -- the record is open, the defenders have read the arc
	# -- and what is left is the club actually arriving, which takes time a
	# defender is entitled to see. See `GolferFigure`.
	_held = true
	_pending = velocity
	_swing_t = 0.0
	_pinned = false

	# Start the camera already behind the shot. Easing into it from wherever the
	# last one finished would swing the camera through the tee on every stroke.
	var away := Vector3(velocity.x, 0.0, velocity.z)
	_trail = -away.normalized() if away.length() > 0.01 else Vector3.BACK
	_golfer.aim = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	_threat = 0.0

	stroke_taken.emit(strokes)
	state = State.FLIGHT
	_still_for = 0.0
	state_changed.emit(state)


func _physics_process(delta: float) -> void:
	# Before the state gate: an arrow in the air is in the air, whether or not
	# the ball has been struck yet. Loosing during the golfer's backswing is
	# allowed and simply wastes the shot, which is a rule that explains itself.
	_advance_the_arrow(delta)

	if state != State.FLIGHT:
		return

	# The backswing. The ball is still frozen on the mat and the defenders'
	# clocks have not started, because neither the ball nor anyone watching it
	# has anything to go on yet -- what is happening is a warning.
	if _held:
		_swing_t += delta
		if _swing_t < GolferFigure.windup():
			return
		_launch()
	elif _swing_t >= 0.0:
		_swing_t += delta
		if _swing_t >= GolferFigure.SWING_TIME:
			_swing_t = -1.0

	# The bow follows the ball while somebody is holding it, so the thread says
	# where the arrow would go if they pressed now. It is the only thing a
	# defender has to judge by, which is the point: they are given the golfer's
	# view and one line, not a solution.
	for defender in _defenders:
		if defender.advance(delta):
			_on_defender_acted(defender)
	_guard_the_boundary()

	var airborne := ball.global_position.y > BALL_RADIUS * 1.8
	if _pinned:
		ball.linear_damp = PINNED_DAMP
	elif club().is_putter:
		ball.linear_damp = ROLL_DAMP
	elif airborne:
		ball.apply_central_force(_curve_accel * ball.mass)
		ball.linear_damp = 0.0
	else:
		ball.linear_damp = ROLL_DAMP

	if ball.linear_velocity.length() < SETTLE_SPEED:
		_still_for += delta
		if _still_for >= SETTLE_TIME:
			_settle()
	else:
		_still_for = 0.0


## The club reaches the ball. Split out of `_on_fired` because the two happen at
## different times now, and only this half is physics.
func _launch() -> void:
	_held = false
	ball.freeze = false
	# A putt is already rolling, so it gets the roll damping from the first tick
	# rather than after it lands. Without this the putter behaves like a very
	# weak long club and runs miles.
	ball.linear_damp = ROLL_DAMP if club().is_putter else 0.0
	ball.angular_damp = 1.4
	ball.linear_velocity = _pending
	Impact.at_point(self, ball.global_position, HoleBuilder.EDGE)


## Where the ball stopped decides everything. On the green is the pin made; in
## the cup is the same thing with a better noise. Anywhere else you hit another
## one, because it is a range and there is no such thing as a penalty on it.
func _settle() -> void:
	var at := ball.global_position
	var flat := Vector2(at.x - pin_position().x, at.z - pin_position().z).length()
	var made := flat <= pin_radius()
	var holed := flat <= CUP_RADIUS

	_finish_stroke("holed" if holed else ("on_target" if made else ""))

	if not made:
		_enter_aim()
		return

	if pin < _beacons.size():
		_beacons[pin].confirm()
	_celebrate(pin_position(), holed)
	pins_made += 1
	pin_made.emit(pin, holed)

	# Every three pins is a round, and a round is when the record store writes.
	# It used to be the end as well; now it is a file, and the range carries on
	# (ADR-029). The file holds this round's strokes and the list starts again,
	# and it is only written if a person struck a ball in it: the game golfing
	# against nobody is not a record of anything. `finished` keeps its name and
	# its meaning, a round of three was completed, and stops meaning that
	# anything has stopped.
	if pins_made % PINS.size() == 0:
		if _player_struck:
			round_path = _save_round()
		last_round = _round.duplicate()
		_round.clear()
		_player_struck = false
		finished.emit(strokes)

	_next_pin()


## The next pin from the sequence, and everything a new line of play resets.
func _next_pin() -> void:
	pin = pin_at(pins_made)
	# A new pin is a new line of play, so the angle the player chose for the old
	# one has stopped meaning anything. This is ADR-001's "auto-snap to putt
	# view" generalised: the camera resets when what it was framed against does,
	# and not merely because time passed.
	_look.recentre()
	# One defender moves per lie (ADR-009), and where it moves to is not a
	# choice: the midpoint of the new line of play.
	_place_the_contender()
	_hand_club(suggested_club_index())
	pin_changed.emit(pin)
	_enter_aim()


# -------------------------------------------------------------- defenders ----

func _defender_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for defender in _defenders:
		entries.append(defender.brain.to_record_entry())
	return entries


func _on_defender_acted(defender: Node3D) -> void:
	var brain: DefenderBrain = defender.brain
	if not brain.will_connect():
		return
	_curve_accel = Vector3.ZERO
	var hit_at := ball.global_position

	match brain.profile.action:
		DefenderProfile.Action.PIN:
			var flight := ball.linear_velocity
			var against := -flight.normalized() if flight.length() > 0.5 else Vector3.ZERO
			var incoming := (against * ARROW_AGAINST_FLIGHT
				+ Vector3.DOWN * ARROW_DOWNWARD).normalized()
			ball.linear_velocity += incoming * (ARROW_MASS * ARROW_SPEED / ball.mass)
			ball.angular_velocity += incoming.cross(Vector3.UP) * 58.0
			_pinned = true
		_:
			ball.linear_velocity = Vector3(0.0, minf(ball.linear_velocity.y, 0.0), 0.0)
			ball.angular_velocity = Vector3.ZERO

	var ink := Archer.THREAD
	if defender is Archer:
		ink = (defender as Archer).ink
	Impact.at_point(self, hit_at, ink)
	_shake = maxf(_shake, SHAKE_ON_HIT)


func _guard_the_boundary() -> void:
	for defender in _defenders:
		var brain: DefenderBrain = defender.brain
		if not brain.profile.guards_bounds:
			continue
		# Not while somebody has hold of it. A net that keeps catching balls
		# while the player is aiming it themselves is a net doing their job for
		# them, and the shot they just missed would look like one they made.
		if _defending and defender == held():
			continue
		var at := ball.global_position
		var margin := minf(
			brain.profile.bounds_extent.x - absf(at.x - brain.profile.bounds_centre.x),
			brain.profile.bounds_extent.y - absf(at.z - brain.profile.bounds_centre.z))
		if brain.profile.in_bounds(at):
			_last_in_bounds = at

		if margin <= STRIKE_MARGIN:
			if defender.intercept(at):
				_on_defender_acted(defender)
			continue

		if not brain.is_committed():
			if margin <= GUARD_MARGIN:
				defender.watch(at)
			else:
				brain.alerted = false


# ---------------------------------------------------------------- records ----

func _layout_hash() -> String:
	var pins := []
	for spec in PINS:
		pins.append([spec["suggests"], Canonical.vec3_array(spec["at"]), spec["radius"]])
	return Canonical.hash_of({
		"bay": Canonical.vec3_array(BAY_POS),
		"pins": pins,
		"bounds": [Canonical.vec3_array(BOUNDS_CENTRE), BOUNDS_EXTENT.x, BOUNDS_EXTENT.y],
		"defended": defended,
	}).substr(0, 16)


func _seed_for_stroke(number: int) -> int:
	return hash("%d:%d" % [_round_seed, number])


## Every ball is struck from the mat, so `before.lie` is always `tee` and the
## interesting lie is the one the ball finishes on.
func _lie_at(at: Vector3) -> String:
	if absf(at.x - BOUNDS_CENTRE.x) > BOUNDS_EXTENT.x \
			or absf(at.z - BOUNDS_CENTRE.z) > BOUNDS_EXTENT.y:
		return "ob"
	for spec in PINS:
		var to: Vector3 = spec["at"]
		if Vector2(at.x - to.x, at.z - to.z).length() <= float(spec["radius"]):
			return "green"
	if Vector2(at.x, at.z).length() <= MAT_RADIUS:
		return "tee"
	return "fairway"


func _finish_stroke(extra := "") -> void:
	if _record == null:
		return
	var events := PackedStringArray()
	for defender in _defenders:
		events.append_array(defender.brain.events())
	if extra != "":
		events.append(extra)
	_record.resolve(ball.global_position, _lie_at(ball.global_position), events)
	_round.append(_record)
	_record = null
	for defender in _defenders:
		defender.rest()


func _save_round() -> String:
	if _round.is_empty():
		return ""
	return RecordStore.save_round(HOLE_ID, _layout_hash(), _round_seed, PINS.size(), _round)


func round_notation() -> String:
	return RecordStore.notation(_round)


# ---------------------------------------------------------------- flourish ---

func _celebrate(at: Vector3, holed: bool) -> void:
	Impact.at_point(self, at + Vector3(0.0, 0.3, 0.0),
		HoleBuilder.CUP if holed else HoleBuilder.PUTTING)
	if holed:
		_shake = maxf(_shake, 0.35)


# ---------------------------------------------------------------- camera -----

func _process(delta: float) -> void:
	# The idle drift and the player's orbit are the same degree of freedom, and a
	# camera that keeps sliding while somebody is holding it is broken. So the
	# drift only advances while the orbit is centred: taking hold stops it, and
	# the one-tap reset sets it going again.
	var idle := _look.is_centred()
	_ease_the_flight_camera(delta)
	# The figure is drawn from the same clock that holds the ball, so what the
	# defender sees and what the physics does cannot drift apart.
	_golfer.swing = 0.0 if _swing_t < 0.0 else _swing_t / GolferFigure.SWING_TIME

	if _defending and state == State.AIM:
		_ai_beat -= delta
		if _ai_beat <= 0.0:
			_play_the_games_shot()

	# Idle is a fact about the player, not the state: a defender watching the
	# game golf and a golfer who wandered off look the same from here. The clock
	# only runs while the orbit is centred -- a player holding the camera is not
	# idle, whatever else they are doing. Past IDLE_AFTER the tour fades in and
	# the turn starts; on a touch the tour fades out and the turn unwinds. Both
	# are rates, never states, and `_framed()` applies them every frame in every
	# state -- which is the whole of how "no jumps" is kept: there is nothing to
	# jump between.
	_idle_for = _idle_for + delta if idle else 0.0
	var touring := _idle_for >= IDLE_AFTER
	_idle = move_toward(_idle, 1.0 if touring else 0.0,
		delta / (IDLE_FADE_IN if touring else IDLE_FADE_OUT))
	var blend := _tour_blend()
	if touring:
		# The turn's speed follows the blend, so it too starts from rest.
		_tour_yaw = wrapf(_tour_yaw + delta * IDLE_ORBIT_RATE * blend, -PI, PI)
	else:
		# Home the short way round -- wrapped to [-PI, PI] while touring, so
		# toward zero is that by construction. The rate rises as the blend falls,
		# so the unwind starts from rest as the pull-back does; and it is capped
		# in proportion to what is left, so it arrives at rest rather than
		# stopping dead.
		var rate := minf(TOUR_RETURN * (1.0 - blend), 4.0 * absf(_tour_yaw))
		_tour_yaw = move_toward(_tour_yaw, 0.0, delta * rate)

	match state:
		State.ATTRACT:
			if idle:
				_drift += delta * 0.14
			_frame_attract()
			return
		State.AIM:
			_cam_target = _frame_defend() if _defending else _frame_aim()
		State.FLIGHT:
			_cam_target = _frame_defend() if _defending else _frame_flight()

	_cam_smooth = _cam_smooth.interpolate_with(_cam_target, clampf(delta * 3.4, 0.0, 1.0))
	camera.global_transform = _cam_smooth
	_apply_shake(delta)


## The two things the flight camera is not allowed to do instantly: change which
## side of the ball it sits on, and cut to a defender. Both used to be recomputed
## from the current frame's facts and nothing else, so both were a teleport -- and
## an arrow strike sets off both at once, which is why a hit the player could not
## see read as the camera breaking rather than as something having happened.
func _ease_the_flight_camera(delta: float) -> void:
	var threat := _acting_defender()
	if threat != null:
		_threat_at = threat.global_position
		_threat = move_toward(_threat, 1.0, delta * THREAT_IN)
	else:
		_threat = move_toward(_threat, 0.0, delta * THREAT_OUT)

	# A pinned ball is being buried, and the direction it is travelling now is
	# the arrow's rather than the shot's. Holding the trail keeps the camera on
	# the place the ball is dying instead of whipping round to chase it back up
	# the range.
	if _pinned:
		return
	var flat := Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z)
	if flat.length() < 0.5:
		return

	var want := -flat.normalized()
	var axis := _trail.cross(want)
	# Exactly reversed leaves no axis to turn about, and that is precisely the
	# case worth handling rather than guarding against: pick the vertical one, so
	# the camera sweeps round the ball at a level height instead of over the top.
	var turn_about := axis.normalized() if axis.length() > 0.001 else Vector3.UP
	_trail = _trail.rotated(
		turn_about, minf(_trail.angle_to(want), TRAIL_TURN * delta)).normalized()


## A knock, not a burst of noise. The frequencies used to be 97, 71 and 59 rad/s
## -- between nine and sixteen cycles a second, which at 60 fps is fewer than
## four samples each. That does not render as a shake, it renders as the camera
## position being replaced with a random number every frame, and it landed at the
## same instant as the two cuts above.
func _apply_shake(delta: float) -> void:
	camera.fov = 58.0
	if _shake <= 0.0:
		return
	_shake_t += delta
	_shake = maxf(0.0, _shake - delta * 2.0)
	var k := _shake * _shake
	camera.global_position += Vector3(
		sin(_shake_t * 41.0) * k,
		sin(_shake_t * 33.0 + 1.7) * k * 0.7,
		sin(_shake_t * 27.0 + 3.1) * k)
	camera.fov = 58.0 - k * 9.0


## Every camera in the range goes through here, which is what makes the orbit a
## modifier rather than a mode. A framing says what is worth looking at, from
## roughly where, and **whom the eye swings around** -- the active player, always
## (ADR-030): the archer when the player holds the bow, the ball when they hold
## the club. `at` and `pivot` used to be the same point, which put the two-finger
## orbit's centre thirty metres down the line from the person doing the
## orbiting.
##
## Two things turn the eye about that pivot, in this order. The idle tour first:
## `_tour_yaw` round, then out by `IDLE_PULL_BACK` and up by `IDLE_RISE`, each
## scaled by `_idle`, with the look-at sliding onto the player as the tour takes
## hold. Then `_look`, the player's own orbit. Centred and untoured, this returns
## exactly the transform the framing asked for, so neither costs anything until
## it is used -- and the tour, being a turn *from* the view rather than a view
## of its own, starts and ends where the eye already is.
func _framed(eye: Vector3, at: Vector3, pivot: Vector3) -> Transform3D:
	var blend := _tour_blend()
	var rel := (eye - pivot).rotated(Vector3.UP, _tour_yaw)
	var out := 1.0 + IDLE_PULL_BACK * blend
	rel = Vector3(rel.x * out, rel.y + IDLE_RISE * blend, rel.z * out)
	var look_at := at.lerp(pivot + Vector3.UP * 1.4, blend)
	return Transform3D(Basis.IDENTITY, _look.apply(pivot + rel, pivot)).looking_at(look_at, Vector3.UP)


## `_idle` eased. `_idle` itself runs linearly so that the fades take exactly
## the seconds their constants say; everything the eye actually does is keyed
## off this instead, because a linear ramp starts and stops with a step in
## velocity, and a step in velocity is what a camera "jumping" looks like even
## when its position never does. Smoothstep starts from rest and arrives at
## rest, at both ends of both fades.
func _tour_blend() -> float:
	return _idle * _idle * (3.0 - 2.0 * _idle)


## Who the camera swings around: the player, whichever end of the swing they are
## on. Everything else -- the pin, the flight, the other side's figure -- is what
## it looks at, never what it turns about.
func _pivot() -> Vector3:
	if _defending and held() != null:
		return held().global_position
	return ball.global_position


## Stands behind the mat, on the line to the live pin, far enough back that the
## pin is in frame at address. A range where you cannot see what you are aiming
## at is a field.
func _frame_aim() -> Transform3D:
	var to_pin := pin_position() - ball.global_position
	to_pin.y = 0.0
	var dir := to_pin.normalized() if to_pin.length() > 0.01 else Vector3.FORWARD
	var reach := clampf(to_pin.length(), 20.0, 80.0)
	return _framed(
		ball.global_position - dir * (7.0 + reach * 0.08) + Vector3.UP * (3.4 + reach * 0.045),
		ball.global_position + dir * (reach * 0.55) + Vector3.UP * 1.0,
		_pivot())


## Over the archer's shoulder, exactly as `_frame_aim` stands over the golfer's.
##
## The first version of defending gave the player the golfer's camera, on the
## grounds that both sides should see the same thing. That was the wrong reading
## of it. Pillar 5 says defence is a *whole way to play*, and a whole way to play
## does not get somebody else's viewpoint -- what has to be equal is that neither
## side gets a god view, not that they get one camera between them. Standing
## behind the archer also makes the shot aimable: a lead is a direction, and a
## direction cannot be judged from a camera pointed the other way.
func _frame_defend() -> Transform3D:
	var archer := held()
	if archer == null:
		return _frame_aim()
	var stand := archer.global_position
	var to_ball := ball.global_position - stand
	to_ball.y = 0.0
	var dir := to_ball.normalized() if to_ball.length() > 0.01 else Vector3.FORWARD
	var reach := clampf(to_ball.length(), 18.0, 80.0)
	# Round to one side rather than straight up the spine. Directly behind, the
	# figure sits in the middle of the frame and the ball it is being aimed at is
	# behind its head -- and the archer is drawn 1.6x human on purpose, so it
	# takes more getting out of the way than the golfer does. It used to be a
	# lateral nudge; it is `DEFEND_YAW` about the archer now, because the eye
	# orbits the archer and an angle is the thing that survives that. Positive
	# about UP from behind is the camera's right, which is the ratifier's "7
	# degrees right of the player". Pulled back by a third at the same request:
	# a bow is aimed at something a long way off, and the extra distance is what
	# puts the archer, the line and the ball in one frame.
	var back := (-dir).rotated(Vector3.UP, DEFEND_YAW)
	return _framed(
		stand + back * (15.0 + reach * 0.12) + Vector3.UP * (8.0 + reach * 0.075),
		stand + dir * (reach * 0.6) + Vector3.UP * 2.0,
		_pivot())


## Trails the ball, and widens to take in a defender that is acting. The widening
## is a *blend* rather than a branch: `_threat` runs from 0 to 1 and back, and
## both the eye and the point it looks at cross over together, so there is no
## frame on which the camera is somewhere it was not heading.
func _frame_flight() -> Transform3D:
	var eye := ball.global_position + _trail * 10.5 + Vector3.UP * 4.8
	var focus := ball.global_position + Vector3.UP * 0.6
	if _threat <= 0.001:
		return _framed(eye, focus, _pivot())

	var mid := (ball.global_position + _threat_at) * 0.5
	var spread := minf(ball.global_position.distance_to(_threat_at), THREAT_SPREAD)
	return _framed(
		eye.lerp(mid + _trail * (10.0 + spread * 0.62)
			+ Vector3.UP * (5.0 + spread * 0.26), _threat),
		focus.lerp(mid + Vector3.UP * 1.2, _threat),
		_pivot())


func _acting_defender() -> Node3D:
	for defender in _defenders:
		var brain: DefenderBrain = defender.brain
		if brain.state == DefenderBrain.State.TELL or brain.state == DefenderBrain.State.ACT:
			return defender
	return null


## Any input at all. The idle orbit is a thing that happens to a player who is
## not there, and the moment they are, the camera goes back to where the state
## put it -- eased, because `_cam_target` always is.
func _touched() -> void:
	_idle_for = 0.0


## The attract camera is placed rather than eased into: it runs before the player
## has done anything, so there is no previous frame worth interpolating from, and
## `_cam_smooth` is kept in step so that the first stroke eases out of what is
## actually on screen. The orbit still applies -- looking around is allowed
## before you have swung, and is a decent way to find out you can.
func _frame_attract() -> void:
	var drift := sin(_drift) * 5.0
	camera.global_transform = _framed(
		Vector3(drift, 5.6, 12.0), Vector3(2.0 + drift * 0.25, 1.4, -40.0), ball.global_position)
	_cam_smooth = camera.global_transform
