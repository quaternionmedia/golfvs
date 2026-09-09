extends Node
## Plays a whole hole headless and prints what the record spine made of it.
##
## The merged demo: Lane A (records), Lane B (ShotIntent and seeds), Lane D (the
## intro hole) and Lane E (the skeet) exercised together, in the order a real
## round exercises them. Nothing here is a mock -- it drives the shipping hole
## through the shipping gesture callback and reads back the files the shipping
## RecordStore wrote.
##
## It is a demo first and a smoke test second, but it is a real smoke test: it
## exits non-zero if a stroke fails to replay to its own hash, if the round on
## disk does not match the round in memory, or if a defender's verdict is not
## reproducible from its seed. Those are the three claims the whole async half
## of the game rests on, and they are cheap to check on every run.
##
##   godot --headless --path . res://tools/demo_round.tscn
##
## Interactive it does the same thing with the hole visible, which is the
## fastest way to watch a shooter tell and fire without playing for it.

## How well the demo golfer strikes it. Deliberately short of perfect: a golfer
## that plays the ideal shot every time never gives the shooter a chance and
## never shows the hole recovering from a bad lie.
const GOLFER_SKILL := 0.86

## Hard stop, so a ball that never settles cannot hang the run.
const MAX_STROKES := 8
const MAX_TICKS_PER_STROKE := 900

var _hole: Node3D
var _failures: PackedStringArray = []


func _ready() -> void:
	_hole = preload("res://holes/intro/intro_hole.tscn").instantiate()
	add_child(_hole)
	if _is_headless():
		# One frame so the hole finishes _ready() and builds its geometry.
		await get_tree().process_frame
		await _play()
		get_tree().quit(0 if _failures.is_empty() else 1)


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless" \
		or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED


func _play() -> void:
	_rule("golfVs — merged demo: one round of intro/01")
	print("  engine       %s" % Engine.get_version_info().string)
	print("  record game  %s" % StrokeRecord.game_string())
	print("  layout hash  %s" % _hole._layout_hash())
	print("  round seed   %d" % _hole._round_seed)
	print("  defenders    %d" % _hole._defenders.size())
	for shooter in _hole._defenders:
		var profile: DefenderProfile = shooter.brain.profile
		print("               %s at %v, watching %v r=%.1f, band %.1f-%.1f m, tell %.2f s" % [
			shooter.brain.id, profile.stand, profile.zone_centre, profile.zone_radius,
			profile.zone_min_y, profile.zone_max_y, profile.tell_for(shooter.brain.tier)])

	_rule("strokes")
	while _hole.state != _hole.State.HOLED and _hole.strokes < MAX_STROKES:
		await _take_stroke()

	_rule("scorecard")
	var strokes: int = _hole.strokes
	print("  par %d, taken %d  (%s)" % [
		_hole.PAR, strokes, _relative(strokes, _hole.PAR)])
	var holed: bool = _hole.state == _hole.State.HOLED
	print("  holed        %s" % ("yes" if holed else "no — gave up after %d strokes" % MAX_STROKES))

	_rule("notation (RECORD_SCHEMA.md §4.1 — derived, never parsed back)")
	for line in _hole.round_notation().split("\n"):
		if line != "":
			print("  %s" % line)

	_rule("verification")
	_check_hashes()
	_check_determinism()
	await _check_round_on_disk()

	_rule("result")
	if _failures.is_empty():
		print("  PASS — every stroke replays to its own hash, and the round on")
		print("         disk is the round that was played.")
	else:
		for failure in _failures:
			print("  FAIL — %s" % failure)


