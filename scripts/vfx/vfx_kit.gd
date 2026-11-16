class_name VfxKit
extends Node
## The level-kit effects of the Vfx director: kindling, the Tie rope, the finishing stroke,
## sealed fights, verse-stones, beads, pickups, throwbacks and the raft's wake. Owner: vfx.
## Part of the director (scripts/vfx/vfx_director.gd): it draws into the director's pooled
## layers and is stepped by it on the 12 fps grid, so it adds no lights, no materials and no
## nodes at the moment of an effect. Every effect can be played by name through Vfx.play().
##
## Hooks: it finds the kit's own nodes by group and connects their signals (kindle_target
## kindled, tie_post tied_up, sealed_fight fight_started / fight_won, verse_stone woken, enemy
## unravel_started), plus Game.enemy_finished, Events.bead_awarded and Events.player_thrown_back.
## A sealed fight's knot is followed while it shows. See docs/SHADERS_VFX.md, "Level-kit effects".

const EFFECTS: Array[StringName] = [
	&"kindle_catch", &"tie_rope", &"unravel", &"clean_cut", &"fight_ring_rise", &"fight_ring_fall",
	&"knot_drift", &"knot_burst", &"verse_wake", &"bead_award", &"pickup", &"cursed_throwback",
	&"water_throwback", &"raft_wake",
]
const STEP := 1.0 / 12.0
const INK_TINT := Color(0.12, 0.115, 0.125)
const SMOKE_TINT := Color(0.45, 0.43, 0.41)
const SCAN_STEPS := 6
const PEAKS := {&"kindle_catch": 0.17, &"tie_rope": 0.42, &"unravel": 0.9, &"clean_cut": 0.25, &"knot_drift": 1.0,
	&"knot_burst": 0.17, &"fight_ring_rise": 0.42, &"fight_ring_fall": 0.33, &"verse_wake": 0.6, &"bead_award": 0.58,
	&"pickup": 0.17, &"cursed_throwback": 0.17, &"water_throwback": 0.33}

var fx: Node
var _ropes: Array[VfxRibbon] = []
var _tracks: Array[Dictionary] = []
var _steps := 0
var _ties := {}
var _shot := {}


func setup(director: Node, rope_material: Material) -> void:
	fx = director
	for i in 4:
		var r := VfxRibbon.new()
		r.name = "Rope%d" % i
		r.add_to_group(&"ink_skip")
		r.material_override = rope_material
		fx._root.add_child(r)
		_ropes.append(r)
	_connect_game.call_deferred()


func _connect_game() -> void:
	var game := get_node_or_null(^"/root/Game")
	if game != null and game.has_signal(&"level_loaded"):
		game.level_loaded.connect(func(_level: Node) -> void:
			var gloom := String(Boot.opt("vfx_gloom", ""))
			if gloom != "":
				CurseField.set_valley_gloom(float(gloom), 0.0))
	if game != null and game.has_signal(&"enemy_finished"):
		game.enemy_finished.connect(func(enemy: Node3D) -> void:
			if is_instance_valid(enemy):
				clean_cut(enemy.global_position + Vector3.UP * 0.5))
	Events.bead_awarded.connect(func(_level_id: StringName, color: Color) -> void:
		var p := get_tree().get_first_node_in_group(&"player") as Node3D
		if p != null:
			bead_award(p.global_position + Vector3.UP * 1.5, color))
	Events.player_thrown_back.connect(func(at: Vector3, cause: StringName) -> void:
		if cause == &"water":
			water_throwback(at)
		else:
			cursed_throwback(at))


## Plays a kit effect by name (EFFECTS). params per effect: kind (kindle_catch: lamp, brazier,
## lantern_fruit), to and sag (tie_rope), node (unravel, knot_drift, raft_wake: the node to
## follow), duration (unravel, knot_drift), radius (fight rings), color (bead_award, pickup),
## water_y (raft_wake). Returns false for an unknown name.
func play(effect: StringName, at: Vector3, params: Dictionary = {}) -> bool:
	match effect:
		&"kindle_catch":
			kindle_catch(at, String(params.get("kind", "lamp")))
		&"tie_rope":
			tie_rope(at, params.get("to", at + Vector3.RIGHT * 3.0), float(params.get("sag", 0.35)))
		&"unravel":
			unravel(params.get("node") as Node3D, at, float(params.get("duration", 1.5)))
		&"clean_cut":
			clean_cut(at)
		&"fight_ring_rise":
			fight_ring_rise(at, float(params.get("radius", 5.0)))
		&"fight_ring_fall":
			fight_ring_fall(at, float(params.get("radius", 5.0)))
		&"knot_drift":
			knot_drift(params.get("node") as Node3D, float(params.get("duration", 1.0e9)))
		&"knot_burst":
			knot_burst(at)
		&"verse_wake":
			verse_wake(at)
		&"bead_award":
			bead_award(at, params.get("color", Palette.GOLD))
		&"pickup":
			pickup(at, params.get("color", Palette.GOLD))
		&"cursed_throwback":
			cursed_throwback(at)
		&"water_throwback":
			water_throwback(at)
		&"raft_wake":
			attach_wake(params.get("node") as Node3D, float(params.get("water_y", NAN)))
		_:
			return false
	return true


