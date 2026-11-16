extends Node
## Autoload "Vfx": every one-shot effect, the wind, and the clock of the living valley.
## Owner: vfx. Public API per docs/CONTRACTS.md, plus warm_up() and the extras listed there in
## docs/SHADERS_VFX.md.
##
## Effects are particles in a handful of pooled VfxLayer MultiMeshes (one draw call per look)
## and pooled VfxRibbon strips. Everything advances in steps of 1/12 s from _process, so it
## moves on the same grid as the characters and freezes while the tree is paused (the brush).
## The director reacts to Events on its own (see _connect_events); gameplay must not also call it
## for those events.

signal warmed_up

const STEP := 1.0 / 12.0
const TEX := "res://assets/textures/vfx/"
const SPRITE_SHADER := preload("res://shaders/vfx/fx_sprite.gdshader")
const SPRITE_FLAT_SHADER := preload("res://shaders/vfx/fx_sprite_flat.gdshader")
const GLOW_SHADER := preload("res://shaders/vfx/fx_glow.gdshader")
const RIBBON_SHADER := preload("res://shaders/vfx/fx_ribbon.gdshader")
const SHARED_ENV_MATERIALS: PackedStringArray = [
	"res://materials/env/water.tres", "res://materials/env/foliage.tres",
	"res://materials/env/mist.tres", "res://materials/env/sky.tres",
]
const ENV_WARM_SCENES: PackedStringArray = [
	"res://scenes/env/foliage_scatter.tscn", "res://scenes/env/mist.tscn",
	"res://scenes/env/river_water.tscn", "res://scenes/env/soot_bank_visual.tscn",
]
const ZONE_SLOTS := {&"zone_a": 0, &"zone_b": 1, &"tree": 2}
const WARM_POS := Vector3(0.0, -2000.0, 0.0)

## Stepped effect clock in seconds. Stops while the tree is paused. Pushed to every registered
## material as "vfx_time".
var time := 0.0
## Flowers sprout in the player's wake on clean ground while this is true.
var wake_flowers := true
## Calm wind direction and strength (the "wind" global wanders and gusts around these).
var wind_direction := Vector3(1.0, 0.0, 0.3)
var wind_strength := 0.4
## Seconds a bloom_ring() without a CurseField zone takes to reach its radius.
var bloom_ring_duration := 2.6

