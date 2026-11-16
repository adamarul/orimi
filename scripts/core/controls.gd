extends Node
## Autoload "Controls": registers the input actions at start-up. Owner: lead (OKAA-1).
## Actions are defined here rather than in project.godot so they are readable and reviewable.
## Ask the lead to add or change an action.


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_action(&"move_forward", [_key(KEY_W)])
	_action(&"move_back", [_key(KEY_S)])
	_action(&"move_left", [_key(KEY_A)])
	_action(&"move_right", [_key(KEY_D)])
	_action(&"cam_left", [_key(KEY_LEFT)])
	_action(&"cam_right", [_key(KEY_RIGHT)])
	_action(&"cam_up", [_key(KEY_UP)])
	_action(&"cam_down", [_key(KEY_DOWN)])
	_action(&"jump", [_key(KEY_SPACE)])
	_action(&"attack", [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_J)])
	_action(&"brush", [_key(KEY_SHIFT), _key(KEY_Q), _mouse(MOUSE_BUTTON_RIGHT)])
	_action(&"brush_draw", [_mouse(MOUSE_BUTTON_LEFT)])
	_action(&"pause", [_key(KEY_ESCAPE), _key(KEY_P)])
	_action(&"paper_cycle", [_key(KEY_F2), _key(KEY_O)])


func _action(action: StringName, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
