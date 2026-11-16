class_name BrushStrokeView
extends Node2D
## Draws one ink stroke as it is painted. Raw input points arrive with a width and dryness
## each; the spline segments that can no longer change are smoothed and turned into triangles
## once and cached, and only the last few samples (the live tip and the end taper) are rebuilt
## per frame, so long strokes stay cheap in the browser.

const SHADER := preload("res://shaders/brush/ink_stroke.gdshader")

var height := 720.0
var _raw := PackedVector2Array()
var _raw_w := PackedFloat32Array()
var _raw_d := PackedFloat32Array()
# Final smoothed samples (segments 0 .. _segments - 1) and their attributes.
var _pts := PackedVector2Array()
var _pos := PackedFloat32Array()
var _w := PackedFloat32Array()
var _d := PackedFloat32Array()
var _segments := 0
# Triangles of samples [0, _baked).
var _baked := 0
var _cache := _empty()
var _geom := {}
var _finished := false
var _dirty := false


func _ready() -> void:
	if material == null:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		material = mat
	clear()


func clear() -> void:
	_raw.clear()
	_raw_w.clear()
	_raw_d.clear()
	_pts.clear()
	_pos.clear()
	_w.clear()
	_d.clear()
	_segments = 0
	_baked = 0
	_cache = _empty()
	_geom = {}
	_finished = false
	set_opacity(1.0)
	set_decay(0.0)
	queue_redraw()


func add_point(p: Vector2, width: float, dryness: float) -> void:
	if _finished:
		return
	if not _raw.is_empty() and _raw[_raw.size() - 1].distance_to(p) < BrushStroke.MIN_RAW_SPACING * height:
		return
	_raw.append(p)
	_raw_w.append(width)
	_raw_d.append(dryness)
	while _segments <= _raw.size() - 3:
		var before := _pts.size()
		BrushStroke.segment(_raw, _segments, BrushStroke.SAMPLE_SPACING * height, _pts, _pos)
		for i in range(before, _pts.size()):
			var k := int(_pos[i])
			var f := _pos[i] - float(k)
			_w.append(lerpf(_raw_w[k], _raw_w[k + 1], f))
			_d.append(lerpf(_raw_d[k], _raw_d[k + 1], f))
		_segments += 1
	_dirty = true


## Ends the stroke: the last segment is final and the end gets its full lift-off taper.
func finish() -> void:
	_finished = true
	_dirty = true


## Shows a whole stroke at once (injected strokes), at one speed in px/s.
func show_stroke(raw: PackedVector2Array, speed_px: float) -> void:
	clear()
	var wd := BrushStroke.width_for(speed_px, -1.0, height)
	for p in BrushStroke.clean(raw, BrushStroke.MIN_RAW_SPACING * height):
		add_point(p, wd.x, wd.y)
	finish()


func raw_points() -> PackedVector2Array:
	return _raw


func set_opacity(value: float) -> void:
	if material:
		(material as ShaderMaterial).set_shader_parameter(&"opacity", value)


func set_decay(value: float) -> void:
	if material:
		(material as ShaderMaterial).set_shader_parameter(&"decay", value)


func _process(_delta: float) -> void:
	if _dirty:
		_rebuild()
		_dirty = false
		queue_redraw()


func _draw() -> void:
	if not _geom.is_empty():
		BrushStroke.draw_geometry(self, _geom)


## A dab drawn where the raw points are, as wide as the widest of them.
func _dab() -> Dictionary:
	var centre := Vector2.ZERO
	var width := 0.0
	for i in _raw.size():
		centre += _raw[i]
		width = maxf(width, _raw_w[i])
	return BrushStroke.dab(centre / float(_raw.size()), width * 1.15)


func _empty() -> Dictionary:
	return {"verts": PackedVector2Array(), "uvs": PackedVector2Array(), "colors": PackedColorArray(), "indices": PackedInt32Array()}


func _rebuild() -> void:
	if _raw.is_empty():
		_geom = {}
		return
	if BrushGlyphs.is_dab(_raw, height):
		_geom = _dab()
		return
	# All samples: the final ones plus the provisional last segment and the last raw point.
	var pts := _pts.duplicate()
	var pos := _pos.duplicate()
	for k in range(_segments, _raw.size() - 1):
		BrushStroke.segment(_raw, k, BrushStroke.SAMPLE_SPACING * height, pts, pos)
	pts.append(_raw[_raw.size() - 1])
	pos.append(float(_raw.size() - 1))
	var n := pts.size()
	var w := _w.duplicate()
	var d := _d.duplicate()
	var tail_w := BrushStroke.interpolate(_raw_w, pos.slice(_w.size()))
	var tail_d := BrushStroke.interpolate(_raw_d, pos.slice(_d.size()))
	w.append_array(tail_w)
	d.append_array(tail_d)
	var arclen := BrushStroke.arc_lengths(pts)
	var total := arclen[n - 1]
	var start_len := BrushStroke.TAPER_START * height
	var end_len := BrushStroke.TAPER_LIVE * height
	if _finished:
		end_len = lerpf(BrushStroke.TAPER_END_SLOW, BrushStroke.TAPER_END_FAST, d[n - 1]) * height
	var widths := PackedFloat32Array()
	widths.resize(n)
	for i in n:
		widths[i] = w[i] * BrushStroke.taper(arclen[i], total, start_len, end_len)
	# Bake samples that are final, have a final neighbour, and lie further from the final end
	# than the longest end taper, so their triangles can never change again.
	var final_n := _pts.size()
	var safe := arclen[maxi(final_n - 1, 0)] - BrushStroke.TAPER_END_FAST * height
	var bake_to := _baked
	while bake_to < final_n - 1 and arclen[bake_to] < safe:
		bake_to += 1
	if bake_to > _baked:
		BrushStroke.append_geometry(pts, widths, d, arclen, _baked, bake_to, _cache["verts"], _cache["uvs"], _cache["colors"], _cache["indices"])
		_baked = bake_to
	var g := {
		"verts": (_cache["verts"] as PackedVector2Array).duplicate(),
		"uvs": (_cache["uvs"] as PackedVector2Array).duplicate(),
		"colors": (_cache["colors"] as PackedColorArray).duplicate(),
		"indices": (_cache["indices"] as PackedInt32Array).duplicate(),
	}
	BrushStroke.append_geometry(pts, widths, d, arclen, _baked, n, g["verts"], g["uvs"], g["colors"], g["indices"])
	_geom = g