var _acc := 0.0
var _root: Node3D
var _ink_ground: VfxLayer
var _ink_air: VfxLayer
var _petals: VfxLayer
var _flowers: VfxLayer
var _strokes: VfxLayer
var _soot: VfxLayer
var _glow: VfxLayer
var _ripples: VfxLayer
var _kit: VfxKit
var _layers: Array[VfxLayer] = []
var _ribbons: Array[VfxRibbon] = []
var _ribbon_material: ShaderMaterial
var _trails: Array[VfxTrail] = []
var _materials: Array[ShaderMaterial] = []
var _rings: Array[Dictionary] = []
var _gusts: Array[Dictionary] = []
var _petal_fall := 0.0
var _last_gust_dir := Vector3.ZERO
var _last_gust_time := -100.0
var _player: Node3D
var _wake_last := Vector3.INF
var _warming := false
var _warm := false
var _wind := Vector4(1.0, 0.0, 0.3, 0.4)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_root = Node3D.new()
	_root.name = "Effects"
	add_child(_root)
	var ink := _sprite_material("ink_splats.png", Vector2(4, 2), 0, Palette.INK)
	_ink_ground = _layer("InkGround", 192, VfxLayer.Align.GROUND, ink)
	_ink_air = _layer("InkAir", 192, VfxLayer.Align.DIRECTIONAL, _sprite_material("ink_splats.png", Vector2(4, 2), 0, Palette.INK, 3))
	var pm := _sprite_material("petals.png", Vector2(4, 2), 1, Palette.PETAL, 0, Palette.PETAL_DEEP, Color("fffaf4"))
	pm.shader = SPRITE_FLAT_SHADER
	_petals = _layer("Petals", 768, VfxLayer.Align.BILLBOARD, pm)
	var fm := _sprite_material("flowers.png", Vector2(4, 2), 2, Color.WHITE, 2, Color("6e9a55"), Palette.GOLD)
	fm.set_shader_parameter(&"pivot_y", 0.5)
	fm.set_shader_parameter(&"cutoff", 0.45)
	_flowers = _layer("Flowers", 640, VfxLayer.Align.UPRIGHT, fm)
	var sm := _sprite_material("curls.png", Vector2(2, 4), 3, Color("f7f3ea"), 3)
	sm.set_shader_parameter(&"cutoff", 0.4)
	_strokes = _layer("Strokes", 192, VfxLayer.Align.DIRECTIONAL, sm)
	_soot = _layer("Soot", 192, VfxLayer.Align.BILLBOARD,
		_sprite_material("soot.png", Vector2(4, 2), 4, Palette.CURSE_INK, 0, Color("6a6560")))
	var gm := ShaderMaterial.new()
	gm.shader = GLOW_SHADER
	gm.set_shader_parameter(&"atlas", load(TEX + "sparks.png"))
	gm.set_shader_parameter(&"halo_color", Palette.GOLD_PALE)
	_glow = _layer("Glow", 160, VfxLayer.Align.BILLBOARD, gm)
	var rm := _sprite_material("ripples.png", Vector2(4, 4), 3, Color("f6f5ef"), 1)
	rm.set_shader_parameter(&"cutoff", 0.4)
	_ripples = _layer("Ripples", 160, VfxLayer.Align.GROUND, rm)
	_ribbon_material = ShaderMaterial.new()
	_ribbon_material.shader = RIBBON_SHADER
	_ribbon_material.set_shader_parameter(&"ribbon_tex", load(TEX + "ribbon.png"))
	for i in 6:
		_new_ribbon()
	var rope := ShaderMaterial.new()
	rope.shader = RIBBON_SHADER
	rope.set_shader_parameter(&"ribbon_tex", load(TEX + "ribbon.png"))
	rope.set_shader_parameter(&"fill_color", Palette.INK)
	rope.set_shader_parameter(&"streak_color", Palette.INK_SOFT)
	rope.set_shader_parameter(&"edge_color", Palette.CURSE_INK)
	rope.set_shader_parameter(&"cutoff", 0.2)
	_kit = VfxKit.new()
	_kit.name = "Kit"
	add_child(_kit)
	_kit.setup(self, rope)
	for path in SHARED_ENV_MATERIALS:
		if ResourceLoader.exists(path):
			register_material(load(path) as ShaderMaterial)
	_connect_events()
	_push_wind()


