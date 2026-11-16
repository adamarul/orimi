extends Node
## QA: dumps the public API of every contract autoload and global class, and inspects the contract
## deliverable scenes, into one JSON file. Run headless through Boot:
##   godot --headless --path . -- scene=res://tests/contract/api_dump.tscn out=<absolute json path>
## tools/qa/contract.py compares the dump with tests/contract/api_baseline.json. Owner: qa.

const AUTOLOADS: PackedStringArray = ["Controls", "Events", "Settings", "CurseField", "Post", "Vfx", "Audio", "Brush", "Game"]
const CLASSES := {
	"Boot": "res://scripts/core/boot.gd",
	"Palette": "res://scripts/core/palette.gd",
	"Layers": "res://scripts/core/layers.gd",
	"InkLook": "res://scripts/render/ink_look.gd",
}
const MODELS := {
	"res://scenes/models/fox.tscn": ["idle", "run", "jump", "fall", "land", "attack_1", "attack_2", "hurt", "brush_pose"],
	"res://scenes/models/splotchet.tscn": ["idle", "hop", "attack", "hurt"],
	"res://scenes/models/reedwraith.tscn": ["idle", "drift", "attack", "veil_off", "hurt"],
	"res://scenes/models/sapling.tscn": ["withered", "bloom"],
	"res://scenes/models/great_tree.tscn": ["withered", "bloom"],
	"res://scenes/models/thorn_gate.tscn": [],
	"res://scenes/models/shrine.tscn": [],
	"res://scenes/models/stepping_stone.tscn": [],
	"res://scenes/models/valley_terrain.tscn": [],
	"res://scenes/models/raft.tscn": ["bob"],
}
const MARKERS := {
	"M_Spawn": Vector3(0, 0, 50), "M_GateA": Vector3(-4, 0, 36), "M_ZoneA": Vector3(-12, 0, 20),
	"M_Crossing": Vector3(0, 0, 8), "M_GateB": Vector3(6, 1.5, 4), "M_ZoneB": Vector3(14, 3, -10),
	"M_Tree": Vector3(0, 6, -42),
}
const MARKER_TOLERANCE := 3.0
const SCENES := {
	"res://scenes/game/main.tscn": "",
	"res://scenes/brush/ink_pot.tscn": "Control",
	"res://scenes/render/blob_shadow.tscn": "Node3D",
	"res://scenes/env/sky.tscn": "",
	"res://scenes/env/river_water.tscn": "",
	"res://scenes/env/foliage_scatter.tscn": "",
	"res://scenes/env/mist.tscn": "",
	"res://scenes/env/soot_bank_visual.tscn": "",
	"res://scenes/dev/render_demo.tscn": "",
	"res://scenes/dev/vfx_demo.tscn": "",
	"res://scenes/dev/brush_demo.tscn": "",
	"res://scenes/dev/gameplay_demo.tscn": "",
	"res://scenes/dev/assets_demo.tscn": "",
}


func _ready() -> void:
	var out := String(Boot.opt("out", ""))
	var dump := {"autoloads": {}, "classes": {}, "deliverables": []}
	for name in AUTOLOADS:
		var node := get_tree().root.get_node_or_null(NodePath(name))
		if node == null:
			dump.autoloads[name] = {"missing": true}
			continue
		var entry := _api(node.get_script())
		entry["node_class"] = node.get_class()
		entry["process_mode"] = node.process_mode
		dump.autoloads[name] = entry
	for name: String in CLASSES:
		var script := load(CLASSES[name]) as Script
		dump.classes[name] = {"missing": true} if script == null else _api(script)
	for path: String in SCENES:
		dump.deliverables.append(_scene_check(path, SCENES[path], null))
	for path: String in MODELS:
		dump.deliverables.append(_scene_check(path, "Node3D", MODELS[path]))
	var text := JSON.stringify(dump, "\t", true)
	if out.is_empty():
		print(text)
	else:
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	print("QA_API_DONE out=", out.get_file())
	get_tree().quit(0)


