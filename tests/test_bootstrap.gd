# GdUnitTestSuite
extends GdUnitTestSuite

## M0's "CI green on an empty test" (Appendix A step 3).
##
## The first assertion is deliberately trivial: its only job is to prove the
## runner, the vendored addon and the workflow line up, so that the first red
## suite at M1 is a real failure and not a plumbing problem.
##
## The second one is not trivial. ADR-008 pins the engine and says upgrades are
## their own ADR with a full export-target test pass -- so an unannounced engine
## change should turn CI red, here, immediately, rather than surface later as a
## physics drift nobody can date.


func test_the_harness_runs() -> void:
	assert_int(2 + 2).is_equal(4)


func test_engine_matches_the_pin() -> void:
	var pinned: String = ProjectSettings.get_setting("golfvs/engine/pinned_godot_version", "")
	assert_str(pinned) \
		.override_failure_message(
			"project.godot has no golfvs/engine/pinned_godot_version. " +
			"ADR-008 requires the engine version to be recorded there."
		) \
		.is_not_empty()

	var info := Engine.get_version_info()
	var running := "%d.%d.%d.%s" % [info.major, info.minor, info.patch, info.status]
	assert_str(running) \
		.override_failure_message(
			"Running Godot %s, but this project is pinned to %s (ADR-008). " % [running, pinned] +
			"Upgrading the engine is its own ADR, not a bump: it needs a full " +
			"export-target test pass and an entry in DECISIONS.md."
		) \
		.is_equal(pinned)


func test_the_pin_agrees_with_the_godot_version_file() -> void:
	# .godot-version is what CI reads; project.godot is what the editor reads.
	# They are two records of one decision, so they must not drift apart.
	var from_file := FileAccess.get_file_as_string("res://.godot-version").strip_edges()
	assert_str(from_file) \
		.override_failure_message("res://.godot-version is missing or empty.") \
		.is_not_empty()

	var from_settings: String = ProjectSettings.get_setting("golfvs/engine/pinned_godot_version", "")
	# The file uses the release's download form (4.7.2-stable), project.godot
	# uses the engine's own form (4.7.2.stable). Compare them on one spelling.
	assert_str(from_file.replace("-", ".")) \
		.override_failure_message(
			".godot-version says %s but project.godot says %s." % [from_file, from_settings]
		) \
		.is_equal(from_settings)
