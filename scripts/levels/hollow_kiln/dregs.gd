extends EnemyBase
## The Dregs, the Hollow Kiln's boss (docs/levels/hollow_kiln/DESIGN.md, "The Dregs"): what stayed
## at the bottom of the Ink-maker's vat. It sits on the vat's rim and never leaves it. Four parts,
## one glyph each:
##   veil   Gust twice within regrow_s to blow the soot off; it spits soot and two Splotchets crawl out
##   lash   it lashes along the floor with its front arms; Slash an arm while it lies there to cut it
##   climb  it hauls itself up the chains; the Tie between the pillar rings (flag dregs_bound) binds it
##   dry    bound, it dries one step per kiln mouth kindled; at three it unravels (flag dregs_unravelled)
## Every attack shows its mark on the floor first. A hit costs one petal. When Orimi falls, the
## current part starts again; nothing already done is undone. Numbers: kiln_layout.json "dregs".
## Scene: scenes/levels/hollow_kiln/dregs_enemy.tscn, spawned by Zone_vat/DregsSpawn. Owner: l5 (hollow_kiln).

enum { WAITING, VEIL, LASH, CLIMB, BOUND, DONE }

const LAYOUT := "res://scripts/levels/hollow_kiln/kiln_layout.json"
const MODEL := "res://scenes/levels/hollow_kiln/models/dregs.tscn"
const LASH_CLIPS: Array[StringName] = [&"lash_l", &"lash_r"]
const LASH_FRAMES := {"windup": 10, "slam": 12, "lie_end": 31}
const MARK_COLOR := Color(0.08, 0.07, 0.09, 0.55)

var part := WAITING
var veil: Dictionary
var lash: Dictionary
var climb: Dictionary
var dry: Dictionary
var crown_y := 36.0
var rim_y := 22.5

var _gusts := 0
var _first_gust := 0.0
var _spit_t := 0.0
var _add_t := 0.0
var _adds: Array[EnemyBase] = []
var _arm := 0
var _cut: Array[bool] = [false, false]
var _lash_t := 0.0
var _lash_dir := Vector3.FORWARD
var _lashing := false
var _slammed := false
var _marks: Array[Node3D] = []
var _arm_yaw: Array[float] = [0.0, 0.0]
var _drip_t := 0.0
var _falling := false
var _slap_t := 0.0
var _dry_frames := 0
var _hinted: Dictionary = {}
var _part_time := 0.0
var _now := 0.0


func _init() -> void:
	kind = &"dregs"
	max_hp = 4.0
	hp = 4.0
	aggro_range = 0.0


func _build_placeholder() -> Node3D:
	return (load(MODEL) as PackedScene).instantiate() as Node3D


func _collision_size() -> Vector2:
	return Vector2(2.4, 5.0)


func _ready() -> void:
	super._ready()
	name = "Dregs"
	model.set_meta(&"placeholder", false)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT)) if FileAccess.file_exists(LAYOUT) else null
	var parts: Array = (data as Dictionary).get("dregs", {}).get("parts", []) if data is Dictionary else []
	if parts.size() < 4:
		push_error("Dregs: no parts in %s" % LAYOUT)
		parts = [{}, {}, {}, {}]
	veil = parts[0]
	lash = parts[1]
	climb = parts[2]
	dry = parts[3]
	crown_y = float(climb.get("climb_top", crown_y))
	animator.play(&"veiled")
	Events.player_died.connect(_on_player_died)
	if Game.level != null:
		Game.level.flag_changed.connect(_on_flag)
	_measure_arms.call_deferred()


## Where each front arm lies after a lash, as a yaw from the body's facing, so a lash can be aimed.
func _measure_arms() -> void:
	var ap := animator.player
	for a in 2:
		ap.play(LASH_CLIPS[a])
		ap.seek(20 * SteppedAnimator.STEP, true)
		var tip := model.find_child("Arm%d_5" % a, true, false) as Node3D
		if tip != null:
			var d := tip.global_position - visual.global_position
			d.y = 0.0
			_arm_yaw[a] = wrapf(atan2(-d.x, -d.z) - visual.global_rotation.y, -PI, PI)
	animator.play(&"veiled", true)


