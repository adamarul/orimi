extends Node3D
## Colour-rule probe (scenes/dev/render_probe.tscn). Owner: render.
## Draws flat patches and reads the viewport back, checking that a Palette colour comes out
## within 4/255 of itself:
##   row "toon":      ink_toon.gdshader with a Palette albedo (source_color -> ink_in -> ink_out)
##   row "constant":  a shader-made constant from ink_common.gdshaderinc through ink_out()
##   row "post":      the toon row again with the post chain on (the 3D pass decodes the
##                    screen texture and re-encodes; canvas passes at strength 0)
## Prints ORIMI_RENDER_PROBE lines and ORIMI_RENDER_PROBE_DONE pass=N fail=M.

const TOL := 4
const TOON_COLORS := {
	"IVORY": Palette.IVORY, "SAGE": Palette.SAGE, "STONE": Palette.STONE, "MOSS": Palette.MOSS,
	"VERMILION": Palette.VERMILION, "GOLD": Palette.GOLD, "INK": Palette.INK, "RIVER": Palette.RIVER,
}
const CONST_COLORS := {
	"IVORY": Palette.IVORY, "VERMILION": Palette.VERMILION, "GOLD": Palette.GOLD, "INK": Palette.INK,
	"CURSE_RED": Palette.CURSE_RED, "SEPIA": Palette.SEPIA, "PARCHMENT": Palette.PARCHMENT,
	"CURSE_INK": Palette.CURSE_INK,
}

var _camera: Camera3D
var _patches: Array[Dictionary] = []
var _pass := 0
var _fail := 0


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Palette.SKY
	add_child(env)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 7.5
	_camera.position = Vector3(0.0, 0.0, 10.0)
	add_child(_camera)
	_camera.make_current()
	_row(TOON_COLORS, 1.6, "toon")
	_row(CONST_COLORS, 0.0, "constant")
	if Boot.opt("ramp", "0") == "1":
		var ramp := {}
		for v in [0, 4, 8, 12, 16, 20, 24, 28]:
			ramp["G%d" % v] = Color8(v, v, v)
		_row(ramp, -1.6, "ramp")
		var ramp2 := {}
		for v in [32, 40, 48, 56, 64, 96, 128, 200]:
			ramp2["G%d" % v] = Color8(v, v, v)
		_row(ramp2, -3.0, "ramp")
	CurseField.set_valley_gloom(0.0)
	_run.call_deferred()


func _row(colors: Dictionary, y: float, kind: String) -> void:
	var i := 0
	for key: String in colors:
		var quad := QuadMesh.new()
		quad.size = Vector2(1.1, 1.1)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.position = Vector3(-4.9 + i * 1.4, y, 0.0)
		var mat := ShaderMaterial.new()
		if kind == "toon":
			mat.shader = InkLook.TOON_SHADER
			mat.set_shader_parameter(&"albedo_color", colors[key])
			mat.set_shader_parameter(&"band_high", 1.0)
			mat.set_shader_parameter(&"band_low", 1.0)
			mat.set_shader_parameter(&"shadow_tint", Vector3.ONE)
			mat.set_shader_parameter(&"fade_max", 0.0)
			mat.set_shader_parameter(&"cursable", false)
		else:
			mat.shader = preload("res://shaders/render/probe_constant.gdshader")
			mat.set_shader_parameter(&"index", i if kind == "constant" else 100 + (colors[key] as Color).r8)
		mi.material_override = mat
		add_child(mi)
		_patches.append({"name": key, "kind": kind, "color": colors[key], "node": mi})
		i += 1


func _run() -> void:
	Post.set_enabled(false)
	await _frames(4)
	_measure(["toon", "constant", "ramp"], "")
	Post.set_enabled(true)
	(Post.get_node("Ink3D").material_override as ShaderMaterial).set_shader_parameter(&"crease_strength", 0.0)
	(Post.get_node("Watercolour").material as ShaderMaterial).set_shader_parameter(&"strength", 0.0)
	(Post.get_node("Paper").material as ShaderMaterial).set_shader_parameter(&"strength", 0.0)
	await _frames(4)
	_measure(["toon", "ramp"], "post")
	print("ORIMI_RENDER_PROBE_DONE pass=%d fail=%d renderer=%s" % [_pass, _fail, RenderingServer.get_current_rendering_method()])


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _measure(kinds: Array, label: String) -> void:
	var image := get_viewport().get_texture().get_image()
	for p in _patches:
		if not kinds.has(p.kind):
			continue
		var screen := _camera.unproject_position((p.node as Node3D).global_position)
		var sum := Vector3.ZERO
		var n := 0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var c := image.get_pixelv(Vector2i(screen) + Vector2i(dx, dy))
				sum += Vector3(c.r, c.g, c.b)
				n += 1
		sum /= n
		var got := Color(sum.x, sum.y, sum.z)
		var want: Color = p.color
		var diff := maxi(maxi(absi(got.r8 - want.r8), absi(got.g8 - want.g8)), absi(got.b8 - want.b8))
		var ok := diff <= TOL
		if ok:
			_pass += 1
		else:
			_fail += 1
		print("ORIMI_RENDER_PROBE %s %s/%s want=#%s got=#%s diff=%d" % [
			"PASS" if ok else "FAIL", label if label else p.kind, p.name,
			want.to_html(false), got.to_html(false), diff])
