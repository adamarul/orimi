extends Node3D
## Brush demo: a small scene that shows the brush on its own. A stone ring orbits (to show the
## freeze), dummy targets react to their glyph (sapling: bloom, thorns: slash, soot: gust, a
## lamp: kindle, two tie posts: tie), the ink pot sits bottom left and a readout shows the last
## recognition result.
##
## Click to capture the mouse, hold Shift / Q / right mouse to open the brush, paint with the
## left button, release to cast. Every brush event prints one "BRUSH_DEMO {json}" line.
##
## Boot options:
##   demo_draw=bloom|slash|gust|kindle|tie|all
##                                   paint the glyph(s) over their targets with synthetic input
##   demo_hold=<seconds>             how long the scripted brush stays open after painting (1.2)
##   demo_speed=<seconds>            how long each scripted stroke takes to paint (0.8)
##   demo_ink=<amount>              start with this much ink
##   demo_inject=1                   cast every glyph with Brush.inject_stroke
##   brush_selftest=1                headless checks of casting, pausing, rays and key orders;
##                                   prints BRUSH_SELFTEST lines and quits

const TargetScript := preload("res://scripts/brush/demo_target.gd")
const InkPotScene := preload("res://scenes/brush/ink_pot.tscn")
const GlyphCardScene := preload("res://scenes/brush/glyph_card.tscn")
const ALL_GLYPHS := ["bloom", "slash", "gust", "kindle", "tie"]
## How long a scripted Kindle press lasts (seconds).
const DAB_TIME := 0.15

var camera: Camera3D
var mover: Node3D
var targets := {}
var _readout: Label
var _mover_angle := 0.0
var _open_pos := Vector3.ZERO
var _failures := 0


func _ready() -> void:
	_build_world()
	_build_hud()
	if Boot.opt("demo_ink", "") != "":
		Brush.ink = 0.0
		Brush.add_ink(float(Boot.opt("demo_ink")))
	Events.brush_opened.connect(_on_brush_opened)
	Events.brush_closed.connect(_on_brush_closed)
	Events.glyph_cast.connect(_on_glyph_cast)
	Events.glyph_failed.connect(_on_glyph_failed)
	await get_tree().process_frame
	await get_tree().process_frame
	_log({"event": "layout", "viewport": _v2(get_viewport().get_visible_rect().size), "targets": _target_screen_points()})
	if Boot.opt("brush_selftest", "") != "":
		_selftest()
	elif Boot.opt("demo_inject", "") != "":
		_inject_all()
	elif Boot.opt("demo_draw", "") != "":
		_scripted_draw(String(Boot.opt("demo_draw")))