# --- effects --------------------------------------------------------------------------------

## A lamp, brazier or lantern-fruit catching from a Kindle dab: a vermilion flare at the wick,
## tongues of gold brush flame licking up, embers, then a thread of smoke.
func kindle_catch(at: Vector3, kind: String = "lamp") -> void:
	_log(&"kindle_catch")
	var k: float = {"lamp": 1.3, "brazier": 1.8, "lantern_fruit": 1.0}.get(kind, 1.3)
	fx._glow.spawn(at, Vector3.ZERO, Vector2.ONE * 1.3 * k, 0.42, 1, {&"grow": 0.08, &"rot": randf() * TAU, &"erode": 0.3, &"tint": Palette.VERMILION})
	fx._glow.spawn(at, Vector3.UP * 0.3, Vector2.ONE * 0.85 * k, 0.6, 0, {&"grow": 0.17, &"erode": 0.4, &"tint": Palette.GOLD})
	fx._glow.spawn(at, Vector3.ZERO, Vector2.ONE * 0.9 * k, 0.33, 2, {&"grow": 0.17, &"erode": 0.3, &"tint": Palette.VERMILION})
	for i in 4:
		var side := Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
		fx._strokes.spawn(at + side * 0.12 * k, (Vector3.UP * randf_range(2.4, 3.4) + side) * k, Vector2(0.9, 0.45) * k * randf_range(0.8, 1.1),
			0.58, 4 + randi() % 4, {&"draw": 0.25, &"tail": 0.3, &"drag": 2.2, &"mirror": i % 2 == 0, &"delay": STEP * i,
			&"tint": Palette.GOLD if i % 2 == 0 else Palette.VERMILION, &"erode": 2.0})
	for i in 9:
		fx._glow.spawn(at + Vector3(randf_range(-0.15, 0.15), randf_range(0.0, 0.2), randf_range(-0.15, 0.15)) * k,
			Vector3(randf_range(-1.0, 1.0), randf_range(1.6, 3.0), randf_range(-1.0, 1.0)) * k, Vector2.ONE * randf_range(0.11, 0.18) * k,
			randf_range(0.7, 1.1), 3, {&"drag": 1.4, &"delay": STEP * (i % 4), &"rot": randf() * TAU, &"erode": 0.45, &"tint": Palette.GOLD})
	for i in 2:
		fx._strokes.spawn(at + Vector3.UP * 0.4 * k, Vector3(randf_range(-0.3, 0.3), 1.2, randf_range(-0.3, 0.3)) * k, Vector2(1.1, 0.55) * k,
			1.1, 4 + randi() % 4, {&"draw": 0.45, &"tail": 0.55, &"drag": 0.8, &"mirror": randf() < 0.5, &"delay": 0.35 + STEP * i,
			&"tint": SMOKE_TINT, &"erode": 2.0})


## The Tie: a rope of ink drawn from a to b with a deep sag, pulled taut with a twang that
## flicks ink off both rings, then left to the kit's own rope.
func tie_rope(a: Vector3, b: Vector3, sag: float = 0.35) -> void:
	_log(&"tie_rope")
	var r: VfxRibbon = null
	for rope in _ropes:
		if not rope.playing:
			r = rope
			break
	if r == null:
		r = _ropes[0]
	r.playing = true
	_tracks.append({"kind": &"rope", "ribbon": r, "a": a, "b": b, "sag": sag, "age": 0.0})


## An enemy unravelling (the finishing-stroke window): threads of ink peel off and curl away,
## drops fall and soot flecks rise, faster toward the end. Follows node while it exists.
func unravel(node: Node3D, at: Vector3 = Vector3.ZERO, duration: float = 1.5) -> void:
	_log(&"unravel")
	_tracks.append({"kind": &"unravel", "node": node, "follow": node != null, "at": at, "age": 0.0, "life": duration})


## The clean cut of a finishing stroke: a bright cut across the enemy, a wide ring of petals,
## gold sparks and a few flowers where it stood.
func clean_cut(at: Vector3) -> void:
	_log(&"clean_cut")
	var side: Vector3 = fx._camera_flat(Vector3.RIGHT)
	fx.slash_ribbon(at - side * 1.4 + Vector3.UP * 0.35, at + side * 1.4 - Vector3.UP * 0.2)
	fx._glow.spawn(at, Vector3.ZERO, Vector2.ONE * 1.6, 0.33, 0, {&"grow": 0.08, &"rot": randf_range(-0.4, 0.4), &"erode": 0.4, &"tint": Palette.GOLD})
	fx._glow.spawn(at, Vector3.ZERO, Vector2.ONE * 2.0, 0.42, 2, {&"grow": 0.17, &"erode": 0.3, &"tint": Palette.PETAL_DEEP})
	var g: float = fx._ground_y(at) + 0.05
	for i in 36:
		var a := TAU * i / 36.0 + randf_range(-0.08, 0.08)
		var out := Vector3(cos(a), 0.0, sin(a))
		fx._spawn_petal(at + out * 0.3, out * randf_range(3.5, 5.5) + Vector3.UP * randf_range(2.0, 4.0), randf_range(2.0, 3.0), g, 1.15)
	for i in 6:
		var a := randf() * TAU
		fx._glow.spawn(at + Vector3(cos(a), randf_range(-0.2, 0.6), sin(a)) * 0.8, Vector3.UP * 0.8, Vector2.ONE * randf_range(0.3, 0.5),
			0.6, 3, {&"delay": randf() * 0.3, &"rot": randf() * 0.6, &"erode": 0.5})
	for i in 7:
		var a := TAU * i / 7.0 + randf_range(-0.3, 0.3)
		var p := at + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.6, 1.3)
		p.y = fx._ground_y(p + Vector3.UP * 2.0)
		fx._spawn_flower(p, randf_range(0.4, 0.6), randf_range(3.0, 4.5))