func _api(script: Script) -> Dictionary:
	var methods := {}
	var properties := {}
	var signals := {}
	var constants := {}
	var s := script
	while s != null:
		for m: Dictionary in s.get_script_method_list():
			var n := String(m.name)
			if n.begins_with("_") or n.begins_with("@") or methods.has(n):
				continue
			var args := []
			for a: Dictionary in m.args:
				args.append(_type(a))
			methods[n] = {"args": args, "defaults": m.default_args.size(), "static": (int(m.flags) & METHOD_FLAG_STATIC) != 0,
				"vararg": (int(m.flags) & METHOD_FLAG_VARARG) != 0, "return": _type(m["return"])}
		for p: Dictionary in s.get_script_property_list():
			var n := String(p.name)
			if (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or n.begins_with("_") or properties.has(n):
				continue
			var t := _type(p)
			t["export"] = (int(p.usage) & PROPERTY_USAGE_EDITOR) != 0
			properties[n] = t
		for sg: Dictionary in s.get_script_signal_list():
			var n := String(sg.name)
			if signals.has(n):
				continue
			var args := []
			for a: Dictionary in sg.args:
				args.append(_type(a))
			signals[n] = args
		var cmap := s.get_script_constant_map()
		for n: String in cmap:
			if n.begins_with("_") or constants.has(n) or cmap[n] is Script:
				continue
			constants[n] = var_to_str(cmap[n])
		s = s.get_base_script()
	return {"script": script.resource_path, "native_base": script.get_instance_base_type(), "global_name": String(script.get_global_name()),
		"methods": methods, "properties": properties, "signals": signals, "constants": constants}


func _type(d: Dictionary) -> Dictionary:
	var t := {"type": int(d.get("type", 0)), "class": String(d.get("class_name", ""))}
	if int(d.get("hint", 0)) == PROPERTY_HINT_ARRAY_TYPE or int(d.get("hint", 0)) == PROPERTY_HINT_DICTIONARY_TYPE:
		t["of"] = String(d.get("hint_string", ""))
	return t


func _scene_check(path: String, root_class: String, animations: Variant) -> Dictionary:
	var r := {"path": path, "exists": ResourceLoader.exists(path), "problems": []}
	if not r.exists:
		return r
	var packed := load(path) as PackedScene
	if packed == null:
		r.problems.append("does not load as a PackedScene")
		return r
	var root := packed.instantiate()
	r["root_class"] = root.get_class()
	if root_class != "" and not root.is_class(root_class):
		r.problems.append("root is %s, contract says %s" % [root.get_class(), root_class])
	if animations != null:
		var has_ink_look := false
		for child in root.get_children():
			if child is InkLook:
				has_ink_look = true
		if not has_ink_look:
			r.problems.append("no InkLook child under the root")
		var anims: Array = animations
		if not anims.is_empty():
			var player := root.get_node_or_null(^"%AnimationPlayer") as AnimationPlayer
			if player == null:
				r.problems.append("no AnimationPlayer reachable as %AnimationPlayer")
			else:
				r["animations"] = Array(player.get_animation_list())
				for a: String in anims:
					if not player.has_animation(a):
						r.problems.append("missing animation '%s'" % a)
					elif a.begins_with("attack") and not _animation_touches(player.get_animation(a), "Smear"):
						r.problems.append("animation '%s' never keys a node named Smear" % a)
		if path.ends_with("valley_terrain.tscn"):
			for m: String in MARKERS:
				var node := root.find_child(m, true, false) as Node3D
				if node == null:
					r.problems.append("marker %s missing" % m)
					continue
				var at := _global_origin(node, root)
				if at.distance_to(MARKERS[m]) > MARKER_TOLERANCE:
					r.problems.append("marker %s at %s, contract %s" % [m, at, MARKERS[m]])
	root.free()
	return r


func _animation_touches(anim: Animation, node_name: String) -> bool:
	for i in anim.get_track_count():
		var p := String(anim.track_get_path(i))
		if p.get_slice(":", 0).get_file() == node_name or p.contains("/" + node_name + ":") or p.begins_with(node_name + ":"):
			return true
	return false


func _global_origin(node: Node3D, root: Node) -> Vector3:
	var xf := node.transform
	var p := node.get_parent()
	while p != null and p != root.get_parent():
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		if p == root:
			break
		p = p.get_parent()
	return xf.origin
