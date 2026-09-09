class_name StrokeRecord
extends Resource
## One stroke by one golfer against zero or more defenders (RECORD_SCHEMA.md §2).
##
## The atomic unit of the whole game. Determinism makes a stroke *data*, and
## every social feature in 1.0 -- sharing, forks, Spot Duel, Postal Round,
## Match -- is an exchange of these and nothing else. There is no server-side
## game logic anywhere, so this file is the wire protocol.
##
## `after` is derived, never authoritative (§2.2). A client that loads a record
## recomputes it by replaying `before` + `intent` + `defense` at `seed`, then
## compares its own hash against the stored one. A match means the record is
## trustworthy; a mismatch means version drift, and the *recomputed* result is
## the one to show. That is what lets a relay be a mailbox rather than a
## referee: there is nothing to gain by editing `after`, because nobody reads
## it.

const SCHEMA_VERSION := 1

## Lies, in the schema's order. Frozen with the schema at M1 exit.
const LIES: Array[String] = [
	"tee", "fairway", "rough", "sand", "water", "green", "ob",
]

## DefenderBrain's states (§6.3), as they appear in `before.defenders[].state`.
const DEFENDER_STATES: Array[String] = ["idle", "tell", "act", "cooldown"]

@export var schema := SCHEMA_VERSION
@export var game := ""
@export var hole_id := ""
@export var layout_hash := ""
@export var seed := 0

@export var before_pos := Vector3.ZERO
@export var before_lie := "tee"
@export var stroke_no := 1
## One entry per defender on the hole, in HoleLayout order. Each is
## `{id, pos, state, cooldown}`. Empty in Scottish Rules.
@export var defenders: Array[Dictionary] = []

var intent: ShotIntent = null
## `null` when the AI defended at the recorded tier; a DefensePlan dictionary
## when a human did.
var defense: Variant = null

@export var after_pos := Vector3.ZERO
@export var after_lie := "fairway"
@export var events: PackedStringArray = PackedStringArray()
@export var after_hash := ""

@export var ext := {}


