extends SceneTree

func _initialize() -> void:
	var root3 := Node3D.new()
	root.add_child(root3)
	var lay := MwLayout.data()
	var log_p: Dictionary = (lay.props as Array).filter(func(p: Dictionary) -> bool: return p.model == "log")[0]
	var n: Node3D = MwBuilder.place(root3, MwBuilder.instance("log", ""), MwLayout.v3(log_p.pos), float(log_p.yaw), 1.0, "log_1")
	var bodies := n.find_children("*", "CollisionObject3D", true, false)
	print("LOGDBG bodies=", bodies.size(), " ", bodies.map(func(b: Node) -> String: return "%s layer=%d" % [b.name, (b as CollisionObject3D).collision_layer]))
	var scene := load("res://scenes/levels/mosswater/mosswater.tscn") as PackedScene
	var st := scene.get_state()
	var free := Transform3D()
	for i in st.get_node_count():
		if st.get_node_name(i) == "LogFree":
			for k in st.get_node_property_count(i):
				if st.get_node_property_name(i, k) == "transform":
					free = st.get_node_property_value(i, k)
	print("LOGDBG free=", free)
	for pose: String in ["jammed", "free"]:
		if pose == "free":
			n.global_transform = free
		await physics_frame
		await physics_frame
		var space := root3.get_world_3d().direct_space_state
		for k: float in [0.5, 2.5, 4.5, 6.5]:
			var dir: Vector3 = -n.global_basis.z
			var p: Vector3 = n.global_position + Vector3(dir.x, 0, dir.z).normalized() * k
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 20.0, p + Vector3.DOWN * 20.0, 1)
			var hit := space.intersect_ray(q)
			print("LOGDBG %s k=%.1f at=(%.2f,%.2f) hit=%s" % [pose, k, p.x, p.z, str(hit.get("position", "none"))])
	quit()
