class_name UiKit
extends RefCounted
## Shared interface look: dark ink text on paper, vermilion for key words, hand-inked
## controls drawn procedurally. Owner: gameplay.

const INK := Color("1b1a1c")
const INK_FAINT := Color(0.106, 0.102, 0.11, 0.55)
const KEY_COLOR := "#a52a1c"

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20
	for type in ["Label", "Button", "CheckBox", "RichTextLabel"]:
		t.set_color("font_color", type, INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_color("font_hover_color", "Button", Palette.VERMILION_DEEP)
	t.set_color("font_pressed_color", "Button", Palette.VERMILION_DEEP)
	t.set_color("font_focus_color", "Button", Palette.VERMILION_DEEP)
	t.set_color("font_hover_pressed_color", "Button", Palette.VERMILION_DEEP)
	t.set_color("font_disabled_color", "Button", INK_FAINT)
	t.set_color("font_hover_color", "CheckBox", Palette.VERMILION_DEEP)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_hover_pressed_color", "CheckBox", Palette.VERMILION_DEEP)
	t.set_color("font_focus_color", "CheckBox", INK)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 10
	empty.content_margin_right = 10
	empty.content_margin_top = 4
	empty.content_margin_bottom = 6
	var under := StyleBoxFlat.new()
	under.bg_color = Color(Palette.VERMILION, 0.08)
	under.border_width_bottom = 3
	under.border_color = Palette.VERMILION
	under.content_margin_left = 10
	under.content_margin_right = 10
	under.content_margin_top = 4
	under.content_margin_bottom = 6
	var pressed := under.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(Palette.VERMILION, 0.18)
	for type in ["Button", "CheckBox"]:
		t.set_stylebox("normal", type, empty)
		t.set_stylebox("hover", type, under)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("focus", type, under)
		t.set_stylebox("disabled", type, empty)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(INK, 0.55)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.VERMILION
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var dot := ink_dot(18, INK)
	t.set_icon("grabber", "HSlider", dot)
	t.set_icon("grabber_highlight", "HSlider", ink_dot(18, Palette.VERMILION_DEEP))
	t.set_icon("unchecked", "CheckBox", ink_box(22, false))
	t.set_icon("checked", "CheckBox", ink_box(22, true))
	t.set_icon("unchecked_disabled", "CheckBox", ink_box(22, false))
	t.set_icon("checked_disabled", "CheckBox", ink_box(22, true))
	_theme = t
	return t


## A soft-edged ink dot.
static func ink_dot(px: int, color: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := Vector2(px, px) * 0.5
	for y in px:
		for x in px:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (px * 0.5)
			var wobble := 0.08 * sin(atan2(y - c.y, x - c.x) * 5.0)
			var a := clampf((0.92 + wobble - d) * 6.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(color, a))
	return ImageTexture.create_from_image(img)


## A hand-inked check box, with a vermilion tick when checked.
static func ink_box(px: int, checked: bool) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in px:
		for x in px:
			var edge := mini(mini(x, y), mini(px - 1 - x, px - 1 - y))
			var jitter := 1 if rng.randf() < 0.25 else 0
			if edge <= 1 + jitter and not (x > px * 0.7 and y < 3):
				img.set_pixel(x, y, INK)
	if checked:
		for i in 60:
			var t := i / 59.0
			var p: Vector2
			if t < 0.35:
				p = Vector2(0.22, 0.5).lerp(Vector2(0.42, 0.78), t / 0.35)
			else:
				p = Vector2(0.42, 0.78).lerp(Vector2(0.9, 0.08), (t - 0.35) / 0.65)
			var w := 1.0 + 1.6 * sin(PI * t)
			for oy in range(-2, 3):
				for ox in range(-2, 3):
					if Vector2(ox, oy).length() <= w:
						var px2 := clampi(int(p.x * px) + ox, 0, px - 1)
						var py2 := clampi(int(p.y * px) + oy, 0, px - 1)
						img.set_pixel(px2, py2, Palette.VERMILION_DEEP)
	return ImageTexture.create_from_image(img)


static func label(text: String, font_size: int = 20, color: Color = INK, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func rich(bbcode: String, font_size: int = 20) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_font_size_override("bold_font_size", font_size)
	r.add_theme_color_override("default_color", INK)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = bbcode
	return r


## Wraps a key word in the accent colour.
static func key(word: String) -> String:
	return "[color=%s]%s[/color]" % [KEY_COLOR, word]
