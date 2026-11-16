class_name TalkPanel
extends CanvasLayer
## Talk on a torn paper panel: the speaker's name, one line at a time, key words in the accent
## colour, advanced with a click, E, Enter or Space. While it is open the game is in the talk
## state (Orimi stands still, the brush is put away). Lines come from the level's data file
## (Level.lines). In a line, *word* is shown in the accent colour. Owner: gameplay.

signal finished

const AUTOPLAY_LINE_TIME := 1.1

var is_open := false
var _panel: PaperPanel
var _who: Label
var _text: RichTextLabel
var _more: Label
var _lines: Array = []
var _index := 0
var _state_before: StringName = Game.STATE_PLAYING
var _shown_at := 0.0
## A bark is showing (a line that does not stop play).
var barking := false
var _bark_serial := 0


func _ready() -> void:
	layer = Layers.CANVAS_HUD + 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	add_child(root)
	_panel = PaperPanel.new()
	_panel.seed_value = 21
	_panel.ragged = 9.0
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -430
	_panel.offset_right = 430
	_panel.offset_top = -200
	_panel.offset_bottom = -26
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 34
	v.offset_right = -34
	v.offset_top = 18
	v.offset_bottom = -14
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_who = UiKit.label("", 22, Palette.VERMILION_DEEP)
	v.add_child(_who)
	_text = UiKit.rich("", 22)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)
	_more = UiKit.label("click, E or Enter", 15, Palette.SEPIA, HORIZONTAL_ALIGNMENT_RIGHT)
	v.add_child(_more)


## Show lines (Array of {"who", "text"}) and return when the last one is dismissed.
## cutscene: the game was already in a cutscene; leave it there afterwards.
func run(lines: Array, cutscene: bool = false) -> void:
	if lines.is_empty():
		return
	if is_open:
		await finished
	_bark_serial += 1
	barking = false
	_lines = lines
	_index = 0
	is_open = true
	_state_before = Game.state if not cutscene else Game.STATE_CUTSCENE
	if Game.state != Game.STATE_CUTSCENE:
		Game.set_state(Game.STATE_TALK)
	if is_instance_valid(Game.player):
		Game.player.set(&"ai_move", Vector3.ZERO)
		Game.player.velocity = Vector3(0, Game.player.velocity.y, 0)
	visible = true
	_show_line()
	await finished


func close() -> void:
	if not is_open:
		visible = false
		return
	is_open = false
	visible = false
	# The key or click that closed the panel must not also jump or swipe: give play back a
	# moment later.
	await get_tree().create_timer(0.15, true, false, true).timeout
	if Game.state == Game.STATE_TALK and not is_open:
		Game.set_state(_state_before if _state_before != Game.STATE_TALK else Game.STATE_PLAYING)
	finished.emit()


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	_who.text = String(line.get("who", ""))
	_who.visible = _who.text != ""
	_text.text = accent(String(line.get("text", "")))
	_more.text = "click, E or Enter" if _index + 1 < _lines.size() else "click, E or Enter to finish"
	_shown_at = Time.get_ticks_msec() / 1000.0
	Game.qa_log("talk_line", {"who": _who.text, "index": _index, "of": _lines.size()})
	Audio.play_sfx(&"talk_next")


## A short remark on the panel that does not stop play: no talk state, no input taken, gone by
## itself after a few seconds a line. A real conversation replaces it; a bark never interrupts one.
func bark(lines: Array, seconds_per_line: float = 2.6) -> void:
	if is_open or lines.is_empty():
		return
	_bark_serial += 1
	var serial := _bark_serial
	barking = true
	for line: Dictionary in lines:
		if is_open or serial != _bark_serial:
			return
		_who.text = String(line.get("who", ""))
		_who.visible = _who.text != ""
		_text.text = accent(String(line.get("text", "")))
		_more.text = ""
		visible = true
		Game.qa_log("bark_line", {"who": _who.text})
		await get_tree().create_timer(seconds_per_line, false).timeout
	if serial == _bark_serial and not is_open:
		visible = false
		barking = false


## *word* -> the word in the accent colour.
static func accent(s: String) -> String:
	var re := RegEx.create_from_string("\\*([^*]+)\\*")
	return re.sub(s, "[color=%s]$1[/color]" % UiKit.KEY_COLOR, true)


func advance() -> void:
	if not is_open or Time.get_ticks_msec() / 1000.0 - _shown_at < 0.25:
		return
	_index += 1
	if _index >= _lines.size():
		close()
	else:
		_show_line()


func _process(_delta: float) -> void:
	if is_open and Game.autoplay and Time.get_ticks_msec() / 1000.0 - _shown_at > AUTOPLAY_LINE_TIME:
		advance()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var go := false
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		go = true
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_J]:
		go = true
	if go:
		advance()
		get_viewport().set_input_as_handled()