func _sprite_material(tex: String, grid: Vector2, look: int, a: Color, align := 0,
		b := Color(0.42, 0.40, 0.38), c := Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SPRITE_SHADER
	m.set_shader_parameter(&"atlas", load(TEX + tex))
	m.set_shader_parameter(&"atlas_grid", grid)
	m.set_shader_parameter(&"look", look)
	m.set_shader_parameter(&"align", align)
	m.set_shader_parameter(&"color_a", a)
	m.set_shader_parameter(&"color_b", b)
	m.set_shader_parameter(&"color_c", c)
	return m


func _layer(layer_name: String, capacity: int, align: int, material: ShaderMaterial) -> VfxLayer:
	var l := VfxLayer.new()
	l.name = layer_name
	l.add_to_group(&"ink_skip")
	if material.shader == SPRITE_SHADER or material.shader == SPRITE_FLAT_SHADER:
		material.set_shader_parameter(&"align", align)
	l.setup(capacity, align, material)
	_root.add_child(l)
	_layers.append(l)
	return l


func _new_ribbon() -> VfxRibbon:
	var r := VfxRibbon.new()
	r.add_to_group(&"ink_skip")
	r.material_override = _ribbon_material
	_root.add_child(r)
	_ribbons.append(r)
	return r


func _connect_events() -> void:
	Events.enemy_died.connect(func(_e: Node3D, kind: StringName, at: Vector3) -> void:
		ink_splash(at, 1.6 if kind == &"reedwraith" else 1.0))
	Events.enemy_hit.connect(func(_e: Node3D, _damage: float, at: Vector3) -> void: hit_spark(at))
	Events.glyph_cast.connect(_on_glyph_cast)
	Events.zone_restore_started.connect(_on_zone_restore_started)
	Events.finale_started.connect(func(center: Vector3) -> void:
		petal_burst(center + Vector3.UP * 5.0, 7.0))
	Events.valley_restored.connect(func() -> void: _petal_fall = 14.0)
	Events.thorns_cut.connect(func(_t: Node3D, at: Vector3) -> void: _thorns_burst(at))
	Events.soot_cleared.connect(func(_t: Node3D, at: Vector3) -> void: _soot_burst(at))
	Events.enemy_unveiled.connect(func(enemy: Node3D) -> void:
		if is_instance_valid(enemy):
			_veil_strip(enemy.global_position + Vector3.UP * 1.4))
	Events.player_attacked.connect(_on_player_attacked)
	Events.player_damaged.connect(func(_hp: int, _max_hp: int) -> void: _hurt_mark())


# --- public API (docs/CONTRACTS.md) -------------------------------------------------------

## Ink splash where an enemy dissolves or ink lands: flat black splats with satellite
## droplets and thrown streaks that soak away into the ground.
func ink_splash(at: Vector3, size: float = 1.0) -> void:
	var g := _ground_y(at) + 0.03
	var base := Vector3(at.x, g, at.z)
	var s := maxf(size, 0.2)
	_ink_ground.spawn(base, Vector3.ZERO, Vector2.ONE * s * randf_range(1.5, 1.9), 3.2, randi() % 4,
		{&"rot": randf() * TAU, &"grow": 0.17, &"erode": 0.4})
	for i in randi_range(2, 3):
		var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * s * randf_range(0.6, 1.1)
		_ink_ground.spawn(base + off + Vector3.UP * 0.002 * (i + 1), Vector3.ZERO,
			Vector2.ONE * s * randf_range(0.45, 0.75), 3.0, randi() % 4,
			{&"rot": randf() * TAU, &"delay": STEP * randi_range(1, 3), &"erode": 0.35})
	for i in randi_range(3, 5):
		var a := randf() * TAU
		var d := Vector3(cos(a), 0, sin(a))
		_ink_ground.spawn(base + d * s * randf_range(0.9, 1.3) + Vector3.UP * 0.004, Vector3.ZERO,
			Vector2(s * randf_range(1.0, 1.5), s * 0.45), 2.6, 4 + (i % 2),
			{&"rot": a, &"delay": STEP * randi_range(1, 2), &"erode": 0.3})
	for i in randi_range(8, 12):
		var a := randf() * TAU
		var v := Vector3(cos(a) * randf_range(1.5, 4.5) * s, randf_range(2.5, 4.5), sin(a) * randf_range(1.5, 4.5) * s)
		_ink_air.spawn(at + Vector3.UP * 0.4, v, Vector2(0.22, 0.13) * s * randf_range(0.7, 1.3),
			randf_range(0.8, 1.1), 6, {&"gravity": 14.0, &"ground": g, &"erode": 0.55})
	for i in 3:
		var a := randf() * TAU
		var v := Vector3(cos(a) * 6.0, randf_range(1.0, 2.5), sin(a) * 6.0) * s
		_ink_air.spawn(at + Vector3.UP * 0.5, v, Vector2(0.75, 0.2) * s, 0.5, 4 + i % 2,
			{&"gravity": 10.0, &"ground": g, &"erode": 0.4, &"drag": 1.5})


## Burst of petals, for restorations.
func petal_burst(at: Vector3, radius: float = 3.0) -> void:
	var n := clampi(int(24 + radius * 8.0), 24, 90)
	var g := _ground_y(at) + 0.05
	for i in n:
		var a := randf() * TAU
		var r := sqrt(randf()) * radius * 0.5
		var p := at + Vector3(cos(a) * r, randf_range(0.0, 0.6), sin(a) * r)
		var v := Vector3(cos(a), 0, sin(a)) * randf_range(1.0, 3.0) * (0.5 + radius * 0.15) + Vector3.UP * randf_range(3.0, 6.0)
		_spawn_petal(p, v, randf_range(2.4, 3.6), g)
	for i in clampi(int(radius), 3, 8):
		var a := randf() * TAU
		_glow.spawn(at + Vector3(cos(a), randf_range(0.5, 2.0), sin(a)) * radius * 0.4, Vector3.UP * 0.6,
			Vector2.ONE * randf_range(0.35, 0.6), randf_range(0.5, 0.8), 3, {&"delay": randf() * 0.4, &"rot": randf() * 0.6, &"erode": 0.5})


## Ring of flowers riding the colour front outward across the ground.
func bloom_ring(center: Vector3, radius: float) -> void:
	_rings.append({"center": center, "radius": radius, "age": 0.0, "slot": -1, "last": 0.0})


## Dry-brush ribbon along a world-space cut, for the slash glyph.
func slash_ribbon(from: Vector3, to: Vector3) -> void:
	var d := to - from
	var length := d.length()
	if length < 0.05:
		return
	var up := Vector3.UP - d.normalized() * d.normalized().dot(Vector3.UP)
	up = up.normalized() if up.length() > 0.01 else Vector3.FORWARD
	var pts := PackedVector3Array()
	var widths := PackedFloat32Array()
	var n := 20
	var w := clampf(length * 0.045, 0.12, 0.3)
	for i in n:
		var s := float(i) / (n - 1)
		pts.append(from + d * s + up * sin(s * PI) * length * 0.12)
		widths.append(w * pow(sin(PI * clampf(s * 0.92 + 0.04, 0.0, 1.0)), 0.6) * (1.15 - s * 0.4))
	_ribbon().play(pts, widths, 0.34)


## Swirl of wind lines, for the gust glyph.
func gust(at: Vector3, direction: Vector3, strength: float = 1.0) -> void:
	var dir := direction
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = _camera_flat(Vector3.RIGHT)
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP)
	var k := clampf(strength, 0.3, 2.0)
	for i in randi_range(6, 8):
		var p := at + side * randf_range(-1.6, 1.6) * k + Vector3.UP * randf_range(0.0, 1.6) - dir * randf_range(0.0, 1.2)
		var v := dir * randf_range(5.0, 8.0) * k + Vector3.UP * randf_range(-0.3, 0.6)
		var dark := i % 3 == 0
		_strokes.spawn(p, v, Vector2(2.6, 1.3) * randf_range(0.75, 1.15) * k, 0.92, randi() % 8,
			{&"drag": 1.6, &"draw": 0.34, &"tail": 0.42, &"mirror": randf() < 0.5, &"delay": STEP * (i % 3),
			&"tint": Color(0.34, 0.33, 0.32) if dark else Color.WHITE, &"erode": 2.0})
	_gusts.append({"dir": dir, "strength": 1.2 * k, "age": 0.0, "life": 1.6})
	_last_gust_dir = dir
	_last_gust_time = time


