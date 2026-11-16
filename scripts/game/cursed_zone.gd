class_name CursedZone
extends Node3D
## A cursed area with a withered sapling (or the great tree) at its heart. The Spill is drawn
## over its radius; enemies under it (EnemyBase or EnemySpawn children) guard it; Bloom on the
## sapling restores it once they are gone and its required flags are set. Restoring sets the
## flag "restored_<zone_id>" (or restored_flag), moves the checkpoint, heals Orimi and emits
## Events.zone_restore_started / zone_restored. EnemySpawn children with wave >= 1 are a final
## wave: pulse 1 rises when Orimi first steps inside, each next pulse when one enemy is left.
## Owner: gameplay.

signal cleared_enemies
signal restored

const RESTORE_TIME := 2.6

## Unique in the level; used for flags, events and the restored-zones list.
@export var zone_id: StringName = &"zone"
## Shown on the "colour restored" banner.
@export var display_name: String = ""
@export var radius: float = 12.0
## "sapling", "great_tree", or "none" (the level supplies its own BloomTarget child).
@export_enum("sapling", "great_tree", "none") var target_kind: String = "sapling"
## Where the sapling stands, relative to the zone's centre.
@export var target_offset: Vector3 = Vector3.ZERO
## Flags that must be set before Bloom is accepted (hint "not_ready" otherwise).
@export var requires_flags: PackedStringArray = PackedStringArray()
## Bloom hands over to Level.run_finale (the level's big ending) instead of restoring at once.
@export var finale: bool = false
## Set when restored. Empty: "restored_<zone_id>".
@export var restored_flag: StringName = &""
@export var checkpoint_on_restore: bool = true
## Show the red curse light over the zone.
@export var curse_light: bool = true

var enemies: Array[Node] = []
var target: BloomTarget
var player_inside := false
var is_cleared := false
var is_restored := false
var wave_index := -1
var light: OmniLight3D
## Assigned by CurseSlots (-1 while another area holds the slot).
var curse_slot := -1
var _waves: Array = []
var _restore_end := 0.0


func _ready() -> void:
	add_to_group(Layers.GROUP_CURSED_ZONE)
	if restored_flag == &"":
		restored_flag = StringName("restored_" + String(zone_id))
	if curse_light:
		light = OmniLight3D.new()
		light.light_color = Palette.CURSE_RED
		light.light_energy = 1.6
		light.omni_range = radius * 1.15
		light.omni_attenuation = 0.6
		light.position = Vector3(0, 5.0, 0)
		add_child(light)
	for c: Node in get_children():
		if c is BloomTarget and target == null:
			target = c
	if target == null and target_kind != "none":
		target = BloomTarget.new()
		target.name = "GreatTree" if target_kind == "great_tree" else "Sapling_" + String(zone_id)
		target.model_name = target_kind
		add_child(target)
		target.position = target_offset - Vector3.UP * (0.3 if target_kind == "great_tree" else 0.0)
	if target != null:
		target.zone = self
	# Ground the sapling and any enemies once the level's collision exists.
	_settle.call_deferred()
	CurseSlots.register(self)


func _settle() -> void:
	await get_tree().physics_frame
	if target != null and Game.level != null:
		target.global_position = Game.level.ground_at(target.global_position + Vector3.UP * 2.0, target) - Vector3.UP * (0.3 if target_kind == "great_tree" else 0.0)
	for c: Node in find_children("*", "", true, false):
		if c is EnemyBase:
			add_enemy(c)
		elif c is EnemySpawn:
			var s := c as EnemySpawn
			if s.wave <= 0:
				add_enemy(s.spawn(get_parent()))
			else:
				while _waves.size() < s.wave:
					_waves.append([])
				_waves[s.wave - 1].append(s)


func _exit_tree() -> void:
	CurseSlots.unregister(self)


func add_enemy(enemy: EnemyBase) -> void:
	if enemy == null or enemy in enemies:
		return
	enemy.zone = self
	enemies.append(enemy)


func living_enemies() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and not e.get(&"dying"):
			n += 1
	return n


func has_waves() -> bool:
	return not _waves.is_empty()


# --- CurseSlots ---------------------------------------------------------------------------

func curse_wants_slot() -> bool:
	return not is_restored or Time.get_ticks_msec() / 1000.0 < _restore_end


func curse_assigned(slot: int) -> void:
	var animating := is_restored and Time.get_ticks_msec() / 1000.0 < _restore_end
	CurseField.set_zone(slot, global_position, radius, 0.0 if is_restored and not animating else 1.0)
	if animating:
		CurseField.restore_zone(slot, maxf(_restore_end - Time.get_ticks_msec() / 1000.0, 0.1))