## "<game version>+godot<engine version>", per the schema. Identifies what
## produced a record; a mismatch is a reason to distrust `after`, never a reason
## to refuse to load.
static func game_string() -> String:
	var version := String(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var engine := Engine.get_version_info()
	return "%s+godot%d.%d.%d" % [version, engine.major, engine.minor, engine.patch]


## A stroke as it is about to be played. `after` is filled in by `resolve()`
## once the ball has come to rest, so a record exists for the whole flight and
## an interrupted round still has a well-formed file on disk.
static func opened(hole: String, layout: String, stroke_seed: int, number: int,
		from: Vector3, lie: String, shot: ShotIntent) -> StrokeRecord:
	var record := StrokeRecord.new()
	record.game = game_string()
	record.hole_id = hole
	record.layout_hash = layout
	record.seed = stroke_seed
	record.stroke_no = number
	record.before_pos = Canonical.quantize_vec3(from, Canonical.POS_DECIMALS)
	record.before_lie = lie
	record.intent = shot
	record.after_pos = record.before_pos
	record.after_lie = lie
	record.after_hash = Canonical.unset_hash()
	return record


## Close the record with where the ball finished and what happened on the way.
## The hash is computed here and nowhere else, so there is exactly one
## definition of what a stroke's result *is*.
func resolve(to: Vector3, lie: String, seen: PackedStringArray) -> void:
	after_pos = Canonical.quantize_vec3(to, Canonical.POS_DECIMALS)
	after_lie = lie
	events = seen
	after_hash = compute_hash()


## §2.2: the hash covers the canonical serialisation of `after.ball` and
## `after.events`, and nothing else. Not the whole record -- `game`, `seed` and
## `before` are inputs, and hashing them would make the digest change for
## reasons that are not the stroke's outcome.
func compute_hash() -> String:
	return Canonical.hash_of({"ball": _after_ball(), "events": events})


## True when the stored hash matches what this record's own `after` produces.
## A fixture that has never been simulated carries the all-zero hash and is
## neither valid nor invalid -- ask `Canonical.is_unset()` first.
func hash_matches() -> bool:
	return after_hash == compute_hash()


func _after_ball() -> Dictionary:
	return {"pos": Canonical.vec3_array(after_pos), "lie": after_lie}


func to_dict() -> Dictionary:
	return {
		"schema": schema,
		"game": game,
		"hole": {"id": hole_id, "layout_hash": layout_hash},
		"seed": seed,
		"before": {
			"ball": {"pos": Canonical.vec3_array(before_pos), "lie": before_lie},
			"stroke_no": stroke_no,
			"defenders": defenders,
		},
		"intent": intent.to_dict() if intent != null else null,
		"defense": defense,
		"after": {
			"ball": _after_ball(),
			"events": events,
			"hash": after_hash,
		},
		"ext": ext,
	}


static func from_dict(data: Dictionary) -> StrokeRecord:
	var record := StrokeRecord.new()
	record.schema = int(data.get("schema", 0))
	record.game = String(data.get("game", ""))

	var hole: Dictionary = data.get("hole", {})
	record.hole_id = String(hole.get("id", ""))
	record.layout_hash = String(hole.get("layout_hash", ""))
	record.seed = int(data.get("seed", 0))

	var before: Dictionary = data.get("before", {})
	var before_ball: Dictionary = before.get("ball", {})
	record.before_pos = Canonical.array_vec3(before_ball.get("pos", [0.0, 0.0, 0.0]))
	record.before_lie = String(before_ball.get("lie", "tee"))
	record.stroke_no = int(before.get("stroke_no", 1))
	var loaded: Array[Dictionary] = []
	for entry in before.get("defenders", []):
		loaded.append(entry as Dictionary)
	record.defenders = loaded

	if data.get("intent") != null:
		record.intent = ShotIntent.from_dict(data.get("intent"))
	record.defense = data.get("defense")

	var after: Dictionary = data.get("after", {})
	var after_ball: Dictionary = after.get("ball", {})
	record.after_pos = Canonical.array_vec3(after_ball.get("pos", [0.0, 0.0, 0.0]))
	record.after_lie = String(after_ball.get("lie", "fairway"))
	record.events = PackedStringArray(after.get("events", []))
	record.after_hash = String(after.get("hash", Canonical.unset_hash()))

	record.ext = data.get("ext", {})
	return record


## Pretty-printed, for a file a human might open. The *hash* is never taken over
## this form -- see `compute_hash` -- so indentation is free.
func to_json() -> String:
	return JSON.stringify(to_dict(), "  ")


static func from_json(text: String) -> StrokeRecord:
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("StrokeRecord.from_json: not a JSON object.")
		return null
	return from_dict(parsed)


## The §4.1 one-line view: "2. I 0.72 L15 → G (skeet ✗)".
##
## Derived, and never parsed back as input -- it is for a diff, a chat message,
## or reading a round down the phone. `tests/records/test_stroke_record.gd`
## asserts there is no parser for it.
func to_notation() -> String:
	var line := "%d. %s → %s" % [
		stroke_no,
		intent.to_notation() if intent != null else "?",
		after_lie.substr(0, 1).to_upper(),
	]
	# Only defenders that actually acted are named. Listing a shooter that never
	# fired as a miss reads as "it tried and failed", which is a different
	# stroke from the one where the ball went under its zone untouched.
	var tells := PackedStringArray()
	for entry in defenders:
		var id := String(entry.get("id", "?"))
		var sport := id.split("_")[0]
		if not events.has("%s_fired" % sport):
			continue
		var hit := events.has("%s_hit" % sport)
		tells.append("%s %s" % [sport, "✓" if hit else "✗"])
	if not tells.is_empty():
		line += " (%s)" % ", ".join(tells)
	return line
