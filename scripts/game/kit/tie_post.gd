class_name TiePost
extends StaticBody3D
## One of a pair of tie posts. A Tie stroke from one post to its partner draws a rope of ink
## between them, sets tied_flag and does the pair's action: "bridge" lays a walkable rope
## bridge between the two, "pull" drags pull_target to pull_to, "catch" holds the rope for a
## moment and catches the first target that crosses it, "bind" only sets the flag (a level
## script or boss listens). Set partner on one post of the pair (or both). The brush
## calls on_glyph(&"tie", info) on both posts, with info.targets holding the two posts in stroke
## order. Owner: gameplay.

## The rope holds. other: the partner post.
signal tied_up(other: TiePost)
## catch: the rope caught this node (emitted on the post holding the pair's settings).
signal caught(target: Node3D)

const ROPE_SEGMENTS := 8
## Seconds before the kit rope appears under the VFX rope.
const ROPE_DELAY := 1.1
const PULL_TIME := 1.6

## The other post of the pair.
@export var partner: NodePath
@export_enum("bridge", "pull", "bind", "catch") var action: String = "bind"
## Set on both posts' level when tied. Empty: "tied_<this node's name in snake_case>".
@export var tied_flag: StringName = &""
## The Tie is refused (hint "not_ready") until all are set.
@export var requires_flags: PackedStringArray = PackedStringArray()
## pull: the node dragged, and the marker (or node) it is dragged to.
@export var pull_target: NodePath
@export var pull_to: NodePath
## pull: set the target down on the ground at pull_to (off: exactly at pull_to, for a swing).
@export var pull_to_ground: bool = true
## bridge: deck width and how far the rope sags in the middle.
@export var bridge_width: float = 1.5
@export var sag: float = 0.35
## catch: what the rope catches (empty: any enemy that is not defeated), how long it holds out
## for one to cross it, and how near the rope (metres, across the ground) counts as crossing.
## Nothing crosses in time: the rope slips, the tied flag clears and the posts can be tied again.
@export var catch_targets: Array[NodePath] = []
@export var catch_window: float = 4.0
@export var catch_radius: float = 0.8
## catch: seconds a caught enemy stays stunned. A caught node with on_caught(post) is told instead.
@export var catch_hold: float = 3.0
## catch: set when something is caught. Empty: "caught_<this node's name in snake_case>".
@export var catch_flag: StringName = &""
## Your own post model. A node named "Ring" in it is where the rope ties on.
@export var model_scene: PackedScene

var tied := false
var other: TiePost
var model: Node3D
var _cast_info: Dictionary = {}
var _rope: Node3D


func _ready() -> void:
	add_to_group(Layers.GROUP_BRUSH_TARGET)
	add_to_group(&"tie_post")
	collision_layer = Layers.WORLD | Layers.BRUSH_TARGET
	collision_mask = 0
	model = model_scene.instantiate() as Node3D if model_scene != null else ModelKit.load_model("tie_post", ModelKit.tie_post)
	add_child(model)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.2
	cyl.height = 1.5
	shape.shape = cyl
	shape.position = Vector3(0, 0.75, 0)
	add_child(shape)
	_link.call_deferred()


func _link() -> void:
	if not partner.is_empty():
		other = get_node_or_null(partner) as TiePost
		if other != null and other.other == null:
			other.other = self
	if tied_flag == &"":
		# A pair kept under its own holder node (scenes/game/kit/tie_posts.tscn) is named by the
		# holder, so two instanced pairs never share a flag.
		var holder := get_parent()
		var named := holder if holder != null and not holder is Level and holder.get_child_count() == 2 and other != null and other.get_parent() == holder else self
		tied_flag = StringName("tied_" + String(named.name).to_snake_case())
	# A warp (or a level script) that sets the pair's flag finds it already tied.
	if Game.level != null and other != null and _owner_post() == self:
		Game.level.flag_changed.connect(func(f: StringName, value: bool) -> void:
			if value and f == _flag() and not tied:
				_tie(true))
		if Game.level.get_flag(_flag()):
			_tie(true)


## Where the rope ties on.
func glyph_anchor() -> Vector3:
	var ring := model.find_child("Ring", true, false) as Node3D
	return ring.global_position if ring != null else global_position + Vector3.UP * 1.4


