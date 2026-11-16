extends StaticBody3D
## QA fixture thorn gate: a slash cuts it. Owner: qa.


func on_glyph(glyph: StringName, _info: Dictionary) -> bool:
	if glyph != &"slash":
		return false
	Events.thorns_cut.emit(self, global_position)
	queue_free.call_deferred()
	return true
