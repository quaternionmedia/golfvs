extends Node
## Plays a whole range session headless and prints what the record spine made
## of it.
##
## The merged demo: records, ShotIntent and seeds, the clubs, the range and the
## archer, exercised together in the order a real session exercises them.
## Nothing here is a mock -- it drives the shipping range through the shipping
## gesture callback and reads back the files the shipping RecordStore wrote.
##
## It is a demo first and a smoke test second, but it is a real smoke test: it
## exits non-zero if a stroke fails to replay to its own hash, if the session on
## disk does not match the one that was played, or if a defender's verdict is not
## reproducible from its seed. Those are the three claims the whole async half of
## the game rests on, and they are cheap to check on every run.
##
##   godot --headless --fixed-fps 120 --path . res://tools/demo_round.tscn

## How well the demo golfer strikes it. Short of perfect on purpose: one that
## plays the ideal shot every time never misses a pin, and a range where nobody
## ever misses shows none of what a range is for.
const GOLFER_SKILL := 0.9

## Hard stop, so a ball that never settles cannot hang the run.
const MAX_STROKES := 14
const MAX_TICKS_PER_STROKE := 900

var _range: Node3D
var _failures: PackedStringArray = []


func _ready() -> void:
	_range = preload("res://holes/range/practice_range.tscn").instantiate()
	add_child(_range)
	if _is_headless():
		await get_tree().process_frame
		await _play()
		get_tree().quit(0 if _failures.is_empty() else 1)


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless" \
		or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED


func _play() -> void:
	_rule("golfVs -- merged demo: one session on range/01")
	print("  engine       %s" % Engine.get_version_info().string)
	print("  record game  %s" % StrokeRecord.game_string())
	print("  layout hash  %s" % _range._layout_hash())
	print("  round seed   %d" % _range._round_seed)
	print("  pins         %d" % _range.PINS.size())
	for spec in _range.PINS:
		var at: Vector3 = spec["at"]
		var club := ClubProfile.for_id(String(spec["suggests"]))
		var reach: float = club.rolls() if club.is_putter else club.carry()
		print("               %-6s pin %5.1f m out, green r=%.1f, club reaches %.0f m" % [
			club.id, Vector2(at.x, at.z).length(), float(spec["radius"]), reach])
	for defender in _range._defenders:
		var profile: DefenderProfile = defender.brain.profile
		print("  marshal      %s on the tower at %v, guarding the boundary" % [
			defender.brain.id, profile.stand])

	_rule("strokes")
	while _range.state != _range.State.DONE and _range.strokes < MAX_STROKES:
		await _take_stroke()

	_rule("card")
	print("  pins made    %d of %d" % [_range.pin, _range.PINS.size()])
	print("  strokes      %d" % _range.strokes)
	var done: bool = _range.state == _range.State.DONE
	print("  finished     %s" % ("yes" if done
		else "no -- gave up after %d strokes" % MAX_STROKES))

	_rule("notation (RECORD_SCHEMA.md 4.1 -- derived, never parsed back)")
	for line in _range.round_notation().split("\n"):
		if line != "":
			print("  %s" % line)

	_rule("verification")
	_check_hashes()
	_check_determinism()
	await _check_session_on_disk()

	_rule("result")
	if _failures.is_empty():
		print("  PASS -- every stroke replays to its own hash, and the session on")
		print("          disk is the session that was played.")
	else:
		for failure in _failures:
			print("  FAIL -- %s" % failure)


