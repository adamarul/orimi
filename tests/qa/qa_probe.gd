extends Node
## QA probe: lives under the root (like an autoload) for the whole run and prints machine-readable
## QAPROBE:{json} lines the browser and desktop harness read from the console. Added by
## tests/qa/qa_host.tscn; never part of the game itself. Owner: qa.
##
## Prints:
##   {"tag":"evt", "name":<Events signal>, "args":[...]}   every Events signal, as plain data
##   {"tag":"snap", ...}                                      every qa_every seconds (default 0.5)
##     and on demand; see _snapshot()
##   {"tag":"targets", "items":[...]}                         brush targets and enemies, with their
##     viewport position, on demand
##   {"tag":"perf", ...}                                      frame-time statistics since the last
##     perf_reset, on demand
## On web, page JavaScript sends commands through window.orimiQA("snap" | "targets" | "perf" |
## "perf_reset" | "paper:<0..2>" | "kindle_all"). On desktop the same commands can be given as qa_cmd_at=<s>:<cmd>.

const PREFIX := "QAPROBE:"

var _every := 0.5
var _since := 0.0
var _js_callback: Variant = null
var _frames: PackedFloat32Array = []
var _perf_t0 := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "QAProbe"
	_every = float(Boot.opt("qa_every", "0.5"))
	for sig: Dictionary in Events.get_script().get_script_signal_list():
		Events.connect(sig.name, _make_handler(String(sig.name), sig.args.size()))
	for item in String(Boot.opt("qa_cmd_at", "")).split(",", false):
		_command_later(float(item.get_slice(":", 0)), item.substr(item.find(":") + 1))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if OS.has_feature("web"):
		_js_callback = JavaScriptBridge.create_callback(_on_js)
		var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
		window.orimiQA = _js_callback
	_emit({"tag": "probe_ready", "web": OS.has_feature("web")})


func _command_later(seconds: float, cmd: String) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	command(cmd)


func _make_handler(sig_name: String, argc: int) -> Callable:
	match argc:
		0: return func() -> void: _on_event(sig_name, [])
		1: return func(a: Variant) -> void: _on_event(sig_name, [a])
		2: return func(a: Variant, b: Variant) -> void: _on_event(sig_name, [a, b])
		3: return func(a: Variant, b: Variant, c: Variant) -> void: _on_event(sig_name, [a, b, c])
		_: return func(a: Variant, b: Variant, c: Variant, d: Variant) -> void: _on_event(sig_name, [a, b, c, d])


func _on_event(sig_name: String, args: Array) -> void:
	var plain := []
	for a: Variant in args:
		plain.append(_plain(a, 0))
	_emit({"tag": "evt", "name": sig_name, "args": plain})


func _process(delta: float) -> void:
	_frames.append(delta * 1000.0)
	if _frames.size() > 20000:
		_frames = _frames.slice(10000)
	_since += delta
	if _every > 0.0 and _since >= _every:
		_since = 0.0
		_emit(_snapshot())


func _on_js(args: Array) -> void:
	command(String(args[0]) if args.size() > 0 else "snap")


func command(cmd: String) -> void:
	if cmd == "snap":
		_emit(_snapshot())
	elif cmd == "targets":
		_emit({"tag": "targets", "items": _targets()})
	elif cmd == "controls":
		var items := []
		for n in get_tree().root.find_children("*", "BaseButton", true, false):
			var b := n as BaseButton
			if b.is_visible_in_tree():
				var r := b.get_global_rect()
				items.append({"text": String(b.get(&"text")) if b.get(&"text") != null else "", "path": String(b.get_path()), "rect": [r.position.x, r.position.y, r.size.x, r.size.y]})
		_emit({"tag": "controls", "items": items})
	elif cmd == "brush_result":
		_emit({"tag": "brush_result", "result": _plain(Brush.get(&"last_result"), 0)})
	elif cmd == "perf":
		_emit(_perf())
	elif cmd == "perf_reset":
		_frames.clear()
		_perf_t0 = Time.get_ticks_msec()
	elif cmd == "kindle_all":
		var targets := get_tree().get_nodes_in_group(&"kindle_target")
		var lit := 0
		for t in targets:
			if t.has_method(&"kindle"):
				t.call(&"kindle", true)
			if t.get(&"lit") == true:
				lit += 1
		_emit({"tag": "kindled_all", "lit": lit, "total": targets.size()})
	elif cmd.begins_with("paper:"):
		Settings.paper_intensity = int(cmd.get_slice(":", 1))
		_emit(_snapshot())


