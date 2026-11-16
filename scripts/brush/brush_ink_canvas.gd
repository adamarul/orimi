class_name BrushInkCanvas
extends Node2D
## Draws a set of finished ink strokes with the ink stroke shader. Used by the ink pot and the
## glyph card. Each stroke is a geometry dictionary from BrushStroke.build / build_simple.

const SHADER := preload("res://shaders/brush/ink_stroke.gdshader")

var strokes: Array[Dictionary] = []:
	set(value):
		strokes = value
		queue_redraw()


func _init() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat


func set_param(param: StringName, value: Variant) -> void:
	(material as ShaderMaterial).set_shader_parameter(param, value)


func _draw() -> void:
	for g in strokes:
		BrushStroke.draw_geometry(self, g)
