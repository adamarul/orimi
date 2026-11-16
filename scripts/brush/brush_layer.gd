extends CanvasLayer
## Autoload "Brush": the ink brush. Owner: brush. See docs/CONTRACTS.md ("Brush") and
## docs/BRUSH.md.
##
## Hold the brush action to freeze the world and open the brush view (sepia underpainting on
## paper), paint one stroke with brush_draw, release to recognise and cast. Whatever happens
## (keys released in any order, focus lost, the game unpausing or disabling the brush
## underneath it) the brush closes, restores the mouse mode and unpauses the tree.

## Seconds to fade the paper in and out.
const OPEN_TIME := 0.18
const CLOSE_TIME := 0.3
## Ink spent per stroke length of one viewport height.
const INK_PER_HEIGHT := 20.0
## Ink regained per second while the world runs, and per enemy defeated.
const INK_REFILL_PER_SECOND := 2.5
const INK_PER_ENEMY := 15.0
## Brush speed is measured over this window of frames (seconds), then smoothed with this weight
## per frame (0..1). Frame-based, because event timestamps and Godot's own pointer velocity
## both lag or bunch up in the browser.
const SPEED_WINDOW := 0.08
const SPEED_SMOOTHING := 0.5
## Width and dryness ease toward their target over about this much stroke length (fraction of
## the viewport height), so a change of speed swells or thins the line instead of stepping.
const WIDTH_EASE := 0.05
## Candidates further than this from the camera are ignored (metres).
const CAST_RANGE := 60.0
## Brush rays: length (metres), rays along the stroke, and where a ray that hits nothing lands.
const RAY_LENGTH := 250.0
const RAY_COUNT := 40
const MISS_DISTANCE := 12.0
## Gust hits candidates inside the stroke bounds grown by this many viewport pixels.
const GUST_MARGIN := 40.0
## Kindle hits candidates whose projected disc comes within this many pixels of the dab.
const KINDLE_MARGIN := 40.0
## Flat ink cost of a Kindle (a dab has almost no length), and the extra cost of the rope a
## Tie draws on top of its stroke length.
const KINDLE_INK := 3.0
const TIE_INK := 4.0
## Group of the tie posts a Tie joins.
const GROUP_TIE_POST := &"tie_post"
## How long an injected stroke stays on screen (seconds).
const AFTERIMAGE_TIME := 0.7
## Speed used to draw injected strokes, in viewport heights per second.
const INJECT_SPEED := 1.2

enum State { CLOSED, OPEN, CLOSING }

## Game sets this false on the title screen, in cutscenes and in menus.
var enabled: bool = true
var ink: float = 100.0
var ink_max: float = 100.0
## The last recognition result (also for failures): glyph, score, reason, detail, scores,
## gates, features. Plain data, for readouts and QA.
var last_result: Dictionary = {}

var _state := State.CLOSED
var _fade := 0.0
var _cast_ok := true
var _prev_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _prev_accumulated := true
var _drawing := false
var _stroke_ink := 0.0
var _tried_dry := false
var _speed := 0.0
var _last_pos := Vector2.ZERO
var _travel := 0.0
var _shape := Vector2.ZERO
var _speed_samples: Array[Vector2] = []
var _pressure := -1.0
var _afterimage := 0.0
var _emitted_ink := -1.0
var _cursor: Image
var _press_usec := 0
var _duration := 0.0
# Tie posts on screen while the brush is open, and the post the stroke started on.
var _posts: Array = []
var _start_post := -1
# What the input looked like during the current stroke, reported in last_result["input"].
var _input_stats := {}

@onready var _view: ColorRect = $View
@onready var _stroke: BrushStrokeView = $Stroke
@onready var _hints: BrushTieHints = $TieHints
@onready var _pot: Control = $InkPot


func _ready() -> void:
	layer = Layers.CANVAS_BRUSH
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_cursor = _make_cursor()
	Events.enemy_died.connect(_on_enemy_died)
	_set_fade(0.0)
	_warm_up()


## Draws the paper and a stroke fully transparent for a few frames at start-up, so their
## shaders are compiled before the first time the player opens the brush.
func _warm_up() -> void:
	_stroke.height = _height()
	_stroke.show_stroke(PackedVector2Array([Vector2(10, 10), Vector2(40, 12), Vector2(70, 10)]), 500.0)
	_stroke.set_opacity(0.0)
	_pot.visible = false
	visible = true
	for i in 3:
		await get_tree().process_frame
	if _state == State.CLOSED and _afterimage <= 0.0:
		visible = false
		_stroke.clear()


func is_open() -> bool:
	return _state != State.CLOSED


