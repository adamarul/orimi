class_name InkLook
extends Node
## Add as a child of any Node3D: every MeshInstance3D under that parent gets the toon material
## (shaders/render/ink_toon.gdshader) with the ink outline (shaders/render/ink_outline.gdshader)
## as its next_pass. Albedo colour and texture come from the mesh's existing material. Owner:
## render. Materials are shared between objects with the same settings until set_dissolve() or
## flash() is called, which gives this object its own copies.
##
## Skipped: meshes with meta "ink_skip", meshes in group "ink_skip", and meshes whose material
## is a ShaderMaterial that is not ours (water, blob shadows, effects keep their own shaders).
## A source material whose name ends in "_sacred" keeps its colour in cursed zones and takes
## the accent.

const TOON_SHADER := preload("res://shaders/render/ink_toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/render/ink_outline.gdshader")
const NOISE_TEX := preload("res://assets/textures/render/ink_noise.png")
const STREAK_TEX := preload("res://assets/textures/render/dry_streak.png")
const SACRED_SUFFIX := "_sacred"
const SOURCE_META := &"ink_source_materials"
## A textured mesh wider than this (metres) is ground: its painted dark marks are drawn as crisp
## ink that lightens once the place is restored (ink_toon's ground_marks).
const GROUND_SIZE := 30.0

## Line and band presets. "world": heavy pure-black one-sided strokes (1.5 to 4 %H).
## "character": softer warm-grey line (0.5 to 1.2 %H), broken in places.
const STYLES := {
	&"world": {
		"width_h": 0.02, "max_h": 0.04, "line_color": Color("1b1a1c"),
		"far_line_color": Color("6b6863"), "one_sided": 0.8, "dry_amount": 0.55,
		"default_dry": 0.25, "band_low": 0.88, "band_high": 1.03, "wobble_amount": 0.15,
		"thick_thin_min": 0.5, "thick_thin_max": 1.4,
	},
	&"character": {
		"width_h": 0.014, "max_h": 0.012, "line_color": Color("2e2826"), "thick_thin_min": 0.85, "thick_thin_max": 1.15,
		"far_line_color": Color("6a625c"), "one_sided": 0.4, "dry_amount": 0.3,
		"default_dry": 0.2, "band_low": 0.9, "band_high": 1.02, "wobble_amount": 0.12,
	},
}
const ACCENTS := {
	&"vermilion": Color("d5402b"),
	&"gold": Color("d9a441"),
}

static var _shared := {}

## Multiplier on the outline width for this object. 0 removes the outline pass.
@export var outline_width: float = 1.0
## &"" for ordinary objects, &"vermilion" or &"gold" for sacred / interactive ones.
@export var accent: StringName = &""
## Whether cursed zones drain this object's colour.
@export var cursable: bool = true
## Whether vertex-colour green drives wind sway on this object.
@export var wind: bool = false
@export var apply_on_ready: bool = true
## Added by render: &"world" (heavy black line) or &"character" (soft warm-grey line).
@export var line_style: StringName = &"world"
## Added by render: how much of its own colour this model keeps against LightPools' drained and
## darkness, 0 (follows the place) to 1 (untouched). -1 = automatic, from the nearest ancestor
## group: 1 under the player, 0.7 under an enemy, 0 for everything else (folk, Pell, props).
@export_range(-1.0, 1.0) var light_keep: float = -1.0

var _surfaces: Array[Dictionary] = []
var _unique := false
var _dissolve := 0.0
var _flash_tween: Tween


func _ready() -> void:
	if apply_on_ready:
		apply()


## (Re)apply the look to every MeshInstance3D under the parent. Call again after
## adding meshes at runtime.
func apply() -> void:
	_surfaces.clear()
	_unique = false
	var root := get_parent()
	if root == null:
		return
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node)
	for mi in meshes:
		_apply_mesh(mi)
	if _dissolve > 0.0:
		set_dissolve(_dissolve)


## 0 = solid, 1 = fully dissolved into ink. Used for enemy deaths.
func set_dissolve(amount: float) -> void:
	_dissolve = clampf(amount, 0.0, 1.0)
	_make_unique()
	for s in _surfaces:
		s.toon.set_shader_parameter(&"dissolve", _dissolve)
		if s.outline:
			s.outline.set_shader_parameter(&"dissolve", _dissolve)


## Brief colour flash, for hits.
func flash(color: Color = Color.WHITE, duration: float = 0.12) -> void:
	_make_unique()
	if _flash_tween:
		_flash_tween.kill()
	_set_flash(0.85, color)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash.bind(color), 0.85, 0.0, maxf(duration, 0.01))


func _set_flash(amount: float, color: Color) -> void:
	var c := Color(color.r, color.g, color.b, amount)
	for s in _surfaces:
		s.toon.set_shader_parameter(&"flash_color", c)


