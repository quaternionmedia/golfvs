# GdUnitTestSuite
extends GdUnitTestSuite

## The shape test from RECORD_SCHEMA.md §5.
##
## Every fixture in tests/fixtures/records/ must be a well-formed schema v1
## Stroke Record. This is the only record test that can exist at M0, because
## there is no simulation yet to replay anything against; M1 adds the replay
## test that checks each fixture reproduces its stored after.hash.
##
## It matters now anyway. Schema v1 freezes at the M1 exit gate, and everything
## after that -- forks, Spot Duel, Postal Round, Match -- is an exchange of
## these files. A field that quietly changes shape before the freeze takes the
## whole fixture set with it.

const FIXTURE_DIR := "res://tests/fixtures/records"

const REQUIRED_TOP_LEVEL := [
	"schema", "game", "hole", "seed", "before", "intent", "defense", "after", "ext",
]
const CLUBS := ["long", "short", "putt"]
const LIES := ["tee", "fairway", "rough", "sand", "water", "green", "ob"]
const DEFENDER_STATES := ["idle", "tell", "act", "cooldown"]


func _fixture_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(FIXTURE_DIR)
	if dir == null:
		return paths
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			paths.append("%s/%s" % [FIXTURE_DIR, file_name])
	paths.sort()
	return paths


func _load_record(path: String) -> Dictionary:
	var raw := FileAccess.get_file_as_string(path)
	assert_str(raw).override_failure_message("could not read %s" % path).is_not_empty()
	var parsed: Variant = JSON.parse_string(raw)
	assert_bool(parsed is Dictionary) \
		.override_failure_message("%s is not a JSON object" % path) \
		.is_true()
	return parsed as Dictionary


func _assert_vec3(value: Variant, where: String) -> void:
	assert_bool(value is Array) \
		.override_failure_message("%s must be an array" % where).is_true()
	var vec: Array = value
	assert_int(vec.size()).override_failure_message("%s must have 3 components" % where).is_equal(3)
	for component: Variant in vec:
		assert_bool(component is float or component is int) \
			.override_failure_message("%s has a non-numeric component" % where) \
			.is_true()


func test_there_is_at_least_one_fixture() -> void:
	# An empty fixture directory would make every test below vacuously pass.
	assert_int(_fixture_paths().size()) \
		.override_failure_message(
			"no fixtures in %s. The fixture set is the record of what the " % FIXTURE_DIR +
			"simulation used to do; it must never be empty."
		) \
		.is_greater(0)


func test_fixtures_carry_the_required_top_level_fields() -> void:
	for path in _fixture_paths():
		var record := _load_record(path)
		for key: String in REQUIRED_TOP_LEVEL:
			assert_bool(record.has(key)) \
				.override_failure_message("%s is missing the required field %s" % [path, key]) \
				.is_true()


func test_fixtures_declare_schema_version_one() -> void:
	for path in _fixture_paths():
		var record := _load_record(path)
		assert_int(int(record.get("schema", -1))) \
			.override_failure_message(
				"%s does not declare schema 1. Bumping the schema is an ADR " % path +
				"(RECORD_SCHEMA.md §1), not a patch."
			) \
			.is_equal(1)


func test_intent_is_within_its_declared_ranges() -> void:
	for path in _fixture_paths():
		var record := _load_record(path)
		var intent: Dictionary = record.get("intent", {})

		assert_array(CLUBS) \
			.override_failure_message("%s: unknown club %s" % [path, intent.get("club", "")]) \
			.contains(intent.get("club", ""))

		# Power is normalised, never metres: metres are a ClubProfile concern
		# and would break replay whenever a club is retuned.
		assert_float(float(intent.get("power", -1.0))) \
			.override_failure_message("%s: power must be 0.0-1.0" % path) \
			.is_between(0.0, 1.0)

		assert_float(float(intent.get("curve", 2.0))) \
			.override_failure_message("%s: curve must be -1.0-1.0" % path) \
			.is_between(-1.0, 1.0)

		_assert_vec3(intent.get("dir"), "%s: intent.dir" % path)


func test_before_state_is_restorable() -> void:
	# ReplayController has to reconstruct the world from `before` alone
	# (RECORD_SCHEMA.md §2.1). Anything missing here makes a record unreplayable.
	for path in _fixture_paths():
		var record := _load_record(path)
		var before: Dictionary = record.get("before", {})

		var ball: Dictionary = before.get("ball", {})
		_assert_vec3(ball.get("pos"), "%s: before.ball.pos" % path)
		assert_array(LIES) \
			.override_failure_message("%s: unknown lie %s" % [path, ball.get("lie", "")]) \
			.contains(ball.get("lie", ""))

		# 1-based ordinal of the stroke this record describes.
		assert_int(int(before.get("stroke_no", 0))) \
			.override_failure_message("%s: before.stroke_no must be 1 or greater" % path) \
			.is_greater(0)

		assert_bool(before.get("defenders") is Array) \
			.override_failure_message(
				"%s: before.defenders must be an array (empty in Scottish Rules)" % path
			) \
			.is_true()
		for defender: Variant in before.get("defenders", []):
			var d: Dictionary = defender
			_assert_vec3(d.get("pos"), "%s: defender %s pos" % [path, d.get("id", "?")])
			assert_array(DEFENDER_STATES) \
				.override_failure_message(
					"%s: defender %s has unknown state %s" % [path, d.get("id", "?"), d.get("state", "")]
				) \
				.contains(d.get("state", ""))


func test_after_is_present_and_hashed() -> void:
	# `after` is derived, never authoritative -- but it must be there, because a
	# client compares its own recomputed hash against this one (§2.2).
	for path in _fixture_paths():
		var record := _load_record(path)
		var after: Dictionary = record.get("after", {})

		var ball: Dictionary = after.get("ball", {})
		_assert_vec3(ball.get("pos"), "%s: after.ball.pos" % path)
		assert_bool(after.get("events") is Array) \
			.override_failure_message("%s: after.events must be an array" % path) \
			.is_true()
		assert_str(str(after.get("hash", ""))) \
			.override_failure_message("%s: after.hash is missing" % path) \
			.is_not_empty()


func test_extensions_live_in_ext() -> void:
	# Everything new goes in `ext` after the M1 freeze. Checking it is a
	# dictionary now is what makes that promise keepable later.
	for path in _fixture_paths():
		var record := _load_record(path)
		assert_bool(record.get("ext") is Dictionary) \
			.override_failure_message("%s: ext must be an object" % path) \
			.is_true()
