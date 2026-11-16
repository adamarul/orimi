class_name ModelKit
extends RefCounted
## Loads the assets workstream's model wrappers (scenes/models/*.tscn) and builds grey-box
## placeholders while a wrapper does not exist yet. Placeholders carry real AnimationPlayers
## with animations keyed at 12 frames per second, so the stepped animator is exercised either
## way, and an InkLook child so the render look applies to them too. Owner: gameplay.

const FPS := 12.0
const MODEL_DIR := "res://scenes/models/"

static var _materials: Dictionary = {}


## Instance scenes/models/<name>.tscn if it exists, else call fallback (returns a Node3D).
static func load_model(model_name: String, fallback: Callable) -> Node3D:
	var path := MODEL_DIR + model_name + ".tscn"
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			var inst := packed.instantiate() as Node3D
			if inst != null:
				inst.set_meta(&"placeholder", false)
				return inst
	var ph: Node3D = fallback.call()
	ph.set_meta(&"placeholder", true)
	return ph


static func anim_player(model: Node) -> AnimationPlayer:
	if model == null:
		return null
	var ap := model.get_node_or_null(^"%AnimationPlayer") as AnimationPlayer
	if ap != null:
		return ap
	var found := model.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if found.size() > 0 else null


## The InkLook node of a model (direct child first, then anywhere below), or null.
static func ink_look(model: Node) -> InkLook:
	if model == null:
		return null
	for child in model.get_children():
		if child is InkLook:
			return child
	for child in model.get_children():
		var found := ink_look(child)
		if found != null:
			return found
	return null


static func add_ink_look(model: Node3D, accent: StringName = &"", cursable: bool = true, width: float = 1.0) -> InkLook:
	var look := ink_look(model)
	if look != null:
		return look
	look = InkLook.new()
	look.name = "InkLook"
	look.accent = accent
	look.cursable = cursable
	look.outline_width = width
	model.add_child(look)
	return look