func _take_stroke() -> void:
	var lesson: int = _hole.lesson
	var putting: bool = lesson == _hole.Lesson.PUTT
	var intent := AIGolfer.choose(
		_hole.ball.global_position, _hole._aim_point(), _hole.BALL_RADIUS,
		Callable(_hole, "_arc_blocked"), putting, GOLFER_SKILL,
		_hole._seed_for_stroke(_hole.strokes + 1))

	# Driven through the same callback StrokeGesture fires, so the demo cannot
	# take a path the player's thumb does not.
	_hole._on_gesture_began()
	_hole._on_fired(intent.direction, intent.power, intent.curve)

	var number: int = _hole.strokes
	var from: Vector3 = _hole._record.before_pos
	var lie: String = _hole._record.before_lie

	var ticks := 0
	while _hole.state == _hole.State.FLIGHT and ticks < MAX_TICKS_PER_STROKE:
		await get_tree().physics_frame
		ticks += 1

	var record: StrokeRecord = _hole._round[-1] if not _hole._round.is_empty() else null
	print("")
	print("  %d. %s" % [number, ["power", "curve around the spire", "putt"][lesson]])
	print("     lesson     %s" % ["POWER", "CURVE", "PUTT"][lesson])
	print("     from       %v on the %s" % [from, lie])
	if record == null:
		_failures.append("stroke %d wrote no record" % number)
		return
	print("     to         %v on the %s   (%.1f m)" % [
		record.after_pos, record.after_lie, from.distance_to(record.after_pos)])
	print("     intent     %s" % record.intent.to_notation())
	print("     seed       %d" % record.seed)
	print("     events     %s" % ("—" if record.events.is_empty() else ", ".join(record.events)))
	for shooter in _hole._defenders:
		if shooter.brain.is_committed():
			print("     %s   fired at %v, %s" % [
				shooter.brain.id, shooter.brain.act_point(),
				"HIT — knocked down in place" if shooter.brain.will_connect() else "missed"])
	print("     hash       %s" % record.after_hash.substr(0, 16))


func _check_hashes() -> void:
	var checked := 0
	for record in _hole._round:
		if not record.hash_matches():
			_failures.append("stroke %d does not match its own hash" % record.stroke_no)
		checked += 1
	print("  %d stroke record(s) re-hashed from their own contents: %s" % [
		checked, "all match" if _failures.is_empty() else "MISMATCH"])


## The defender verdict has to be a pure function of (arc, seed). If it is not,
## no record replays and every async mode in §4 is unreachable.
func _check_determinism() -> void:
	if _hole._defenders.is_empty():
		print("  determinism  no defenders on this hole; nothing to re-roll")
		return
	var shooter: Skeet = _hole._defenders[0]
	var arc := BallFlight.sample_arc(
		Vector3(0.0, 0.35, 0.0),
		BallFlight.launch_velocity(Vector3(0.0, 0.0, -1.0), 1.0),
		Vector3.ZERO, 0.18, 900, _hole.DEFENDER_DT)

	var first := DefenderBrain.new()
	first.configure(shooter.brain.profile, shooter.brain.tier, shooter.brain.id)
	first.read_shot(arc, _hole.DEFENDER_DT, 8123481)
	var stable := true
	for i in 50:
		var again := DefenderBrain.new()
		again.configure(shooter.brain.profile, shooter.brain.tier, shooter.brain.id)
		again.read_shot(arc, _hole.DEFENDER_DT, 8123481)
		stable = stable and again.will_connect() == first.will_connect() \
			and is_equal_approx(again.act_time(), first.act_time())
	if not stable:
		_failures.append("the same seed and arc gave different defender verdicts")
	print("  determinism  50 re-reads of one arc at seed 8123481: %s (fires at t=%.2fs, %s)" % [
		"identical" if stable else "DIVERGED", first.act_time(),
		"hit" if first.will_connect() else "miss"])


func _check_round_on_disk() -> void:
	var path: String = _hole.round_path
	if path == "":
		print("  on disk      round not saved (the hole was not finished)")
		return
	await get_tree().process_frame
	var data := RecordStore.load_round(path)
	var reloaded := RecordStore.strokes_of(data)
	print("  on disk      %s" % path)
	print("               %d strokes, %d bytes" % [
		reloaded.size(), FileAccess.get_file_as_string(path).length()])

	if reloaded.size() != _hole._round.size():
		_failures.append("the round on disk has %d strokes, the round played had %d"
			% [reloaded.size(), _hole._round.size()])
		return
	for i in reloaded.size():
		var there: StrokeRecord = reloaded[i]
		var here: StrokeRecord = _hole._round[i]
		if there.after_hash != here.after_hash:
			_failures.append("stroke %d changed hash on the way to disk" % here.stroke_no)
		if not there.hash_matches():
			_failures.append("stroke %d does not validate after reloading" % here.stroke_no)
	print("               every reloaded stroke validates against its stored hash")


func _relative(strokes: int, par: int) -> String:
	var diff := strokes - par
	if diff == 0:
		return "par"
	return "%+d" % diff


func _rule(title: String) -> void:
	print("")
	print("── %s %s" % [title, "─".repeat(maxi(2, 66 - title.length()))])
