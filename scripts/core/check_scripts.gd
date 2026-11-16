extends Node
## Loads every script, scene and resource in the project from inside the running game, so
## autoloads and global classes resolve, and reports anything that fails to load.
## Run by tools/check.sh through scenes/dev/check_scripts.tscn. Owner: lead (OKAA-1).

const EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]


func _ready() -> void:
	var paths: PackedStringArray = []
	_walk("res://", paths)
	paths.sort()
	var failed := 0
	for path in paths:
		var resource: Resource = ResourceLoader.load(path)
		var ok := resource != null
		if ok and resource is GDScript:
			ok = (resource as GDScript).can_instantiate() or _is_abstract_or_static(resource)
		if ok:
			print("ORIMI_CHECK ok   ", path)
		else:
			failed += 1
			print("ORIMI_CHECK FAIL ", path)
	print("ORIMI_CHECK_DONE files=%d failed=%d" % [paths.size(), failed])
	get_tree().quit(1 if failed > 0 else 0)


func _is_abstract_or_static(script: GDScript) -> bool:
	return script.is_abstract()


func _walk(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	if dir.file_exists(".gdignore"):
		return
	dir.include_hidden = false
	for sub in dir.get_directories():
		if sub.begins_with("."):
			continue
		_walk(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.get_extension() in EXTENSIONS:
			out.append(dir_path.path_join(file))
