# GdUnit generated TestSuite
extends GdUnitTestSuite

## StrokeRecord as the wire format: what it writes, what it reads back, and
## what its hash covers.
##
## `tests/records/test_record_schema.gd` already checks that the fixtures on
## disk have the right *shape*. This suite checks the class that will produce
## them from M1 on: that a record survives its own serialisation, that the hash
## covers what §2.2 says it covers and nothing else, and that `after` really is
## derived -- editing a stored hash has to be detectable, or the "a relay is a
## mailbox, not a referee" argument does not hold.

const FIXTURE := "res://tests/fixtures/records/0001-parkland-03-stroke-2.json"


func _a_stroke() -> StrokeRecord:
	var intent := ShotIntent.make(ShotIntent.Club.SHORT, 0.72, -0.15, Vector3(0.0, 0.0, -1.0))
	var record := StrokeRecord.opened(
		"parkland/03", "0000000000000000", 8123481, 2,
		Vector3(12.5, 0.0, -38.25), "fairway", intent)
	record.defenders = [
		{"id": "skeet_0", "pos": [4.0, 0.0, -60.0], "state": "idle", "cooldown": 0.0},
	]
	return record


func test_an_opened_record_has_not_been_simulated_yet() -> void:
	var record := _a_stroke()
	assert_bool(Canonical.is_unset(record.after_hash)).is_true()
	# Before the ball moves, `after` is `before`. A round abandoned mid-stroke
	# still writes a well-formed file rather than a half-filled one.
	assert_vector(record.after_pos).is_equal(record.before_pos)
	assert_str(record.after_lie).is_equal("fairway")


func test_resolving_fills_in_the_result_and_the_hash() -> void:
	var record := _a_stroke()
	record.resolve(Vector3(1.75, 0.0, -96.5), "green",
		PackedStringArray(["skeet_fired", "miss"]))
	assert_bool(Canonical.is_unset(record.after_hash)).is_false()
	assert_bool(record.hash_matches()).is_true()
	assert_str(record.after_lie).is_equal("green")


func test_the_hash_covers_the_result_and_not_the_inputs() -> void:
	# §2.2: the digest is over `after.ball` and `after.events`. Hashing `seed`
	# or `before` too would make it change for reasons that are not the
	# stroke's outcome, and a fork -- which replays the same before-state with a
	# different intent -- could then never be compared against its parent.
	var record := _a_stroke()
	record.resolve(Vector3(1.75, 0.0, -96.5), "green", PackedStringArray(["miss"]))
	var digest := record.after_hash

	record.seed = 999
	record.stroke_no = 7
	record.before_pos = Vector3(0.0, 0.0, 0.0)
	record.game = "somebody-elses-build"
	assert_str(record.compute_hash()).is_equal(digest)

	record.after_lie = "sand"
	assert_str(record.compute_hash()).is_not_equal(digest)


func test_a_tampered_hash_is_detectable() -> void:
	var record := _a_stroke()
	record.resolve(Vector3(1.75, 0.0, -96.5), "green", PackedStringArray([]))
	assert_bool(record.hash_matches()).is_true()
	record.after_pos = Vector3(9.0, 0.0, -57.0)
	assert_bool(record.hash_matches()).is_false()


func test_a_record_survives_a_json_round_trip() -> void:
	var record := _a_stroke()
	record.resolve(Vector3(1.75, 0.0, -96.5), "green",
		PackedStringArray(["skeet_fired", "miss"]))

	var reloaded := StrokeRecord.from_json(record.to_json())
	assert_object(reloaded).is_not_null()
	assert_int(reloaded.schema).is_equal(1)
	assert_str(reloaded.hole_id).is_equal("parkland/03")
	assert_int(reloaded.seed).is_equal(8123481)
	assert_int(reloaded.stroke_no).is_equal(2)
	assert_vector(reloaded.before_pos).is_equal(record.before_pos)
	assert_vector(reloaded.after_pos).is_equal(record.after_pos)
	assert_array(Array(reloaded.events)).is_equal(["skeet_fired", "miss"])
	assert_int(reloaded.defenders.size()).is_equal(1)

	# The point of the exercise: a record that has been to disk and back still
	# validates against its own hash, on the same platform and on any other.
	assert_str(reloaded.after_hash).is_equal(record.after_hash)
	assert_bool(reloaded.hash_matches()).is_true()


func test_the_intent_survives_the_round_trip_exactly() -> void:
	var record := _a_stroke()
	var reloaded := StrokeRecord.from_json(record.to_json())
	assert_float(reloaded.intent.power).is_equal(record.intent.power)
	assert_float(reloaded.intent.curve).is_equal(record.intent.curve)
	assert_vector(reloaded.intent.direction).is_equal(record.intent.direction)
	assert_str(reloaded.intent.club_name()).is_equal("short")


func test_intent_values_are_quantized_at_construction() -> void:
	# Not on write. If the sim ran on the raw drag and the record stored a
	# rounded copy, a replay would feed the sim different numbers from the ones
	# the original stroke used.
	var intent := ShotIntent.make(
		ShotIntent.Club.LONG, 0.7234567891, -0.1512345678, Vector3(0.3, 5.0, -1.0))
	assert_float(intent.power).is_equal(0.723457)
	assert_float(intent.curve).is_equal(-0.151235)
	# Flattened to the XZ plane and normalised, as the schema promises.
	assert_float(intent.direction.y).is_equal(0.0)
	assert_float(intent.direction.length()).is_equal_approx(1.0, 1.0e-5)


func test_the_m0_fixture_loads_through_the_class() -> void:
	# The fixture was hand-authored before this class existed. It has to keep
	# loading -- it is the reference for "996 bytes including a long ext".
	var record := StrokeRecord.from_json(FileAccess.get_file_as_string(FIXTURE))
	assert_object(record).is_not_null()
	assert_int(record.schema).is_equal(StrokeRecord.SCHEMA_VERSION)
	assert_str(record.hole_id).is_equal("parkland/03")
	assert_float(record.intent.power).is_equal(0.72)
	assert_bool(Canonical.is_unset(record.after_hash)).is_true()
	assert_bool(record.ext.has("fixture")).is_true()


func test_notation_is_the_derived_one_line_view() -> void:
	var record := _a_stroke()
	record.resolve(Vector3(1.75, 0.0, -96.5), "green",
		PackedStringArray(["skeet_fired", "miss"]))
	assert_str(record.to_notation()).is_equal("2. S 0.72 L15 → G (skeet ✗)")

	record.events = PackedStringArray(["skeet_fired", "skeet_hit"])
	assert_str(record.to_notation()).is_equal("2. S 0.72 L15 → G (skeet ✓)")


func test_notation_is_never_parsed_back() -> void:
	# §4.1 calls the notation a derived view and says it is never parsed as
	# input. That is only true for as long as nobody writes the parser, so the
	# absence is the thing worth asserting -- a `from_notation` appearing here
	# is a schema change wearing a convenience's clothes.
	# get_script_method_list() reports static methods too, which has_method()
	# on an instance does not -- and a parser would almost certainly be written
	# as a static one, so that is the list worth searching.
	assert_array(_method_names(StrokeRecord.new())).not_contains(["from_notation"])
	assert_array(_method_names(ShotIntent.new())).not_contains(["from_notation"])


func _method_names(instance: Object) -> Array:
	var names := []
	for entry in instance.get_script().get_script_method_list():
		names.append(entry["name"])
	return names
