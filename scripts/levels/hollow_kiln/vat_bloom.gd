extends BloomTarget
## CrackedVat, the cracked vat as the finale's Bloom target (Zone_vat in hollow_kiln.tscn, finale = true): no
## model of its own (the vat is part of the set), a body over the vat for the brush, and the tree
## (the set's VatTree) grows when the zone hands over to HollowKiln.run_finale. Owner: l5 (hollow_kiln).

const RADIUS := 3.0
const HEIGHT := 2.5


func _ready() -> void:
	add_to_group(Layers.GROUP_BRUSH_TARGET)
	collision_layer = Layers.BRUSH_TARGET
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = HEIGHT
	shape.shape = cyl
	shape.position = Vector3(0, HEIGHT * 0.5, 0)
	add_child(shape)
	model = Node3D.new()
	add_child(model)


func glyph_anchor() -> Vector3:
	return global_position + Vector3.UP * 1.0


func glyph_radius() -> float:
	return 2.6


func play_bloom() -> void:
	bloomed = true


func set_bloomed() -> void:
	bloomed = true