func glyph_anchor() -> Vector3:
	if part == LASH and _lashing and _in_window():
		var mid := model.find_child("Arm%d_3" % _arm, true, false) as Node3D
		if mid != null:
			return mid.global_position
	return visual.global_position + Vector3.UP * 2.6


func glyph_radius() -> float:
	return 1.8 if part == LASH and _lashing and _in_window() else 2.2


func _can_be_hurt(_source: StringName) -> bool:
	return false


func _on_blocked(_source: StringName) -> void:
	if look != null:
		look.flash(Palette.STONE, 0.1)


func _on_glyph(glyph: StringName, _info: Dictionary) -> bool:
	match [part, glyph]:
		[VEIL, &"gust"]:
			if _gusts == 0 or _now - _first_gust > float(veil.get("regrow_s", 6.0)):
				_gusts = 0
				_first_gust = _now
			_gusts += 1
			if look != null:
				look.flash(Palette.STONE, 0.15)
			Game.qa_log("dregs_gust", {"gusts": _gusts})
			if _gusts >= int(veil.get("gusts", 2)):
				_set_flag(&"dregs_veil_thin", false)
				_unveil()
			else:
				_set_flag(&"dregs_veil_thin", true)
			return true
		[LASH, &"slash"]:
			if _lashing and _in_window() and not _cut[_arm]:
				_cut_arm(_arm)
				return true
			_on_blocked(&"slash")
			return false
	_on_blocked(glyph)
	return false


func _on_flag(flag: StringName, on: bool) -> void:
	if not on:
		return
	if flag == &"dregs_started" and part == WAITING:
		_begin(_resume_part())
	elif flag == &"dregs_bound" and part == CLIMB:
		_begin(BOUND)
	elif String(flag).begins_with("mouth_") and part == BOUND:
		_dry_step()


func _on_player_died() -> void:
	_clear_marks()
	match part:
		VEIL:
			_gusts = 0
			_set_flag(&"dregs_veil_thin", false)
		CLIMB:
			_falling = true


func _begin(p: int) -> void:
	part = p
	_part_time = 0.0
	Game.qa_log("dregs_part", {"part": ["waiting", "veil", "lash", "climb", "bound", "done"][p]})
	match p:
		VEIL:
			animator.play(&"veiled", true)
			_spit_t = 2.0
			_add_t = 6.0
		LASH:
			_lash_t = 1.0
			animator.play(&"idle", true)
		CLIMB:
			_falling = false
			_drip_t = 1.0
			animator.play(&"climb", true)
		BOUND:
			_falling = true
			_slap_t = 2.0
			animator.play(&"bound", true)
			for f: String in ["mouth_nw_lit", "mouth_n_lit", "mouth_ne_lit"]:
				if Game.level != null and Game.level.get_flag(StringName(f)):
					_dry_step()


func _think(delta: float) -> void:
	_now += delta
	_part_time += delta
	velocity.x = 0.0
	velocity.z = 0.0
	var p := player_target()
	if p != null and not _in_chamber(p.global_position):
		p = null
	if p != null and (part == VEIL or part == BOUND or (part == LASH and not _lashing)):
		face(flat_to(p.global_position), delta, 2.0)
	match part:
		VEIL:
			_think_veil(delta, p)
		LASH:
			_think_lash(delta, p)
		CLIMB:
			_think_climb(delta, p)
		BOUND:
			_think_bound(delta, p)


func _think_veil(delta: float, p: Node3D) -> void:
	_hint_after(&"dregs_hint_veil", 25.0)
	if _gusts > 0 and _now - _first_gust > float(veil.get("regrow_s", 6.0)):
		_gusts = 0
		_set_flag(&"dregs_veil_thin", false)
	if p == null:
		return
	_spit_t -= delta
	if _spit_t <= 0.0 and p != null:
		_spit_t = float(veil.get("spit_every_s", 3.0))
		_strike_circle(p.global_position, float(veil.get("spit_radius", 1.6)), float(veil.get("spit_tell_s", 0.8)))
	_add_t -= delta
	_adds = _adds.filter(func(e: EnemyBase) -> bool: return is_instance_valid(e) and not e.is_defeated())
	if _add_t <= 0.0:
		_add_t = float(veil.get("adds_every_s", 10.0))
		if _adds.size() < int(veil.get("adds_max", 2)):
			_spawn_add()


