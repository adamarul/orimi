extends SceneTree
## Finds overrides on instanced scenes' children that the web export would drop.
##
## A .tscn may set properties on a node inside an instanced scene (for example PostA under a
## tie_posts.tscn instance) or add a node below one of its children. Text loading applies these,
## so desktop runs work, but the export's text-to-binary conversion repacks each scene with
## PackedScene.pack(), which keeps them only when the instance is marked editable
## ([editable path="..."], what the editor writes for Editable Children). Without it they vanish
## in the browser without a warning (godotengine/godot#123172).
##
## Run through tools/game/check_scenes.sh [--fix] [scene paths...]. --fix appends the missing
## [editable] lines. Exit code 1 when a scene needs one (and --fix was not given).

const SKIP_DIRS := [".godot", ".tools", ".reference", ".worktrees", "build", "node_modules"]


func _init() -> void:
	var fix := false
	var files := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a == "--fix":
			fix = true
		else:
			files.append(a if a.begins_with("res://") else "res://" + a.trim_prefix("./"))
	if files.is_empty():
		_collect("res://", files)
	var bad := 0
	for f in files:
		var missing := _missing_editable(f)
		if missing.is_empty():
			continue
		for line in missing[1]:
			print("CHECK_SCENES %s: %s" % [f, line])
		if fix:
			var text := FileAccess.get_file_as_string(f).rstrip("\n") + "\n"
			for p: String in missing[0]:
				text += "\n[editable path=\"%s\"]\n" % p
			var out := FileAccess.open(f, FileAccess.WRITE)
			out.store_string(text)
			out.close()
			print("CHECK_SCENES %s: added [editable] for %s" % [f, ", ".join(missing[0])])
		else:
			bad += 1
	print("CHECK_SCENES_DONE files=%d needing_editable=%d" % [files.size(), bad])
	quit(1 if bad > 0 else 0)


func _collect(dir: String, out: PackedStringArray) -> void:
	for d in DirAccess.get_directories_at(dir):
		if d in SKIP_DIRS or FileAccess.file_exists(dir.path_join(d).path_join(".gdignore")):
			continue
		_collect(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))


## [instance paths that need an [editable] line, one message per node that needs it]; [] if fine.
func _missing_editable(path: String) -> Array:
	var instances := PackedStringArray()
	var editable := PackedStringArray()
	var nodes := []
	var head := RegEx.create_from_string("^\\[(node|editable) (.*)\\]\\s*$")
	var attr := RegEx.create_from_string("(\\w+)=(\"((?:[^\"\\\\]|\\\\.)*)\"|\\w+\\([^)]*\\))")
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var m := head.search(line)
		if m == null:
			continue
		var at := {}
		for a in attr.search_all(m.get_string(2)):
			at[a.get_string(1)] = a.get_string(3) if a.get_string(3) != "" or a.get_string(2).begins_with("\"") else a.get_string(2)
		if m.get_string(1) == "editable":
			editable.append(at.get("path", ""))
			continue
		if not at.has("parent"):
			continue
		var parent: String = at["parent"]
		var own := String(at["name"]) if parent == "." else parent + "/" + String(at["name"])
		if at.has("instance"):
			instances.append(own)
		nodes.append([own, parent, at.has("type") or at.has("instance") or at.has("instance_placeholder")])
	var need := PackedStringArray()
	var lines := PackedStringArray()
	for n: Array in nodes:
		var own: String = n[0]
		var parent: String = n[1]
		var new_node: bool = n[2]
		var inst := ""
		for i in instances:
			if i != own and (parent == i or parent.begins_with(i + "/")) and i.length() > inst.length():
				inst = i
		if inst == "" or inst in editable:
			continue
		# A new node straight under the instance root is kept; overrides and deeper nodes are not.
		if new_node and parent == inst:
			continue
		if not inst in need:
			need.append(inst)
		lines.append("%s %s inside instance %s needs [editable path=\"%s\"]" % ["new node" if new_node else "override of", own, inst, inst])
	return [] if need.is_empty() else [need, lines]