## A sealed fight's ring of ink wash rising: a wave of upright ink strokes runs round the
## circle while ink soaks into the ground along it.
func fight_ring_rise(center: Vector3, radius: float) -> void:
	_log(&"fight_ring_rise")
	var g: float = fx._ground_y(center + Vector3.UP * 2.0)
	var n := clampi(int(TAU * radius / 0.95), 16, 40)
	for i in n:
		var a := TAU * i / n
		var out := Vector3(cos(a), 0.0, sin(a))
		var p := Vector3(center.x, g, center.z) + out * radius
		var wave := STEP * float(i * 6 / n)
		for j in 2:
			fx._ink_air.spawn(p + out * randf_range(-0.15, 0.15) + Vector3.UP * (0.3 + 0.6 * j), Vector3.UP * randf_range(4.0, 5.5) * (1.0 - 0.3 * j),
				Vector2(randf_range(1.3, 1.8), randf_range(0.45, 0.6)), 0.85, 4 + (i + j) % 2,
				{&"drag": 3.2, &"delay": wave + STEP * j, &"erode": 0.55, &"shrink": 0.3})
		if i % 3 == 1:
			fx._strokes.spawn(p + Vector3.UP * 0.2, Vector3.UP * randf_range(3.0, 4.0) + out * 0.25, Vector2(1.3, 0.65), 0.8, randi() % 4,
				{&"draw": 0.3, &"tail": 0.45, &"drag": 2.2, &"mirror": i % 2 == 0, &"delay": wave, &"tint": INK_TINT, &"erode": 2.0})
		if i % 3 == 0:
			fx._ink_ground.spawn(p + Vector3.UP * (0.03 + 0.002 * (i % 5)), Vector3.ZERO, Vector2.ONE * randf_range(0.7, 1.0), 1.8, randi() % 4,
				{&"rot": randf() * TAU, &"grow": 0.17, &"delay": wave, &"erode": 0.35})


## The ring sinking when the fight is won: the wash runs back down into the ground and breaks
## into soot that drifts outward.
func fight_ring_fall(center: Vector3, radius: float) -> void:
	_log(&"fight_ring_fall")
	var g: float = fx._ground_y(center + Vector3.UP * 2.0)
	var n := clampi(int(TAU * radius / 1.1), 14, 34)
	for i in n:
		var a := TAU * i / n
		var out := Vector3(cos(a), 0.0, sin(a))
		var p := Vector3(center.x, g, center.z) + out * radius
		fx._ink_air.spawn(p + Vector3.UP * randf_range(1.6, 2.2), Vector3.DOWN * randf_range(3.0, 4.0), Vector2(randf_range(1.3, 1.7), 0.5), 0.6, 4 + i % 2,
			{&"gravity": 4.0, &"ground": g + 0.05, &"delay": STEP * (i % 3), &"erode": 0.5, &"shrink": 0.4})
		if i % 2 == 0:
			fx._ink_ground.spawn(p + Vector3.UP * (0.03 + 0.002 * (i % 5)), Vector3.ZERO, Vector2.ONE * randf_range(0.8, 1.2), 1.6, randi() % 4,
				{&"rot": randf() * TAU, &"delay": 0.3, &"erode": 0.3})
		if i % 2 == 1:
			fx._soot.spawn(p + Vector3.UP * randf_range(0.2, 1.2), out * randf_range(1.5, 2.6) + Vector3.UP * randf_range(0.2, 0.8),
				Vector2.ONE * randf_range(0.5, 0.9), randf_range(1.0, 1.4), randi() % 8,
				{&"drag": 1.1, &"spin": randf_range(-2.0, 2.0), &"rot": randf() * TAU, &"erode": 0.15, &"delay": 0.2 + STEP * (i % 3)})


## The knot of black cord drifting: threads trail off it and soot flecks rise behind it.
## Follows node for duration seconds, or while it is visible.
func knot_drift(node: Node3D, duration: float = 1.0e9) -> void:
	if not is_instance_valid(node):
		return
	for t in _tracks:
		if t["kind"] == &"knot" and t["node"] == node:
			return
	_tracks.append({"kind": &"knot", "node": node, "fight": null, "age": 0.0, "life": duration, "last": node.global_position})


