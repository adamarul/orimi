extends StaticBody3D
## A dummy brush target for the brush demo. Reacts visibly to its own glyph through on_glyph
## and shrugs at the others: a sapling (bloom) greens and grows, a thorn knot (slash) is cut in
## two, a soot bank (gust) is blown away along the gust direction, a lamp (kindle) lights. A tie
## post (in the tie_post group, not a brush target) answers a Tie: both posts nod and the first
## in stroke order hangs an ink rope between the two anchors. Resets after a few seconds.

const RESET_AFTER := 3.0

@export_enum("bloom", "slash", "gust", "kindle", "tie_post") var kind: String = "bloom"

var reacted := 0
## Time.get_ticks_usec() of the last on_glyph call, whatever it answered.
var called_usec := 0
var _parts: Array[MeshInstance3D] = []
var _busy := false
var _light: OmniLight3D


func _ready() -> void:
	add_to_group(Brush.GROUP_TIE_POST if kind == "tie_post" else Layers.GROUP_BRUSH_TARGET)
	collision_layer = Layers.BRUSH_TARGET
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 1.7, 0.5) if kind in ["kindle", "tie_post"] else Vector3(1.4, 2.0, 1.4)
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	add_child(shape)
	_build()


func _build() -> void:
	match kind:
		"bloom":
			_part(_cylinder(0.08, 1.1), Vector3(0, 0.55, 0), Palette.INK_SOFT)
			_part(_sphere(0.45), Vector3(0, 1.3, 0), Palette.STONE)
		"slash":
			for i in 7:
				var m := _part(_box(Vector3(0.12, 1.5, 0.12)), Vector3(-0.55 + i * 0.18, 0.75, 0), Palette.CURSE_INK)
				m.rotation.z = (0.5 if i % 2 == 0 else -0.5)
		"gust":
			for i in 3:
				_part(_box(Vector3(0.5, 1.8 - i * 0.3, 0.9)), Vector3(-0.45 + i * 0.45, 0.9 - i * 0.15, 0), Palette.INK_SOFT)
		"kindle":
			_part(_box(Vector3(0.36, 1.0, 0.36)), Vector3(0, 0.5, 0), Palette.STONE)
			_part(_cylinder(0.3, 0.18), Vector3(0, 1.09, 0), Palette.STONE_DARK)
			_part(_cylinder(0.025, 0.14), Vector3(0, 1.24, 0), Palette.INK)
			# The flame and its light exist (unlit) from the start: adding a light or a new
			# material at the moment of lighting makes the web renderer compile shaders mid-game.
			var flame := _part(_sphere(0.12), Vector3(0, 1.36, 0), Palette.GOLD)
			flame.scale = Vector3.ONE * 0.01
			var mat := flame.material_override as StandardMaterial3D
			mat.emission_enabled = true
			mat.emission = Palette.GOLD_PALE
			mat.emission_energy_multiplier = 2.0
			if _light == null:
				_light = OmniLight3D.new()
				_light.light_color = Palette.GOLD_PALE
				_light.omni_range = 3.0
				_light.position = Vector3(0, 1.4, 0)
				add_child(_light)
			_light.light_energy = 0.0
		"tie_post":
			_part(_cylinder(0.1, 1.5), Vector3(0, 0.75, 0), Palette.SEPIA)
			_part(_sphere(0.14), Vector3(0, 1.52, 0), Palette.SEPIA)


func glyph_anchor() -> Vector3:
	match kind:
		"kindle":
			return global_position + Vector3.UP * 1.3
		"tie_post":
			return global_position + Vector3.UP * 1.45
	return global_position + Vector3.UP * 1.0


func glyph_radius() -> float:
	return 0.35 if kind in ["kindle", "tie_post"] else 0.9


func on_glyph(glyph: StringName, info: Dictionary) -> bool:
	called_usec = Time.get_ticks_usec()
	if _busy:
		return false
	var tween := create_tween()
	if String(glyph) != ("tie" if kind == "tie_post" else kind):
		tween.tween_property(self, ^"rotation:y", 0.15, 0.08)
		tween.tween_property(self, ^"rotation:y", -0.15, 0.12)
		tween.tween_property(self, ^"rotation:y", 0.0, 0.08)
		return false
	_busy = true
	reacted += 1
	print("BRUSH_DEMO ", JSON.stringify({"event": "target_reacted", "target": String(name), "glyph": String(glyph), "order": (info["targets"] as Array).find(self)}))
	match kind:
		"bloom":
			var crown := _parts[1]
			(crown.material_override as StandardMaterial3D).albedo_color = Palette.SAGE
			tween.tween_property(crown, ^"scale", Vector3.ONE * 2.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			(_parts[0].material_override as StandardMaterial3D).albedo_color = Palette.MOSS
		"slash":
			tween.set_parallel(true)
			for i in _parts.size():
				var m := _parts[i]
				var side := -1.0 if i < _parts.size() / 2 else 1.0
				tween.tween_property(m, ^"position", m.position + Vector3(side * 0.8, -0.5, 0.2), 0.4)
				tween.tween_property(m, ^"rotation:z", side * 1.4, 0.4)
		"gust":
			var dir: Vector3 = info["world_dir"]
			tween.set_parallel(true)
			for m in _parts:
				tween.tween_property(m, ^"position", m.position + dir * 4.0 + Vector3.UP * 1.2, 0.8).set_ease(Tween.EASE_IN)
				tween.tween_property(m, ^"scale", Vector3.ONE * 0.05, 0.8)
		"kindle":
			tween.set_parallel(true)
			tween.tween_property(_parts[3], ^"scale", Vector3(1.0, 1.7, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(_light, ^"light_energy", 2.0, 0.3)
		"tie_post":
			var anchors: PackedVector3Array = info["tie_anchors"]
			if (info["targets"] as Array).find(self) == 0:
				var span := anchors[1] - anchors[0]
				var rope := _part(_cylinder(0.03, span.length()), Vector3.ZERO, Palette.INK)
				(rope.mesh as CylinderMesh).bottom_radius = 0.03
				rope.top_level = true
				rope.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, span.normalized())), anchors[0] + span * 0.5)
			var cap := _parts[1]
			tween.tween_property(cap, ^"position:y", 1.42, 0.12)
			tween.tween_property(cap, ^"position:y", 1.52, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(RESET_AFTER)
	tween.chain().tween_callback(_reset)
	return true


func _reset() -> void:
	for m in _parts:
		m.queue_free()
	_parts.clear()
	_busy = false
	_build()


func _part(mesh: Mesh, pos: Vector3, colour: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	m.material_override = mat
	add_child(m)
	_parts.append(m)
	return m


func _cylinder(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r * 1.4
	c.height = h
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