## Small hit mark.
func hit_spark(at: Vector3) -> void:
	_glow.spawn(at, Vector3.ZERO, Vector2.ONE * 0.95, 0.25, 0, {&"grow": 0.09, &"rot": randf_range(-0.4, 0.4), &"erode": 0.5})
	_glow.spawn(at, Vector3.ZERO, Vector2.ONE * 1.25, 0.25, 1, {&"rot": randf() * TAU, &"erode": 0.4})
	for i in 4:
		var a := randf() * TAU
		_ink_air.spawn(at, Vector3(cos(a) * 3.0, randf_range(1.0, 3.0), sin(a) * 3.0), Vector2(0.14, 0.08),
			0.42, 6, {&"gravity": 12.0, &"erode": 0.5})


## Attach a ribbon trail that follows node (for example the fox's tail tip).
## Returns the trail node; set its "emitting" property to start and stop it.
## Plays a level-kit effect by name; effects() lists the names. See VfxKit.play() for params.
## The kit's own nodes already trigger most of these (docs/SHADERS_VFX.md, "Level-kit effects").
func play(effect: StringName, at: Vector3, params: Dictionary = {}) -> bool:
	return _kit.play(effect, at, params)


func effects() -> Array[StringName]:
	return VfxKit.EFFECTS


## A wake of ripples behind node while it moves on water (Pell's raft). water_y: the surface
## height (default: the node's own height).
func attach_wake(node: Node3D, water_y: float = NAN) -> void:
	_kit.attach_wake(node, water_y)


func detach_wake(node: Node3D) -> void:
	_kit.detach_wake(node)


func attach_trail(node: Node3D, lifetime: float = 0.25) -> Node:
	if not is_instance_valid(node):
		return null
	var t := VfxTrail.new()
	t.target = node
	t.lifetime = maxf(lifetime, STEP)
	t.material_override = _ribbon_material
	_root.add_child(t)
	_trails.append(t)
	return t


# --- extras (listed in docs/SHADERS_VFX.md) ----------------------------------------------