func add_ink(amount: float) -> void:
	ink = clampf(ink + amount, 0.0, ink_max)
	_emitted_ink = ink
	Events.ink_changed.emit(ink, ink_max)


func refill() -> void:
	add_ink(ink_max)


func known_glyphs() -> Array[StringName]:
	return BrushGlyphs.GLYPHS.duplicate()


## Run recognition and casting on a stroke given in viewport pixels, exactly as if the
## player had drawn it, without opening the brush. For QA and demos. Ink is spent the same
## way (the stroke is cut short where the ink runs out). The stroke shows briefly on screen.
## One point, or a few within a dab's size, is a Kindle (the press time counts as 0).
## Returns the glyph info dictionary, or {} if nothing was recognised.
func inject_stroke(points: PackedVector2Array) -> Dictionary:
	var height := _height()
	var had_ink := ink > 0.0
	var cut := PackedVector2Array()
	var cost := 0.0
	for i in points.size():
		if i == 0:
			cut.append(points[0])
			continue
		var step := points[i - 1].distance_to(points[i]) / height * INK_PER_HEIGHT
		if cost + step > ink:
			var f := (ink - cost) / step if step > 0.0 else 0.0
			cut.append(points[i - 1].lerp(points[i], f))
			cost = ink
			break
		cost += step
		cut.append(points[i])
	if had_ink:
		ink -= cost
		_emit_ink(true)
	if _state == State.CLOSED and had_ink:
		_stroke.height = height
		_stroke.show_stroke(cut, INJECT_SPEED * height)
		_afterimage = 1.0
		_view.visible = false
		_hints.visible = false
		visible = true
	return _cast(cut, cost, not had_ink, {"injected": true, "duration": 0.0})


func _unhandled_input(event: InputEvent) -> void:
	if _state == State.CLOSED and event.is_action_pressed(&"brush") and not event.is_echo():
		if _open():
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _state != State.OPEN:
		return
	if event.is_action_pressed(&"pause"):
		_close(false)
	elif event.is_action(&"brush_draw") and event is InputEventMouseButton:
		if event.pressed:
			_begin_stroke(event.position)
		else:
			_end_stroke()
	elif event is InputEventMouseMotion:
		if _drawing:
			_extend_stroke(event.position, event.pressure)
	else:
		return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _state == State.OPEN:
		_close(false)
	elif what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		Input.set_custom_mouse_cursor(null)


func _process(delta: float) -> void:
	match _state:
		State.OPEN:
			_set_fade(move_toward(_fade, 1.0, delta / OPEN_TIME))
			if _drawing:
				_measure_speed()
			if not enabled or not get_tree().paused:
				_close(false)
			elif not Input.is_action_pressed(&"brush"):
				_close(true)
		State.CLOSING:
			_set_fade(move_toward(_fade, 0.0, delta / CLOSE_TIME))
			var t := _fade
			if _cast_ok:
				_stroke.set_opacity(t)
			else:
				_stroke.set_decay(1.0 - t)
			if _fade <= 0.0:
				_finish_close()
		State.CLOSED:
			if not get_tree().paused and ink < ink_max:
				ink = minf(ink_max, ink + INK_REFILL_PER_SECOND * delta)
				_emit_ink(false)
			if _afterimage > 0.0:
				_afterimage = maxf(0.0, _afterimage - delta / AFTERIMAGE_TIME)
				_stroke.set_opacity(minf(1.0, _afterimage * 2.0))
				if _afterimage <= 0.0:
					visible = false


func _open() -> bool:
	if not enabled or get_tree().paused:
		return false
	_state = State.OPEN
	get_tree().paused = true
	_prev_mouse_mode = Input.mouse_mode
	_prev_accumulated = Input.use_accumulated_input
	Input.use_accumulated_input = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.set_custom_mouse_cursor(_cursor, Input.CURSOR_ARROW, Vector2(2, 29))
	_afterimage = 0.0
	_stroke.clear()
	_stroke.height = _height()
	_drawing = false
	_tried_dry = false
	_stroke_ink = 0.0
	_view.visible = true
	_pot.visible = true
	_posts = _tie_posts()
	_start_post = -1
	_hints.visible = true
	_hints.set_posts(_posts, _height())
	visible = true
	_set_fade(0.0)
	Events.brush_opened.emit()
	return true


