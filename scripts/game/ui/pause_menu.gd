class_name PauseMenu
extends CanvasLayer
## Pause menu on a torn paper sheet: resume, settings (paper intensity, volumes, mouse
## sensitivity, invert Y), a controls list, a glyph guide, and return to title. Owner: gameplay.

const CONTROLS := [
	["Run", "W A S D"],
	["Look around", "Mouse (click the game first) or arrow keys"],
	["Leap", "Space"],
	["Tail swipe", "Left mouse button or J  (press again for a second swipe)"],
	["Take up the brush", "Hold Left Shift, Q or the right mouse button"],
	["Paint a glyph", "Drag with the left mouse button or a pen, then let go of the brush"],
	["Pause", "Esc or P"],
	["Paper intensity", "F2 or O"],
]
const GLYPHS := [
	[&"bloom", "Bloom", "A closed circle drawn around something. Wakes a withered sapling once its zone is clear, and the great camphor at the end."],
	[&"slash", "Slash", "One straight stroke from side to side. Cuts thorn gates, and cuts down ink-spawn."],
	[&"gust", "Gust", "A stroke with a single loop in it. Blows soot away and strips the veil from a reedwraith."],
	[&"kindle", "Kindle", "A quick dab of the brush, barely moving, on a wick. Lights lamps, braziers and lantern-fruit."],
	[&"tie", "Tie", "One straight line from one tie post to another, at any angle. Ties a rope between them."],
]

var _pages: Dictionary = {}
var _paper_buttons: Array[Button] = []
var _first: Button
var _syncing := false


func _ready() -> void:
	layer = Layers.CANVAS_MENU
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.42)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var sheet := PaperPanel.new()
	sheet.seed_value = 44
	sheet.ragged = 9.0
	sheet.stains = 8
	sheet.anchor_left = 0.5
	sheet.anchor_right = 0.5
	sheet.anchor_top = 0.5
	sheet.anchor_bottom = 0.5
	sheet.offset_left = -440
	sheet.offset_right = 440
	sheet.offset_top = -280
	sheet.offset_bottom = 280
	root.add_child(sheet)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 40
	row.offset_right = -40
	row.offset_top = 34
	row.offset_bottom = -34
	row.add_theme_constant_override("separation", 30)
	sheet.add_child(row)

	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(220, 0)
	nav.add_theme_constant_override("separation", 6)
	row.add_child(nav)
	nav.add_child(UiKit.label("Resting", 40))
	var sub := UiKit.label("the world holds still", 17, Palette.SEPIA)
	nav.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	nav.add_child(gap)
	_first = _nav_button(nav, "Resume", func() -> void: Game.resume_game())
	_nav_button(nav, "Settings", _show_page.bind("settings"))
	_nav_button(nav, "Controls", _show_page.bind("controls"))
	_nav_button(nav, "Glyph guide", _show_page.bind("glyphs"))
	var gap2 := Control.new()
	gap2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(gap2)
	_nav_button(nav, "Return to title", func() -> void: Game.return_to_title())

	var divider := ColorRect.new()
	divider.color = Color(Palette.INK, 0.35)
	divider.custom_minimum_size = Vector2(2, 0)
	row.add_child(divider)

	var content := Control.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(content)
	_pages["settings"] = _build_settings()
	_pages["controls"] = _build_controls()
	_pages["glyphs"] = _build_glyphs()
	for p: Control in _pages.values():
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.add_child(p)
	_show_page("settings")
	Settings.paper_intensity_changed.connect(func(_l: int) -> void: _sync_paper())


func open() -> void:
	visible = true
	_sync_paper()
	_show_page("settings")
	_first.grab_focus()


func close() -> void:
	visible = false


func _nav_button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(func() -> void:
		Audio.play_sfx(&"ui_accept")
		action.call())
	b.mouse_entered.connect(func() -> void: Audio.play_sfx(&"ui_move"))
	parent.add_child(b)
	return b


func _show_page(page: String) -> void:
	for k: String in _pages:
		(_pages[k] as Control).visible = k == page


func _heading(parent: Control, text: String) -> void:
	var l := UiKit.label(text, 26)
	parent.add_child(l)


func _build_settings() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_heading(v, "Settings")
	var paper_row := HBoxContainer.new()
	paper_row.add_theme_constant_override("separation", 8)
	var pl := UiKit.label("Paper", 20)
	pl.custom_minimum_size = Vector2(180, 0)
	paper_row.add_child(pl)
	var group := ButtonGroup.new()
	for i in Settings.PAPER_LABELS.size():
		var b := Button.new()
		b.text = Settings.PAPER_LABELS[i]
		b.toggle_mode = true
		b.button_group = group
		b.toggled.connect(func(on: bool) -> void:
			if on and not _syncing:
				Settings.paper_intensity = i)
		paper_row.add_child(b)
		_paper_buttons.append(b)
	v.add_child(paper_row)
	_slider(v, "Master volume", 0.0, 1.0, 0.05, Settings.master_volume, func(x: float) -> void: Settings.master_volume = x)
	_slider(v, "Music", 0.0, 1.0, 0.05, Settings.music_volume, func(x: float) -> void: Settings.music_volume = x)
	_slider(v, "Effects", 0.0, 1.0, 0.05, Settings.sfx_volume, func(x: float) -> void: Settings.sfx_volume = x)
	_slider(v, "Mouse sensitivity", 0.2, 3.0, 0.05, Settings.mouse_sensitivity, func(x: float) -> void: Settings.mouse_sensitivity = x)
	var inv := CheckBox.new()
	inv.text = "Invert vertical look"
	inv.button_pressed = Settings.invert_y
	inv.toggled.connect(func(on: bool) -> void: Settings.invert_y = on)
	v.add_child(inv)
	return v


func _slider(parent: Control, text: String, lo: float, hi: float, step: float, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var l := UiKit.label(text, 20)
	l.custom_minimum_size = Vector2(180, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(260, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(x: float) -> void: on_change.call(x))
	row.add_child(s)
	parent.add_child(row)


func _sync_paper() -> void:
	_syncing = true
	for i in _paper_buttons.size():
		_paper_buttons[i].button_pressed = i == Settings.paper_intensity
	_syncing = false


func _build_controls() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_heading(v, "Controls")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 8)
	for c: Array in CONTROLS:
		var a := UiKit.label(c[0], 18, Palette.VERMILION_DEEP)
		a.custom_minimum_size = Vector2(170, 0)
		grid.add_child(a)
		var b := UiKit.label(c[1], 18)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(340, 0)
		grid.add_child(b)
	v.add_child(grid)
	return v


func _build_glyphs() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_heading(v, "Glyph guide")
	v.add_child(UiKit.rich("Hold the brush key, paint one stroke over what you want to touch, then let go.", 17))
	for g: Array in GLYPHS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var icon: Control
		if ResourceLoader.exists(GameHud.GLYPH_CARD_SCENE):
			icon = (load(GameHud.GLYPH_CARD_SCENE) as PackedScene).instantiate() as Control
			icon.custom_minimum_size = Vector2(96, 96)
			icon.set("show_name", false)
			icon.set("glyph", String(g[0]))
		else:
			var drawn := GlyphIcon.new()
			drawn.glyph = g[0]
			icon = drawn
			icon.custom_minimum_size = Vector2(84, 84)
		row.add_child(icon)
		var text := UiKit.rich("[font_size=22]%s[/font_size]\n%s" % [UiKit.key(g[1]), g[2]], 17)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(text)
		v.add_child(row)
	return v
