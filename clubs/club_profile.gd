class_name ClubProfile
extends Resource
## What a club does to a ball (§6.3), as data.
##
## Three clubs and an auto-putter is DESIGN.md §2.1's proposal, and until now
## `BallFlight` held one set of numbers for every full shot -- so every stroke in
## the game was the same club wearing a different label in the record. This is
## that label becoming real.
##
## A club is four numbers: the speed band a full swing spans, the angle it
## launches at, and how hard it bends. Nothing else. A wedge is not a special
## case in code, it is a high launch angle and a short speed band, which is what
## it is on a driving range too.
##
## `intent.power` stays normalised 0..1 and never holds metres
## (RECORD_SCHEMA.md §2.1): metres are this resource's business, so retuning a
## club does not invalidate a stored record, it re-plays it with the new club.
## That is the whole reason the schema stores power rather than speed.

## The schema's `intent.club` enum. Frozen with the record format.
@export var id := "iron"

## Speed at power 0 and power 1, in m/s.
@export var min_speed := 8.0
@export var max_speed := 25.0
## Launch angle above the horizontal. The short clubs go up, the long ones out.
@export var launch_deg := 21.0
## Lateral acceleration at full curve, m/s^2. A longer club bends further in
## metres for the same number, because the ball is in the air longer -- so the
## numbers rise with the club rather than staying level.
@export var curve_accel := 8.0
## A putter rolls: no launch angle, no shaping, its own much smaller speed band.
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
## place range targets and to assert in tests that the three clubs actually
## cover three different distances.
func carry() -> float:
	if is_putter:
		return 0.0
	var g := absf(BallFlight.gravity().y)
	var v := max_speed
	return v * v * sin(deg_to_rad(launch_deg * 2.0)) / g


## The 1.0 set. Named constructors rather than `.tres` files for now: the
## numbers are still moving, and a resource on disk is harder to diff than a
## line of code. They become `.tres` when they stop changing every session
## (§6.1 wants clubs data-driven, and this is the same data one step earlier).
static func driver() -> ClubProfile:
	# Long and low. Carries about 78 m, which is the far target on the range.
	return make("driver", 13.0, 38.0, 16.0, 10.4)


static func iron() -> ClubProfile:
	# The middle of everything, and the club every previous version of this game
	# was secretly using for every shot.
	return make("iron", 8.5, 25.2, 24.0, 8.2)


static func wedge() -> ClubProfile:
	# Short and steep. Lands almost without running, which is what makes the
	# near target reachable at all -- a low club would skid straight past it.
	return make("wedge", 4.5, 15.6, 38.0, 5.4)


static func putter() -> ClubProfile:
	# Never chosen by the player (§2.1 makes it automatic on the green), and it
	# has no business on a driving range -- but the schema has four club names
	# and a reader has to be able to resolve all of them.
	return make("putter", 1.15, 9.7, 0.0, 0.0, true)


## The full set, in the schema's order.
static func all() -> Array[ClubProfile]:
	return [driver(), iron(), wedge(), putter()]


static func for_id(id_: String) -> ClubProfile:
	for club in all():
		if club.id == id_:
			return club
	push_error("ClubProfile: no club called %s; defaulting to iron." % id_)
	return iron()


static func for_intent(club: ShotIntent.Club) -> ClubProfile:
	return for_id(ShotIntent.CLUB_NAMES[club])


func to_intent_club() -> ShotIntent.Club:
	return ShotIntent.club_from_name(id)