func _close(cast: bool) -> void:
	if _state != State.OPEN:
		return
	_state = State.CLOSING
	_end_stroke()
	Input.set_custom_mouse_cursor(null)
	Input.mouse_mode = _prev_mouse_mode
	Input.use_accumulated_input = _prev_accumulated
	_cast_ok = true
	var raw := _stroke.raw_points()
	if cast and (raw.size() > 0 or _tried_dry):
		_cast_ok = not _cast(raw, _stroke_ink, raw.size() < 2 and _tried_dry, _input_stats).is_empty()
	elif not cast:
		_cast_ok = false


func _finish_close() -> void:
	_state = State.CLOSED
	visible = false
	_stroke.clear()
	get_tree().paused = false
	Events.brush_closed.emit()


func _begin_stroke(pos: Vector2) -> void:
	# While the browser is still leaving pointer lock the position is not real yet.
	if _drawing or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	_stroke.clear()
	_stroke.height = _height()
	_stroke_ink = 0.0
	_press_usec = Time.get_ticks_usec()
	_duration = 0.0
	_start_post = BrushGlyphs.post_at(pos, _posts)
	_hints.set_state(_start_post, -1)
	if ink <= 0.0:
		_tried_dry = true
		return
	_drawing = true
	_speed = 0.0
	_pressure = -1.0
	_travel = 0.0
	_speed_samples.clear()
	_input_stats = {"events": 0, "pen": false, "pressure_min": 1.0, "pressure_max": 0.0, "speed_max": 0.0, "width_min": INF, "width_max": 0.0}
	_last_pos = pos
	_shape = BrushStroke.width_for(0.0, -1.0, _stroke.height)
	_stroke.add_point(pos, _shape.x, _shape.y)


func _extend_stroke(pos: Vector2, pressure: float) -> void:
	var height := _stroke.height
	var dist := pos.distance_to(_last_pos)
	_travel += dist
	if pressure > 0.0:
		_pressure = pressure
		_input_stats["pen"] = true
		_input_stats["pressure_min"] = minf(_input_stats["pressure_min"], pressure)
		_input_stats["pressure_max"] = maxf(_input_stats["pressure_max"], pressure)
	_input_stats["events"] += 1
	var cost := dist / height * INK_PER_HEIGHT
	var ran_dry := cost >= ink
	if ran_dry:
		pos = _last_pos.lerp(pos, ink / cost) if cost > 0.0 else _last_pos
		cost = ink
	ink -= cost
	_stroke_ink += cost
	_emit_ink(ran_dry)
	var target := BrushStroke.width_for(_speed, _pressure, height)
	_shape = _shape.lerp(target, 1.0 - exp(-dist / (WIDTH_EASE * height)))
	_input_stats["width_min"] = minf(_input_stats["width_min"], _shape.x)
	_input_stats["width_max"] = maxf(_input_stats["width_max"], _shape.x)
	_stroke.add_point(pos, _shape.x, _shape.y)
	_last_pos = pos
	if _start_post >= 0:
		_hints.set_state(_start_post, BrushGlyphs.post_at(pos, _posts, _start_post))
	if ran_dry:
		_drawing = false
		_stroke.finish()


## Distance painted over the last SPEED_WINDOW seconds of frames, in px/s.
func _measure_speed() -> void:
	var now := Time.get_ticks_usec() / 1e6
	_speed_samples.append(Vector2(now, _travel))
	while _speed_samples.size() > 2 and now - _speed_samples[1].x >= SPEED_WINDOW:
		_speed_samples.pop_front()
	var first := _speed_samples[0]
	if now - first.x > 0.0:
		_speed = lerpf(_speed, (_travel - first.y) / (now - first.x), SPEED_SMOOTHING)
		_input_stats["speed_max"] = maxf(_input_stats["speed_max"], _speed)


func _end_stroke() -> void:
	if _drawing:
		_drawing = false
		_duration = float(Time.get_ticks_usec() - _press_usec) / 1e6
		_input_stats["duration"] = _duration
		_stroke.finish()


## Recognises a raw stroke and, if it is a glyph, casts it. Emits glyph_cast or glyph_failed.
func _cast(raw: PackedVector2Array, ink_cost: float, no_ink: bool, input: Dictionary) -> Dictionary:
	var height := _height()
	var pts := BrushStroke.prepare(raw, height)
	var posts := _tie_posts()
	var duration: float = input.get("duration", 0.0)
	var res := BrushGlyphs.recognise(pts, height, duration, posts)
	var extra := KINDLE_INK if res["glyph"] == &"kindle" else TIE_INK if res["glyph"] == &"tie" else 0.0
	if not no_ink and extra > 0.0:
		if ink < extra:
			no_ink = true
		else:
			ink -= extra
			ink_cost += extra
			_emit_ink(true)
	if no_ink:
		res["reason"] = &"no_ink"
		res["glyph"] = &""
	last_result = res.duplicate(true)
	(last_result["features"] as Dictionary).erase("crossings")
	last_result["input"] = input.duplicate()
	if res["glyph"] == &"":
		Events.glyph_failed.emit({
			"reason": res["reason"], "screen_points": pts, "detail": res["detail"],
			"score": res["score"], "ink_cost": ink_cost,
		})
		return {}
	var info := _glyph_info(res["glyph"], res["score"], pts, ink_cost)
	info["duration"] = duration
	if res["glyph"] == &"tie":
		_apply_tie(info, posts[res["tie"][0]], posts[res["tie"][1]])
	else:
		_apply(info)
	Events.glyph_cast.emit(info["glyph"], info)
	return info


