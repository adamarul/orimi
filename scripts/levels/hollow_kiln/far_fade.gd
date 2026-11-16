extends Node
## Pushes the paper fade back on a far landmark, so the kiln's dome and chimney still read from the
## landing and the valley below still shows in the ending view. The shared toon and outline shaders
## fade everything toward paper between 35 m and 140 m; this sets later values on this model only.
## Add as a sibling after the model's InkLook. Owner: l5 (hollow_kiln).

@export var fade_start := 90.0
@export var fade_end := 400.0
@export_range(0.0, 1.0) var fade_max := 0.55


func _ready() -> void:
	_apply.call_deferred()


func _apply() -> void:
	var root := get_parent()
	if root == null:
		return
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m == null:
				continue
			m = m.duplicate() as ShaderMaterial
			if m.next_pass is ShaderMaterial:
				m.next_pass = m.next_pass.duplicate()
			for mat: ShaderMaterial in [m, m.next_pass as ShaderMaterial]:
				if mat == null:
					continue
				mat.set_shader_parameter(&"fade_start", fade_start)
				mat.set_shader_parameter(&"fade_end", fade_end)
				mat.set_shader_parameter(&"fade_max", fade_max)
			mi.set_surface_override_material(i, m)