func _snapshot() -> Dictionary:
	var vp := get_viewport()
	var cam := vp.get_camera_3d()
	var player: Node3D = Game.player if is_instance_valid(Game.player) else get_tree().get_first_node_in_group(&"player") as Node3D
	var scene := get_tree().current_scene
	var snap := {
		"tag": "snap",
		"paused": get_tree().paused,
		"brush_open": Brush.is_open(),
		"brush_enabled": Brush.enabled,
		"ink": Brush.ink,
		"ink_max": Brush.ink_max,
		"mouse_mode": Input.mouse_mode,
		"paper": Settings.paper_intensity,
		"fps": Engine.get_frames_per_second(),
		"scene": scene.scene_file_path if scene else "",
		"game_state": String(Game.state),
		"game": _plain(Game.debug_snapshot(), 0),
		"player": _v3(player.global_position) if player else null,
		"viewport": [vp.get_visible_rect().size.x, vp.get_visible_rect().size.y],
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"screen_xform": _xf2(vp.get_screen_transform()),
	}
	if scene and scene.has_method(&"qa_fixture_snapshot"):
		snap["game"] = scene.call(&"qa_fixture_snapshot")
	if cam:
		var e := cam.global_basis.get_euler()
		snap["cam"] = {"pos": _v3(cam.global_position), "yaw": rad_to_deg(e.y), "pitch": rad_to_deg(e.x), "fov": cam.fov}
	return snap


func _targets() -> Array:
	var cam := get_viewport().get_camera_3d()
	var out := []
	var seen := {}
	for group: StringName in [&"brush_target", &"enemy", &"cursed_zone", &"player"]:
		for n in get_tree().get_nodes_in_group(group):
			if seen.has(n) or not (n is Node3D):
				continue
			seen[n] = true
			var node := n as Node3D
			var anchor: Vector3 = node.call(&"glyph_anchor") if node.has_method(&"glyph_anchor") else node.global_position + Vector3.UP * 0.8
			var item := {"name": String(node.name), "path": String(node.get_path()), "groups": _groups(node), "pos": _v3(node.global_position), "anchor": _v3(anchor)}
			if node.has_method(&"glyph_radius"):
				item["radius"] = node.call(&"glyph_radius")
			if cam:
				item["in_front"] = not cam.is_position_behind(anchor)
				var sp := cam.unproject_position(anchor)
				item["screen"] = [sp.x, sp.y]
				item["distance"] = cam.global_position.distance_to(anchor)
			out.append(item)
			if out.size() >= 64:
				return out
	return out


func _perf() -> Dictionary:
	var sorted := Array(_frames)
	sorted.sort()
	var n := sorted.size()
	var total := 0.0
	for f: float in sorted:
		total += f
	var rid := get_viewport().get_viewport_rid()
	return {
		"tag": "perf", "frames": n, "window_ms": Time.get_ticks_msec() - _perf_t0,
		"mean_ms": total / n if n else 0.0,
		"p50_ms": sorted[n / 2] if n else 0.0,
		"p95_ms": sorted[mini(n - 1, int(n * 0.95))] if n else 0.0,
		"p99_ms": sorted[mini(n - 1, int(n * 0.99))] if n else 0.0,
		"max_ms": sorted[n - 1] if n else 0.0,
		"fps": Engine.get_frames_per_second(),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu(),
		"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(rid),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
	}


func _emit(data: Dictionary) -> void:
	data["t"] = Time.get_ticks_msec()
	print(PREFIX, JSON.stringify(data))


func _groups(n: Node) -> Array:
	var out := []
	for g in n.get_groups():
		if not String(g).begins_with("_"):
			out.append(String(g))
	return out


func _v3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


func _xf2(t: Transform2D) -> Array:
	return [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]


func _plain(v: Variant, depth: int) -> Variant:
	if depth > 4:
		return str(v)
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return v
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return String(v)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [v.x, v.y]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return _v3(Vector3(v))
		TYPE_VECTOR4:
			return [v.x, v.y, v.z, v.w]
		TYPE_COLOR:
			return [v.r, v.g, v.b, v.a]
		TYPE_TRANSFORM3D:
			return {"origin": _v3(v.origin)}
		TYPE_OBJECT:
			if not is_instance_valid(v):
				return null
			if v is Node:
				var d := {"node": String(v.name), "class": v.get_class(), "groups": _groups(v)}
				if v is Node3D and (v as Node3D).is_inside_tree():
					d["pos"] = _v3((v as Node3D).global_position)
				return d
			return {"object": v.get_class()}
		TYPE_DICTIONARY:
			var d := {}
			for k: Variant in v:
				d[String(k) if typeof(k) in [TYPE_STRING, TYPE_STRING_NAME] else str(k)] = _plain(v[k], depth + 1)
			return d
		_:
			if typeof(v) >= TYPE_ARRAY:
				var arr := []
				var count := 0
				for item: Variant in v:
					arr.append(_plain(item, depth + 1))
					count += 1
					if count >= 200:
						break
				return arr
			return str(v)
