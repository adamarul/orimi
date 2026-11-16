class_name VfxTrail
extends VfxRibbon
## A ribbon that follows a node (Vfx.attach_trail). Owner: vfx. Set emitting to start and stop
## it. It samples the node every frame while the tree runs, so the curve is smooth, but it is
## only redrawn on the 12 fps grid, so it moves in steps like everything else. It frees itself
## once its node is gone and its last stroke has faded.

## While true, the node's position is recorded into the trail.
var emitting := false
## Seconds a point stays in the trail.
var lifetime := 0.25
## Half width of the ribbon at its head, in metres.
var width := 0.12
var target: Node3D

var _points := PackedVector3Array()
var _times := PackedFloat32Array()
var _clock := 0.0


func _process(delta: float) -> void:
	_clock += delta
	if not is_instance_valid(target):
		emitting = false
		target = null
		if _points.is_empty():
			queue_free()
			return
	elif emitting:
		var p := target.global_position
		if _points.is_empty() or _points[_points.size() - 1].distance_to(p) > 0.02:
			_points.append(p)
			_times.append(_clock)
	while not _times.is_empty() and _clock - _times[0] > lifetime:
		_points.remove_at(0)
		_times.remove_at(0)


func step(_dt: float) -> void:
	var n := _points.size()
	if n < 2:
		visible = false
		_imesh.clear_surfaces()
		return
	var pts := PackedVector3Array()
	var widths := PackedFloat32Array()
	var us := PackedFloat32Array()
	pts.resize(n)
	widths.resize(n)
	us.resize(n)
	for i in n:
		var j := n - 1 - i
		var age := clampf((_clock - _times[j]) / lifetime, 0.0, 1.0)
		pts[i] = _points[j]
		us[i] = age
		widths[i] = width * (1.0 - age) * minf(1.0, float(i) / 2.0 + 0.4)
	build(pts, widths, us, us, 0.0, 1.0, 0.0)
