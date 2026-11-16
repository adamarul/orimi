class_name BrushTieHints
extends BrushInkCanvas
## Tie feedback while the brush is open: a faint dry ink ring round every tie post on screen; the
## ring goes dark and wet round the post a stroke starts on, and round the second post once the
## stroke's end is over it, so the player can see a Tie will land.

## Ring radius beyond the post's projected radius (pixels).
const RING_GAP := 14.0

var _posts: Array = []
var _height := 720.0
var _start := -1
var _hover := -1


func set_posts(posts: Array, height: float) -> void:
	_posts = posts
	_height = height
	_start = -1
	_hover = -1
	_rebuild()


func set_state(start: int, hover: int) -> void:
	if start == _start and hover == _hover:
		return
	_start = start
	_hover = hover
	_rebuild()


func _rebuild() -> void:
	var list: Array[Dictionary] = []
	for i in _posts.size():
		list.append(_ring(_posts[i]["pos"], float(_posts[i]["radius"]) + RING_GAP, i == _start or i == _hover, i))
	strokes = list


func _ring(centre: Vector2, radius: float, active: bool, index: int) -> Dictionary:
	var pts := PackedVector2Array()
	var start := -PI * 0.5 + float(index) * 1.7
	for k in 40:
		var a := start - TAU * 0.93 * float(k) / 39.0
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	var smooth := BrushStroke.smooth(pts, 2.0)
	var widths := PackedFloat32Array()
	var dry := PackedFloat32Array()
	widths.resize(smooth.size())
	dry.resize(smooth.size())
	widths.fill((0.009 if active else 0.004) * _height)
	dry.fill(0.15 if active else 0.75)
	var length := BrushStroke.path_length(smooth)
	var g := BrushStroke.build(smooth, widths, dry, length * 0.1, length * 0.25)
	var colors: PackedColorArray = g["colors"]
	for k in colors.size():
		colors[k].a = 1.0 if active else 0.45
	g["colors"] = colors
	return g
