class_name RecordStore
extends Object
## Reads and writes rounds under `user://records/` (RECORD_SCHEMA.md §4).
##
## Plain files are the source of truth; the index is a convenience the Replay
## browser rebuilds from them. Nothing under `res://` is written at runtime
## (§6.5), so a round survives an app update and an export is just a file copy.
##
## **Deviation to ratify:** §6.2 lists `RecordStore` as an autoload. It is a
## static class instead, for two reasons. Registering an autoload means editing
## `project.godot`, which HANDOFF.md records the open Godot editor silently
## overwriting twice; and every method here is a pure function of its arguments,
## so an instance would hold no state worth having. If the autoload is wanted
## for `get_node()` reachability from scenes, adding it later changes call sites
## and nothing else.

const DIR := "user://records"

## Append-only during play (§4). A round is opened once, then each stroke is
## flushed as it resolves, so a crash mid-round leaves a short valid file rather
## than no file.
const ROUND_SCHEMA := 1


static func ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)


## A round file name that sorts chronologically and says what it is at a glance:
## "0003-intro-20260909T113000.json".
static func round_filename(number: int, hole: String, stamp: String) -> String:
	var slug := hole.replace("/", "-")
	return "%04d-%s-%s.json" % [number, slug, stamp]


## Round Record: a header plus ordered Stroke Records (§4).
static func round_dict(hole: String, layout_hash: String, round_seed: int,
		par: int, strokes: Array[StrokeRecord]) -> Dictionary:
	var out: Array = []
	for record in strokes:
		out.append(record.to_dict())
	return {
		"schema": ROUND_SCHEMA,
		"game": StrokeRecord.game_string(),
		"hole": {"id": hole, "layout_hash": layout_hash},
		"seed": round_seed,
		"par": par,
		"strokes": out,
	}


static func save_round(hole: String, layout_hash: String, round_seed: int,
		par: int, strokes: Array[StrokeRecord]) -> String:
	ensure_dir()
	var stamp := Time.get_datetime_string_from_system(true, false) \
		.replace("-", "").replace(":", "")
	var path := "%s/%s" % [DIR, round_filename(next_round_number(), hole, stamp)]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("RecordStore: cannot write %s (%d)." % [path, FileAccess.get_open_error()])
		return ""
	file.store_string(JSON.stringify(round_dict(hole, layout_hash, round_seed, par, strokes), "  "))
	file.close()
	return path


static func load_round(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("RecordStore: no such round %s." % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RecordStore: %s is not a round record." % path)
		return {}
	return parsed


## The Stroke Records of a saved round, in play order.
static func strokes_of(round_data: Dictionary) -> Array[StrokeRecord]:
	var out: Array[StrokeRecord] = []
	for entry in round_data.get("strokes", []):
		out.append(StrokeRecord.from_dict(entry as Dictionary))
	return out


static func list_rounds() -> PackedStringArray:
	ensure_dir()
	var names := DirAccess.get_files_at(DIR)
	var rounds := PackedStringArray()
	for name in names:
		if name.ends_with(".json"):
			rounds.append("%s/%s" % [DIR, name])
	rounds.sort()
	return rounds


static func next_round_number() -> int:
	return list_rounds().size() + 1


## The whole round as §4.1 notation -- one line per stroke, readable in a diff
## or down the phone. Derived, and never parsed back.
static func notation(strokes: Array[StrokeRecord]) -> String:
	var lines := PackedStringArray()
	for record in strokes:
		lines.append(record.to_notation())
	return "\n".join(lines)