## The knot bursting when Orimi touches it: shards of cord fly out, a puff of soot, a red flare.
func knot_burst(at: Vector3) -> void:
	_log(&"knot_burst")
	var g: float = fx._ground_y(at)
	fx._glow.spawn(at, Vector3.ZERO, Vector2.ONE * 1.8, 0.33, 2, {&"grow": 0.08, &"erode": 0.3, &"tint": Palette.CURSE_RED})
	for i in 8:
		var a := randf() * TAU
		var v := Vector3(cos(a) * randf_range(3.0, 6.0), randf_range(1.0, 4.0), sin(a) * randf_range(3.0, 6.0))
		fx._ink_air.spawn(at, v, Vector2(0.55, 0.16) * randf_range(0.7, 1.3), randf_range(0.6, 0.9), [4, 5, 7][i % 3],
			{&"gravity": 9.0, &"ground": g + 0.03, &"drag": 0.8, &"erode": 0.5})
	for i in 6:
		var a := TAU * i / 6.0
		var out := Vector3(cos(a), 0.0, sin(a))
		fx._strokes.spawn(at + out * 0.2, out * randf_range(3.0, 4.0) + Vector3.UP * randf_range(-0.5, 1.0), Vector2(1.3, 0.65), 0.7, randi() % 4,
			{&"draw": 0.25, &"tail": 0.35, &"drag": 2.0, &"mirror": i % 2 == 0, &"tint": INK_TINT, &"erode": 2.0})
	for i in 6:
		var a := randf() * TAU
		fx._soot.spawn(at + Vector3(cos(a), randf_range(-0.3, 0.3), sin(a)) * 0.3, Vector3(cos(a), randf_range(0.3, 1.0), sin(a)) * randf_range(1.6, 2.8),
			Vector2.ONE * randf_range(0.35, 0.6), randf_range(0.9, 1.3), randi() % 8,
			{&"drag": 1.2, &"spin": randf_range(-3.0, 3.0), &"rot": randf() * TAU, &"erode": 0.15, &"delay": STEP * (i % 3)})


## A verse-stone waking under Bloom: a gold ring, lines of verse lifting off its face as ink
## strokes, flowers opening round its foot and petals.
func verse_wake(at: Vector3) -> void:
	_log(&"verse_wake")
	var g: float = fx._ground_y(at)
	fx._glow.spawn(at, Vector3.ZERO, Vector2.ONE * 1.9, 0.5, 2, {&"grow": 0.17, &"erode": 0.35, &"tint": Palette.GOLD})
	fx._glow.spawn(at, Vector3.ZERO, Vector2.ONE * 1.1, 0.4, 0, {&"grow": 0.08, &"rot": randf() * 0.5, &"erode": 0.4})
	var side: Vector3 = fx._camera_flat(Vector3.RIGHT)
	for i in 4:
		var p := at + side * (float(i) - 1.5) * 0.2 + Vector3.UP * randf_range(-0.15, 0.25)
		fx._strokes.spawn(p, Vector3.UP * randf_range(1.0, 1.4) + side * randf_range(-0.2, 0.2), Vector2(0.75, 0.37), 1.2, 4 + i,
			{&"draw": 0.35, &"tail": 0.7, &"drag": 0.6, &"mirror": i % 2 == 1, &"delay": STEP * 2 * i, &"tint": INK_TINT, &"erode": 2.0})
	for i in 9:
		var a := TAU * i / 9.0 + randf_range(-0.25, 0.25)
		var p := Vector3(at.x, g, at.z) + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.8, 1.5)
		p.y = fx._ground_y(p + Vector3.UP * 2.0)
		fx._spawn_flower(p, randf_range(0.4, 0.62), randf_range(4.0, 6.0))
	for i in 18:
		var a := randf() * TAU
		fx._spawn_petal(at + Vector3(cos(a), randf_range(0.0, 0.6), sin(a)) * 0.5, Vector3(cos(a), 0.0, sin(a)) * randf_range(0.8, 1.8) + Vector3.UP * randf_range(1.5, 3.0),
			randf_range(2.0, 3.0), g + 0.04)
	for i in 6:
		fx._glow.spawn(at + Vector3(randf_range(-0.5, 0.5), randf_range(-0.3, 0.6), randf_range(-0.5, 0.5)), Vector3.UP * randf_range(0.6, 1.2),
			Vector2.ONE * randf_range(0.18, 0.3), randf_range(0.8, 1.2), 3, {&"delay": randf() * 0.4, &"rot": randf(), &"erode": 0.5, &"tint": Palette.GOLD})


