class_name ClubProfile
extends Resource
## What a club does to a ball (§6.3), as data.
##
## Three clubs, and the player picks between them. A club is four numbers: the
## speed band a full swing spans, the angle it launches at, and how hard it
## bends. Nothing else. The short club is not a special case in code, it is a
## high launch angle and a small speed band, which is what it is on a range too.
##
## They are named **long**, **short** and **putt** rather than driver, iron and
## wedge. Golf's own vocabulary carries golf's own barrier to entry: it asks a
## player to already know that a wedge is the short one. These three names say
## the decision instead of the equipment, and there are only three because three
## is how many decisions there actually are.
##
## `intent.power` stays normalised 0..1 and never holds metres
## (RECORD_SCHEMA.md §2.1): metres are this resource's business, so retuning a
## club does not invalidate a stored record, it replays it with the new club.
## That is the whole reason the schema stores power rather than speed.

## The schema's `intent.club` enum. Frozen with the record format at M1 exit.
@export var id := "short"

## Speed at power 0 and power 1, in m/s.
@export var min_speed := 4.5
@export var max_speed := 15.6
## Launch angle above the horizontal. The short club goes up, the long one out.
@export var launch_deg := 38.0
## Lateral acceleration at full curve, m/s^2. A longer club bends further in
## metres for the same number, because the ball is in the air longer -- so the
## numbers rise with the club rather than staying level.
@export var curve_accel := 5.4
## A putt rolls: no launch angle, no shaping, its own much smaller speed band.
@export var is_putter := false


static func make(id_: String, min_: float, max_: float, launch: float,
		curve: float, putter := false) -> ClubProfile:
	var club := ClubProfile.new()
	club.id = id_
	club.min_speed = min_
	club.max_speed = max_
	club.launch_deg = launch
	club.curve_accel = curve
	club.is_putter = putter
	return club


## Where a full-power shot from ground level would first land, in metres.
##
## The closed form of the same model `BallFlight` integrates, so it agrees with
## the simulation by construction rather than by being kept in step. Used to
## place range targets and to assert in tests that the clubs actually cover
## different distances. A putt never leaves the ground, so its carry is zero and
## its reach is roll -- see `rolls()`.
func carry() -> float:
	if is_putter:
		return 0.0
	var g := absf(BallFlight.gravity().y)
	var v := max_speed
	return v * v * sin(deg_to_rad(launch_deg * 2.0)) / g


## Roughly how far a full putt runs before friction takes it, in metres.
##
## **Calibrated, not derived.** The obvious closed form -- v squared over twice a
## deceleration -- gave 18 m against a measured 8.7 m, because Godot's linear
## damping is an exponential decay rather than a constant deceleration, and the
## ball is also losing energy to the surface's friction and to its own angular
## damping. Three effects, none of them a clean constant.
##
## So this is the measurement, expressed as a coefficient: `tools/probe_putt.tscn`
## rolls a full putt down the range and reports where it stops. Re-run it if the
## putter, the roll damping or the green's physics material change, and move this
## number to match. It exists so a putting target can be placed somewhere
## reachable without hard-coding a distance that silently stops being right.
const ROLL_PER_SPEED := 0.9

func rolls() -> float:
	if not is_putter:
		return 0.0
	return max_speed * ROLL_PER_SPEED


## The 1.0 set. Named constructors rather than `.tres` files for now: the
## numbers are still moving, and a resource on disk is harder to diff than a
## line of code. They become `.tres` when they stop changing every session
## (§6.1 wants clubs data-driven, and this is the same data one step earlier).
static func long_club() -> ClubProfile:
	# Low and far. Carries about 78 m, which is the far pin on the range, and at
	# half power it covers the middle one -- so the long club is two shots, not
	# one, and choosing how hard to hit it is most of what there is to learn.
	return make("long", 11.0, 38.0, 16.0, 10.4)


static func short_club() -> ClubProfile:
	# High and steep. Lands almost without running, which is what makes a near
	# target reachable at all: a low club would skid straight past it.
	return make("short", 4.5, 15.6, 38.0, 5.4)


static func putt() -> ClubProfile:
	# Rolls. No launch, no shaping -- the one stroke in the game where the only
	# decision is how hard.
	return make("putt", 1.15, 9.7, 0.0, 0.0, true)


## The full set, in the schema's order.
static func all() -> Array[ClubProfile]:
	return [long_club(), short_club(), putt()]


static func for_id(id_: String) -> ClubProfile:
	for club in all():
		if club.id == id_:
			return club
	push_error("ClubProfile: no club called %s; defaulting to short." % id_)
	return short_club()


static func for_intent(club: ShotIntent.Club) -> ClubProfile:
	return for_id(ShotIntent.CLUB_NAMES[club])


func to_intent_club() -> ShotIntent.Club:
	return ShotIntent.club_from_name(id)


## The club a golfer would reach for at a given distance.
##
## Deliberately blunt: putt inside its roll, short inside its carry, long for
## everything else. It is the fallback for anyone who has not chosen -- the
## player always can, and on the range that choice is the point.
static func for_distance(metres: float) -> ClubProfile:
	if metres <= putt().rolls() * 0.9:
		return putt()
	if metres <= short_club().carry() * 0.98:
		return short_club()
	return long_club()
