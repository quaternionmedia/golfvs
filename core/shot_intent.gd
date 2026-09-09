class_name ShotIntent
extends RefCounted
## The only thing that crosses from input into simulation (§6.3).
##
## Everything the player did is in here and nothing else reaches the sim: no
## node references, no screen coordinates, no clock, no engine state. That is
## the whole trick behind replay -- the record stores this object, and the
## simulation cannot tell a replayed intent from a live one.
##
## Values are quantized on construction rather than on write. The distinction
## matters: if the sim ran on the raw drag and the record stored a rounded copy,
## a replay would be feeding the sim very slightly different inputs from the
## original, and over a few hundred physics ticks the two would part company.
## Quantizing at the boundary means the number the player produced, the number
## the simulation consumes, and the number on disk are one number.

enum Club { DRIVER, IRON, WEDGE, PUTTER }

## Index by Club. These strings are the schema's `intent.club` enum and are
## frozen with it at M1 exit -- renaming one invalidates every stored record.
const CLUB_NAMES: Array[String] = ["driver", "iron", "wedge", "putter"]

var club: Club = Club.IRON
var power := 0.0
var curve := 0.0
var direction := Vector3.FORWARD


## The only constructor. Named rather than `_init` so that the quantizing step
## cannot be skipped by building the object field by field.
static func make(club_: Club, power_: float, curve_: float, direction_: Vector3) -> ShotIntent:
	var intent := ShotIntent.new()
	intent.club = club_
	intent.power = Canonical.quantize(clampf(power_, 0.0, 1.0), Canonical.SCALAR_DECIMALS)
	intent.curve = Canonical.quantize(clampf(curve_, -1.0, 1.0), Canonical.SCALAR_DECIMALS)
	# Flattened and normalised before quantizing: the schema calls this a unit
	# vector on the XZ plane, and a reader is entitled to rely on that without
	# re-normalising. Quantizing afterwards costs at most a millionth of a
	# degree of aim, which is well under the width of the ball at any range.
	var flat := Vector3(direction_.x, 0.0, direction_.z)
	if flat.length_squared() < 1.0e-12:
		push_error("ShotIntent.make: direction has no horizontal component.")
		flat = Vector3.FORWARD
	intent.direction = Canonical.quantize_vec3(flat.normalized(), Canonical.DIR_DECIMALS)
	return intent


func club_name() -> String:
	return CLUB_NAMES[club]


static func club_from_name(name: String) -> Club:
	var index := CLUB_NAMES.find(name)
	if index < 0:
		push_error("ShotIntent: unknown club %s; defaulting to iron." % name)
		return Club.IRON
	return index as Club


func is_putt() -> bool:
	return club == Club.PUTTER


func to_dict() -> Dictionary:
	return {
		"club": club_name(),
		"power": power,
		"curve": curve,
		"dir": Canonical.vec3_array(direction, Canonical.DIR_DECIMALS),
	}


static func from_dict(data: Dictionary) -> ShotIntent:
	return make(
		club_from_name(String(data.get("club", "iron"))),
		float(data.get("power", 0.0)),
		float(data.get("curve", 0.0)),
		Canonical.array_vec3(data.get("dir", [0.0, 0.0, -1.0])))


## The §4.1 notation fragment for this intent: "I 0.72 L15".
func to_notation() -> String:
	var letter := club_name().substr(0, 1).to_upper()
	var out := "%s %.2f" % [letter, power]
	if not is_zero_approx(curve):
		out += " %s%02d" % ["R" if curve > 0.0 else "L", roundi(absf(curve) * 100.0)]
	return out