func glyph_radius() -> float:
	return 0.4


func on_glyph(glyph: StringName, info: Dictionary) -> bool:
	if glyph != &"tie" or not GlyphReach.clear(self):
		return false
	if tied:
		# The partner already tied us in this same stroke.
		return is_same(info, _cast_info)
	var targets: Array = info.get("targets", [])
	if other == null or not other in targets or not self in targets:
		return false
	if Game.level != null and not Game.level.all_flags(Array(requires_flags) + Array(other.requires_flags)):
		Game.qa_log("tie_refused", {"post": String(name)})
		Game.hint(&"not_ready")
		return false
	_cast_info = info
	other._cast_info = info
	_tie()
	return true


## silent: the flag was set some other way (a warp); the rope, bridge or pulled object is just
## there, with no effects, no catch and no tied_up.
func _tie(silent: bool = false) -> void:
	tied = true
	other.tied = true
	var flag := _flag()
	if silent:
		_draw_rope(0.0)
	else:
		_draw_rope(ROPE_DELAY)
	match _action():
		"bridge":
			_lay_bridge(silent)
		"pull":
			_pull(silent)
		"catch":
			if not silent:
				_hold_for_catch.call_deferred()
	var info := {"posts": [String(name), String(other.name)], "action": _action(), "flag": String(flag), "silent": silent}
	var target := _owner_post().get_node_or_null(_owner_post().pull_target) as Node3D
	if _action() == "pull" and target != null and silent:
		info["target_at"] = Game._v(target.global_position)
	Game.qa_log("tied", info)
	if silent:
		return
	if Game.level != null:
		Game.level.set_flag(flag)
	tied_up.emit(other)
	other.tied_up.emit(self)


## The pair's settings live on whichever post names its partner.
func _owner_post() -> TiePost:
	return self if not partner.is_empty() or other == null else other


func _action() -> String:
	return _owner_post().action


func _flag() -> StringName:
	return _owner_post().tied_flag


func _draw_rope(delay: float) -> void:
	var a := glyph_anchor()
	var b := other.glyph_anchor()
	var s := _owner_post().sag
	var pts: Array[Vector3] = []
	for i in ROPE_SEGMENTS + 1:
		var u := float(i) / ROPE_SEGMENTS
		pts.append(a.lerp(b, u) + Vector3.DOWN * sin(u * PI) * s)
	# The VFX rope (tie_rope) is drawn first; this one settles in as it fades.
	_build_rope(pts, delay)


func _build_rope(pts: Array[Vector3], delay: float) -> void:
	if is_instance_valid(_rope):
		_rope.queue_free()
	_rope = Node3D.new()
	_rope.name = "Rope"
	var holder: Node = Game.level if Game.level != null else get_parent()
	holder.add_child(_rope)
	for i in range(1, pts.size()):
		var seg := MeshInstance3D.new()
		seg.mesh = ModelKit.cylinder(0.035, 0.035, pts[i - 1].distance_to(pts[i]), 5)
		seg.material_override = ModelKit.mat(Palette.INK)
		_rope.add_child(seg)
		seg.global_position = (pts[i - 1] + pts[i]) * 0.5
		seg.global_basis = _basis_along((pts[i] - pts[i - 1]).normalized())
		seg.scale = Vector3(1, 0.01, 1)
		create_tween().tween_property(seg, "scale", Vector3.ONE, 0.04 * i).set_delay(delay)


## catch: hold the rope until a target crosses it or the window runs out.
func _hold_for_catch() -> void:
	var op := _owner_post()
	var left := op.catch_window
	while left > 0.0:
		await get_tree().physics_frame
		if get_tree().paused:
			continue
		left -= get_physics_process_delta_time()
		var hit := _crossing(op)
		if hit != null:
			_catch(hit, op)
			return
	Game.qa_log("tie_slipped", {"posts": [String(name), String(other.name)]})
	if is_instance_valid(_rope):
		_rope.queue_free()
	tied = false
	other.tied = false
	if Game.level != null:
		Game.level.set_flag(_flag(), false)


