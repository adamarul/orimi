class_name LevelRegistry
extends RefCounted
## Reads the level list, scenes/levels/levels.json (owned by the lead): the levels of the book
## in playing order, plus "dev" levels that only load by id (level=<id>). A level whose scene
## does not exist yet is skipped, so the list can name levels before they land. Owner: gameplay.

const PATH := "res://scenes/levels/levels.json"

static var _cache: Dictionary = {}


static func _data() -> Dictionary:
	if _cache.is_empty():
		if FileAccess.file_exists(PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if parsed is Dictionary:
				_cache = parsed
		if _cache.is_empty():
			push_error("LevelRegistry: %s missing or not a JSON object" % PATH)
			_cache = {"levels": []}
	return _cache


static func _playable(entry: Dictionary) -> bool:
	return ResourceLoader.exists(String(entry.get("scene", "")))


## The book's levels, in order, that exist in this build.
static func levels() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in _data().get("levels", []):
		if e is Dictionary and _playable(e):
			out.append(e)
	return out


## True while the book is still being written: levels wait under "dev", or a listed book level
## has no scene yet. The end card says so only then.
static func book_unfinished() -> bool:
	var data := _data()
	if not (data.get("dev", []) as Array).is_empty():
		return true
	for e: Variant in data.get("levels", []):
		if e is Dictionary and not _playable(e):
			return true
	return false


## The entry for an id, from the book or the dev list; {} when unknown or not built.
static func find(id: StringName) -> Dictionary:
	for list: String in ["levels", "dev"]:
		for e: Variant in _data().get(list, []):
			if e is Dictionary and StringName(e.get("id", "")) == id and _playable(e):
				return e
	return {}


static func first_id() -> StringName:
	var l := levels()
	return StringName(l[0]["id"]) if not l.is_empty() else &""


## The next book level after id, or &"" at the end of what exists (dev levels have no next).
static func next_after(id: StringName) -> StringName:
	var l := levels()
	for i in l.size():
		if StringName(l[i]["id"]) == id:
			return StringName(l[i + 1]["id"]) if i + 1 < l.size() else &""
	return &""


## True for a level in the book's list (not a dev level).
static func in_book(id: StringName) -> bool:
	for e: Variant in _data().get("levels", []):
		if e is Dictionary and StringName(e.get("id", "")) == id:
			return true
	return false


static func is_dev(id: StringName) -> bool:
	for e: Variant in _data().get("dev", []):
		if e is Dictionary and StringName(e.get("id", "")) == id:
			return true
	return false
