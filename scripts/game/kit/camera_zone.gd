class_name CameraZone
extends Node3D
## A box in the level where the camera behaves differently while Orimi is inside it. The
## highest priority zone containing her wins; the camera blends in and out over blend_time.
##   follow: the usual follow camera with overrides (distance, a locked pitch such as looking
##           up a shaft, a locked yaw, a raised pivot, a field of view).
##   fixed:  the camera sits at the view node (a Marker3D), optionally turning to watch Orimi.
##   frame:  the camera looks along the view node's -Z and backs off until Orimi and every
##           frame_targets node fit in the picture (a boss arena: both ends always in view).
## The camera never ends inside geometry in any mode. Owner: gameplay.

@export var size: Vector3 = Vector3(8, 6, 8)
@export_enum("follow", "fixed", "frame") var mode: String = "follow"
@export var priority: int = 0
@export var blend_time: float = 0.6
@export_group("Follow")
## Distance behind Orimi (0: unchanged).
@export var distance: float = 0.0
@export var lock_pitch: bool = false
## Degrees; negative looks down at Orimi, positive looks up (a shaft).
@export var pitch_deg: float = -16.0
@export var lock_yaw: bool = false
## World yaw in degrees: the camera looks toward -Z turned by this much.
@export var yaw_deg: float = 0.0
## Raise the point the camera looks at (metres).
@export var pivot_raise: float = 0.0
## Field of view in degrees (0: unchanged).
@export var fov: float = 0.0
@export_group("Fixed and frame")
## A Marker3D (or any Node3D): where the camera sits (fixed) or the direction it looks (frame).
@export var view: NodePath
## fixed: turn to keep Orimi in the middle of the picture.
@export var look_at_player: bool = true
## frame: nodes kept in the picture along with Orimi.
@export var frame_targets: Array[NodePath] = []
## frame: extra room around them, metres.
@export var margin: float = 2.5
## frame: the camera backs off at most this far from the middle of the picture (0: no limit).
@export var max_distance: float = 0.0
## frame: the camera never backs out of this zone's box (the room it frames), whatever the picture
## needs. Roofs need colliders as well, or the collision check cannot stop the camera at them.
@export var stay_inside: bool = false


func _ready() -> void:
	add_to_group(&"camera_zone")


func contains(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) <= size.x * 0.5 and absf(l.y) <= size.y * 0.5 and absf(l.z) <= size.z * 0.5


## How far from p along dir until leaving the box (INF if p is outside it or dir never leaves).
func exit_distance(p: Vector3, dir: Vector3) -> float:
	var l := to_local(p)
	var d := global_basis.inverse() * dir
	var half := size * 0.5
	var t := INF
	for i in 3:
		if absf(l[i]) > half[i]:
			return INF
		if absf(d[i]) > 0.0001:
			t = minf(t, ((half[i] if d[i] > 0.0 else -half[i]) - l[i]) / d[i])
	return t


func view_node() -> Node3D:
	return get_node_or_null(view) as Node3D


func frame_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for path in frame_targets:
		var n := get_node_or_null(path) as Node3D
		if n != null:
			out.append(n.global_position + Vector3.UP * 1.0)
	return out