## Tie posts in front of the camera and in range, with their projected anchor and radius:
## [{"node", "anchor": Vector3, "pos": Vector2, "radius": float px}, ...].
func _tie_posts() -> Array:
	var out: Array = []
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return out
	for node in get_tree().get_nodes_in_group(GROUP_TIE_POST):
		if not node is Node3D or not node.is_inside_tree():
			continue
		var c := _candidate(camera, node)
		if not c.is_empty():
			out.append(c)
	return out


## Projects a candidate: anchor (glyph_anchor() or 0.8 m above its origin), screen position and
## the screen radius of glyph_radius() (default 1 m). Empty if behind the camera or too far.
func _candidate(camera: Camera3D, node: Node3D) -> Dictionary:
	var anchor: Vector3 = node.glyph_anchor() if node.has_method(&"glyph_anchor") else node.global_position + Vector3.UP * 0.8
	if camera.is_position_behind(anchor):
		return {}
	var dist := camera.global_position.distance_to(anchor)
	if dist > CAST_RANGE:
		return {}
	var radius: float = node.glyph_radius() if node.has_method(&"glyph_radius") else 1.0
	var sp := camera.unproject_position(anchor)
	return {"node": node, "anchor": anchor, "pos": sp, "dist": dist,
		"radius": sp.distance_to(camera.unproject_position(anchor + camera.global_basis.x * radius))}


## A Tie: both posts are told, in stroke order, and are the targets whatever they answer.
func _apply_tie(info: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var targets: Array[Node] = info["targets"]
	targets.append(a["node"])
	targets.append(b["node"])
	info["tie_anchors"] = PackedVector3Array([a["anchor"], b["anchor"]])
	for node: Node in [a["node"], b["node"]]:
		if is_instance_valid(node) and node.has_method(&"on_glyph"):
			node.on_glyph(&"tie", info)


func _glyph_info(glyph: StringName, score: float, pts: PackedVector2Array, ink_cost: float) -> Dictionary:
	var even := BrushStroke.resample(pts, 64)
	var center := Vector2.ZERO
	for p in even:
		center += p
	center /= float(even.size())
	var radius := 0.0
	for p in even:
		radius += p.distance_to(center)
	radius /= float(even.size())
	var info := {
		"glyph": glyph, "score": score, "screen_points": pts,
		"screen_center": center, "screen_radius": radius,
		"world_points": PackedVector3Array(), "world_center": Vector3.ZERO, "world_radius": 0.0,
		"world_from": Vector3.ZERO, "world_to": Vector3.ZERO, "world_dir": Vector3.FORWARD,
		"targets": [] as Array[Node], "ink_cost": ink_cost,
	}
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return info
	var space := camera.get_world_3d().direct_space_state
	var world_points := PackedVector3Array()
	var ray_points := PackedVector2Array([center]) if glyph == &"kindle" else BrushStroke.resample(pts, RAY_COUNT)
	for p in ray_points:
		var hit := _ray(camera, space, p)
		if not hit.is_empty():
			world_points.append(hit["position"])
	var world_center := _ray_point(camera, space, center)
	var world_from := _ray_point(camera, space, pts[0])
	var world_to := _ray_point(camera, space, pts[pts.size() - 1])
	var dir := world_to - world_from
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = -camera.global_basis.z
		dir.y = 0.0
	var world_radius := 0.0
	if world_points.size() > 0:
		for q in world_points:
			world_radius += Vector2(q.x - world_center.x, q.z - world_center.z).length()
		world_radius /= float(world_points.size())
	else:
		var focal := _height() * 0.5 / tan(deg_to_rad(camera.fov) * 0.5)
		world_radius = radius * camera.global_position.distance_to(world_center) / focal
	info["world_points"] = world_points
	info["world_center"] = world_center
	info["world_radius"] = world_radius
	info["world_from"] = world_from
	info["world_to"] = world_to
	info["world_dir"] = dir.normalized() if dir.length() > 0.0 else Vector3.FORWARD
	return info


func _ray(camera: Camera3D, space: PhysicsDirectSpaceState3D, p: Vector2) -> Dictionary:
	var from := camera.project_ray_origin(p)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(p) * RAY_LENGTH, Layers.BRUSH_RAY_MASK)
	query.collide_with_areas = true
	return space.intersect_ray(query)