## Draws every effect once far below the world, through a small off-screen viewport, so their
## shaders are compiled before play (the cold browser load is shader compilation). Safe to call
## more than once; emits warmed_up when done. Works while the tree is paused.
func warm_up() -> void:
	if _warming or _warm:
		return
	_warming = true
	var vp := SubViewport.new()
	vp.name = "WarmUp"
	vp.size = Vector2i(96, 64)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.process_mode = Node.PROCESS_MODE_ALWAYS
	var cam := Camera3D.new()
	vp.add_child(cam)
	var holder := Node3D.new()
	holder.name = "WarmUpProps"
	add_child(holder)
	add_child(vp)
	cam.global_transform = Transform3D(Basis(), WARM_POS + Vector3(0.0, 1.0, 6.0))
	for l in _layers:
		var frame := 0
		l.spawn(WARM_POS + Vector3(randf_range(-1, 1), 1.0, 0.0), Vector3.RIGHT * 0.01, Vector2.ONE, 0.4, frame, {&"draw": 0.1 if l == _strokes else 0.0})
		l.refresh()
	var r := _ribbon()
	var pts := PackedVector3Array([WARM_POS + Vector3(-1, 1, 0), WARM_POS + Vector3(0, 1.4, 0), WARM_POS + Vector3(1, 1, 0)])
	r.play(pts, PackedFloat32Array([0.2, 0.3, 0.2]), 0.4)
	r.build(pts, PackedFloat32Array([0.2, 0.3, 0.2]), PackedFloat32Array([0.0, 0.5, 1.0]), PackedFloat32Array([0.0, 0.5, 1.0]), 0.0, 1.0, 0.0)
	_kit.warm(WARM_POS)
	for path in ENV_WARM_SCENES:
		if not ResourceLoader.exists(path):
			continue
		var n := (load(path) as PackedScene).instantiate() as Node3D
		if n == null:
			continue
		n.set_meta(&"vfx_warm_up", true)
		holder.add_child(n)
		n.global_position = WARM_POS
	for i in 3:
		await RenderingServer.frame_post_draw
	holder.queue_free()
	vp.queue_free()
	r.playing = false
	r.visible = false
	_kit.end_warm()
	_warming = false
	_warm = true
	warmed_up.emit()


func is_warm() -> bool:
	return _warm


## Adds a ShaderMaterial whose "vfx_time" uniform the director advances (env materials do this
## themselves; call it for a duplicate of one of them).
func register_material(material: ShaderMaterial) -> void:
	if material != null and not _materials.has(material):
		_materials.append(material)
		material.set_shader_parameter(&"vfx_time", time)


## Removes every playing one-shot effect (trails stay attached).
func clear_all() -> void:
	for l in _layers:
		l.clear()
	for r in _ribbons:
		r.playing = false
		r.visible = false
	_kit.clear()
	_rings.clear()
	_gusts.clear()
	_petal_fall = 0.0


## The wind vector last pushed to the "wind" global: xyz direction, w strength.
func current_wind() -> Vector4:
	return _wind


# --- stepping -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_acc += delta
	if _acc >= STEP:
		_acc = minf(_acc - STEP, STEP)
		_step()


func _step() -> void:
	time += STEP
	for m in _materials:
		m.set_shader_parameter(&"vfx_time", time)
	_push_wind()
	_kit.step()
	_step_rings()
	_step_petal_fall()
	_step_wake()
	for l in _layers:
		l.step(STEP)
	for r in _ribbons:
		r.step(STEP)
	for i in range(_trails.size() - 1, -1, -1):
		var t := _trails[i]
		if not is_instance_valid(t) or t.is_queued_for_deletion():
			_trails.remove_at(i)
		else:
			t.step(STEP)


func _push_wind() -> void:
	var t := time
	var base := wind_direction.normalized() if wind_direction.length() > 0.001 else Vector3.RIGHT
	var turn := sin(t * 0.11) * 0.22 + sin(t * 0.047 + 1.3) * 0.15
	var dir := base.rotated(Vector3.UP, turn)
	var gusting := maxf(0.0, sin(t * 0.37) * sin(t * 0.13 + 1.0))
	var strength := wind_strength * (0.8 + 0.25 * sin(t * 0.9 + 0.4) + gusting * 1.1)
	for i in range(_gusts.size() - 1, -1, -1):
		var g: Dictionary = _gusts[i]
		g["age"] = float(g["age"]) + STEP
		var k: float = 1.0 - float(g["age"]) / float(g["life"])
		if k <= 0.0:
			_gusts.remove_at(i)
			continue
		var gv: Vector3 = dir * strength + (g["dir"] as Vector3) * float(g["strength"]) * k
		strength = gv.length()
		dir = gv.normalized()
	_wind = Vector4(dir.x, dir.y, dir.z, strength)
	RenderingServer.global_shader_parameter_set(&"wind", _wind)