func _think_lash(delta: float, p: Node3D) -> void:
	_hint_after(&"dregs_hint_arms", 25.0)
	_set_flag(&"dregs_arm_down", _lashing and _in_window() and not _cut[_arm])
	if _lashing:
		if animator.frame >= LASH_FRAMES["slam"] and not _slammed and p != null:
			_slammed = true
			if _in_lane(p.global_position):
				p.call(&"take_damage", 1, visual.global_position)
		if animator.is_done():
			_lashing = false
			_lash_t = float(lash.get("rest_s", 1.2))
			animator.play(&"idle", true)
			_arm = 1 - _arm
		return
	_lash_t -= delta
	if _lash_t > 0.0 or p == null:
		return
	if _cut[_arm]:
		if _cut[1 - _arm]:
			return
		_arm = 1 - _arm
	# turn so the chosen arm comes down on Orimi's line, and mark the lane
	var to := flat_to(p.global_position)
	var want := atan2(-to.x, -to.z) - _arm_yaw[_arm]
	_facing = want
	rotation.y = want
	_lash_dir = to.normalized() if to.length() > 0.1 else -global_basis.z
	_lashing = true
	_slammed = false
	animator.play(LASH_CLIPS[_arm], true)
	_mark_lane(float(LASH_FRAMES["slam"]) * SteppedAnimator.STEP)


func _in_window() -> bool:
	return animator.frame >= LASH_FRAMES["slam"] and animator.frame < LASH_FRAMES["lie_end"]


func _in_lane(at: Vector3) -> bool:
	var from := Vector2(global_position.x, global_position.z)
	var dir := Vector2(_lash_dir.x, _lash_dir.z)
	var q := Vector2(at.x, at.z) - from
	var along := q.dot(dir)
	var across := absf(q.dot(Vector2(-dir.y, dir.x)))
	return along > 0.0 and along < float(lash.get("lane_len", 9.5)) + 1.5 and across < float(lash.get("lane_w", 1.6)) * 0.5 + 0.4


## The part to wake in: the veil, or a later part when its flags are already set (the QA starts
## hk_start=dregs_lash, dregs_climb, dregs_bound in level.json "qa_starts").
func _resume_part() -> int:
	var lv := Game.level
	if lv == null or not lv.get_flag(&"dregs_veil_off"):
		return VEIL
	if not lv.get_flag(&"dregs_arms_cut"):
		return LASH
	for a in 2:
		_hide_arm(a)
		hp -= 1.0
	return BOUND if lv.get_flag(&"dregs_bound") else CLIMB


func _hide_arm(a: int) -> void:
	_cut[a] = true
	for k in range(2, 6):
		var seg := model.find_child("Arm%d_%d" % [a, k], true, false) as Node3D
		if seg != null:
			seg.visible = false


func _cut_arm(a: int) -> void:
	_hide_arm(a)
	Vfx.hit_spark(glyph_anchor())
	Events.enemy_hit.emit(self, 1.0, glyph_anchor())
	hp -= 1.0
	Game.qa_log("dregs_arm_cut", {"arm": a})
	_set_flag(&"dregs_arm_down", false)
	_set_flag(&"dregs_cut_one", true)
	_lashing = false
	_lash_t = float(lash.get("rest_s", 1.2))
	animator.play(&"hurt", true)
	if _cut[0] and _cut[1]:
		if Game.level != null:
			Game.level.set_flag(&"dregs_arms_cut")
		_begin(CLIMB)


func _think_climb(delta: float, p: Node3D) -> void:
	if _falling:
		if is_on_floor():
			_falling = false
			_hint_once(&"dregs_hint_chains")
			_wave()
			animator.play(&"climb", true)
		return
	velocity.y = float(climb.get("climb_speed", 1.0))
	if global_position.y >= crown_y:
		velocity.y = 0.0
		_falling = true
		animator.play(&"hurt", true)
	_drip_t -= delta
	if _drip_t <= 0.0 and p != null:
		_drip_t = float(climb.get("drip_every_s", 1.5))
		_strike_circle(p.global_position, float(climb.get("drip_radius", 1.2)), float(climb.get("drip_tell_s", 0.7)))


