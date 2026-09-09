# GdUnit generated TestSuite
extends GdUnitTestSuite

## The serialisation contract, asserted rather than assumed.
##
## RECORD_SCHEMA.md §6.4 says records must round-trip bit-for-bit across
## platforms and that the decision has to be made before the first fixture is
## recorded. Canonical's answer is to quantize on write so that the number the
## simulation uses is the number on disk. That claim is only worth anything if
## something checks it, and the check has to be exact equality -- an
## "approximately equal" assertion here would pass while records silently
## drifted, which is the exact failure the schema freeze exists to prevent.


func test_quantize_collapses_negative_zero() -> void:
	# Rounding any small negative produces -0.0, which serialises as
	# "-0.000000". Two records that are the same game would then hash
	# differently, which is a bug that would surface as a bogus version-drift
	# warning months later.
	var q := Canonical.quantize(-0.0000001, Canonical.SCALAR_DECIMALS)
	assert_str(Canonical.num(q)).is_equal("0.000000")
	assert_str(Canonical.num(-0.0)).is_equal("0.000000")


func test_a_quantized_float_survives_the_round_trip_exactly() -> void:
	# The load-bearing assertion in the whole record format.
	var samples := [
		0.0, 1.0, -1.0, 0.5, 0.72, -0.15,
		12.5, -38.25, 57.0, 0.000001, -0.000001,
		9.8765432109, 123456.789, -0.9999995,
	]
	for value in samples:
		var quantized: float = Canonical.quantize(value, Canonical.CANON_DECIMALS)
		var text := Canonical.num(quantized)
		var parsed := float(text)
		assert_float(parsed).is_equal(quantized)


func test_the_round_trip_holds_over_a_wide_random_sweep() -> void:
	# Fourteen hand-picked values prove the easy cases. A sweep is what catches
	# the ones nobody thought to write down.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260909
	for i in 2000:
		var raw := rng.randf_range(-500.0, 500.0)
		var quantized := Canonical.quantize(raw, Canonical.CANON_DECIMALS)
		assert_float(float(Canonical.num(quantized))).is_equal(quantized)


func test_numbers_are_never_written_in_scientific_notation() -> void:
	# A record is meant to be readable in a chat message and diffable in git.
	# "1e-06" is neither, and some JSON readers narrow it to a float32.
	assert_str(Canonical.num(0.000001)).is_equal("0.000001")
	assert_str(Canonical.num(123456.5)).is_equal("123456.500000")
	assert_str(Canonical.num(0.0)).is_equal("0.000000")


func test_positions_quantize_to_a_tenth_of_a_millimetre() -> void:
	var q := Canonical.quantize(12.34567891, Canonical.POS_DECIMALS)
	assert_float(q).is_equal_approx(12.3457, 1.0e-9)


func test_encoding_sorts_keys_so_the_hash_ignores_insertion_order() -> void:
	var one := {"b": 2, "a": 1, "c": 3}
	var other := {"c": 3, "a": 1, "b": 2}
	assert_str(Canonical.encode(one)).is_equal('{"a":1,"b":2,"c":3}')
	assert_str(Canonical.encode(one)).is_equal(Canonical.encode(other))
	assert_str(Canonical.hash_of(one)).is_equal(Canonical.hash_of(other))


func test_encoding_keeps_ints_and_floats_apart() -> void:
	# `schema` is an int and `power` is a float. If the encoder blurred them,
	# every record would hash differently depending on how it was built.
	assert_str(Canonical.encode({"schema": 1})).is_equal('{"schema":1}')
	assert_str(Canonical.encode({"power": 1.0})).is_equal('{"power":1.000000}')


func test_encoding_has_no_whitespace() -> void:
	var encoded := Canonical.encode({"ball": {"pos": [1.0, 2.0, 3.0]}, "events": ["a"]})
	assert_str(encoded).is_equal(
		'{"ball":{"pos":[1.000000,2.000000,3.000000]},"events":["a"]}')


func test_the_hash_is_sixty_four_hex_characters() -> void:
	var digest := Canonical.hash_of({"ball": {"lie": "green"}})
	assert_int(digest.length()).is_equal(64)
	assert_bool(digest.is_valid_hex_number()).is_true()
	assert_str(digest).is_equal(digest.to_lower())


func test_the_unset_hash_means_no_simulation_has_run() -> void:
	# The M0 fixture carries this on purpose. HANDOFF.md is emphatic that nobody
	# should "fix" the zeros by hand, so the meaning gets a test of its own.
	assert_int(Canonical.unset_hash().length()).is_equal(64)
	assert_bool(Canonical.is_unset(Canonical.unset_hash())).is_true()
	assert_bool(Canonical.is_unset(Canonical.hash_of({"a": 1}))).is_false()


func test_a_changed_value_changes_the_hash() -> void:
	var before := Canonical.hash_of({"pos": [1.0, 0.0, 0.0]})
	var after := Canonical.hash_of({"pos": [1.0001, 0.0, 0.0]})
	assert_str(before).is_not_equal(after)