func _on_zone_restore_started(zone_id: StringName, center: Vector3, radius: float) -> void:
	var slot: int = ZONE_SLOTS.get(zone_id, -1)
	for z: Node in get_tree().get_nodes_in_group(&"cursed_zone"):
		if z.get(&"zone_id") == zone_id and int(z.get(&"curse_slot")) >= 0:
			slot = int(z.get(&"curse_slot"))
	_rings.append({"center": center, "radius": radius, "age": 0.0, "slot": slot, "last": 0.0})
	petal_burst(center + Vector3.UP, 3.0)


func _step_rings() -> void:
	for i in range(_rings.size() - 1, -1, -1):
		var ring: Dictionary = _rings[i]
		var age: float = ring["age"] + STEP
		ring["age"] = age
		var radius: float = ring["radius"]
		var slot: int = ring["slot"]
		var r: float
		if slot >= 0:
			r = CurseField.front_radius(slot)
		else:
			var k := clampf(age / bloom_ring_duration, 0.0, 1.0)
			r = radius * (1.0 - (1.0 - k) * (1.0 - k))
		var last: float = ring["last"]
		var limit := radius * 1.03
		if r > last + 0.05 and last < limit:
			_ring_flowers(ring["center"], minf(last, limit), minf(r, limit))
		ring["last"] = maxf(last, r)
		if last >= limit or age > 12.0:
			_rings.remove_at(i)


func _ring_flowers(center: Vector3, r0: float, r1: float) -> void:
	var r := (r0 + r1) * 0.5
	var n := clampi(int(TAU * r / 1.3), 3, 24)
	var a0 := randf() * TAU
	for j in n:
		var a := a0 + TAU * (j + randf_range(-0.3, 0.3)) / n
		var rr := randf_range(r0, r1)
		var p := center + Vector3(cos(a) * rr, 0.0, sin(a) * rr)
		p.y = _ground_y(p + Vector3.UP * 2.0)
		var keeper := randf() < 0.12
		_spawn_flower(p, randf_range(0.7, 1.05), randf_range(9.0, 13.0) if keeper else randf_range(0.4, 0.65))
		if j % 4 == 0:
			_spawn_petal(p + Vector3.UP * 0.3, Vector3(cos(a), 0, sin(a)) * 1.5 + Vector3.UP * randf_range(2.0, 3.5), randf_range(1.2, 1.8), p.y + 0.03)
		if j % 7 == 0:
			_glow.spawn(p + Vector3.UP * randf_range(0.3, 0.9), Vector3.UP * 0.4, Vector2.ONE * 0.4, 0.5, 3, {&"rot": randf() * 0.5, &"erode": 0.5})


func _step_petal_fall() -> void:
	if _petal_fall <= 0.0:
		return
	_petal_fall -= STEP
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var fwd := _camera_flat(Vector3.FORWARD)
	var side := fwd.cross(Vector3.UP)
	var n := 7 if _petal_fall > 3.0 else 3
	for i in n:
		var p := cam.global_position + fwd * randf_range(2.0, 20.0) + side * randf_range(-12.0, 12.0) + Vector3.UP * randf_range(2.0, 8.0)
		var g := _ground_y(p) + 0.04
		_spawn_petal(p, Vector3(randf_range(-0.6, 0.6), -randf_range(0.6, 1.2), randf_range(-0.6, 0.6)), randf_range(5.0, 7.0), g, 1.4)


