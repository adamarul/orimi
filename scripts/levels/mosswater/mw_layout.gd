class_name MwLayout
extends RefCounted
## Mosswater Wood's layout data: scripts/levels/mosswater/mosswater_layout.json, written by
## tools/levels/mosswater/export_layout.py from tools/levels/mosswater/mw_layout.py (the same
## numbers that build the terrain and draw the plan). Owner: l4.

const PATH := "res://scripts/levels/mosswater/mosswater_layout.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("MwLayout: cannot open %s" % PATH)
			return {}
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_cache = parsed
	return _cache


static func v3(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


static func marker(marker_name: String) -> Vector3:
	return v3((data().get("markers", {}) as Dictionary).get(marker_name, [0, 0, 0]))


static func markers() -> Dictionary:
	var out := {}
	var m: Dictionary = data().get("markers", {})
	for k: String in m:
		out[k] = v3(m[k])
	return out
