class_name GroundShadow
extends Node3D
## Keeps a blob shadow on the ground under a character. Uses render's
## scenes/render/blob_shadow.tscn when it exists, else a soft dark disc. Owner: gameplay.

const RENDER_SCENE := "res://scenes/render/blob_shadow.tscn"

## Shadow footprint in metres (x across, y along the body).
@export var size: Vector2 = Vector2(0.7, 1.0)
var follow: Node3D

static var _disc_texture: GradientTexture2D


## Put a blob shadow under body: render's scene parented to the body when it exists (it
## follows its parent on its own), else this fallback following the given visual.
static func attach(body: Node3D, footprint: Vector2, visual: Node3D) -> Node3D:
	if ResourceLoader.exists(RENDER_SCENE):
		var inst := (load(RENDER_SCENE) as PackedScene).instantiate() as Node3D
		inst.set(&"size", footprint)
		body.add_child(inst)
		return inst
	var g := GroundShadow.new()
	g.size = footprint
	g.follow = visual
	body.add_child(g)
	return g


func _ready() -> void:
	top_level = true
	var mi := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = size
	mi.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(Palette.INK, 0.62)
	m.albedo_texture = _disc()
	m.render_priority = -1
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _process(_delta: float) -> void:
	if not is_instance_valid(follow):
		return
	var from := follow.global_position + Vector3.UP * 0.6
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		visible = false
		return
	visible = true
	var drop: float = from.y - 0.6 - hit.position.y
	global_position = hit.position + Vector3.UP * 0.03
	global_rotation = Vector3(0, follow.global_rotation.y, 0)
	var s := clampf(1.0 - drop * 0.25, 0.4, 1.0)
	scale = Vector3(s, 1, s)


static func _disc() -> GradientTexture2D:
	if _disc_texture != null:
		return _disc_texture
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.72, Color(1, 1, 1, 0.95))
	_disc_texture = GradientTexture2D.new()
	_disc_texture.gradient = g
	_disc_texture.fill = GradientTexture2D.FILL_RADIAL
	_disc_texture.fill_from = Vector2(0.5, 0.5)
	_disc_texture.fill_to = Vector2(0.5, 0.0)
	_disc_texture.width = 64
	_disc_texture.height = 64
	return _disc_texture
