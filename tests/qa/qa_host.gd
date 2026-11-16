extends Node
## QA host scene: adds the QA probe (tests/qa/qa_probe.gd) under the root so it survives scene
## changes, then switches to the scene under test. Owner: qa.
##   scene=res://tests/qa/qa_host.tscn target=res://scenes/game/main.tscn [any game options]
## Without target, the game's main scene is used. If the target does not exist the probe prints
## {"tag":"target_missing"} and the host stays on an empty scene, so the harness reports NOT YET.

const DEFAULT_TARGET := "res://scenes/game/main.tscn"


func _ready() -> void:
	var probe := preload("res://tests/qa/qa_probe.gd").new()
	get_tree().root.add_child.call_deferred(probe)
	var target := String(Boot.opt("target", DEFAULT_TARGET))
	await get_tree().process_frame
	await get_tree().process_frame
	if not ResourceLoader.exists(target):
		probe.call(&"_emit", {"tag": "target_missing", "target": target})
		return
	probe.call(&"_emit", {"tag": "target", "target": target})
	get_tree().change_scene_to_file(target)