static func mat(color: Color, alpha: float = 1.0, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s/%.2f/%s" % [color.to_html(), alpha, unshaded]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = 1.0
	m.metallic_specular = 0.0
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = m
	return m


static func part(parent: Node3D, part_name: String, mesh: Mesh, color: Color, pos: Vector3 = Vector3.ZERO,
		rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, alpha: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.material_override = mat(color, alpha)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func node(parent: Node3D, node_name: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	return n


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	return m


static func sphere(radius: float, height: float = -1.0, segments: int = 12) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0 if height < 0.0 else height
	m.radial_segments = segments
	m.rings = maxi(4, segments / 2)
	return m


static func cylinder(top: float, bottom: float, height: float, segments: int = 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


static func torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 16
	m.ring_segments = 6
	return m


## A flat arc in the XZ plane, from angle a0 to a1 (radians, 0 = -Z), between radii r0 and r1.
static func arc_mesh(r0: float, r1: float, a0: float, a1: float, segments: int = 10) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var t0 := lerpf(a0, a1, float(i) / segments)
		var t1 := lerpf(a0, a1, float(i + 1) / segments)
		var d0 := Vector3(sin(t0), 0, -cos(t0))
		var d1 := Vector3(sin(t1), 0, -cos(t1))
		# Taper toward both ends of the arc, like a brush stroke.
		var w0 := sin(PI * float(i) / segments)
		var w1 := sin(PI * float(i + 1) / segments)
		var in0 := lerpf(r1, r0, w0)
		var in1 := lerpf(r1, r0, w1)
		st.set_normal(Vector3.UP)
		st.add_vertex(d0 * in0)
		st.add_vertex(d0 * r1)
		st.add_vertex(d1 * r1)
		st.add_vertex(d0 * in0)
		st.add_vertex(d1 * r1)
		st.add_vertex(d1 * in1)
	return st.commit()


## Adds an AnimationPlayer with the given animations to root. anims maps a name to
## [frame_count, loop, tracks], where tracks maps "Node/Path:property" to an Array of values,
## one per frame (null = no key on that frame).
static func add_animations(root: Node3D, anims: Dictionary) -> AnimationPlayer:
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	for anim_name: String in anims:
		var spec: Array = anims[anim_name]
		var frames: int = spec[0]
		var anim := Animation.new()
		anim.length = frames / FPS
		anim.loop_mode = Animation.LOOP_LINEAR if spec[1] else Animation.LOOP_NONE
		var tracks: Dictionary = spec[2]
		for path: String in tracks:
			var t := anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(t, NodePath(path))
			anim.track_set_interpolation_type(t, Animation.INTERPOLATION_NEAREST)
			anim.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
			var values: Array = tracks[path]
			for f in values.size():
				if values[f] != null:
					anim.track_insert_key(t, f / FPS, values[f])
		lib.add_animation(StringName(anim_name), anim)
	ap.add_animation_library(&"", lib)
	root.add_child(ap)
	return ap


# --- Placeholders -----------------------------------------------------------------------

static func fox() -> Node3D:
	var root := Node3D.new()
	root.name = "FoxPlaceholder"
	var ivory := Palette.IVORY
	var ash := Palette.STONE
	var pivot := node(root, "Pivot")
	part(pivot, "Body", box(Vector3(0.32, 0.28, 0.6)), ivory, Vector3(0, 0.42, 0))
	part(pivot, "Chest", prism(Vector3(0.32, 0.22, 0.2)), ivory, Vector3(0, 0.38, -0.3), Vector3(-90, 0, 0))
	var head := node(pivot, "Head", Vector3(0, 0.62, -0.34))
	part(head, "Skull", prism(Vector3(0.3, 0.34, 0.24)), ivory, Vector3(0, 0, -0.08), Vector3(-90, 0, 0))
	part(head, "EarL", prism(Vector3(0.1, 0.2, 0.05)), ivory, Vector3(-0.09, 0.15, 0.04), Vector3(0, 0, 12))
	part(head, "EarR", prism(Vector3(0.1, 0.2, 0.05)), ivory, Vector3(0.09, 0.15, 0.04), Vector3(0, 0, -12))
	part(head, "EarTipL", prism(Vector3(0.05, 0.08, 0.055)), ash, Vector3(-0.105, 0.23, 0.04), Vector3(0, 0, 12))
	part(head, "EarTipR", prism(Vector3(0.05, 0.08, 0.055)), ash, Vector3(0.105, 0.23, 0.04), Vector3(0, 0, -12))
	part(head, "Nose", sphere(0.03, -1.0, 6), Palette.INK, Vector3(0, -0.04, -0.27))
	part(pivot, "Cord", torus(0.13, 0.16), Palette.VERMILION, Vector3(0, 0.5, -0.27), Vector3(70, 0, 0))
	part(pivot, "Bead", sphere(0.035, -1.0, 8), Palette.GOLD, Vector3(0, 0.37, -0.33))
	for i in 4:
		var x := -0.1 if i % 2 == 0 else 0.1
		var z := -0.2 if i < 2 else 0.2
		var leg := node(pivot, "Leg%d" % i, Vector3(x, 0.3, z))
		part(leg, "Shin", box(Vector3(0.07, 0.26, 0.07)), ivory, Vector3(0, -0.12, 0))
		part(leg, "Paw", box(Vector3(0.08, 0.06, 0.1)), ash, Vector3(0, -0.27, -0.01))
	var tail := node(pivot, "TailPivot", Vector3(0, 0.5, 0.28))
	part(tail, "Tail", prism(Vector3(0.24, 0.62, 0.12)), ivory, Vector3(0, 0.1, 0.3), Vector3(72, 0, 0))
	part(tail, "TailTip", prism(Vector3(0.1, 0.16, 0.13)), ash, Vector3(0, 0.2, 0.6), Vector3(72, 0, 0))
	var smear := part(tail, "Smear", arc_mesh(0.25, 0.85, -1.2, 1.2, 12), Palette.INK_SOFT, Vector3(0, 0.08, 0), Vector3(0, 180, 0), Vector3.ONE, 0.75)
	smear.visible = false
	var shadow_pos := [Vector3(-0.1, 0.3, -0.2), Vector3(0.1, 0.3, -0.2), Vector3(-0.1, 0.3, 0.2), Vector3(0.1, 0.3, 0.2)]
	var _unused := shadow_pos
	var z3 := Vector3.ZERO
	add_animations(root, {
		"idle": [12, true, {
			"Pivot:position": [z3, null, null, null, null, null, Vector3(0, 0.015, 0), null, null, null, null, null],
			"Pivot/TailPivot:rotation": [Vector3(0, -0.15, 0), null, null, null, null, null, Vector3(0, 0.15, 0), null, null, null, null, null],
			"Pivot/Head:rotation": [z3, null, null, null, null, null, null, null, Vector3(0, 0.1, 0), null, null, null],
		}],
		"run": [6, true, {
			"Pivot:position": [Vector3(0, 0.02, 0), Vector3(0, 0.09, 0), Vector3(0, 0.05, 0), Vector3(0, 0.0, 0), Vector3(0, 0.08, 0), Vector3(0, 0.04, 0)],
			"Pivot:rotation": [Vector3(0.06, 0, 0), Vector3(-0.05, 0, 0), Vector3(0, 0, 0), Vector3(0.06, 0, 0), Vector3(-0.05, 0, 0), Vector3(0, 0, 0)],
			"Pivot/Leg0:rotation": [Vector3(0.7, 0, 0), Vector3(0.1, 0, 0), Vector3(-0.6, 0, 0), Vector3(-0.7, 0, 0), Vector3(-0.1, 0, 0), Vector3(0.6, 0, 0)],
			"Pivot/Leg1:rotation": [Vector3(-0.7, 0, 0), Vector3(-0.1, 0, 0), Vector3(0.6, 0, 0), Vector3(0.7, 0, 0), Vector3(0.1, 0, 0), Vector3(-0.6, 0, 0)],
			"Pivot/Leg2:rotation": [Vector3(-0.6, 0, 0), Vector3(0.1, 0, 0), Vector3(0.7, 0, 0), Vector3(0.6, 0, 0), Vector3(-0.1, 0, 0), Vector3(-0.7, 0, 0)],
			"Pivot/Leg3:rotation": [Vector3(0.6, 0, 0), Vector3(-0.1, 0, 0), Vector3(-0.7, 0, 0), Vector3(-0.6, 0, 0), Vector3(0.1, 0, 0), Vector3(0.7, 0, 0)],
			"Pivot/TailPivot:rotation": [Vector3(-0.3, 0.1, 0), null, null, Vector3(-0.3, -0.1, 0), null, null],
		}],
		"jump": [3, false, {
			"Pivot:rotation": [Vector3(-0.15, 0, 0), Vector3(-0.3, 0, 0), Vector3(-0.25, 0, 0)],
			"Pivot/Leg0:rotation": [Vector3(-0.8, 0, 0), null, null],
			"Pivot/Leg1:rotation": [Vector3(-0.8, 0, 0), null, null],
			"Pivot/Leg2:rotation": [Vector3(0.9, 0, 0), null, null],
			"Pivot/Leg3:rotation": [Vector3(0.9, 0, 0), null, null],
			"Pivot/TailPivot:rotation": [Vector3(-0.5, 0, 0), null, null],
		}],
		"fall": [4, true, {
			"Pivot:rotation": [Vector3(0.15, 0, 0), null, Vector3(0.2, 0, 0), null],
			"Pivot/Leg0:rotation": [Vector3(-0.3, 0, 0), null, null, null],
			"Pivot/Leg1:rotation": [Vector3(-0.3, 0, 0), null, null, null],
			"Pivot/Leg2:rotation": [Vector3(0.3, 0, 0), null, null, null],
			"Pivot/Leg3:rotation": [Vector3(0.3, 0, 0), null, null, null],
			"Pivot/TailPivot:rotation": [Vector3(0.4, 0, 0), null, Vector3(0.5, 0, 0), null],
		}],
		"land": [3, false, {
			"Pivot:position": [Vector3(0, -0.07, 0), Vector3(0, -0.03, 0), z3],
			"Pivot:scale": [Vector3(1.12, 0.82, 1.12), Vector3(1.05, 0.93, 1.05), Vector3.ONE],
			"Pivot:rotation": [z3, null, null],
			"Pivot/Leg0:rotation": [z3, null, null],
			"Pivot/Leg1:rotation": [z3, null, null],
			"Pivot/Leg2:rotation": [z3, null, null],
			"Pivot/Leg3:rotation": [z3, null, null],
		}],
		"attack_1": [6, false, {
			"Pivot:rotation": [z3, Vector3(0, -0.45, 0), Vector3(0, 1.4, 0), Vector3(0, 2.7, 0), Vector3(0, 1.2, 0), z3],
			"Pivot/TailPivot:rotation": [z3, Vector3(0, 0.4, 0), Vector3(0, -0.5, 0), Vector3(0, -0.6, 0), Vector3(0, -0.2, 0), z3],
			"Pivot/TailPivot/Smear:visible": [false, false, true, true, false, false],
		}],
		"attack_2": [7, false, {
			"Pivot:rotation": [z3, Vector3(0, 0.5, 0), Vector3(0, -1.6, 0), Vector3(0, -3.3, 0), Vector3(0, -5.0, 0), Vector3(0, -6.28, 0), Vector3(0, -6.28, 0)],
			"Pivot:position": [z3, Vector3(0, 0.12, 0), Vector3(0, 0.22, 0), Vector3(0, 0.18, 0), Vector3(0, 0.08, 0), z3, z3],
			"Pivot/TailPivot:rotation": [z3, Vector3(0, -0.4, 0), Vector3(0, 0.6, 0), Vector3(0, 0.6, 0), Vector3(0, 0.5, 0), z3, z3],
			"Pivot/TailPivot/Smear:visible": [false, false, true, true, true, false, false],
		}],
		"hurt": [4, false, {
			"Pivot:rotation": [Vector3(-0.45, 0, 0.2), Vector3(-0.3, 0, 0.1), Vector3(-0.1, 0, 0), z3],
			"Pivot:position": [Vector3(0, 0.05, 0.12), Vector3(0, 0.03, 0.06), z3, z3],
		}],
		"brush_pose": [12, true, {
			"Pivot:rotation": [Vector3(-0.3, 0, 0), null, null, null, null, null, Vector3(-0.32, 0, 0), null, null, null, null, null],
			"Pivot/Leg2:rotation": [Vector3(1.2, 0, 0), null, null, null, null, null, null, null, null, null, null, null],
			"Pivot/Leg3:rotation": [Vector3(1.2, 0, 0), null, null, null, null, null, null, null, null, null, null, null],
			"Pivot/TailPivot:rotation": [Vector3(0.2, 0.9, 0), null, null, null, null, null, Vector3(0.2, 1.0, 0), null, null, null, null, null],
		}],
	})
	add_ink_look(root, &"", false, 0.8)
	return root


static func splotchet() -> Node3D:
	var root := Node3D.new()
	root.name = "SplotchetPlaceholder"
	var pivot := node(root, "Pivot")
	part(pivot, "Blob", sphere(0.36, 0.56, 12), Palette.CURSE_INK, Vector3(0, 0.28, 0))
	part(pivot, "Drip", sphere(0.14, 0.2, 8), Palette.CURSE_INK, Vector3(0.22, 0.06, 0.15))
	part(pivot, "EyeL", sphere(0.065, 0.09, 8), Palette.IVORY, Vector3(-0.11, 0.38, -0.3))
	part(pivot, "EyeR", sphere(0.065, 0.09, 8), Palette.IVORY, Vector3(0.11, 0.38, -0.3))
	var z3 := Vector3.ZERO
	add_animations(root, {
		"idle": [8, true, {
			"Pivot:scale": [Vector3(1.05, 0.92, 1.05), null, null, null, Vector3(0.97, 1.05, 0.97), null, null, null],
			"Pivot:position": [z3, null, null, null, null, null, null, null],
		}],
		"hop": [6, false, {
			"Pivot:scale": [Vector3(1.2, 0.7, 1.2), Vector3(0.8, 1.3, 0.8), Vector3(0.9, 1.15, 0.9), Vector3(1.0, 1.0, 1.0), Vector3(1.1, 0.88, 1.1), Vector3.ONE],
		}],
		"attack": [6, false, {
			"Pivot:scale": [Vector3(1.25, 0.65, 1.25), Vector3(1.3, 0.6, 1.3), Vector3(0.75, 0.9, 1.6), Vector3(0.8, 0.95, 1.4), Vector3(1.0, 1.0, 1.1), Vector3.ONE],
			"Pivot:rotation": [Vector3(0.2, 0, 0), null, Vector3(-0.3, 0, 0), null, z3, null],
		}],
		"hurt": [3, false, {
			"Pivot:scale": [Vector3(1.35, 0.6, 1.35), Vector3(1.1, 0.85, 1.1), Vector3.ONE],
			"Pivot:rotation": [z3, null, null],
		}],
	})
	add_ink_look(root, &"", false, 1.0)
	return root


## A person cut from paper: a robe, a head, two sleeves, an optional hat ("", "paper", "brim").
## Animations: idle (a slow breath) and talk (a nod).
static func person(robe: Color = Palette.SAGE, hat: String = "") -> Node3D:
	var root := Node3D.new()
	root.name = "PersonPlaceholder"
	var pivot := node(root, "Pivot")
	part(pivot, "Robe", cylinder(0.22, 0.42, 1.15, 10), robe, Vector3(0, 0.58, 0))
	part(pivot, "Collar", cylinder(0.2, 0.24, 0.12, 10), Palette.IVORY, Vector3(0, 1.18, 0))
	var head := part(pivot, "Head", sphere(0.2, 0.42, 12), Palette.PARCHMENT, Vector3(0, 1.42, 0))
	part(pivot, "SleeveL", cylinder(0.07, 0.12, 0.62, 6), robe, Vector3(-0.3, 0.9, 0), Vector3(0, 0, -14))
	part(pivot, "SleeveR", cylinder(0.07, 0.12, 0.62, 6), robe, Vector3(0.3, 0.9, 0), Vector3(0, 0, 14))
	match hat:
		"paper":
			part(head, "Hat", prism(Vector3(0.62, 0.3, 0.36)), Palette.IVORY, Vector3(0, 0.27, 0))
		"brim":
			part(head, "Hat", cylinder(0.05, 0.38, 0.18, 12), Palette.PARCHMENT_WARM, Vector3(0, 0.22, 0))
	var z3 := Vector3.ZERO
	add_animations(root, {
		"idle": [24, true, {
			"Pivot:scale": [Vector3.ONE, null, null, null, null, null, Vector3(1.0, 1.02, 1.0), null, null, null, null, null,
				Vector3(1.0, 1.03, 1.0), null, null, null, null, null, Vector3(1.0, 1.02, 1.0), null, null, null, null, null],
			"Pivot/Head:rotation": [z3, null, null, null, null, null, null, null, null, null, null, null,
				Vector3(0, 0.12, 0), null, null, null, null, null, null, null, null, null, null, null],
		}],
		"talk": [8, true, {
			"Pivot/Head:rotation": [Vector3(0.15, 0, 0), null, z3, null, Vector3(0.1, 0, 0), null, z3, null],
			"Pivot:scale": [Vector3.ONE, null, null, null, null, null, null, null],
		}],
	})
	add_ink_look(root, &"", true, 1.0)
	return root


static func reedwraith() -> Node3D:
	var root := Node3D.new()
	root.name = "ReedwraithPlaceholder"
	var pivot := node(root, "Pivot")
	var reeds := node(pivot, "Reeds")
	for i in 9:
		var a := TAU * i / 9.0
		var r := 0.12 + 0.06 * float(i % 3)
		var h := 1.9 + 0.35 * float((i * 7) % 4) / 3.0
		part(reeds, "Reed%d" % i, cylinder(0.012, 0.045, h, 6), Palette.CURSE_INK,
			Vector3(cos(a) * r, h * 0.5 + 0.1, sin(a) * r), Vector3(sin(a * 3.0) * 7.0, 0, cos(a * 2.0) * 7.0))
	part(pivot, "Tuft", prism(Vector3(0.5, 0.5, 0.1)), Palette.CURSE_INK, Vector3(0, 2.35, 0), Vector3(0, 0, 180))
	part(pivot, "EyeL", box(Vector3(0.1, 0.03, 0.03)), Palette.IVORY, Vector3(-0.08, 1.9, -0.2), Vector3(0, 0, -10))
	part(pivot, "EyeR", box(Vector3(0.1, 0.03, 0.03)), Palette.IVORY, Vector3(0.08, 1.9, -0.2), Vector3(0, 0, 10))
	part(pivot, "Lash", cylinder(0.01, 0.04, 1.6, 6), Palette.CURSE_INK, Vector3(0.35, 1.4, -0.1), Vector3(0, 0, -30))
	part(pivot, "Veil", cylinder(0.5, 0.65, 2.2, 10), Palette.STONE_DARK, Vector3(0, 1.15, 0), Vector3.ZERO, Vector3.ONE, 0.55)
	var z3 := Vector3.ZERO
	add_animations(root, {
		"idle": [12, true, {
			"Pivot/Reeds:rotation": [Vector3(0, 0, -0.04), null, null, null, null, null, Vector3(0, 0, 0.04), null, null, null, null, null],
			"Pivot:position": [Vector3(0, 0.1, 0), null, null, null, null, null, Vector3(0, 0.16, 0), null, null, null, null, null],
			"Pivot/Lash:rotation": [Vector3(0, 0, -0.5), null, null, null, null, null, Vector3(0, 0, -0.6), null, null, null, null, null],
		}],
		"drift": [12, true, {
			"Pivot/Reeds:rotation": [Vector3(0.08, 0, -0.05), null, null, null, null, null, Vector3(0.08, 0, 0.05), null, null, null, null, null],
			"Pivot:position": [Vector3(0, 0.15, 0), null, null, Vector3(0, 0.22, 0), null, null, Vector3(0, 0.15, 0), null, null, Vector3(0, 0.08, 0), null, null],
			"Pivot/Lash:rotation": [Vector3(0, 0, -0.5), null, null, null, null, null, null, null, null, null, null, null],
		}],
		"attack": [7, false, {
			"Pivot/Reeds:rotation": [Vector3(0.25, 0, 0), Vector3(0.3, 0, 0), Vector3(-0.35, 0, 0), Vector3(-0.3, 0, 0), Vector3(-0.1, 0, 0), z3, z3],
			"Pivot/Lash:rotation": [Vector3(0.6, 0, -0.9), Vector3(0.8, 0, -1.0), Vector3(-1.4, 0, -0.2), Vector3(-1.5, 0, 0.2), Vector3(-0.8, 0, -0.2), Vector3(0, 0, -0.5), Vector3(0, 0, -0.5)],
		}],
		"veil_off": [6, false, {
			"Pivot/Veil:scale": [Vector3(1.1, 1.0, 1.1), Vector3(1.4, 0.8, 1.4), Vector3(1.7, 0.55, 1.7), Vector3(2.0, 0.3, 2.0), Vector3(2.2, 0.1, 2.2), Vector3(2.2, 0.1, 2.2)],
			"Pivot/Veil:visible": [true, null, null, null, null, false],
			"Pivot/Reeds:rotation": [Vector3(0, 0, 0.2), Vector3(0, 0, -0.2), Vector3(0, 0, 0.1), z3, null, null],
		}],
		"hurt": [3, false, {
			"Pivot/Reeds:rotation": [Vector3(-0.4, 0, 0.1), Vector3(-0.2, 0, 0.0), z3],
		}],
	})
	add_ink_look(root, &"", false, 1.0)
	return root


static func sapling() -> Node3D:
	var root := Node3D.new()
	root.name = "SaplingPlaceholder"
	part(root, "Trunk", cylinder(0.03, 0.08, 1.4, 6), Palette.CURSE_INK, Vector3(0, 0.7, 0), Vector3(0, 0, 4))
	part(root, "BranchA", cylinder(0.01, 0.03, 0.7, 5), Palette.CURSE_INK, Vector3(-0.18, 1.15, 0), Vector3(0, 0, 40))
	part(root, "BranchB", cylinder(0.01, 0.03, 0.6, 5), Palette.CURSE_INK, Vector3(0.16, 1.25, 0.05), Vector3(10, 0, -45))
	part(root, "Cord", torus(0.08, 0.11), Palette.VERMILION, Vector3(0, 0.6, 0), Vector3(8, 0, 0))
	part(root, "CordTail", box(Vector3(0.03, 0.3, 0.01)), Palette.VERMILION, Vector3(0.1, 0.48, 0), Vector3(0, 0, 12))
	part(root, "Stake", cylinder(0.025, 0.03, 0.9, 5), Palette.STONE, Vector3(0.18, 0.45, 0.06))
	var canopy := node(root, "Canopy", Vector3(0, 1.45, 0))
	part(canopy, "LeafA", sphere(0.45, 0.6, 8), Palette.SAGE, Vector3(-0.2, 0, 0))
	part(canopy, "LeafB", sphere(0.4, 0.5, 8), Palette.SAGE_DEEP, Vector3(0.25, 0.1, 0.1))
	part(canopy, "BlossomA", sphere(0.14, -1.0, 8), Palette.PETAL, Vector3(-0.3, 0.25, -0.25))
	part(canopy, "BlossomB", sphere(0.12, -1.0, 8), Palette.PETAL_DEEP, Vector3(0.3, 0.3, -0.2))
	part(canopy, "BlossomC", sphere(0.12, -1.0, 8), Palette.PETAL, Vector3(0.05, 0.4, 0.3))
	canopy.visible = false
	add_animations(root, {
		"withered": [1, true, {"Canopy:visible": [false], "Canopy:scale": [Vector3(0.05, 0.05, 0.05)]}],
		"bloom": [12, false, {
			"Canopy:visible": [true, null, null, null, null, null, null, null, null, null, null, null],
			"Canopy:scale": [Vector3(0.1, 0.1, 0.1), null, Vector3(0.3, 0.3, 0.3), null, Vector3(0.55, 0.55, 0.55), null, Vector3(0.8, 0.8, 0.8), null, Vector3(1.1, 1.1, 1.1), null, Vector3.ONE, null],
		}],
	})
	add_ink_look(root, &"vermilion", true, 1.0)
	return root


static func great_tree() -> Node3D:
	var root := Node3D.new()
	root.name = "GreatTreePlaceholder"
	part(root, "Trunk", cylinder(0.9, 1.6, 9.0, 10), Palette.CURSE_INK, Vector3(0, 4.5, 0))
	part(root, "Root", cylinder(1.6, 2.6, 1.0, 10), Palette.CURSE_INK, Vector3(0, 0.3, 0))
	var limbs := [[Vector3(-2.2, 8.5, 0), Vector3(0, 0, 50), 5.5], [Vector3(2.4, 9.0, 0.5), Vector3(10, 0, -55), 6.0],
		[Vector3(0.3, 9.6, -2.0), Vector3(-50, 0, 0), 5.0], [Vector3(-0.5, 9.4, 2.2), Vector3(48, 0, 8), 4.5]]
	for i in limbs.size():
		var l: Array = limbs[i]
		part(root, "Limb%d" % i, cylinder(0.12, 0.45, l[2], 7), Palette.CURSE_INK, l[0], l[1])
	part(root, "Cord", torus(1.45, 1.6), Palette.VERMILION, Vector3(0, 2.6, 0), Vector3(4, 0, 2))
	part(root, "CordBead", sphere(0.18, -1.0, 8), Palette.GOLD, Vector3(0, 2.35, -1.5))
	var canopy := node(root, "Canopy", Vector3(0, 11.0, 0))
	var blobs := [[Vector3(0, 0.8, 0), 4.2, Palette.SAGE], [Vector3(-4, -0.6, 0.5), 3.0, Palette.SAGE_DEEP],
		[Vector3(4.2, -0.3, -0.5), 3.2, Palette.SAGE], [Vector3(0.5, -0.5, -3.8), 2.8, Palette.SAGE_DEEP],
		[Vector3(-0.8, -0.2, 3.8), 2.9, Palette.SAGE], [Vector3(-2, 2.2, -1), 1.2, Palette.PETAL],
		[Vector3(2.4, 1.6, 1.8), 1.1, Palette.PETAL_DEEP], [Vector3(0.6, 2.8, 2.2), 1.0, Palette.PETAL]]
	for i in blobs.size():
		var b: Array = blobs[i]
		part(canopy, "Leaf%d" % i, sphere(b[1], b[1] * 1.3, 10), b[2], b[0])
	canopy.visible = false
	var steps: Array = []
	for f in 30:
		steps.append(Vector3.ONE * clampf(0.04 + f / 26.0, 0.04, 1.0) if f % 2 == 0 else null)
	var vis: Array = [true]
	vis.resize(30)
	add_animations(root, {
		"withered": [1, true, {"Canopy:visible": [false], "Canopy:scale": [Vector3(0.04, 0.04, 0.04)]}],
		"bloom": [30, false, {"Canopy:visible": vis, "Canopy:scale": steps}],
	})
	add_ink_look(root, &"vermilion", true, 1.4)
	return root


## A standing verse-stone: a leaning slab with carved lines and a moss foot.
static func verse_stone() -> Node3D:
	var root := Node3D.new()
	root.name = "VerseStonePlaceholder"
	var slab := part(root, "Slab", box(Vector3(0.9, 1.7, 0.32)), Palette.STONE, Vector3(0, 0.85, 0), Vector3(-4, 0, 3))
	for i in 4:
		part(slab, "Line%d" % i, box(Vector3(0.5 - 0.06 * (i % 2), 0.05, 0.02)), Palette.INK, Vector3(-0.04, 0.45 - i * 0.24, 0.17))
	part(root, "Foot", cylinder(0.55, 0.7, 0.18, 9), Palette.MOSS, Vector3(0, 0.05, 0))
	add_ink_look(root, &"", true, 1.0)
	return root


## A lamp on a post (kind "lamp"), a brazier bowl ("brazier") or a lantern-fruit hanging from a
## stalk ("lantern_fruit"). The node "Flame" is shown when lit.
static func kindle(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "KindlePlaceholder"
	var wick_y := 1.9
	match kind:
		"brazier":
			wick_y = 0.95
			part(root, "Stand", cylinder(0.12, 0.28, 0.7, 6), Palette.STONE_DARK, Vector3(0, 0.35, 0))
			part(root, "Bowl", cylinder(0.5, 0.25, 0.3, 10), Palette.SEPIA, Vector3(0, 0.82, 0))
		"lantern_fruit":
			wick_y = 0.0
			part(root, "Stalk", cylinder(0.02, 0.02, 0.6, 4), Palette.MOSS, Vector3(0, 0.45, 0))
			part(root, "Fruit", sphere(0.22, 0.34, 10), Palette.PARCHMENT_WARM, Vector3(0, 0.0, 0))
		_:
			part(root, "Post", cylinder(0.07, 0.09, 1.7, 6), Palette.SEPIA, Vector3(0, 0.85, 0))
			part(root, "Arm", box(Vector3(0.08, 0.08, 0.5)), Palette.SEPIA, Vector3(0, 1.65, -0.2))
			part(root, "Shade", cylinder(0.14, 0.2, 0.36, 8), Palette.PARCHMENT, Vector3(0, 1.75, -0.42))
			wick_y = 1.75
			root.set_meta(&"wick", Vector3(0, wick_y, -0.42))
	if not root.has_meta(&"wick"):
		root.set_meta(&"wick", Vector3(0, wick_y, 0))
	var flame := part(root, "Flame", sphere(0.13, 0.3, 8), Palette.GOLD_PALE, root.get_meta(&"wick") + Vector3(0, 0.12, 0))
	flame.material_override = mat(Palette.GOLD_PALE, 1.0, true)
	flame.add_to_group(&"ink_skip")
	flame.visible = false
	add_ink_look(root, &"", true, 1.0)
	return root


## A tie post: a short stake with a paper charm and a ring at the top.
static func tie_post() -> Node3D:
	var root := Node3D.new()
	root.name = "TiePostPlaceholder"
	part(root, "Stake", cylinder(0.11, 0.15, 1.5, 7), Palette.SEPIA, Vector3(0, 0.75, 0))
	part(root, "Ring", torus(0.12, 0.2), Palette.VERMILION, Vector3(0, 1.42, 0), Vector3(90, 0, 0))
	part(root, "Charm", box(Vector3(0.18, 0.4, 0.02)), Palette.IVORY, Vector3(0, 1.05, 0.13))
	add_ink_look(root, &"vermilion", true, 1.0)
	return root


static func thorn_gate() -> Node3D:
	var root := Node3D.new()
	root.name = "ThornGatePlaceholder"
	var tangle := node(root, "Tangle")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 16:
		var x := rng.randf_range(-3.0, 3.0)
		var y := rng.randf_range(0.4, 2.2)
		var len := rng.randf_range(2.0, 3.6)
		part(tangle, "Vine%d" % i, cylinder(0.02, 0.07, len, 5), Palette.CURSE_INK, Vector3(x, y, rng.randf_range(-0.3, 0.3)),
			Vector3(rng.randf_range(-20, 20), rng.randf_range(-30, 30), rng.randf_range(-70, 70)))
	for i in 14:
		part(tangle, "Thorn%d" % i, prism(Vector3(0.12, 0.35, 0.05)), Palette.CURSE_INK,
			Vector3(rng.randf_range(-2.8, 2.8), rng.randf_range(0.3, 2.3), rng.randf_range(-0.25, 0.25)),
			Vector3(0, rng.randf_range(0, 360), rng.randf_range(-120, 120)))
	part(root, "PostL", cylinder(0.12, 0.16, 2.8, 6), Palette.STONE_DARK, Vector3(-3.2, 1.4, 0))
	part(root, "PostR", cylinder(0.12, 0.16, 2.6, 6), Palette.STONE_DARK, Vector3(3.2, 1.3, 0))
	add_ink_look(root, &"", true, 1.2)
	return root


static func soot_bank() -> Node3D:
	var root := Node3D.new()
	root.name = "SootBankPlaceholder"
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 12:
		var s := rng.randf_range(0.7, 1.4)
		part(root, "Puff%d" % i, sphere(s, s * 1.6, 10), Palette.STONE_DARK if i % 3 == 0 else Palette.INK_SOFT,
			Vector3(rng.randf_range(-3.2, 3.2), rng.randf_range(0.6, 2.6), rng.randf_range(-0.6, 0.6)))
	add_ink_look(root, &"", false, 1.0)
	return root


static func shrine() -> Node3D:
	var root := Node3D.new()
	root.name = "ShrinePlaceholder"
	part(root, "Plinth", box(Vector3(3.2, 0.4, 2.4)), Palette.STONE, Vector3(0, 0.2, 0))
	part(root, "PostL", cylinder(0.11, 0.13, 2.4, 8), Palette.VERMILION, Vector3(-1.1, 1.6, -0.8))
	part(root, "PostR", cylinder(0.11, 0.13, 2.4, 8), Palette.VERMILION, Vector3(1.1, 1.6, -0.8))
	part(root, "PostBL", cylinder(0.11, 0.13, 2.4, 8), Palette.VERMILION, Vector3(-1.1, 1.6, 0.8))
	part(root, "PostBR", cylinder(0.11, 0.13, 2.4, 8), Palette.VERMILION, Vector3(1.1, 1.6, 0.8))
	part(root, "Roof", prism(Vector3(3.4, 0.9, 2.6)), Palette.STONE_DARK, Vector3(0, 3.25, 0))
	part(root, "Box", box(Vector3(0.7, 0.5, 0.5)), Palette.SEPIA, Vector3(0, 0.65, 0.2))
	part(root, "Paper", box(Vector3(0.5, 0.6, 0.02)), Palette.IVORY, Vector3(0, 1.2, 0.46))
	add_ink_look(root, &"vermilion", false, 1.2)
	return root


static func stepping_stone() -> Node3D:
	var root := Node3D.new()
	root.name = "SteppingStonePlaceholder"
	part(root, "Stone", cylinder(0.7, 0.85, 0.7, 9), Palette.STONE, Vector3(0, -0.15, 0))
	add_ink_look(root, &"", true, 1.0)
	return root


static func rock(size: float, seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "RockPlaceholder"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	part(root, "Rock", sphere(size, size * rng.randf_range(1.0, 1.5), 7), Palette.STONE,
		Vector3(0, size * 0.25, 0), Vector3(rng.randf_range(-10, 10), rng.randf_range(0, 360), 0),
		Vector3(rng.randf_range(0.9, 1.4), 1.0, rng.randf_range(0.8, 1.2)))
	add_ink_look(root, &"", true, 1.0)
	return root


static func reeds(seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "ReedsPlaceholder"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 7:
		var h := rng.randf_range(0.8, 1.6)
		part(root, "Reed%d" % i, cylinder(0.005, 0.02, h, 4), Palette.SAGE_DEEP,
			Vector3(rng.randf_range(-0.4, 0.4), h * 0.5, rng.randf_range(-0.4, 0.4)), Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12)))
	var look := add_ink_look(root, &"", true, 0.6)
	look.wind = true
	return root