## A bead being awarded: sparks of the bead's colour spiral in to a point, which swells into a
## ringed bead and pops into petals.
func bead_award(at: Vector3, color: Color = Palette.GOLD) -> void:
	_log(&"bead_award")
	var c := Color(color, 1.0)
	for i in 16:
		var a := TAU * i / 16.0
		var p := at + Vector3(cos(a), randf_range(-0.4, 0.9), sin(a)) * 1.7
		var life := 0.5
		fx._glow.spawn(p, (at - p) / life, Vector2.ONE * randf_range(0.2, 0.28), life, 3, {&"delay": STEP * (i % 4), &"rot": a, &"erode": 0.8, &"tint": c})
	fx._glow.spawn(at, Vector3.ZERO, Vector2.ONE * 0.9, 1.0, 2, {&"delay": 0.45, &"grow": 0.17, &"erode": 0.6, &"tint": c})
	fx._glow.spawn(at, Vector3.ZERO, Vector2.ONE * 0.55, 0.9, 0, {&"delay": 0.5, &"grow": 0.08, &"erode": 0.6, &"tint": c})
	fx._glow.spawn(at, Vector3.ZERO, Vector2.ONE * 1.4, 0.35, 1, {&"delay": 0.5, &"rot": randf() * TAU, &"erode": 0.3, &"tint": c})
	var g: float = fx._ground_y(at)
	for i in 14:
		var a := randf() * TAU
		fx._petals.spawn(at, Vector3(cos(a) * randf_range(1.5, 3.0), randf_range(2.0, 3.5), sin(a) * randf_range(1.5, 3.0)),
			Vector2.ONE * randf_range(0.17, 0.24), randf_range(1.8, 2.6), randi() % 8,
			{&"gravity": 3.2, &"drag": 1.4, &"flutter": randf_range(0.06, 0.12), &"spin": randf_range(-7.0, 7.0), &"rot": randf() * TAU,
			&"ground": g + 0.04, &"erode": 0.75, &"shrink": 0.7, &"delay": 0.55})


## Something picked up: a small ring pops, sparks fly out and a curl lifts away.
func pickup(at: Vector3, color: Color = Palette.GOLD) -> void:
	_log(&"pickup")
	var c := Color(color, 1.0)
	fx._glow.spawn(at, Vector3.ZERO, Vector2.ONE * 0.95, 0.3, 1, {&"grow": 0.08, &"rot": randf() * TAU, &"erode": 0.3, &"tint": c})
	fx._glow.spawn(at, Vector3.ZERO, Vector2.ONE * 0.6, 0.3, 2, {&"grow": 0.08, &"erode": 0.3, &"tint": c})
	for i in 7:
		var a := TAU * i / 7.0
		fx._glow.spawn(at, Vector3(cos(a) * 2.2, randf_range(0.8, 2.0), sin(a) * 2.2), Vector2.ONE * 0.15, 0.5, 3,
			{&"drag": 2.5, &"rot": a, &"erode": 0.5, &"tint": c})
	fx._strokes.spawn(at, Vector3.UP * 2.0, Vector2(0.7, 0.35), 0.5, 4 + randi() % 4, {&"draw": 0.2, &"tail": 0.28, &"drag": 2.0, &"mirror": randf() < 0.5, &"erode": 2.0})


## Cursed ground throwing Orimi back: black ink spits up where she stepped, with a curse-red
## flare and a puff of soot, and a splat soaks into the ground.
func cursed_throwback(at: Vector3) -> void:
	_log(&"cursed_throwback")
	var g: float = fx._ground_y(at + Vector3.UP * 0.5)
	var base := Vector3(at.x, g, at.z)
	fx._glow.spawn(base + Vector3.UP * 0.4, Vector3.ZERO, Vector2.ONE * 1.4, 0.3, 1, {&"rot": randf() * TAU, &"erode": 0.3, &"tint": Palette.CURSE_RED})
	fx._ink_ground.spawn(base + Vector3.UP * 0.03, Vector3.ZERO, Vector2.ONE * randf_range(1.1, 1.4), 2.2, randi() % 4, {&"rot": randf() * TAU, &"grow": 0.17, &"erode": 0.4})
	for i in 12:
		var a := randf() * TAU
		fx._ink_air.spawn(base + Vector3.UP * 0.2, Vector3(cos(a) * randf_range(0.8, 2.2), randf_range(3.5, 5.5), sin(a) * randf_range(0.8, 2.2)),
			Vector2(0.24, 0.14) * randf_range(0.8, 1.3), randf_range(0.8, 1.0), 6, {&"gravity": 13.0, &"ground": g + 0.03, &"erode": 0.55})
	for i in 3:
		var a := randf() * TAU
		fx._ink_air.spawn(base + Vector3.UP * 0.3, Vector3(cos(a) * 1.5, 4.5, sin(a) * 1.5), Vector2(0.7, 0.18), 0.45, 4 + i % 2,
			{&"gravity": 10.0, &"ground": g + 0.03, &"erode": 0.4, &"drag": 1.5})
	for i in 6:
		var a := randf() * TAU
		fx._soot.spawn(base + Vector3(cos(a) * 0.3, 0.3, sin(a) * 0.3), Vector3(cos(a), randf_range(1.0, 2.0), sin(a)) * randf_range(0.8, 1.4),
			Vector2.ONE * randf_range(0.4, 0.7), randf_range(0.8, 1.1), randi() % 8, {&"drag": 1.2, &"rot": randf() * TAU, &"erode": 0.2, &"delay": STEP * (i % 2)})


