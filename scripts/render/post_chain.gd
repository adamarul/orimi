extends CanvasLayer
## Autoload "Post": the screen-space paper / ink post chain. Owner: render.
## Shape (measured in phase 0, docs/RENDERER_NOTES.md):
##   1. one full-screen 3D pass (post_ink3d.gdshader): light Kuwahara + depth/normal creases.
##      A quad this node keeps in the viewport's 3D world; it attaches to whatever Camera3D is
##      current, so other scenes need no setup.
##   2. canvas ColorRect (post_watercolour.gdshader): edge darkening and pigment blotches.
##   3. BackBufferCopy, then canvas ColorRect (post_paper.gdshader): tooth, staining, fibres,
##      grain, vignette, glow.
## Follows Settings.paper_intensity (Light / Normal / Heavy, PRESETS below). Canvas layer 5, so
## the HUD and menus above it are untouched. Boot option post=0 starts with the chain off
## (for frame-time comparisons).

## Uniform values per paper level. Keys are "<pass>:<uniform>" with pass = ink3d, water, paper.
const PRESETS := [
	{ # Light: tooth only, barely visible; a light touch of wash
		"ink3d:kuwahara_radius": 2, "ink3d:kuwahara_mix": 0.5, "ink3d:crease_strength": 0.7,
		"water:edge_darken": 0.6, "water:blotch_strength": 0.03,
		"paper:tooth_strength": 0.025, "paper:stain_strength": 0.0, "paper:fibre_strength": 0.0,
		"paper:vignette_strength": 0.0, "paper:saturation": 1.0, "paper:grain_strength": 0.006,
		"paper:glow_strength": 0.15,
	},
	{ # Normal: adds the staining and a mild warm vignette
		"ink3d:kuwahara_radius": 2, "ink3d:kuwahara_mix": 0.85, "ink3d:crease_strength": 0.85,
		"water:edge_darken": 1.2, "water:blotch_strength": 0.1,
		"paper:tooth_strength": 0.07, "paper:stain_strength": 0.24, "paper:fibre_strength": 0.0,
		"paper:vignette_strength": 0.35, "paper:saturation": 0.75, "paper:grain_strength": 0.012,
		"paper:glow_strength": 0.22,
	},
	{ # Heavy: doubles the tooth, adds fibres, deeper vignette and stain, less saturation
		"ink3d:kuwahara_radius": 3, "ink3d:kuwahara_mix": 0.9, "ink3d:crease_strength": 0.9,
		"water:edge_darken": 1.6, "water:blotch_strength": 0.18,
		"paper:tooth_strength": 0.15, "paper:stain_strength": 0.45, "paper:fibre_strength": 1.0,
		"paper:vignette_strength": 0.7, "paper:saturation": 0.55, "paper:grain_strength": 0.022,
		"paper:glow_strength": 0.25,
	},
]

var enabled: bool = true

@onready var _water: ColorRect = %Watercolour
@onready var _paper: ColorRect = %Paper
@onready var _copy: BackBufferCopy = %PaperCopy
@onready var _quad: MeshInstance3D = %Ink3D


func _ready() -> void:
	layer = Layers.CANVAS_POST
	process_mode = Node.PROCESS_MODE_ALWAYS
	_quad.custom_aabb = AABB(Vector3(-1.0e5, -1.0e5, -1.0e5), Vector3(2.0e5, 2.0e5, 2.0e5))
	_quad.material_override.render_priority = Material.RENDER_PRIORITY_MIN
	Settings.paper_intensity_changed.connect(_apply_preset)
	_apply_preset(Settings.paper_intensity)
	_read_boot_options()


func _process(_delta: float) -> void:
	if not enabled:
		return
	var cam := get_viewport().get_camera_3d()
	_quad.visible = cam != null
	if cam:
		_quad.global_transform = cam.global_transform.translated_local(Vector3(0.0, 0.0, -1.0))


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	if is_node_ready():
		_water.visible = on
		_paper.visible = on
		_copy.visible = on
		_quad.visible = on and get_viewport().get_camera_3d() != null


## post=0 starts with the chain off; read once the boot scene has parsed the options.
func _read_boot_options() -> void:
	await get_tree().process_frame
	set_enabled(String(Boot.opt("post", "1")) != "0")


## Added by render: the uniform values of one paper level (0 Light, 1 Normal, 2 Heavy).
func preset(level: int) -> Dictionary:
	return PRESETS[clampi(level, 0, PRESETS.size() - 1)]


func _apply_preset(level: int) -> void:
	var mats := {
		"ink3d": _quad.material_override as ShaderMaterial,
		"water": _water.material as ShaderMaterial,
		"paper": _paper.material as ShaderMaterial,
	}
	var values := preset(level)
	for key: String in values:
		var parts := key.split(":")
		(mats[parts[0]] as ShaderMaterial).set_shader_parameter(StringName(parts[1]), values[key])
