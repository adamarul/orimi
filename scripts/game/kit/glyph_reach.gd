class_name GlyphReach
## A glyph lands on a kit target unless a solid wall stands between the view and it: a bellows
## behind a wall, or a lamp in the next room, ignores a stroke drawn over where it would be. The
## line runs from the camera (or from Orimi) to the target's glyph anchor on the world layer, and
## only a solid wall counts: the target's own colliders and children, whatever the anchor sits
## inside, other glyph targets, props that fade for the camera ("camera_fade") or are skipped by
## the ink look ("ink_skip": foliage, water, soot, effects), and triggers are looked through, and a
## hit within the target's glyph radius plus TOLERANCE of the anchor is the target's own
## surroundings (soot packed in a wheel, a lamp in a niche). Owner: gameplay.

const TOLERANCE := 0.6
const MAX_LOOK_THROUGH := 8


## Whether the target can be reached; report logs a refusal as glyph_blocked.
static func clear(target: Node3D, report: bool = true) -> bool:
	if not target.is_inside_tree():
		return true
	var anchor: Vector3 = target.call(&"glyph_anchor") if target.has_method(&"glyph_anchor") else target.global_position + Vector3.UP * 0.8
	var near: float = TOLERANCE + (float(target.call(&"glyph_radius")) if target.has_method(&"glyph_radius") else 0.0)
	var space := target.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	for n in target.find_children("*", "CollisionObject3D", true, false):
		exclude.append((n as CollisionObject3D).get_rid())
	var inside := PhysicsPointQueryParameters3D.new()
	inside.position = anchor
	inside.collision_mask = Layers.WORLD
	for h in space.intersect_point(inside, 8):
		exclude.append(h["rid"])
	var froms: Array[Vector3] = []
	var cam := target.get_viewport().get_camera_3d()
	if cam != null:
		froms.append(cam.global_position)
	if is_instance_valid(Game.player):
		froms.append(Game.player.global_position + Vector3.UP * 0.8)
		exclude.append(Game.player.get_rid())
	var wall := {}
	for from in froms:
		wall = _wall(space, from, anchor, near, exclude.duplicate())
		if wall.is_empty():
			return true
	if wall.is_empty():
		return true
	if not report:
		return false
	Game.qa_log("glyph_blocked", {"target": String(target.name), "by": String((wall["collider"] as Node).name), "from_anchor": snappedf((wall["position"] as Vector3).distance_to(anchor), 0.01), "anchor": Game._v(anchor), "hit": Game._v(wall["position"]), "cam": Game._v(froms[0])})
	return false


## The first solid wall the line from "from" to the anchor meets, or {} when there is none.
static func _wall(space: PhysicsDirectSpaceState3D, from: Vector3, anchor: Vector3, near: float, exclude: Array[RID]) -> Dictionary:
	for i in MAX_LOOK_THROUGH:
		var q := PhysicsRayQueryParameters3D.create(from, anchor, Layers.WORLD)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty() or (hit["position"] as Vector3).distance_to(anchor) < near:
			return {}
		if _solid(hit["collider"] as Node):
			return hit
		exclude.append(hit["rid"])
	return {}


static func _solid(n: Node) -> bool:
	if n is Area3D:
		return false
	while n != null and not n is Level:
		if n.is_in_group(&"camera_fade") or n.is_in_group(&"ink_skip") or n.has_meta(&"ink_skip") or n.has_method(&"glyph_anchor"):
			return false
		n = n.get_parent()
	return true