func _step_wake() -> void:
	if not wake_flowers:
		return
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		_wake_last = Vector3.INF
		if _player == null:
			return
	var body := _player as CharacterBody3D
	if body != null and not body.is_on_floor():
		return
	var p := _player.global_position
	if _wake_last == Vector3.INF or p.distance_to(_wake_last) > 6.0:
		_wake_last = p
		return
	var moved := p - _wake_last
	moved.y = 0.0
	if moved.length() < 0.6:
		return
	_wake_last = p
	if CurseField.amount_at(p) > 0.05:
		return
	var dir := moved.normalized()
	var side := dir.cross(Vector3.UP)
	for i in randi_range(2, 3):
		var q := p - dir * randf_range(0.1, 0.5) + side * randf_range(0.2, 0.7) * (1.0 if i % 2 == 0 else -1.0)
		_spawn_flower(q + Vector3.UP * 0.01, randf_range(0.42, 0.62), randf_range(4.0, 6.0))


# --- effect pieces --------------------------------------------------------------------------

func _spawn_petal(p: Vector3, v: Vector3, life: float, ground: float, size := 1.0) -> void:
	_petals.spawn(p, v, Vector2.ONE * randf_range(0.17, 0.26) * size, life, randi() % 8,
		{&"gravity": 3.2, &"drag": 1.4, &"flutter": randf_range(0.06, 0.14), &"spin": randf_range(-7.0, 7.0),
		&"rot": randf() * TAU, &"ground": ground, &"erode": 0.75, &"shrink": 0.7,
		&"tint": Color(1, 1, 1).darkened(randf() * 0.08)})


const _FLOWER_TINTS: Array[Color] = [Color("f3b7c0"), Color("fbf6ee"), Color("ebcb7a"), Color("e58aa0"), Color("f7ece0")]


func _spawn_flower(p: Vector3, height: float, life: float) -> void:
	var tint: Color = _FLOWER_TINTS[randi() % _FLOWER_TINTS.size()]
	_flowers.spawn(p, Vector3.ZERO, Vector2.ONE * height, life, randi() % 8,
		{&"grow": 0.25, &"erode": 0.75, &"shrink": 0.85, &"rot": randf_range(-0.18, 0.18), &"tint": tint})


func _on_glyph_cast(glyph: StringName, info: Dictionary) -> void:
	var center: Vector3 = info.get("world_center", Vector3.ZERO)
	match glyph:
		&"slash":
			var a: Vector3 = info.get("world_from", center)
			var b: Vector3 = info.get("world_to", center)
			var lift := Vector3.UP * 0.8
			slash_ribbon(a + lift, b + lift)
		&"gust":
			gust(center + Vector3.UP * 0.8, info.get("world_dir", Vector3.ZERO), 1.0)
		&"bloom":
			var r := clampf(float(info.get("world_radius", 1.5)), 0.8, 4.0)
			for i in 14:
				var a := TAU * i / 14.0 + randf_range(-0.2, 0.2)
				var p := center + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.6, 1.05)
				p.y = _ground_y(p + Vector3.UP * 2.0)
				_spawn_flower(p, randf_range(0.4, 0.65), randf_range(3.0, 5.0))
			petal_burst(center + Vector3.UP * 0.5, 1.2)


func _on_player_attacked(attack: StringName, origin: Transform3D) -> void:
	for t in _trails:
		if is_instance_valid(t) and t.emitting and is_instance_valid(t.target) and is_instance_valid(_player) \
				and (t.target == _player or _player.is_ancestor_of(t.target)):
			return
	var fwd := -origin.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)
	var c := origin.origin + Vector3.UP * 0.45
	var sweep := -1.0 if attack == &"attack_2" else 1.0
	var pts := PackedVector3Array()
	var widths := PackedFloat32Array()
	var n := 16
	for i in n:
		var s := float(i) / (n - 1)
		var a := lerpf(-1.9, 1.9, s) * sweep
		var dir := fwd * cos(a) + right * sin(a)
		pts.append(c + dir * (0.95 + 0.12 * sin(s * PI)) + Vector3.UP * (0.12 * s - 0.06))
		widths.append(0.15 * pow(sin(PI * clampf(s, 0.0, 1.0)), 0.7) + 0.01)
	_ribbon().play(pts, widths, 0.3)


