class_name Canonical
extends Object
## Canonical serialisation for records: the one place a float becomes text.
##
## RECORD_SCHEMA.md §6.4 leaves float serialisation open and warns it must be
## fixed "before the first fixture is recorded, not after". This is the proposed
## answer, and it sidesteps the round-trip problem rather than solving it:
## **quantize on write, and let the record be the source of truth.**
##
## A stroke's inputs are rounded to a fixed number of decimals before they are
## either simulated or written. The number the sim consumes is therefore exactly
## the number on disk, so a record read back on another platform feeds that
## platform's sim bit-identical inputs. Nothing depends on a double surviving a
## decimal round trip by luck, and nothing needs hex floats or seventeen digits
## of noise to stay honest.
##
## The precisions come from what the values mean, not from what a float can
## hold. A tenth of a millimetre is orders below anything a golfer can aim; six
## decimals on a 0..1 scalar is finer than any screen can express as a drag.
##
## Round-tripping is then exact rather than approximate. A decimal with six or
## fewer places and a magnitude under a million names exactly one double, and
## every correctly-rounded `strtod` -- which is all of them on our targets --
## returns that double. The test suite asserts it rather than trusting it.

## 0.1 mm. Positions, in metres.
const POS_DECIMALS := 4
## Normalised 0..1 and -1..1 values: power, curve, cooldowns.
const SCALAR_DECIMALS := 6
## Unit vector components.
const DIR_DECIMALS := 6
## The width every float is written at. Must be at least the largest above, so
## that a value already quantized is written back unchanged.
const CANON_DECIMALS := 6

## Beyond this a fixed-decimal string stops being either small or exact. Course
## coordinates are three orders below it; anything larger is a bug upstream, and
## silently writing it would put an unreadable record on disk.
const MAX_MAGNITUDE := 1.0e9


## The value the simulation must use, so that it matches the value on disk.
static func quantize(value: float, decimals: int) -> float:
	# pow() is Variant-typed, so the annotations are load-bearing rather than
	# decorative: without them the inferred type is Variant and the file will
	# not compile under the typed-GDScript rule in CONTRIBUTING.md.
	var factor: float = pow(10.0, float(decimals))
	var q: float = roundf(value * factor) / factor
	# -0.0 == 0.0 is true, so this collapses the negative zero that rounding a
	# small negative produces. Left alone it serialises as "-0.000000" and two
	# records that are the same game hash differently.
	return 0.0 if q == 0.0 else q


static func quantize_vec3(v: Vector3, decimals: int) -> Vector3:
	return Vector3(
		quantize(v.x, decimals),
		quantize(v.y, decimals),
		quantize(v.z, decimals))


## A float as canonical text. Fixed width, never scientific notation.
static func num(value: float) -> String:
	if not is_finite(value):
		push_error("Canonical.num: %f is not finite; a record cannot hold it." % value)
		return "0.000000"
	if absf(value) > MAX_MAGNITUDE:
		push_error("Canonical.num: %f exceeds MAX_MAGNITUDE." % value)
		return "0.000000"
	return "%.*f" % [CANON_DECIMALS, quantize(value, CANON_DECIMALS)]


## A Vector3 as the schema's `[x, y, z]`, quantized to `decimals`.
static func vec3_array(v: Vector3, decimals := POS_DECIMALS) -> Array:
	var q := quantize_vec3(v, decimals)
	return [q.x, q.y, q.z]


static func array_vec3(a: Array) -> Vector3:
	if a.size() != 3:
		push_error("Canonical.array_vec3: expected 3 components, got %d." % a.size())
		return Vector3.ZERO
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Canonical JSON: sorted keys, no whitespace, every float at CANON_DECIMALS.
##
## Not `JSON.stringify`. That function's key order follows insertion and its
## float format follows the engine's default precision, so two runs that agree
## on every value can still produce different bytes -- and the bytes are what is
## hashed. Determinism has to be a property of the encoder, not of the caller.
static func encode(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return num(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(String(value))
		TYPE_VECTOR3:
			return encode(vec3_array(value))
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var parts := PackedStringArray()
			for item in value:
				parts.append(encode(item))
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			var keys := dict.keys()
			keys.sort()
			var pairs := PackedStringArray()
			for key in keys:
				pairs.append("%s:%s" % [JSON.stringify(String(key)), encode(dict[key])])
			return "{" + ",".join(pairs) + "}"
	push_error("Canonical.encode: no encoding for type %d." % typeof(value))
	return "null"


## SHA-256 of the canonical encoding, as lowercase hex.
static func hash_of(value: Variant) -> String:
	return encode(value).sha256_text()


## The all-zero hash: "no simulation has computed this yet". The M0 fixture
## carries it deliberately and the replay test skips any record that has it.
static func unset_hash() -> String:
	return "0".repeat(64)


static func is_unset(digest: String) -> bool:
	return digest == unset_hash()