func _process(delta: float) -> void:
	_mover_angle += delta * 1.6
	mover.position = Vector3(cos(_mover_angle) * 2.2, 2.6 + sin(_mover_angle * 2.0) * 0.3, -3.0 + sin(_mover_angle) * 0.8)
	mover.rotation = Vector3(_mover_angle * 1.3, _mover_angle, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_log({"event": "capture_requested"})


# --- Scene -------------------------------------------------------------------

func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Palette.SKY
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Palette.IVORY
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.9
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.position = Vector3(0, 4.2, 8.5)
	add_child(camera)
	camera.look_at(Vector3(0, 0.9, 0))
	camera.current = true
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 0.2, 60)
	shape.shape = box
	shape.position.y = -0.1
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.SAGE
	mesh.material_override = mat
	ground.add_child(mesh)
	add_child(ground)
	mover = MeshInstance3D.new()
	mover.name = "Mover"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.25
	torus.outer_radius = 0.55
	(mover as MeshInstance3D).mesh = torus
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Palette.GOLD
	(mover as MeshInstance3D).material_override = mm
	add_child(mover)
	for spec in [["Sapling", "bloom", "bloom", Vector3(-3.4, 0, 0)], ["Thorns", "slash", "slash", Vector3.ZERO], ["Soot", "gust", "gust", Vector3(3.4, 0, 0)],
			["Lamp", "kindle", "kindle", Vector3(-1.4, 0, 3.6)], ["PostA", "tie_post", "tie_a", Vector3(0.9, 0, 3.6)], ["PostB", "tie_post", "tie_b", Vector3(3.2, 0, 3.6)]]:
		var t := StaticBody3D.new()
		t.set_script(TargetScript)
		t.name = spec[0]
		t.kind = spec[1]
		t.position = spec[3]
		add_child(t)
		targets[spec[2]] = t


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = Layers.CANVAS_HUD
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	var pot := InkPotScene.instantiate()
	pot.position = Vector2(24, 600)
	hud.add_child(pot)
	_readout = Label.new()
	_readout.position = Vector2(860, 16)
	_readout.size = Vector2(400, 120)
	_readout.add_theme_color_override(&"font_color", Palette.INK)
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD
	_readout.text = "Last cast: none yet"
	hud.add_child(_readout)
	var help := Label.new()
	help.position = Vector2(24, 16)
	help.size = Vector2(620, 80)
	help.add_theme_color_override(&"font_color", Palette.INK)
	help.text = "Click to capture the mouse. Hold Shift, Q or the right button to open the brush,\npaint with the left button, release to cast."
	hud.add_child(help)
	for i in ALL_GLYPHS.size():
		var card := GlyphCardScene.instantiate()
		card.glyph = ALL_GLYPHS[i]
		card.position = Vector2(694 + i * 116, 568)
		card.custom_minimum_size = Vector2(108, 130)
		card.size = Vector2(108, 130)
		hud.add_child(card)


# --- Readout and log -----------------------------------------------------------

func _on_brush_opened() -> void:
	_open_pos = mover.global_position
	_log({"event": "brush_opened", "paused": get_tree().paused, "mouse_mode": Input.mouse_mode, "mover": _v3(mover.global_position)})
	_watch_freeze()


func _watch_freeze() -> void:
	while Brush.is_open():
		await get_tree().create_timer(0.25, true).timeout
		if Brush.is_open():
			_log({"event": "frozen_check", "paused": get_tree().paused, "mover_moved": mover.global_position.distance_to(_open_pos), "mouse_mode": Input.mouse_mode})


func _on_brush_closed() -> void:
	var before := mover.global_position
	_log({"event": "brush_closed", "paused": get_tree().paused, "mouse_mode": Input.mouse_mode, "mover_moved_while_open": before.distance_to(_open_pos)})
	await get_tree().create_timer(0.3).timeout
	_log({"event": "resumed", "mover_moved_after": mover.global_position.distance_to(before)})


func _on_glyph_cast(glyph: StringName, info: Dictionary) -> void:
	var names: PackedStringArray = []
	for t: Node in info["targets"]:
		names.append(t.name)
	_readout.text = "Last cast: %s (score %.2f)\nTargets: %s\nInk spent %.1f" % [BrushGlyphs.NAMES[glyph], info["score"], ", ".join(names) if names.size() > 0 else "none", info["ink_cost"]]
	var f: Dictionary = Brush.last_result.get("features", {})
	_log({"event": "glyph_cast", "glyph": String(glyph), "score": snappedf(info["score"], 0.001), "targets": names,
		"world_center": _v3(info["world_center"]), "world_points": (info["world_points"] as PackedVector3Array).size(),
		"world_dir": _v3(info["world_dir"]), "ink_cost": snappedf(info["ink_cost"], 0.1), "features": _round(f),
		"input": _round(Brush.last_result.get("input", {}))})


func _on_glyph_failed(info: Dictionary) -> void:
	_failures += 1
	_readout.text = "Last cast: not recognised (%s)\n%s" % [info["reason"], info.get("detail", "")]
	_log({"event": "glyph_failed", "reason": String(info["reason"]), "detail": info.get("detail", ""), "points": (info["screen_points"] as PackedVector2Array).size(), "input": _round(Brush.last_result.get("input", {}))})