func _take_stroke() -> void:
	var club: ClubProfile = _range.club()
	var target: Vector3 = _range.pin_position()
	# Nothing is ever in the way on a range, so the golfer's blocked-predicate
	# always answers no. It still gets one, because AIGolfer takes the world it
	# is playing rather than reaching for a particular level's geometry.
	var clear := func(_arc: PackedVector3Array) -> bool: return false
	var intent := AIGolfer.choose(
		_range.ball.global_position, target, _range.BALL_RADIUS,
		clear, club.is_putter, GOLFER_SKILL,
		_range._seed_for_stroke(_range.strokes + 1), club)

	var pin_before: int = _range.pin
	# Driven through the same callback StrokeGesture fires, so the demo cannot
	# take a path the player's thumb does not.
	_range._on_gesture_began()
	_range._on_fired(intent.direction, intent.power, intent.curve)

	var number: int = _range.strokes
	var ticks := 0
	while _range.state == _range.State.FLIGHT and ticks < MAX_TICKS_PER_STROKE:
		await get_tree().physics_frame
		ticks += 1

	var record: StrokeRecord = _range._round[-1] if not _range._round.is_empty() else null
	print("")
	print("  %d. at the %s pin, %.0f m out" % [
		number, club.id, Vector2(target.x, target.z).length()])
	if record == null:
		_failures.append("stroke %d wrote no record" % number)
		return
	var rest := record.after_pos
	print("     intent     %s" % record.intent.to_notation())
	print("     finished   %v on the %s   (%.1f m out, %.1f m from the pin)" % [
		rest, record.after_lie, Vector2(rest.x, rest.z).length(),
		Vector2(rest.x - target.x, rest.z - target.z).length()])
	print("     seed       %d" % record.seed)
	print("     events     %s" % ("-" if record.events.is_empty() else ", ".join(record.events)))
	for defender in _range._defenders:
		var brain: DefenderBrain = defender.brain
		if brain.is_committed() and brain.will_connect():
			print("     %s  pinned it at %v -- it was leaving the range" % [
				brain.id, brain.act_point()])
	print("     hash       %s" % record.after_hash.substr(0, 16))
	if _range.pin != pin_before:
		print("     >>> pin made; the %s comes out next" % _range.club().id)


func _check_hashes() -> void:
	var checked := 0
	for record in _range._round:
		if not record.hash_matches():
			_failures.append("stroke %d does not match its own hash" % record.stroke_no)
		checked += 1
	print("  %d stroke record(s) re-hashed from their own contents: %s" % [
		checked, "all match" if _failures.is_empty() else "MISMATCH"])


## The defender verdict has to be a pure function of (arc, seed). If it is not,
## no record replays and every async mode in section 4 is unreachable.
func _check_determinism() -> void:
	if _range._defenders.is_empty():
		print("  determinism  no defenders here; nothing to re-roll")
		return
	var brain: DefenderBrain = _range._defenders[0].brain
	var arc := BallFlight.sample_arc(
		Vector3(0.0, 0.35, 0.0),
		BallFlight.launch_velocity(
			Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(46.0)), 1.0,
			false, ClubProfile.long_club()),
		Vector3.ZERO, 0.18, 900, _range.DEFENDER_DT)

	var first := ArcherBrain.new()
	first.configure(brain.profile, brain.tier, brain.id)
	first.read_shot(arc, _range.DEFENDER_DT, 8123481)
	var stable := true
	for i in 50:
		var again := ArcherBrain.new()
		again.configure(brain.profile, brain.tier, brain.id)
		again.read_shot(arc, _range.DEFENDER_DT, 8123481)
		stable = stable and again.will_connect() == first.will_connect() \
			and is_equal_approx(again.reaction_delay(), first.reaction_delay())
	if not stable:
		_failures.append("the same seed and arc gave different defender verdicts")
	print("  determinism  50 re-reads of one wild arc at seed 8123481: %s (hesitates %.3f s)" % [
		"identical" if stable else "DIVERGED", first.reaction_delay()])


func _check_session_on_disk() -> void:
	var path: String = _range.round_path
	if path == "":
		print("  on disk      not saved (the session was not finished)")
		return
	await get_tree().process_frame
	var data := RecordStore.load_round(path)
	var reloaded := RecordStore.strokes_of(data)
	print("  on disk      %s" % path)
	print("               %d strokes, %d bytes" % [
		reloaded.size(), FileAccess.get_file_as_string(path).length()])

	if reloaded.size() != _range._round.size():
		_failures.append("the session on disk has %d strokes, the one played had %d"
			% [reloaded.size(), _range._round.size()])
		return
	for i in reloaded.size():
		var there: StrokeRecord = reloaded[i]
		var here: StrokeRecord = _range._round[i]
		if there.after_hash != here.after_hash:
			_failures.append("stroke %d changed hash on the way to disk" % here.stroke_no)
		if not there.hash_matches():
			_failures.append("stroke %d does not validate after reloading" % here.stroke_no)
	print("               every reloaded stroke validates against its stored hash")


func _rule(title: String) -> void:
	print("")
	print("-- %s %s" % [title, "-".repeat(maxi(2, 66 - title.length()))])