func _ray_point(camera: Camera3D, space: PhysicsDirectSpaceState3D, p: Vector2) -> Vector3:
	var hit := _ray(camera, space, p)
	if not hit.is_empty():
		return hit["position"]
	return camera.project_ray_origin(p) + camera.project_ray_normal(p) * MISS_DISTANCE


## Finds the candidates the glyph touches on screen and tells them, nearest first.
func _apply(info: Dictionary) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var glyph: StringName = info["glyph"]
	var pts: PackedVector2Array = info["screen_points"]
	var outline := BrushStroke.resample(pts, 96)
	var bounds := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		bounds = bounds.expand(p)
	bounds = bounds.grow(GUST_MARGIN)
	var half_width := BrushStroke.WIDTH_SLOW * _height() * 0.5
	var dab: Vector2 = info["screen_center"]
	var seen := {}
	var hits: Array = []
	for group in [Layers.GROUP_BRUSH_TARGET, Layers.GROUP_ENEMY]:
		for node in get_tree().get_nodes_in_group(group):
			if seen.has(node) or not node is Node3D or not node.is_inside_tree():
				continue
			seen[node] = true
			var c := _candidate(camera, node)
			if c.is_empty():
				continue
			var sp: Vector2 = c["pos"]
			var r_px: float = c["radius"]
			var dist: float = c["dist"]
			var hit := false
			match glyph:
				&"kindle":
					hit = sp.distance_to(dab) <= r_px + KINDLE_MARGIN
				&"bloom":
					hit = Geometry2D.is_point_in_polygon(sp, outline)
				&"slash":
					hit = _distance_to_polyline(sp, outline) <= r_px + half_width
				&"gust":
					hit = bounds.has_point(sp)
			if hit:
				hits.append([dist, node])
	hits.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var targets: Array[Node] = info["targets"]
	for h in hits:
		var node: Node = h[1]
		if is_instance_valid(node) and node.has_method(&"on_glyph") and node.on_glyph(glyph, info):
			targets.append(node)


static func _distance_to_polyline(p: Vector2, line: PackedVector2Array) -> float:
	var best := INF
	for i in range(1, line.size()):
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i - 1], line[i])))
	return best


func _on_enemy_died(_enemy: Node3D, _kind: StringName, _at: Vector3) -> void:
	add_ink(INK_PER_ENEMY)


func _emit_ink(force: bool) -> void:
	if force or absf(ink - _emitted_ink) >= 0.5 or ink >= ink_max or ink <= 0.0:
		if ink != _emitted_ink or force:
			_emitted_ink = ink
			Events.ink_changed.emit(ink, ink_max)


func _set_fade(value: float) -> void:
	_fade = value
	(_view.material as ShaderMaterial).set_shader_parameter(&"fade", value)
	_pot.modulate.a = clampf(value * 1.5, 0.0, 1.0)


func _height() -> float:
	return get_viewport().get_visible_rect().size.y


## The cursor: a plain ink brush tip pointing down-left, hot spot at the tip. An Image rather
## than a texture, so no GPU resource is left behind if the game quits with the brush open.
func _make_cursor() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var tip := Vector2(2, 29)
	var heel := Vector2(14, 17)
	var end := Vector2(30, 1)
	var ink_col := Color("1b1a1c")
	var rim := Color("efe6d2")
	var wood := Color("8a6a48")
	for y in 32:
		for x in 32:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := Color(0, 0, 0, 0)
			# Bristles: a teardrop from the tip to the heel.
			var q := Geometry2D.get_closest_point_to_segment(p, tip, heel)
			var t := tip.distance_to(q) / tip.distance_to(heel)
			var r := 0.6 + 4.2 * sin(clampf(t, 0.0, 1.0) * PI * 0.62)
			var d := p.distance_to(q)
			# Handle: a thin shaft from the heel to the end.
			var qh := Geometry2D.get_closest_point_to_segment(p, heel, end)
			var dh := p.distance_to(qh)
			if d <= r:
				col = ink_col
			elif dh <= 2.0:
				col = wood
			elif d <= r + 1.2 or dh <= 3.0:
				col = Color(rim, 0.9)
			img.set_pixel(x, y, col)
	return img