func _log(data: Dictionary) -> void:
	print("BRUSH_DEMO ", JSON.stringify(data))


func _round(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = snappedf(d[k], 0.001) if d[k] is float else d[k]
	return out


func _v2(v: Vector2) -> Array:
	return [snappedf(v.x, 0.1), snappedf(v.y, 0.1)]


func _v3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


func _target_screen_points() -> Dictionary:
	var out := {}
	for k in targets:
		out[k] = _v2(camera.unproject_position(targets[k].glyph_anchor()))
	return out


# --- Glyph strokes over the targets --------------------------------------------

## A hand-ish stroke of the glyph over its target, in viewport pixels: for Kindle a dab on the
## lamp's wick, for Tie a line from post A to post B.
func glyph_points(glyph: String, wobble: float = 0.8) -> PackedVector2Array:
	if glyph == "kindle":
		var dab := _screen("kindle")
		return PackedVector2Array([dab, dab + Vector2(1.5, 1.0), dab + Vector2(2.5, 2.2)])
	if glyph == "tie":
		return tie_line(_screen("tie_a"), _screen("tie_b"), wobble)
	var centre := _screen(glyph)
	var pts := BrushGlyphs.ideal(StringName(glyph), 48)
	var r := 90.0 if glyph != "slash" else 150.0
	var out := PackedVector2Array()
	for i in pts.size():
		var j := Vector2(sin(i * 1.7), cos(i * 2.3)) * wobble
		out.append(centre + pts[i] * r + j)
	return out


## A slightly wavering straight stroke from a to b.
func tie_line(a: Vector2, b: Vector2, wobble: float = 0.8) -> PackedVector2Array:
	var out := PackedVector2Array()
	var normal := (b - a).normalized().orthogonal()
	for i in 40:
		var t := float(i) / 39.0
		out.append(a.lerp(b, t) + normal * (sin(t * 7.0) * 2.0 + sin(i * 2.3) * wobble))
	return out


func _screen(key: String) -> Vector2:
	return camera.unproject_position(targets[key].glyph_anchor())


## The projected radius of a target's glyph_radius(), as the brush measures it.
func _screen_radius(key: String) -> float:
	var anchor: Vector3 = targets[key].glyph_anchor()
	return camera.unproject_position(anchor).distance_to(camera.unproject_position(anchor + camera.global_basis.x * targets[key].glyph_radius()))


func _inject_all() -> void:
	for g in ALL_GLYPHS:
		var info := Brush.inject_stroke(glyph_points(g))
		_log({"event": "injected", "glyph": g, "result": String(info.get("glyph", "")), "targets": (info.get("targets", []) as Array).size()})
		await get_tree().create_timer(1.0).timeout


func _scripted_draw(which: String) -> void:
	var list := ALL_GLYPHS if which == "all" else [which]
	for g in list:
		var speed := DAB_TIME if g == "kindle" else float(Boot.opt("demo_speed", 0.8))
		await play_stroke(glyph_points(g), speed, float(Boot.opt("demo_hold", 1.2)))
		await get_tree().create_timer(1.2, true).timeout


## Holds the brush action, paints the points with synthetic mouse events over duration
## seconds, keeps the brush open for hold seconds, then releases. Goes through the real input
## path (Input.parse_input_event), the same as a player.
func play_stroke(points: PackedVector2Array, duration: float, hold: float, release_draw_first: bool = true) -> void:
	_send_action(&"brush", true)
	await get_tree().create_timer(0.25, true).timeout
	# On desktop the real cursor also sends motion events (when the brush cursor appears, for
	# one), so it is moved along with the synthetic stroke to keep the two from mixing.
	_warp(points[0])
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	down.position = _to_window(points[0])
	down.global_position = down.position
	Input.parse_input_event(down)
	var start := Time.get_ticks_msec()
	var i := 1
	var prev := points[0]
	while i < points.size():
		await get_tree().process_frame
		var due := int(float(Time.get_ticks_msec() - start) / (duration * 1000.0) * points.size())
		while i < points.size() and i <= due:
			var m := InputEventMouseMotion.new()
			m.position = _to_window(points[i])
			m.global_position = m.position
			m.relative = points[i] - prev
			m.velocity = (points[i] - prev) * float(points.size()) / duration
			m.button_mask = MOUSE_BUTTON_MASK_LEFT
			_warp(points[i])
			Input.parse_input_event(m)
			prev = points[i]
			i += 1
	if release_draw_first:
		_send_up(prev)
	await get_tree().create_timer(hold, true).timeout
	_send_action(&"brush", false)
	if not release_draw_first:
		await get_tree().process_frame
		_send_up(prev)


func _send_up(pos: Vector2) -> void:
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = _to_window(pos)
	up.global_position = up.position
	Input.parse_input_event(up)


func _warp(p: Vector2) -> void:
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		Input.warp_mouse(_to_window(p))


## Synthetic events enter as window coordinates and the viewport maps them back.
func _to_window(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p


func _send_action(action: StringName, pressed: bool) -> void:
	var a := InputEventAction.new()
	a.action = action
	a.pressed = pressed
	Input.parse_input_event(a)


# --- Self test (headless) --------------------------------------------------------

var _results: Array = []


func _check(name: String, ok: bool, detail: Variant = "") -> void:
	_results.append(ok)
	print("BRUSH_SELFTEST %s %s %s" % ["PASS" if ok else "FAIL", name, str(detail)])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _selftest() -> void:
	print("BRUSH_SELFTEST physics engine setting %s, server %s" % [ProjectSettings.get_setting("physics/3d/physics_engine"), Engine.get_singleton(&"PhysicsServer3D").get_class()])
	Brush.refill()
	# 1. Each glyph injected over its target hits exactly that target.
	var required := ["glyph", "score", "screen_points", "screen_center", "screen_radius", "world_points", "world_center", "world_radius", "world_from", "world_to", "world_dir", "targets", "ink_cost"]
	for g in ALL_GLYPHS:
		Brush.refill()
		var info := Brush.inject_stroke(glyph_points(g))
		var names: PackedStringArray = []
		for t: Node in info.get("targets", []):
			names.append(t.name)
		var expect := PackedStringArray([targets["tie_a"].name, targets["tie_b"].name]) if g == "tie" else PackedStringArray([targets[g].name])
		_check("inject_%s" % g, info.get("glyph", &"") == StringName(g) and names == expect, "%s targets=%s" % [info.get("glyph", ""), names])
		var missing := required.filter(func(k): return not info.has(k))
		var min_points := 1 if g == "kindle" else 11
		_check("info_keys_%s" % g, missing.is_empty() and info.get("world_points", PackedVector3Array()).size() >= min_points, "missing=%s world_points=%d" % [missing, info.get("world_points", []).size()])
		await _frames(2)
	await get_tree().create_timer(3.6).timeout
	# 2. A vertical line is rejected with glyph_failed.
	var vertical := PackedVector2Array()
	for i in 30:
		vertical.append(Vector2(640, 200 + i * 10))
	var failed_before := _failures
	_check("reject_vertical", Brush.inject_stroke(vertical).is_empty() and _failures == failed_before + 1, Brush.last_result.get("detail", ""))
	await _kindle_tie_tests()
	# 3. Opening and closing through real input, in several key orders.
	Brush.refill()
	var reacted_before: int = targets["bloom"].reacted
	await play_stroke(glyph_points("bloom"), 0.4, 0.2, true)
	await _frames(1)
	_check("draw_then_release_closing", Brush.is_open(), "still fading out")
	await get_tree().create_timer(0.6, true).timeout
	_check("draw_release_order_a", not Brush.is_open() and not get_tree().paused and targets["bloom"].reacted == reacted_before + 1, "open=%s paused=%s reacted=%d" % [Brush.is_open(), get_tree().paused, targets["bloom"].reacted])
	await get_tree().create_timer(3.5).timeout
	Brush.refill()
	reacted_before = targets["slash"].reacted
	await play_stroke(glyph_points("slash"), 0.4, 0.2, false)
	await get_tree().create_timer(0.6, true).timeout
	_check("brush_released_before_draw", not Brush.is_open() and not get_tree().paused and targets["slash"].reacted == reacted_before + 1, "open=%s paused=%s reacted=%d" % [Brush.is_open(), get_tree().paused, targets["slash"].reacted])
	# 4. Refusals.
	Brush.enabled = false
	_send_action(&"brush", true)
	await _frames(2)
	_check("refuse_when_disabled", not Brush.is_open() and not get_tree().paused)
	_send_action(&"brush", false)
	Brush.enabled = true
	get_tree().paused = true
	_send_action(&"brush", true)
	await _frames(2)
	_check("refuse_when_paused", not Brush.is_open())
	_send_action(&"brush", false)
	get_tree().paused = false
	await _frames(2)
	# 5. Closing from outside: focus lost, brush disabled, game unpausing, Escape.
	for how in ["focus_out", "disabled", "unpaused", "escape"]:
		_send_action(&"brush", true)
		await _frames(3)
		var opened := Brush.is_open() and get_tree().paused
		match how:
			"focus_out":
				Brush.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			"disabled":
				Brush.enabled = false
			"unpaused":
				get_tree().paused = false
			"escape":
				_send_action(&"pause", true)
				_send_action(&"pause", false)
		await get_tree().create_timer(0.6, true).timeout
		_check("close_on_%s" % how, opened and not Brush.is_open() and not get_tree().paused, "opened=%s open=%s paused=%s" % [opened, Brush.is_open(), get_tree().paused])
		Brush.enabled = true
		_send_action(&"brush", false)
		await _frames(2)
	# 6. Freeze: the mover does not move while the brush is open.
	_send_action(&"brush", true)
	await _frames(2)
	var p0 := mover.global_position
	await get_tree().create_timer(0.5, true).timeout
	var moved_open := mover.global_position.distance_to(p0)
	_send_action(&"brush", false)
	await get_tree().create_timer(0.8, true).timeout
	_check("world_frozen_while_open", moved_open == 0.0 and mover.global_position.distance_to(p0) > 0.1, "moved while open %.3f, after %.3f" % [moved_open, mover.global_position.distance_to(p0)])
	# 7. Ray queries while the tree is paused.
	await _ray_tests()
	# 8. Ink: drains with length, stops the stroke when empty, refills over time and on kills.
	Brush.ink = 4.0
	var long := glyph_points("gust")
	var info := Brush.inject_stroke(long)
	_check("ink_runs_out", Brush.ink == 0.0 and info.is_empty(), "ink=%.2f result=%s" % [Brush.ink, Brush.last_result.get("detail", "")])
	var no_ink := Brush.inject_stroke(glyph_points("bloom"))
	_check("no_ink_reason", no_ink.is_empty() and Brush.last_result.get("reason") == &"no_ink", Brush.last_result.get("reason"))
	await get_tree().create_timer(1.0).timeout
	var refilled := Brush.ink
	_check("refill_over_time", refilled > 1.5 and refilled < 4.0, "%.2f after 1 s" % refilled)
	Events.enemy_died.emit(self, &"splotchet", Vector3.ZERO)
	_check("refill_on_enemy_died", is_equal_approx(Brush.ink, refilled + Brush.INK_PER_ENEMY), "%.2f" % Brush.ink)
	var passed := _results.count(true)
	print("BRUSH_SELFTEST_DONE passed=%d failed=%d" % [passed, _results.size() - passed])
	get_tree().quit(0 if passed == _results.size() else 1)


## Kindle and Tie: real presses, the 40 px tolerance, stroke order, the no-post fallback to Slash
## and the ink costs.
func _kindle_tie_tests() -> void:
	var lamp: Node = targets["kindle"]
	var post_a: Node = targets["tie_a"]
	var post_b: Node = targets["tie_b"]
	# A short real press on the wick lights the lamp; the same press held 1.2 s does nothing.
	Brush.refill()
	var reacted_before: int = lamp.reacted
	await play_stroke(glyph_points("kindle"), DAB_TIME, 0.2)
	await get_tree().create_timer(0.6, true).timeout
	var held: float = Brush.last_result.get("input", {}).get("duration", -1.0)
	_check("kindle_real_press", lamp.reacted == reacted_before + 1 and Brush.last_result.get("glyph") == &"kindle", "reacted=%d duration=%.2f" % [lamp.reacted - reacted_before, held])
	# play_stroke sends the last of n points at (n - 1) / n of its time, so 1.8 s holds 1.2 s.
	await play_stroke(glyph_points("kindle"), 1.8, 0.2)
	await get_tree().create_timer(0.6, true).timeout
	_check("long_press_not_kindle", Brush.last_result.get("glyph") == &"" and String(Brush.last_result.get("detail", "")).begins_with("closest kindle: held"), Brush.last_result.get("detail", ""))
	# The dab hits within the lamp's projected radius plus 40 px, and not beyond.
	var r_px := _screen_radius("kindle")
	for spec in [["kindle_within_40px", r_px + 30.0, true], ["kindle_beyond_40px", r_px + 55.0, false]]:
		Brush.refill()
		var called: int = lamp.called_usec
		var dab: Vector2 = _screen("kindle") + Vector2(0, spec[1])
		var info := Brush.inject_stroke(PackedVector2Array([dab, dab + Vector2(1, 1)]))
		_check(spec[0], info.get("glyph") == &"kindle" and (lamp.called_usec != called) == spec[2], "offset %.0f px, called=%s" % [spec[1], lamp.called_usec != called])
	# Kindle costs KINDLE_INK.
	Brush.refill()
	var ink_before := Brush.ink
	var dab_info := Brush.inject_stroke(glyph_points("kindle"))
	_check("kindle_ink", absf(ink_before - Brush.ink - dab_info.get("ink_cost", -1.0)) < 0.01 and absf(dab_info.get("ink_cost", 0.0) - Brush.KINDLE_INK) < 0.5, "cost %.2f" % dab_info.get("ink_cost", -1.0))
	# Tie: both posts are told, in stroke order, and info.targets follows the stroke.
	for order in [["tie_a", "tie_b"], ["tie_b", "tie_a"]]:
		Brush.refill()
		var first: Node = targets[order[0]]
		var second: Node = targets[order[1]]
		var line := tie_line(_screen(order[0]), _screen(order[1]))
		var calls := [first.called_usec, second.called_usec]
		ink_before = Brush.ink
		var info := Brush.inject_stroke(line)
		var names: PackedStringArray = []
		for t: Node in info.get("targets", []):
			names.append(t.name)
		var told: bool = first.called_usec != calls[0] and second.called_usec != calls[1] and first.called_usec <= second.called_usec
		_check("tie_%s_first" % first.name, info.get("glyph") == &"tie" and names == PackedStringArray([first.name, second.name]) and told, "targets=%s told_in_order=%s" % [names, told])
		var length_cost := BrushStroke.path_length(line) / get_viewport().get_visible_rect().size.y * Brush.INK_PER_HEIGHT
		_check("tie_ink_%s" % first.name, absf(info.get("ink_cost", 0.0) - (length_cost + Brush.TIE_INK)) < 0.05 and absf(ink_before - Brush.ink - info.get("ink_cost", 0.0)) < 0.01, "cost %.2f = %.2f + %.1f" % [info.get("ink_cost", -1.0), length_cost, Brush.TIE_INK])
	# The same near-horizontal line with no posts on screen is a Slash, as before.
	Brush.refill()
	for post in [post_a, post_b]:
		post.remove_from_group(Brush.GROUP_TIE_POST)
	var plain := Brush.inject_stroke(glyph_points("tie"))
	for post in [post_a, post_b]:
		post.add_to_group(Brush.GROUP_TIE_POST)
	_check("tie_line_without_posts_is_slash", plain.get("glyph") == &"slash", plain.get("glyph", Brush.last_result.get("detail", "")))
	# Starting on a post but ending away from the other is judged as if there were no posts.
	Brush.refill()
	var calls := [post_a.called_usec, post_b.called_usec]
	var a := _screen("tie_a")
	var away := Brush.inject_stroke(tie_line(a, a + (a - _screen("tie_b"))))
	_check("tie_one_end_is_slash", away.get("glyph") == &"slash" and post_a.called_usec == calls[0] and post_b.called_usec == calls[1], away.get("glyph", Brush.last_result.get("detail", "")))
	# Not enough ink for the rope: the cast fails with no_ink.
	var tie_pts := glyph_points("tie")
	Brush.ink = BrushStroke.path_length(tie_pts) / get_viewport().get_visible_rect().size.y * Brush.INK_PER_HEIGHT + 1.0
	var short := Brush.inject_stroke(tie_pts)
	_check("tie_no_ink", short.is_empty() and Brush.last_result.get("reason") == &"no_ink", Brush.last_result.get("reason"))
	Brush.refill()
	await get_tree().create_timer(3.6).timeout


func _ray_tests() -> void:
	var space := get_world_3d().direct_space_state
	get_tree().paused = true
	await _frames(2)
	var soot: Node3D = targets["gust"]
	var hit := _ray_at(space, soot.glyph_anchor())
	_check("ray_hits_while_paused", not hit.is_empty() and hit["collider"] == soot, hit.get("collider", "nothing"))
	# Move a body while paused, then cast at its new place without any physics step.
	var old := soot.global_position
	soot.global_position = old + Vector3(0, 0, -6)
	var same_frame := _ray_at(space, soot.glyph_anchor())
	print("BRUSH_SELFTEST INFO ray at a body moved while paused, same frame: %s" % same_frame.get("collider", "nothing"))
	await _frames(2)
	var moved_hit := _ray_at(space, soot.glyph_anchor())
	_check("ray_sees_body_moved_while_paused_next_frame", not moved_hit.is_empty() and moved_hit["collider"] == soot, moved_hit.get("collider", "nothing"))
	soot.global_position = old
	await _frames(2)
	# Add a new body while paused.
	var fresh := StaticBody3D.new()
	fresh.collision_layer = Layers.BRUSH_TARGET
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	fresh.add_child(shape)
	add_child(fresh)
	fresh.global_position = Vector3(0, 3.5, 2.0)
	print("BRUSH_SELFTEST INFO ray at a body added while paused, same frame: %s" % _ray_at(space, fresh.global_position).get("collider", "nothing"))
	await _frames(2)
	var fresh_hit := _ray_at(space, fresh.global_position)
	_check("ray_sees_body_added_while_paused_next_frame", not fresh_hit.is_empty() and fresh_hit["collider"] == fresh, fresh_hit.get("collider", "nothing"))
	fresh.queue_free()
	get_tree().paused = false
	await _frames(2)


func _ray_at(space: PhysicsDirectSpaceState3D, world: Vector3) -> Dictionary:
	var p := camera.unproject_position(world)
	var from := camera.project_ray_origin(p)
	var q := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(p) * 100.0, Layers.BRUSH_RAY_MASK)
	q.collide_with_areas = true
	return space.intersect_ray(q)