func _thorns_burst(at: Vector3) -> void:
	var g := _ground_y(at) + 0.03
	for i in randi_range(9, 12):
		var a := randf() * TAU
		var v := Vector3(cos(a) * randf_range(2.0, 5.0), randf_range(2.0, 5.5), sin(a) * randf_range(2.0, 5.0))
		_ink_air.spawn(at + Vector3(randf_range(-1.5, 1.5), randf_range(-0.6, 0.8), 0), v,
			Vector2(0.7, 0.35) * randf_range(0.6, 1.2), randf_range(0.9, 1.3), 7,
			{&"gravity": 12.0, &"ground": g, &"erode": 0.55, &"rot": randf_range(-0.5, 0.5)})
	for i in 3:
		var off := Vector3(randf_range(-1.8, 1.8), 0, randf_range(-0.6, 0.6))
		_ink_ground.spawn(Vector3(at.x, g, at.z) + off, Vector3.ZERO, Vector2.ONE * randf_range(0.5, 0.9), 2.4,
			randi() % 4, {&"rot": randf() * TAU, &"delay": STEP * 3, &"erode": 0.3})
	hit_spark(at)


func _soot_burst(at: Vector3) -> void:
	var dir := _last_gust_dir if time - _last_gust_time < 2.5 else _camera_flat(Vector3.FORWARD)
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	for i in 16:
		var p := at + Vector3(randf_range(-2.6, 2.6), randf_range(-1.2, 1.2), randf_range(-0.5, 0.5))
		var v := dir * randf_range(3.0, 7.0) + Vector3.UP * randf_range(0.3, 2.0) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		_soot.spawn(p, v, Vector2.ONE * randf_range(0.7, 1.4), randf_range(1.1, 1.7), randi() % 8,
			{&"drag": 1.2, &"spin": randf_range(-2.0, 2.0), &"rot": randf() * TAU, &"erode": 0.15, &"delay": STEP * (i % 3)})
	for i in 4:
		var p := at + Vector3(randf_range(-1.5, 1.5), randf_range(-0.5, 1.0), 0)
		_strokes.spawn(p, dir * randf_range(4.0, 6.0), Vector2(2.4, 1.2), 0.9, randi() % 8,
			{&"drag": 1.5, &"draw": 0.34, &"tail": 0.42, &"mirror": randf() < 0.5, &"tint": Color(0.3, 0.29, 0.28), &"erode": 2.0})


func _veil_strip(at: Vector3) -> void:
	for i in 12:
		var a := randf() * TAU
		var out := Vector3(cos(a), 0, sin(a))
		_soot.spawn(at + out * 0.35 + Vector3.UP * randf_range(-0.8, 0.6), out * randf_range(1.2, 2.4) + Vector3.UP * randf_range(1.0, 2.0),
			Vector2.ONE * randf_range(0.45, 0.85), randf_range(1.0, 1.4), randi() % 8,
			{&"drag": 0.9, &"spin": randf_range(-3.0, 3.0), &"rot": randf() * TAU, &"erode": 0.15, &"delay": STEP * (i % 3)})
	for i in 3:
		var a := TAU * i / 3.0
		_strokes.spawn(at + Vector3(cos(a), 0, sin(a)) * 0.6, Vector3(cos(a) * 1.5, 3.5, sin(a) * 1.5), Vector2(1.8, 0.9), 0.8, randi() % 8,
			{&"drag": 1.2, &"draw": 0.3, &"tail": 0.38, &"mirror": i % 2 == 0, &"tint": Color(0.3, 0.29, 0.28), &"erode": 2.0})


func _hurt_mark() -> void:
	if not is_instance_valid(_player):
		return
	var at := _player.global_position + Vector3.UP * 0.6
	_glow.spawn(at, Vector3.ZERO, Vector2.ONE * 0.8, 0.25, 1, {&"rot": randf() * TAU, &"erode": 0.4})
	for i in 5:
		var a := randf() * TAU
		_ink_air.spawn(at, Vector3(cos(a) * 2.5, randf_range(1.5, 3.0), sin(a) * 2.5), Vector2(0.14, 0.08),
			0.5, 6, {&"gravity": 12.0, &"erode": 0.5})


# --- helpers --------------------------------------------------------------------------------

func _ribbon() -> VfxRibbon:
	for r in _ribbons:
		if not r.playing:
			return r
	if _ribbons.size() < 16:
		return _new_ribbon()
	return _ribbons[0]


func _ground_y(at: Vector3) -> float:
	var world := _root.get_world_3d()
	if world == null:
		return at.y
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 8.0, Layers.WORLD)
	q.collide_with_areas = false
	var hit := world.direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else at.y


func _camera_flat(fallback: Vector3) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return fallback
	var v := -cam.global_basis.z if fallback == Vector3.FORWARD else cam.global_basis.x
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else fallback