func _think_bound(delta: float, p: Node3D) -> void:
	if _dry_frames > 0 and animator.current == &"dry" and animator.frame >= _dry_frames - 1 and _dry_frames < animator.frame_count():
		animator.speed = 0.0
	if _dry_frames >= animator.frame_count() and animator.current == &"dry" and animator.is_done():
		_finish()
		return
	_slap_t -= delta
	if _slap_t <= 0.0 and p != null:
		_slap_t = float(dry.get("slap_every_s", 4.0))
		var mouth := _nearest_mouth(p.global_position)
		if mouth != Vector3.INF:
			var front := mouth.lerp(global_position, 0.25)
			_strike_circle(front, float(dry.get("slap_radius", 2.2)), float(dry.get("slap_tell_s", 0.8)))


func _dry_step() -> void:
	if part != BOUND:
		return
	var per := roundi(float(dry.get("dry_seek_per_mouth", 1.0)) / SteppedAnimator.STEP)
	if animator.current != &"dry":
		animator.play(&"dry", true)
	_dry_frames = mini(_dry_frames + per, animator.frame_count())
	animator.speed = 1.0
	hp = maxf(hp - 0.5, 0.5)
	Game.qa_log("dregs_dry", {"frames": _dry_frames})


func _finish() -> void:
	part = DONE
	animator.speed = 1.0
	animator.play(&"unravel", true)
	if Game.level != null:
		Game.level.set_flag(&"dregs_unravelled")
	Game.qa_log("dregs_unravelled", {})
	_clear_marks()
	await get_tree().create_timer(1.5, false).timeout
	hp = 0.0
	_unravel()


## The ring of floor round the vat (drum radius 14), where its attacks reach.
func _in_chamber(at: Vector3) -> bool:
	return Vector2(at.x - global_position.x, at.z - global_position.z).length() < 14.5 and absf(at.y - (rim_y - 4.5)) < 4.0


## Level flags the autoplay route reads: the veil thinned by one Gust, an arm lying in its window.
func _set_flag(flag: StringName, on: bool) -> void:
	if Game.level != null and Game.level.get_flag(flag) != on:
		Game.level.set_flag(flag, on)


func _nearest_mouth(from: Vector3) -> Vector3:
	var best := Vector3.INF
	if Game.level == null:
		return best
	for m: String in ["M_Mouth_NW", "M_Mouth_N", "M_Mouth_NE"]:
		var at := Game.level.marker(m)
		if best == Vector3.INF or at.distance_to(from) < best.distance_to(from):
			best = at
	return best


func _spawn_add() -> void:
	var a := randf() * TAU
	var at := Vector3(global_position.x + sin(a) * 6.5, global_position.y, global_position.z + cos(a) * 6.5)
	var e := EnemySpawn.make(&"splotchet")
	e.name = "DregsAdd%d" % Time.get_ticks_msec()
	get_parent().add_child(e)
	var ground := Game.level.ground_at(at) if Game.level != null else at
	e.global_position = ground + Vector3.UP * 0.1
	e.home = ground
	e.aggro = true
	if zone != null and zone.has_method(&"add_enemy"):
		zone.call(&"add_enemy", e)
	_adds.append(e)


# --- telegraphed strikes ------------------------------------------------------------------


## A dark wash on the floor for tell seconds, then a hit on Orimi if she still stands in it.
func _strike_circle(center: Vector3, radius: float, tell: float) -> void:
	var at := Game.level.ground_at(center) if Game.level != null else center
	var mark := _mark_mesh(CylinderMesh.new())
	(mark.mesh as CylinderMesh).top_radius = radius
	(mark.mesh as CylinderMesh).bottom_radius = radius
	(mark.mesh as CylinderMesh).height = 0.04
	mark.global_position = at + Vector3.UP * 0.05
	await _grow(mark, tell)
	if not is_instance_valid(mark):
		return
	var p := player_target()
	if p != null and part != DONE and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < radius + 0.35 and absf(p.global_position.y - at.y) < 1.5:
		p.call(&"take_damage", 1, at)
	Vfx.hit_spark(at + Vector3.UP * 0.3)
	_drop(mark)