func _crossing(op: TiePost) -> Node3D:
	var candidates: Array = []
	for path in op.catch_targets:
		candidates.append(op.get_node_or_null(path))
	if op.catch_targets.is_empty():
		candidates = get_tree().get_nodes_in_group(Layers.GROUP_ENEMY)
	var a := glyph_anchor()
	var b := other.glyph_anchor()
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	for c: Variant in candidates:
		var n := c as Node3D
		if n == null or not n.is_inside_tree() or (n is EnemyBase and (n as EnemyBase).is_defeated()):
			continue
		var p := n.global_position
		if p.y < minf(a.y, b.y) - 2.5 or p.y > maxf(a.y, b.y) + 0.8:
			continue
		var p2 := Vector2(p.x, p.z)
		if p2.distance_to(Geometry2D.get_closest_point_to_segment(p2, a2, b2)) < op.catch_radius:
			return n
	return null


func _catch(target: Node3D, op: TiePost) -> void:
	var flag := op.catch_flag if op.catch_flag != &"" else StringName("caught_" + String(op.name).to_snake_case())
	Game.qa_log("tie_caught", {"posts": [String(name), String(other.name)], "target": String(target.name), "flag": String(flag)})
	var held := target.global_position + Vector3.UP * 0.5
	if target.has_method(&"glyph_anchor"):
		held = target.call(&"glyph_anchor")
	var through: Array[Vector3] = [glyph_anchor(), held, other.glyph_anchor()]
	_build_rope(through, 0.0)
	if target.has_method(&"on_caught"):
		target.call(&"on_caught", op)
	elif target is EnemyBase:
		var e := target as EnemyBase
		e.stun = maxf(e.stun, op.catch_hold)
		e.velocity = Vector3.ZERO
	if Game.level != null:
		Game.level.set_flag(flag)
	op.caught.emit(target)


func _basis_along(dir: Vector3) -> Basis:
	var up := dir
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(side, up, side.cross(up).normalized())


func _lay_bridge(instant: bool = false) -> void:
	var a := global_position
	var b := other.global_position
	var mid := (a + b) * 0.5
	var flat := b - a
	var length := flat.length()
	var w := _owner_post().bridge_width
	var deck := StaticBody3D.new()
	deck.name = "RopeBridge"
	deck.add_to_group(&"safe_ground")
	deck.collision_layer = Layers.WORLD
	deck.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, 0.2, length + 0.6)
	shape.shape = box
	deck.add_child(shape)
	var planks := int(length / 0.45)
	for i in planks:
		var plank := MeshInstance3D.new()
		plank.mesh = ModelKit.box(Vector3(w, 0.08, 0.32))
		plank.material_override = ModelKit.mat(Palette.PARCHMENT_WARM)
		plank.position = Vector3(0, 0.06, -length * 0.5 + (i + 0.5) * length / planks)
		deck.add_child(plank)
		if not instant:
			plank.scale = Vector3(1, 1, 0.01)
			create_tween().tween_property(plank, "scale", Vector3.ONE, 0.15 + 0.03 * i)
	(Game.level if Game.level != null else get_parent()).add_child(deck)
	deck.global_position = mid + Vector3.UP * 0.02
	deck.look_at(b + Vector3.UP * 0.02, Vector3.UP)
	ModelKit.add_ink_look(deck, &"", false, 0.8)


func _pull(instant: bool = false) -> void:
	var owner_post := _owner_post()
	var target := owner_post.get_node_or_null(owner_post.pull_target) as Node3D
	var dest := owner_post.get_node_or_null(owner_post.pull_to) as Node3D
	if target == null or dest == null:
		push_warning("TiePost %s: pull needs pull_target and pull_to" % owner_post.name)
		return
	# The target ends at pull_to's position and turn: a log dragged aside, or one swung free
	# on its post when pull_to is rotated about the post.
	var to := dest.global_transform
	if owner_post.pull_to_ground and Game.level != null:
		to.origin = Game.level.ground_at(to.origin + Vector3.UP, target)
	var end := Transform3D(to.basis.orthonormalized() * Basis.from_scale(target.global_basis.get_scale()), to.origin)
	if instant:
		target.global_transform = end
		return
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(target, "global_transform", end, PULL_TIME)
