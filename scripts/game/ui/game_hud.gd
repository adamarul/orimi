class_name GameHud
extends CanvasLayer
## In-play interface: health petals, the ink pot and the beads on Orimi's cord on a torn paper scrap,
## tutorial prompts,
## the zone-restored banner, and a hint when the mouse is not captured. Owner: gameplay.

const INK_POT_SCENE := "res://scenes/brush/ink_pot.tscn"
const GLYPH_CARD_SCENE := "res://scenes/brush/glyph_card.tscn"

var petals: PetalHealth
var ink_pot: Control
var beads: BeadCord
var prompt_panel: PaperPanel
var prompt_text: RichTextLabel
var prompt_icon: GlyphIcon
var prompt_card_holder: Control
var banner: PaperPanel
var banner_title: Label
var banner_sub: Label
var capture_hint: Label
var prompt_id: StringName = &""

var _root: Control
var _prompt_timer := 0.0
var _banner_timer := 0.0


func _ready() -> void:
	layer = Layers.CANVAS_HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.theme()
	add_child(_root)

	var status := PaperPanel.new()
	status.seed_value = 3
	status.position = Vector2(14, 10)
	status.size = Vector2(214, 160)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(status)
	petals = PetalHealth.new()
	petals.position = Vector2(12, 10)
	petals.size = Vector2(108, 108)
	status.add_child(petals)
	if ResourceLoader.exists(INK_POT_SCENE):
		ink_pot = (load(INK_POT_SCENE) as PackedScene).instantiate() as Control
	else:
		ink_pot = InkPotFallback.new()
	ink_pot.position = Vector2(122, 16)
	ink_pot.custom_minimum_size = Vector2(84, 96)
	ink_pot.size = Vector2(84, 96)
	ink_pot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(ink_pot)
	beads = BeadCord.new()
	beads.bead_radius = 10.0
	beads.position = Vector2(18, 118)
	status.add_child(beads)

	prompt_panel = PaperPanel.new()
	prompt_panel.seed_value = 9
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_panel.anchor_left = 0.5
	prompt_panel.anchor_right = 0.5
	prompt_panel.anchor_top = 1.0
	prompt_panel.anchor_bottom = 1.0
	prompt_panel.offset_left = -390
	prompt_panel.offset_right = 390
	prompt_panel.offset_top = -132
	prompt_panel.offset_bottom = -22
	_root.add_child(prompt_panel)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 22
	row.offset_right = -22
	row.offset_top = 12
	row.offset_bottom = -12
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_panel.add_child(row)
	prompt_card_holder = Control.new()
	prompt_card_holder.custom_minimum_size = Vector2(86, 86)
	prompt_card_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt_card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(prompt_card_holder)
	prompt_icon = GlyphIcon.new()
	prompt_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	prompt_card_holder.add_child(prompt_icon)
	prompt_text = UiKit.rich("", 19)
	prompt_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(prompt_text)
	prompt_panel.visible = false

	banner = PaperPanel.new()
	banner.seed_value = 21
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -300
	banner.offset_right = 300
	banner.offset_top = 26
	banner.offset_bottom = 132
	_root.add_child(banner)
	var bv := VBoxContainer.new()
	bv.set_anchors_preset(Control.PRESET_FULL_RECT)
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(bv)
	banner_title = UiKit.label("", 36, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	banner_sub = UiKit.label("", 20, Palette.VERMILION_DEEP, HORIZONTAL_ALIGNMENT_CENTER)
	bv.add_child(banner_title)
	bv.add_child(banner_sub)
	banner.visible = false

	capture_hint = UiKit.label("Click to look around with the mouse", 17, UiKit.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	capture_hint.anchor_left = 1.0
	capture_hint.anchor_right = 1.0
	capture_hint.anchor_top = 1.0
	capture_hint.anchor_bottom = 1.0
	capture_hint.offset_left = -420
	capture_hint.offset_right = -18
	capture_hint.offset_top = -40
	capture_hint.offset_bottom = -14
	capture_hint.add_theme_color_override("font_outline_color", Palette.IVORY)
	capture_hint.add_theme_constant_override("outline_size", 6)
	capture_hint.visible = false
	_root.add_child(capture_hint)


func reset() -> void:
	petals.set_health(OrimiPlayer.MAX_HP, OrimiPlayer.MAX_HP)
	hide_prompt()
	banner.visible = false
	beads.refresh()
	Events.ink_changed.emit(Brush.ink, Brush.ink_max)


## Show a tutorial prompt. glyph (&"bloom", &"slash", &"gust") adds the stroke drawing.
func show_prompt(id: StringName, bbcode: String, glyph: StringName = &"", duration: float = 8.0) -> void:
	prompt_id = id
	prompt_text.text = bbcode
	for c in prompt_card_holder.get_children():
		if c != prompt_icon:
			c.queue_free()
	prompt_card_holder.visible = glyph != &""
	prompt_icon.visible = glyph != &""
	if glyph != &"":
		prompt_icon.glyph = glyph
		if ResourceLoader.exists(GLYPH_CARD_SCENE):
			var card := (load(GLYPH_CARD_SCENE) as PackedScene).instantiate()
			if card is Control and "glyph" in card:
				var c := card as Control
				c.custom_minimum_size = prompt_card_holder.custom_minimum_size
				c.set("show_name", false)
				c.set("glyph", String(glyph))
				prompt_card_holder.add_child(c)
				c.position = Vector2.ZERO
				c.size = prompt_card_holder.custom_minimum_size
				prompt_icon.visible = false
			else:
				card.queue_free()
	prompt_panel.seed_value = hash(id) % 1000
	prompt_panel.queue_redraw()
	prompt_panel.visible = true
	_prompt_timer = duration
	Game.qa_log("prompt", {"id": String(id)})


func hide_prompt(id: StringName = &"") -> void:
	if id != &"" and id != prompt_id:
		return
	if prompt_id != &"":
		Game.qa_log("prompt_hidden", {"id": String(prompt_id)})
	prompt_panel.visible = false
	prompt_id = &""


func show_banner(title: String, sub: String, duration: float = 3.5) -> void:
	banner_title.text = title
	banner_sub.text = sub
	banner.visible = true
	_banner_timer = duration


func _process(delta: float) -> void:
	if prompt_panel.visible and _prompt_timer > 0.0:
		_prompt_timer -= delta
		if _prompt_timer <= 0.0:
			hide_prompt()
	if banner.visible:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			banner.visible = false
	capture_hint.visible = visible and Game.is_playing() and not Game.autoplay \
		and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Brush.is_open() \
		and DisplayServer.get_name() != "headless"