## Deep water throwing Orimi back: a white crown of brush spray and broken ripple rings
## spreading on the surface. at is on the water surface.
func water_throwback(at: Vector3) -> void:
	_log(&"water_throwback")
	for i in 10:
		var a := TAU * i / 10.0 + randf_range(-0.2, 0.2)
		var out := Vector3(cos(a), 0.0, sin(a))
		fx._strokes.spawn(at + out * 0.3 + Vector3.UP * 0.1, out * randf_range(1.2, 2.2) + Vector3.UP * randf_range(3.5, 5.0), Vector2(0.8, 0.4) * randf_range(0.8, 1.15),
			0.75, 4 + randi() % 4, {&"gravity": 9.0, &"draw": 0.2, &"tail": 0.4, &"mirror": i % 2 == 0, &"ground": at.y, &"erode": 2.0})
	for i in 10:
		var a := randf() * TAU
		fx._glow.spawn(at + Vector3(cos(a), 0.3, sin(a)) * 0.3, Vector3(cos(a) * randf_range(0.8, 1.8), randf_range(2.5, 4.0), sin(a) * randf_range(0.8, 1.8)),
			Vector2.ONE * randf_range(0.14, 0.24), 0.7, 2, {&"gravity": 8.0, &"ground": at.y, &"erode": 0.6, &"tint": Color.WHITE})
	for ring in 3:
		var n := 6 + ring * 3
		var r := 0.6 + ring * 0.7
		for i in n:
			var a := TAU * (i + 0.5 * ring) / n
			var out := Vector3(cos(a), 0.0, sin(a))
			fx._ripples.spawn(at + out * r + Vector3.UP * 0.04, out * (1.2 + ring * 0.4), Vector2(1.5 + ring * 0.4, 0.75 + ring * 0.2), 1.0, randi() % 16,
				{&"rot": a + PI * 0.5, &"grow": 0.25, &"draw": 0.25, &"tail": 0.55, &"drag": 2.0, &"delay": STEP * ring * 2})


## A wake behind a moving node (the raft): ripple arcs peel off both sides of it on the water
## and spread, with a little spray at the bow. Follows node until it is freed or detach_wake().
func attach_wake(node: Node3D, water_y: float = NAN) -> void:
	if not is_instance_valid(node):
		return
	detach_wake(node)
	_log(&"raft_wake")
	_tracks.append({"kind": &"wake", "node": node, "water_y": water_y, "age": 0.0, "last": node.global_position})


func detach_wake(node: Node3D) -> void:
	for i in range(_tracks.size() - 1, -1, -1):
		if _tracks[i]["kind"] == &"wake" and _tracks[i]["node"] == node:
			_tracks.remove_at(i)


## Lays a rope at p for warm_up() (the rope material compiles with the other effects).
func warm(p: Vector3) -> void:
	var pts := PackedVector3Array([p + Vector3(-1, 1, 0), p + Vector3(0, 0.8, 0), p + Vector3(1, 1, 0)])
	var u := PackedFloat32Array([0.0, 0.5, 1.0])
	_ropes[0].build(pts, PackedFloat32Array([0.05, 0.05, 0.05]), u, u, 0.0, 1.0, 0.0)


func end_warm() -> void:
	if not _ropes[0].playing:
		_ropes[0].visible = false


## Stops the one-shot effects (ropes, unravelling); knots and wakes keep following their nodes.
func clear() -> void:
	for i in range(_tracks.size() - 1, -1, -1):
		if _tracks[i]["kind"] == &"rope" or _tracks[i]["kind"] == &"unravel":
			_tracks.remove_at(i)
	for r in _ropes:
		r.playing = false
		r.visible = false


# --- stepping -------------------------------------------------------------------------------

func step() -> void:
	_steps += 1
	if _steps % SCAN_STEPS == 1:
		_scan()
	for i in range(_tracks.size() - 1, -1, -1):
		var t: Dictionary = _tracks[i]
		t["age"] = float(t["age"]) + STEP
		var keep := true
		match t["kind"]:
			&"rope":
				keep = _step_rope(t)
			&"unravel":
				keep = _step_unravel(t)
			&"knot":
				keep = _step_knot(t)
			&"wake":
				keep = _step_wake(t)
		if not keep:
			_tracks.remove_at(i)