# --- play ---------------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	var p := Game.player
	if is_instance_valid(p) and Game.state != Game.STATE_TITLE:
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		var inside := d < radius if not player_inside else d < radius + 1.5
		if inside != player_inside:
			player_inside = inside
			if inside:
				Events.zone_entered.emit(zone_id)
			else:
				Events.zone_exited.emit(zone_id)
			Game.qa_log("zone_entered" if inside else "zone_exited", {"zone": String(zone_id)})
	if is_restored:
		return
	if not _waves.is_empty():
		_update_waves()
		return
	if not is_cleared and living_enemies() == 0:
		_mark_cleared()


func _mark_cleared() -> void:
	is_cleared = true
	Game.qa_log("zone_cleared", {"zone": String(zone_id)})
	cleared_enemies.emit()
	Game.hint(&"tree_bloom" if finale else &"bloom_ready")


func _update_waves() -> void:
	if wave_index < 0:
		# The final wave waits for the zone's required flags, so arriving early (Level 1's west
		# ramp onto the Rise) finds it quiet and the hint says what is missing.
		if player_inside and Game.is_playing() and (Game.level == null or Game.level.all_flags(Array(requires_flags))):
			_spawn_wave(0)
		return
	if living_enemies() <= (1 if wave_index + 1 < _waves.size() else 0):
		if wave_index + 1 < _waves.size():
			_spawn_wave(wave_index + 1)
		elif not is_cleared:
			_mark_cleared()


func _spawn_wave(index: int) -> void:
	wave_index = index
	Game.qa_log("wave", {"zone": String(zone_id), "wave": index + 1, "of": _waves.size()})
	if index == 0:
		Game.hint(&"final_wave")
	for s: EnemySpawn in _waves[index]:
		var e := s.spawn(get_parent(), true)
		add_enemy(e)
		Vfx.ink_splash(e.global_position, 1.2)


## Bloom landed on this zone's sapling or tree. Returns true if the restore starts.
func request_restore() -> bool:
	if is_restored:
		return false
	if Game.level != null and not Game.level.all_flags(Array(requires_flags)):
		Game.qa_log("bloom_refused", {"zone": String(zone_id), "needs": Array(requires_flags)})
		Game.hint(&"tree_saplings" if finale else &"not_ready")
		return false
	if not is_cleared:
		Game.qa_log("bloom_refused", {"zone": String(zone_id), "living": living_enemies(), "wave": wave_index})
		Game.hint(&"not_clear" if not finale or wave_index >= 0 else &"tree_wait")
		return false
	if finale and Game.level != null:
		Game.level.run_finale(self)
		return true
	restore()
	return true


func restore() -> void:
	if is_restored:
		return
	is_restored = true
	_restore_end = Time.get_ticks_msec() / 1000.0 + RESTORE_TIME
	Events.zone_restore_started.emit(zone_id, global_position, radius)
	if curse_slot >= 0:
		CurseField.restore_zone(curse_slot, RESTORE_TIME)
	if target != null:
		target.play_bloom()
	if light != null:
		create_tween().tween_property(light, "light_energy", 0.0, RESTORE_TIME)
	await get_tree().create_timer(RESTORE_TIME, false).timeout
	if not zone_id in Game.restored_zones:
		Game.restored_zones.append(zone_id)
	if checkpoint_on_restore:
		Game.checkpoint = checkpoint_point()
	Events.zone_restored.emit(zone_id)
	if Game.level != null:
		Game.level.set_flag(restored_flag)
	restored.emit()
	if is_instance_valid(Game.player) and Game.player.has_method("heal_full"):
		Game.player.heal_full()
	CurseSlots.refresh()


## A safe spot beside the sapling, on the side facing the level's spawn.
func checkpoint_point() -> Vector3:
	if Game.level == null:
		return global_position
	var toward := Game.level.spawn_point() - global_position
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.1 else Vector3.BACK
	var at := target.global_position if target != null else global_position
	return Game.level.ground_at(at + toward * 2.5)


## Restore at once with no events (warp, or a level loaded with the zone already done).
func restore_silently() -> void:
	is_restored = true
	is_cleared = true
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	_waves.clear()
	if curse_slot >= 0:
		CurseField.set_zone(curse_slot, global_position, radius, 0.0)
	if light != null:
		light.light_energy = 0.0
	if target != null:
		target.set_bloomed()
	if not zone_id in Game.restored_zones:
		Game.restored_zones.append(zone_id)
	if Game.level != null:
		Game.level.set_flag(restored_flag)
	CurseSlots.refresh()
