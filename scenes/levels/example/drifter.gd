extends Node3D
## The example level's moving target for a catching Tie: a paper kite that drifts back and
## forth across the gap between SnareA and SnareB until the rope catches it. Owner: gameplay.

## Half the width of its drift (metres, along its own x) and seconds for one full swing.
@export var reach: float = 3.0
@export var period: float = 3.2

var caught := false
var _t := 0.0
var _start := Vector3.ZERO
var _kite: Node3D


func _ready() -> void:
	_start = position
	_kite = ModelKit.node(self, "Kite")
	ModelKit.part(_kite, "Sail", ModelKit.prism(Vector3(0.5, 0.6, 0.04)), Palette.PARCHMENT, Vector3.ZERO, Vector3(0, 0, 180))
	ModelKit.part(_kite, "Spar", ModelKit.box(Vector3(0.04, 0.6, 0.05)), Palette.VERMILION)
	ModelKit.add_ink_look(_kite, &"vermilion", false, 0.8)


func _physics_process(delta: float) -> void:
	_t += delta
	_kite.rotation.z = sin(_t * 3.0) * 0.25
	if caught:
		return
	position = _start + basis.x * sin(_t * TAU / period) * reach + Vector3.UP * sin(_t * 2.1) * 0.1


## Where the rope holds it.
func glyph_anchor() -> Vector3:
	return global_position


func on_caught(_post: Node) -> void:
	caught = true