func _step_rope(t: Dictionary) -> bool:
	var r: VfxRibbon = t["ribbon"]
	var age: float = t["age"]
	var a: Vector3 = t["a"]
	var b: Vector3 = t["b"]
	var sag: float = t["sag"]
	const DRAW := 0.34
	var deep := sag * 2.2 + 0.35
	var head := clampf(age / DRAW, 0.0, 1.0)
	var s := deep
	var pull := int(round((age - DRAW) / STEP))
	if age > DRAW:
		var steps: Array[float] = [deep * 0.55 + sag * 0.45, sag * 0.55, sag * 1.25, sag * 0.9, sag]
		s = steps[mini(pull, steps.size() - 1)]
	if pull == 1:
		for p: Vector3 in [a, b]:
			fx._glow.spawn(p, Vector3.ZERO, Vector2.ONE * 0.6, 0.25, 1, {&"rot": randf() * TAU, &"erode": 0.3, &"tint": Palette.GOLD_PALE})
			for i in 4:
				var d := (b - a).normalized() * (1.0 if p == a else -1.0)
				fx._ink_air.spawn(p, -d * randf_range(1.0, 2.0) + Vector3(randf_range(-1, 1), randf_range(1.0, 2.5), randf_range(-1, 1)),
					Vector2(0.16, 0.1), 0.6, 6, {&"gravity": 12.0, &"ground": fx._ground_y(p) + 0.03, &"erode": 0.5})
		var mid := a.lerp(b, 0.5) + Vector3.DOWN * sag
		for i in 5:
			fx._ink_air.spawn(mid + (b - a) * randf_range(-0.3, 0.3), Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 1.0), randf_range(-0.5, 0.5)),
				Vector2(0.14, 0.09), 0.7, 6, {&"gravity": 12.0, &"ground": fx._ground_y(mid) + 0.03, &"erode": 0.5})
	var erode := clampf((age - 1.2) / 0.5, 0.0, 1.0)
	if erode >= 1.0:
		r.playing = false
		r.visible = false
		return false
	var n := 20
	var pts := PackedVector3Array()
	var widths := PackedFloat32Array()
	var us := PackedFloat32Array()
	for i in n:
		var u := float(i) / (n - 1)
		pts.append(a.lerp(b, u) + Vector3.DOWN * sin(u * PI) * s)
		widths.append(0.055 * (0.75 + 0.35 * sin(u * PI)))
		us.append(u)
	r.build(pts, widths, us, us, erode, head, 0.0)
	return true


func _step_unravel(t: Dictionary) -> bool:
	var node: Node3D = t["node"] if is_instance_valid(t["node"]) else null
	var age: float = t["age"]
	if age > float(t["life"]) or (t["follow"] and node == null):
		return false
	var p: Vector3 = (node.global_position + Vector3.UP * 0.5) if node != null else t["at"]
	var k := age / float(t["life"])
	for i in (3 if k > 0.6 else 2):
		var out := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1)).normalized()
		fx._strokes.spawn(p + out * 0.3, out * randf_range(1.0, 1.8) + Vector3.UP * randf_range(1.2, 2.2), Vector2(1.0, 0.5) * randf_range(0.85, 1.15),
			0.75, randi() % 8, {&"draw": 0.2, &"tail": 0.3, &"drag": 1.5, &"mirror": randf() < 0.5, &"tint": INK_TINT, &"erode": 2.0})
	var n := int(round(age / STEP))
	if n % 2 == 0:
		fx._ink_air.spawn(p + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3)), Vector3(0.0, -0.5, 0.0), Vector2(0.22, 0.13), 0.6, 6,
			{&"gravity": 10.0, &"ground": fx._ground_y(p) + 0.03, &"erode": 0.5})
	if n % 3 == 0:
		fx._soot.spawn(p + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.4), randf_range(-0.3, 0.3)), Vector3.UP * randf_range(0.5, 1.0),
			Vector2.ONE * randf_range(0.25, 0.4), 0.8, randi() % 8, {&"drag": 0.8, &"rot": randf() * TAU, &"erode": 0.2})
	return true


func _step_knot(t: Dictionary) -> bool:
	var node: Node3D = t["node"] if is_instance_valid(t["node"]) else null
	if node == null or float(t["age"]) > float(t["life"]):
		return false
	var fight: Node = t["fight"] if is_instance_valid(t["fight"]) else null
	if not node.is_visible_in_tree() or (fight != null and (fight.get(&"started") or fight.get(&"done"))):
		t["last"] = node.global_position
		t["trailing"] = false
		return fight != null and not fight.get(&"done")
	if not t.get("trailing", false):
		t["trailing"] = true
		_log(&"knot_drift")
	var p := node.global_position
	var moved: Vector3 = (p - (t["last"] as Vector3)) / STEP
	t["last"] = p
	var n := int(round(float(t["age"]) / STEP))
	if true:
		var out := Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)).normalized()
		fx._strokes.spawn(p + out * 0.3, -moved * 0.4 + out * 0.6 + Vector3.UP * 0.3, Vector2(0.8, 0.4), 0.75, 4 + randi() % 4,
			{&"draw": 0.25, &"tail": 0.35, &"drag": 1.2, &"mirror": randf() < 0.5, &"tint": INK_TINT, &"erode": 2.0})
	if n % 4 == 1:
		fx._soot.spawn(p + Vector3(randf_range(-0.2, 0.2), -0.2, randf_range(-0.2, 0.2)), -moved * 0.3 + Vector3.UP * 0.35, Vector2.ONE * randf_range(0.22, 0.35),
			1.0, randi() % 8, {&"drag": 0.6, &"spin": randf_range(-1.5, 1.5), &"rot": randf() * TAU, &"erode": 0.2})
	return true