func _mark_lane(tell: float) -> void:
	var length := float(lash.get("lane_len", 9.5))
	var mark := _mark_mesh(BoxMesh.new())
	(mark.mesh as BoxMesh).size = Vector3(float(lash.get("lane_w", 1.6)), 0.04, length)
	var floor_y := Game.level.ground_at(global_position + _lash_dir * 7.0).y if Game.level != null else global_position.y
	mark.global_position = Vector3(global_position.x, floor_y + 0.05, global_position.z) + _lash_dir * (length * 0.5 + 1.5)
	mark.global_rotation = Vector3(0, atan2(_lash_dir.x, _lash_dir.z), 0)
	await _grow(mark, tell + 1.6)
	_drop(mark)


## The splash when it falls back into the vat: a ring rolls out across the floor; jump it.
func _wave() -> void:
	var floor_y := Game.level.ground_at(global_position + Vector3(0, 0, 7.0)).y if Game.level != null else global_position.y - 4.5
	var mark := _mark_mesh(TorusMesh.new())
	var torus := mark.mesh as TorusMesh
	mark.global_position = Vector3(global_position.x, floor_y + 0.1, global_position.z)
	var speed := float(climb.get("fall_wave_speed", 6.0))
	var r := 5.0
	var hit := false
	while r < 14.0 and is_instance_valid(mark):
		torus.inner_radius = r - 0.4
		torus.outer_radius = r
		var p := player_target()
		if p != null and not hit:
			var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
			if absf(d - r) < 0.5 and p.global_position.y - floor_y < float(climb.get("fall_wave_h", 0.5)):
				hit = true
				p.call(&"take_damage", 1, mark.global_position)
		await get_tree().create_timer(SteppedAnimator.STEP, false).timeout
		r += speed * SteppedAnimator.STEP
	_drop(mark)


func _mark_mesh(mesh: PrimitiveMesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = MARK_COLOR
	mesh.material = mat
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(Game.level if Game.level != null else get_parent()).add_child(mi)
	_marks.append(mi)
	return mi


## The mark darkens in 12 fps steps over the tell.
func _grow(mark: MeshInstance3D, tell: float) -> void:
	var steps := maxi(1, roundi(tell / SteppedAnimator.STEP))
	for i in steps:
		if not is_instance_valid(mark):
			return
		var k := float(i + 1) / steps
		((mark.mesh as PrimitiveMesh).material as StandardMaterial3D).albedo_color.a = 0.15 + 0.5 * k
		await get_tree().create_timer(SteppedAnimator.STEP, false).timeout


func _drop(mark: Node3D) -> void:
	_marks.erase(mark)
	if is_instance_valid(mark):
		mark.queue_free()


func _clear_marks() -> void:
	for m in _marks.duplicate():
		_drop(m)


# --- hints --------------------------------------------------------------------------------

func _hint_after(id: StringName, seconds: float) -> void:
	if _part_time > seconds:
		_hint_once(id)


func _hint_once(id: StringName) -> void:
	if _hinted.has(id) or Game.level == null or not Game.level.has_lines(String(id)):
		return
	_hinted[id] = true
	var lines: Array = Game.level.lines(String(id))
	var text := String((lines[0] as Dictionary).get("text", "")) if not lines.is_empty() and lines[0] is Dictionary else ""
	Game.qa_log("dregs_hint", {"id": String(id)})
	if text != "" and is_instance_valid(Game.main) and Game.main.has_method(&"prompt_near"):
		Game.main.call(&"prompt_near", id, text.replace("*", ""), &"")


func _unveil() -> void:
	animator.play(&"veil_off", true)
	if Game.level != null:
		Game.level.set_flag(&"dregs_veil_off")
	Events.enemy_unveiled.emit(self)
	part = WAITING
	await get_tree().create_timer(1.0, false).timeout
	_begin(LASH)
