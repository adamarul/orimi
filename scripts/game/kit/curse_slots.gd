class_name CurseSlots
extends RefCounted
## Shares CurseField's four render slots among any number of cursed areas (CursedZone and
## CursedGround both register here). Every cursed area keeps its own state; the four nearest
## the player that are still cursed (or still animating back to colour) hold a slot and are
## drawn. A level with four or fewer areas never changes assignment. Owner: gameplay.

const SWAP_MARGIN := 6.0

static var areas: Array[Node3D] = []
static var _owners: Array = [null, null, null, null]


static func reset() -> void:
	areas.clear()
	_owners = [null, null, null, null]
	for slot in CurseField.MAX_ZONES:
		CurseField.clear_zone(slot)


static func register(area: Node3D) -> void:
	if area in areas:
		return
	areas.append(area)
	area.set(&"curse_slot", -1)
	refresh()


static func unregister(area: Node3D) -> void:
	areas.erase(area)
	var slot: int = area.get(&"curse_slot") if area.get(&"curse_slot") != null else -1
	if slot >= 0 and _owners[slot] == area:
		_owners[slot] = null
		CurseField.clear_zone(slot)
	refresh()


## Re-deal the slots. Cheap; the level calls it twice a second. An area that already holds a
## slot is favoured by SWAP_MARGIN metres, so slots do not flicker between two equal areas.
static func refresh() -> void:
	var p := Game.player.global_position if is_instance_valid(Game.player) and Game.player.is_inside_tree() else Vector3.ZERO
	var live: Array[Node3D] = []
	for a in areas:
		if is_instance_valid(a) and a.is_inside_tree() and bool(a.call(&"curse_wants_slot")):
			live.append(a)
	live.sort_custom(func(x: Node3D, y: Node3D) -> bool: return _score(x, p) < _score(y, p))
	var keep := live.slice(0, CurseField.MAX_ZONES)
	for slot in CurseField.MAX_ZONES:
		var owner: Variant = _owners[slot]
		if owner == null:
			continue
		if is_instance_valid(owner) and owner in keep:
			continue
		if is_instance_valid(owner):
			owner.set(&"curse_slot", -1)
		_owners[slot] = null
		CurseField.clear_zone(slot)
	for a: Node3D in keep:
		if a in _owners:
			continue
		var slot := _owners.find(null)
		if slot < 0:
			break
		_owners[slot] = a
		a.set(&"curse_slot", slot)
		a.call(&"curse_assigned", slot)


static func _score(a: Node3D, p: Vector3) -> float:
	var c := a.global_position
	var s := Vector2(c.x - p.x, c.z - p.z).length() - float(a.get(&"radius"))
	return s - (SWAP_MARGIN if a in _owners else 0.0)