func _step_wake(t: Dictionary) -> bool:
	var node: Node3D = t["node"] if is_instance_valid(t["node"]) else null
	if node == null or not node.is_inside_tree():
		return false
	var p := node.global_position
	var moved: Vector3 = p - (t["last"] as Vector3)
	moved.y = 0.0
	t["last"] = p
	if moved.length() < 0.01:
		return true
	var dir := moved.normalized()
	var side := dir.cross(Vector3.UP)
	var y: float = t["water_y"] if not is_nan(float(t["water_y"])) else p.y
	var n := int(round(float(t["age"]) / STEP))
	var speed := moved.length() / STEP
	if n % 2 == 0:
		for s: float in [-1.0, 1.0]:
			var q := Vector3(p.x, y + 0.04, p.z) - dir * 1.0 + side * s * 0.7
			var a := atan2(dir.z, dir.x) + s * 0.45
			fx._ripples.spawn(q, side * s * clampf(speed * 0.35, 0.3, 1.2), Vector2(1.3, 0.55), 1.5, randi() % 16,
				{&"rot": a, &"grow": 0.3, &"draw": 0.3, &"tail": 1.0, &"drag": 0.6, &"mirror": s > 0.0})
	if n % 3 == 0 and speed > 0.5:
		for s: float in [-1.0, 1.0]:
			fx._strokes.spawn(Vector3(p.x, y + 0.1, p.z) + dir * 1.1 + side * s * 0.4, side * s * 1.2 + Vector3.UP * 1.6, Vector2(0.5, 0.25), 0.4, 4 + randi() % 4,
				{&"gravity": 8.0, &"draw": 0.15, &"tail": 0.22, &"mirror": s > 0.0, &"ground": y, &"erode": 2.0})
	return true


# --- hooks ----------------------------------------------------------------------------------

func _scan() -> void:
	var tree := get_tree()
	for n: Node in tree.get_nodes_in_group(&"kindle_target"):
		if n.has_signal(&"kindled") and not n.has_meta(&"vfx_hooked"):
			n.set_meta(&"vfx_hooked", true)
			n.kindled.connect(func() -> void:
				if is_instance_valid(n) and not fx._warming:
					kindle_catch(n.call(&"glyph_anchor"), String(n.get(&"kind"))))
	for n: Node in tree.get_nodes_in_group(&"tie_post"):
		if n.has_signal(&"tied_up") and not n.has_meta(&"vfx_hooked"):
			n.set_meta(&"vfx_hooked", true)
			n.tied_up.connect(_on_tied.bind(n))
	for n: Node in tree.get_nodes_in_group(&"sealed_fight"):
		if n.has_signal(&"fight_started") and not n.has_meta(&"vfx_hooked"):
			n.set_meta(&"vfx_hooked", true)
			n.fight_started.connect(func() -> void:
				if not is_instance_valid(n):
					return
				var c: Vector3 = (n as Node3D).global_position
				knot_burst(n.call(&"knot_position") if n.has_method(&"knot_position") else c + Vector3.UP)
				fight_ring_rise(c, float(n.get(&"radius"))))
			n.fight_won.connect(func() -> void:
				if is_instance_valid(n):
					fight_ring_fall((n as Node3D).global_position, float(n.get(&"radius"))))
			var knot := n.get(&"knot") as Node3D
			if knot != null:
				_tracks.append({"kind": &"knot", "node": knot, "fight": n, "age": 0.0, "life": 1.0e9, "last": knot.global_position})


	for n: Node in tree.get_nodes_in_group(&"verse_stone"):
		if n.has_signal(&"woken") and not n.has_meta(&"vfx_hooked"):
			n.set_meta(&"vfx_hooked", true)
			n.woken.connect(func() -> void:
				if is_instance_valid(n):
					verse_wake(n.call(&"glyph_anchor")))
	for n: Node in tree.get_nodes_in_group(&"enemy"):
		if n.has_signal(&"unravel_started") and not n.has_meta(&"vfx_hooked"):
			n.set_meta(&"vfx_hooked", true)
			n.unravel_started.connect(func(duration: float) -> void:
				if is_instance_valid(n):
					unravel(n as Node3D, (n as Node3D).global_position, duration))


func _on_tied(other: Node, post: Node) -> void:
	if not is_instance_valid(post) or not is_instance_valid(other):
		return
	var key := "%d_%d" % [mini(post.get_instance_id(), other.get_instance_id()), maxi(post.get_instance_id(), other.get_instance_id())]
	if fx.time - float(_ties.get(key, -10.0)) < 0.5:
		return
	_ties[key] = fx.time
	var partner: NodePath = post.get(&"partner")
	var owner_post: Node = post if not partner.is_empty() else other
	tie_rope(post.call(&"glyph_anchor"), other.call(&"glyph_anchor"), float(owner_post.get(&"sag")))


func _log(effect: StringName) -> void:
	if fx._warming:
		return
	print("VFX_FX %s" % effect)
	if Boot.opt("vfx_stage_shots", "0") == "1" and not _shot.has(effect):
		_shot[effect] = true
		_stage_shot.call_deferred(effect)


## Boot option vfx_gloom=<0..1> (captures): the valley-wide gloom is set to it when a level loads.
## Boot option vfx_stage_shots=1: the first time each effect plays, a QA "stage" line at its peak,
## so tools/game/web_autoplay.sh screenshots it from the gameplay camera.
func _stage_shot(effect: StringName) -> void:
	await get_tree().create_timer(float(PEAKS.get(effect, 0.25)), false).timeout
	var game := get_node_or_null(^"/root/Game")
	if game != null:
		game.qa_log("stage", {"stage": "vfx_" + String(effect)})