func _apply_mesh(mi: MeshInstance3D) -> void:
	if mi.mesh == null or mi.has_meta(&"ink_skip") or mi.is_in_group(&"ink_skip"):
		return
	var count := mi.mesh.get_surface_count()
	var sources: Array = mi.get_meta(SOURCE_META, [])
	if sources.size() != count:
		sources = []
		for i in count:
			var m: Material = mi.material_override
			if m == null:
				m = mi.get_surface_override_material(i)
			if m == null:
				m = mi.mesh.surface_get_material(i)
			sources.append(m)
		for m in sources:
			if m is ShaderMaterial and not _is_ours(m):
				return
		mi.set_meta(SOURCE_META, sources)
	mi.material_override = null
	var size := mi.mesh.get_aabb().size * (mi.global_transform if mi.is_inside_tree() else mi.transform).basis.get_scale()
	var ground := maxf(size.x, size.z) > GROUND_SIZE
	for i in count:
		var src: Material = sources[i]
		var has_vc := false
		if mi.mesh is ArrayMesh:
			has_vc = ((mi.mesh as ArrayMesh).surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0
		var toon := _shared_material(src, has_vc, ground)
		mi.set_surface_override_material(i, toon)
		_surfaces.append({"mesh": mi, "index": i, "toon": toon, "outline": toon.next_pass})


func _is_ours(m: Material) -> bool:
	return m is ShaderMaterial and (m as ShaderMaterial).shader == TOON_SHADER


func _shared_material(src: Material, has_vc: bool, ground: bool) -> ShaderMaterial:
	var color := Color(Palette.IVORY)
	var tex: Texture2D = null
	var sacred := false
	if src is BaseMaterial3D:
		color = (src as BaseMaterial3D).albedo_color
		tex = (src as BaseMaterial3D).albedo_texture
	if src:
		sacred = src.resource_name.ends_with(SACRED_SUFFIX)
	var style: StringName = line_style if STYLES.has(line_style) else &"world"
	var keep := _light_keep()
	var marks := ground and tex != null
	var key := "%s|%d|%s|%s|%s|%s|%s|%.3f|%s|%.2f|%s" % [
		color.to_html(), tex.get_instance_id() if tex else 0, style, sacred, accent, cursable,
		wind, outline_width, has_vc, keep, marks]
	if _shared.has(key) and is_instance_valid(_shared[key]):
		return _shared[key]
	var mat := _build(color, tex, sacred, style, has_vc)
	mat.set_shader_parameter(&"light_keep", keep)
	mat.set_shader_parameter(&"ground_marks", marks)
	if mat.next_pass:
		(mat.next_pass as ShaderMaterial).set_shader_parameter(&"light_keep", keep)
	_shared[key] = mat
	return mat


func _light_keep() -> float:
	if light_keep >= 0.0:
		return light_keep
	var node := get_parent()
	while node != null:
		if node.is_in_group(Layers.GROUP_PLAYER):
			return 1.0
		if node.is_in_group(Layers.GROUP_ENEMY):
			return 0.7
		node = node.get_parent()
	return 0.0


func _build(color: Color, tex: Texture2D, sacred: bool, style: StringName, has_vc: bool) -> ShaderMaterial:
	var p: Dictionary = STYLES[style]
	var toon := ShaderMaterial.new()
	toon.shader = TOON_SHADER
	toon.set_shader_parameter(&"albedo_color", color)
	toon.set_shader_parameter(&"use_texture", tex != null)
	if tex:
		toon.set_shader_parameter(&"albedo_tex", tex)
	toon.set_shader_parameter(&"has_vertex_color", has_vc)
	toon.set_shader_parameter(&"band_low", p.band_low)
	toon.set_shader_parameter(&"band_high", p.band_high)
	toon.set_shader_parameter(&"wind_enabled", wind)
	toon.set_shader_parameter(&"noise_tex", NOISE_TEX)
	toon.set_shader_parameter(&"cursable", cursable)
	toon.set_shader_parameter(&"sacred", sacred)
	var accent_color: Color = ACCENTS.get(accent, Palette.VERMILION)
	toon.set_shader_parameter(&"accent_color", accent_color)
	var strength := 0.0
	if accent != &"":
		strength = 0.35
	elif sacred:
		strength = 0.2
	toon.set_shader_parameter(&"accent_strength", strength)
	if outline_width > 0.0:
		var line := ShaderMaterial.new()
		line.shader = OUTLINE_SHADER
		line.set_shader_parameter(&"width_h", p.width_h)
		line.set_shader_parameter(&"max_h", p.max_h)
		line.set_shader_parameter(&"width_scale", outline_width)
		line.set_shader_parameter(&"line_color", p.line_color)
		line.set_shader_parameter(&"far_line_color", p.far_line_color)
		line.set_shader_parameter(&"one_sided", p.one_sided)
		line.set_shader_parameter(&"dry_amount", p.dry_amount)
		line.set_shader_parameter(&"default_dry", p.default_dry)
		line.set_shader_parameter(&"wobble_amount", p.wobble_amount)
		line.set_shader_parameter(&"thick_thin_min", p.thick_thin_min)
		line.set_shader_parameter(&"thick_thin_max", p.thick_thin_max)
		line.set_shader_parameter(&"has_vertex_color", has_vc)
		line.set_shader_parameter(&"wind_enabled", wind)
		line.set_shader_parameter(&"streak_tex", STREAK_TEX)
		line.set_shader_parameter(&"noise_tex", NOISE_TEX)
		toon.next_pass = line
	return toon


func _make_unique() -> void:
	if _unique:
		return
	_unique = true
	for s in _surfaces:
		var toon: ShaderMaterial = s.toon.duplicate()
		if s.outline:
			toon.next_pass = s.outline.duplicate()
		s.toon = toon
		s.outline = toon.next_pass
		(s.mesh as MeshInstance3D).set_surface_override_material(s.index, toon)
