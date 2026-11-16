extends Node
## The main scene: the title screen (with a level loading behind it), level intro cards,
## loading and travel between levels by Pell's raft, the end of a level (bead, raft), the end
## card, plus mouse capture, pause, talk and the tutorial prompts. Levels come from
## scenes/levels/levels.json through LevelRegistry. Owner: gameplay.

const PROMPTS := {
	&"move": ["[b]W A S D[/b] to run.  [b]Mouse[/b] or [b]arrow keys[/b] to look around.", &"", 9.0],
	&"jump": ["[b]Space[/b] to leap.", &"", 5.0],
	&"gate_a": ["Thorns bar the path. Hold [b]Shift[/b], [b]Q[/b] or the [b]right mouse button[/b] to take up the brush, then draw one stroke straight across them: %s.", &"slash", 14.0],
	&"fight": ["Ink-spawn! [b]Click[/b] or [b]J[/b] to whip your tail; strike again quickly for a second swipe.", &"", 8.0],
	&"bloom_ready": ["The ground is quiet. Take up the brush and draw a circle around the withered sapling: %s.", &"bloom", 14.0],
	&"not_clear": ["The sapling will not wake while ink-spawn remain nearby.", &"", 5.0],
	&"not_ready": ["Something here is not ready to wake yet.", &"", 5.0],
	&"gate_b": ["Soot hangs across the ramp. Take up the brush and draw a stroke with one loop through it: %s.", &"gust", 14.0],
	&"veil": ["A veiled reedwraith turns every blow. Strip its veil with a %s, then strike.", &"gust", 8.0],
	&"final_wave": ["The spilled ink rises to guard the great camphor!", &"", 5.0],
	&"tree_wait": ["Clear the ink-spawn from the rise first.", &"", 5.0],
	&"tree_saplings": ["The camphor stirs, but its roots still drink from a cursed zone. Wake both saplings first.", &"", 7.0],
	&"tree_bloom": ["The rise is clear. Draw a circle around the great camphor: %s.", &"bloom", 16.0],
	&"finish": ["It is unravelling! A quick %s through it now is a clean cut.", &"slash", 6.0],
	&"talk": ["[b]E[/b] or [b]Enter[/b] to talk.", &"", 4.0],
	&"sealed": ["The ink has closed a ring around you. Nothing leaves until every one of them is gone.", &"", 6.0],
	&"cursed_ground": ["The spilled ink burns. Keep to the clean ground.", &"", 5.0],
}
## Prompts that teach a control: each shows once per save (Game.teach), never over a fight or a
## talk, and leaves as soon as the control has been used once.
const CONTROL_PROMPTS: Array[StringName] = [&"move", &"jump", &"fight"]
const KEY_WORDS := {&"slash": "Slash", &"bloom": "Bloom", &"gust": "Gust", &"kindle": "Kindle", &"tie": "Tie"}

var world: Node3D
var level: Level
## The level shown behind the title or being played (kept for older callers).
var valley: Level
var hud: GameHud
var pause_menu: PauseMenu
var talk: TalkPanel
var title_ready := false
var intro_open := false
var end_open := false
var loading := false
## Pell's raft is bringing Orimi in; control comes after.
var arriving := false
## The raft moment playing now (any key skips it).
var raft_trip: RaftTrip
var _arrive_next := false

var _menu: CanvasLayer
var _title: Control
var _title_buttons: VBoxContainer
var _title_list: VBoxContainer
var _title_progress: InkProgress
var _title_status: Label
var _intro: Control
var _intro_text: RichTextLabel
var _end: Control
var _end_stats: RichTextLabel
var _travel: Control
var _travel_text: RichTextLabel
var _travel_progress: InkProgress
var _fade: ColorRect
var _title_time := 0.0
var _was_captured := false
var _brush_closed_at := -10.0
var _pause_opened_at := 0.0
var _end_opened_at := 0.0
var _shown: Dictionary = {}
var _hint_at: Dictionary = {}
var _spawn_pos := Vector3.ZERO
var _first_title := true
var _autoplay_started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.main = self
	Game.read_options()
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	hud = GameHud.new()
	hud.name = "Hud"
	hud.visible = false
	add_child(hud)
	talk = TalkPanel.new()
	talk.name = "Talk"
	add_child(talk)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	_build_menus()
	Events.brush_closed.connect(func() -> void: _brush_closed_at = _now())
	Events.zone_restored.connect(_on_zone_restored)
	Events.enemy_unveiled.connect(func(_e: Node3D) -> void: hud.hide_prompt(&"veil"))
	Events.player_attacked.connect(func(_a: StringName, _o: Transform3D) -> void: hud.hide_prompt(&"fight"))
	Game.apply_beads()
	if Game.start_level != &"" and not LevelRegistry.find(Game.start_level).is_empty():
		_start_direct(Game.start_level)
	else:
		go_to_title()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- screens ------------------------------------------------------------------------------

func _build_menus() -> void:
	_menu = CanvasLayer.new()
	_menu.layer = Layers.CANVAS_MENU
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = Layers.CANVAS_FADE
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(Palette.IVORY, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)

	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.theme = UiKit.theme()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(_title)
	var wash := ColorRect.new()
	wash.color = Color(Palette.IVORY, 1.0)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.name = "Wash"
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(wash)
	var panel := PaperPanel.new()
	panel.seed_value = 12
	panel.ragged = 10.0
	panel.stains = 7
	panel.position = Vector2(70, 90)
	panel.size = Vector2(540, 500)
	_title.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 44
	v.offset_right = -40
	v.offset_top = 30
	v.offset_bottom = -26
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(UiKit.label("Orimi", 96))
	v.add_child(UiKit.label("The Unfaded Vale", 32, Palette.VERMILION_DEEP))
	v.add_child(UiKit.label("Book One: Upriver", 18, Palette.SEPIA))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	_title_progress = InkProgress.new()
	_title_progress.custom_minimum_size = Vector2(0, 22)
	v.add_child(_title_progress)
	_title_status = UiKit.label("Grinding the ink...", 18, Palette.SEPIA)
	v.add_child(_title_status)
	_title_buttons = VBoxContainer.new()
	_title_buttons.add_theme_constant_override("separation", 2)
	_title_buttons.visible = false
	v.add_child(_title_buttons)
	_title_list = VBoxContainer.new()
	_title_list.add_theme_constant_override("separation", 0)
	_title_list.visible = false
	v.add_child(_title_list)
	var footer := UiKit.label("Esc: rest    F2 or O: paper intensity", 16, UiKit.INK)
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = 78
	footer.offset_top = -44
	footer.offset_bottom = -18
	footer.offset_right = 700
	footer.add_theme_color_override("font_outline_color", Palette.IVORY)
	footer.add_theme_constant_override("outline_size", 6)
	_title.add_child(footer)

	_intro = _card("", "Click or press any key")
	_intro_text = _intro.get_meta(&"text") as RichTextLabel
	_end = _card("", "Click or press any key to return to the title")
	_end_stats = _end.get_meta(&"text") as RichTextLabel
	_travel = _card("", "")
	_travel_text = _travel.get_meta(&"text") as RichTextLabel
	_travel_progress = InkProgress.new()
	_travel_progress.custom_minimum_size = Vector2(0, 22)
	(_travel_text.get_parent() as Container).add_child(_travel_progress)


func _card(text: String, footer: String) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.theme()
	root.visible = false
	_menu.add_child(root)
	var wash := ColorRect.new()
	wash.color = Color(Palette.PARCHMENT, 0.82)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wash)
	var panel := PaperPanel.new()
	panel.seed_value = 30 + root.get_index()
	panel.ragged = 10.0
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = -210
	panel.offset_bottom = 210
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 56
	v.offset_right = -56
	v.offset_top = 46
	v.offset_bottom = -34
	panel.add_child(v)
	var body := UiKit.rich(text, 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	if footer != "":
		v.add_child(UiKit.label(footer, 18, Palette.SEPIA, HORIZONTAL_ALIGNMENT_RIGHT))
	root.set_meta(&"text", body)
	return root


func fade(to: float, duration: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", to, duration)
	await t.finished


func _hide_screens() -> void:
	pause_menu.close()
	talk.close()
	hud.visible = false
	_title.visible = false
	_intro.visible = false
	_end.visible = false
	_travel.visible = false
	intro_open = false
	end_open = false
	title_ready = false


## Free the current level and load another by registry id. on_progress gets (fraction, text).
func load_level(id: StringName, on_progress: Callable) -> bool:
	var entry := LevelRegistry.find(id)
	if entry.is_empty():
		push_error("Main: no playable level '%s'" % id)
		return false
	loading = true
	if is_instance_valid(level):
		level.queue_free()
		level = null
		valley = null
		await get_tree().process_frame
	Game.reset_run()
	_shown.clear()
	_hint_at.clear()
	await get_tree().process_frame
	level = (load(String(entry["scene"])) as PackedScene).instantiate() as Level
	if level == null:
		push_error("Main: %s does not have a Level root" % entry["scene"])
		loading = false
		return false
	if level.level_id == &"":
		level.level_id = id
	if level.display_name == "":
		level.display_name = String(entry.get("name", id))
	if level.chapter == "":
		level.chapter = String(entry.get("chapter", ""))
	valley = level
	world.add_child(level)
	await level.build_async(on_progress)
	loading = false
	Game.level_loaded.emit(level)
	return true


func title_level_id() -> StringName:
	var current := StringName(String(Game.progress.get("current", "")))
	if current != &"" and not LevelRegistry.find(current).is_empty():
		return current
	return LevelRegistry.first_id()


func go_to_title() -> void:
	if loading:
		return
	get_tree().paused = false
	Game.set_state(Game.STATE_TITLE)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hide_screens()
	_title.visible = true
	_title_buttons.visible = false
	_title_list.visible = false
	_title_progress.visible = true
	_title_status.text = "Grinding the ink..."
	_title_progress.value = 0.0
	(_title.get_node(^"Wash") as ColorRect).color.a = 1.0
	var id := title_level_id()
	if not await load_level(id, _on_title_progress):
		_title_status.text = "No levels found."
		return
	level.camera.cinematic = true
	_title_time = 0.0
	_update_title_camera(0.0)
	create_tween().tween_property(_title.get_node(^"Wash"), "color:a", 0.0, 1.2)
	_title_status.text = ""
	_title_progress.visible = false
	_build_title_buttons()
	title_ready = true
	Game.qa_log("title_ready", {"t": snappedf(_now(), 0.01), "level": String(id)})
	if _first_title:
		_first_title = false
		var warp := String(Boot.opt("warp", ""))
		if warp != "" and not Game.autoplay:
			_begin_play(warp)
			return
	if Game.autoplay and not _autoplay_started:
		_start_autoplay()


func _start_autoplay() -> void:
	_autoplay_started = true
	var ap := AutoplayDirector.new()
	ap.name = "Autoplay"
	add_child(ap)


## level=<id>: no title, straight into the level (autoplay runs only this level).
func _start_direct(id: StringName) -> void:
	_hide_screens()
	Game.set_state(Game.STATE_CUTSCENE)
	await _travel_to(id, "")
	_first_title = false
	# arrive=1: play Pell's raft bringing Orimi in, as after travel (for checking a level's data).
	_arrive_next = String(Boot.opt("arrive", "0")) == "1"
	if Game.autoplay:
		title_ready = true
		_start_autoplay()
		return
	var warp := String(Boot.opt("warp", ""))
	_begin_play(warp)


func _on_title_progress(fraction: float, text: String) -> void:
	_title_progress.value = fraction
	_title_status.text = text + "..."


func _build_title_buttons() -> void:
	for c in _title_buttons.get_children():
		c.queue_free()
	var any_done: bool = not (Game.progress["completed"] as Array).is_empty()
	var first := _title_button(_title_buttons, "Continue" if any_done else "Begin", start_game)
	if any_done:
		_title_button(_title_buttons, "Chapters", _show_chapters)
		_title_button(_title_buttons, "Begin anew", new_journey)
	first.grab_focus()
	_title_buttons.visible = true


func _title_button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	b.focus_entered.connect(func() -> void: Audio.play_sfx(&"ui_move"))
	parent.add_child(b)
	return b


func _show_chapters() -> void:
	for c in _title_list.get_children():
		c.queue_free()
	var levels := LevelRegistry.levels()
	var first: Button = null
	for i in levels.size():
		var e: Dictionary = levels[i]
		var id := StringName(e["id"])
		var open := i == 0 or Game.is_level_completed(StringName(levels[i - 1]["id"])) or Game.is_level_completed(id)
		var b := _title_button(_title_list, "%d. %s" % [i + 1, String(e.get("name", id))], choose_level.bind(id))
		b.add_theme_font_size_override("font_size", 22)
		b.disabled = not open
		if Game.is_level_completed(id):
			b.text += "   (%s bead)" % String(e.get("bead", ""))
		if first == null and open:
			first = b
	_title_button(_title_list, "Back", func() -> void:
		_title_list.visible = false
		_title_buttons.visible = true
		(_title_buttons.get_child(0) as Button).grab_focus())
	_title_buttons.visible = false
	_title_list.visible = true
	if first != null:
		first.grab_focus()


## Title: play the level shown behind the title (Begin / Continue).
func start_game() -> void:
	if not title_ready or Game.state != Game.STATE_TITLE:
		return
	Audio.play_sfx(&"ui_accept")
	_show_intro()


## Title: play a chosen level from the chapter list.
func choose_level(id: StringName) -> void:
	if not title_ready:
		return
	Audio.play_sfx(&"ui_accept")
	title_ready = false
	if level != null and level.level_id == id:
		_show_intro()
		return
	Game.set_state(Game.STATE_CUTSCENE)
	_title.visible = false
	await _travel_to(id, "")
	_show_intro()


## Title: forget saved progress and start from the first level.
func new_journey() -> void:
	if not title_ready:
		return
	Game.reset_progress()
	choose_level(LevelRegistry.first_id())


func _show_intro() -> void:
	title_ready = false
	Game.set_state(Game.STATE_CUTSCENE)
	_title.visible = false
	_title_buttons.visible = false
	_title_list.visible = false
	var head := "[font_size=34]%s[/font_size]\n[color=%s]%s[/color]\n\n" % [level.display_name, UiKit.KEY_COLOR, level.chapter]
	_intro_text.text = head + level.intro_text
	_intro.visible = true
	intro_open = true
	Game.qa_log("intro", {"level": String(level.level_id)})


func dismiss_intro() -> void:
	if not intro_open:
		return
	intro_open = false
	Audio.play_sfx(&"ui_accept")
	_intro.visible = false
	_begin_play("")


func _begin_play(warp: String) -> void:
	_title.visible = false
	_travel.visible = false
	var by_raft := _arrive_next and warp == "" and RaftTrip.can_arrive(level)
	_arrive_next = false
	if by_raft:
		arriving = true
		hud.visible = false
		level.player.control_enabled = false
		raft_trip = RaftTrip.new(level)
		raft_trip.moment.connect(_on_raft_moment.bind(level))
		level.add_child(raft_trip)
		await raft_trip.arrive()
		raft_trip = null
		arriving = false
	level.camera.release()
	level.player.control_enabled = true
	level.camera.snap_behind(level.player)
	if warp != "":
		level.apply_warp(warp)
	_spawn_pos = level.player.global_position
	hud.reset()
	hud.visible = true
	Game.set_state(Game.STATE_PLAYING)
	Game.capture_mouse()
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_teach(&"move")
	Game.qa_log("play_started", Game.debug_snapshot())


## Show the travel card and load a level behind it. line is Pell's line on the card.
func _travel_to(id: StringName, line: String) -> bool:
	var entry := LevelRegistry.find(id)
	var head := "[font_size=30]%s[/font_size]\n[color=%s]%s[/color]\n\n" % [String(entry.get("name", id)), UiKit.KEY_COLOR, String(entry.get("chapter", ""))]
	_travel_text.text = head + line
	_travel_progress.value = 0.0
	_travel.visible = true
	var ok := await load_level(id, func(f: float, _t: String) -> void: _travel_progress.value = f)
	_travel.visible = false
	return ok


func show_pause(on: bool) -> void:
	if on:
		_pause_opened_at = _now()
		pause_menu.open()
	else:
		pause_menu.close()
		# Capture comes back a frame or more later (never for Escape in a browser); re-arm the
		# lost-capture pause only once it really has.
		_was_captured = false


# --- the end of a level -------------------------------------------------------------------

## A raft moment (autoplay takes a shot): "<level>_<stage>".
signal moment(stage: String)


func _on_raft_moment(stage: String, l: Level) -> void:
	moment.emit("%s_%s" % [String(l.level_id), stage])


## Called by Level.complete(): the bead, Pell's raft, then the next level or the end card.
func finish_level(l: Level) -> void:
	if l != level:
		return
	Game.set_state(Game.STATE_CUTSCENE)
	hud.hide_prompt()
	l.player.control_enabled = false
	l.player.velocity = Vector3.ZERO
	var id := l.level_id
	var entry := LevelRegistry.find(id)
	var next := LevelRegistry.next_after(id)
	var new_bead := not Game.is_level_completed(id) and entry.has("bead") and not LevelRegistry.is_dev(id)
	if not LevelRegistry.is_dev(id):
		Game.mark_level_complete(id, next if next != &"" else id)
	if new_bead:
		hud.visible = true
		hud.show_banner("The %s bead" % String(entry["bead"]), "a remembered colour on Orimi's cord; the ink pot holds more", 4.0)
		Game.qa_log("bead", {"level": String(id), "bead": String(entry["bead"]), "ink_max": Brush.ink_max})
		Events.bead_awarded.emit(id, Color(String(entry.get("bead_color", "#efe6d2"))))
		await get_tree().create_timer(4.2).timeout
	var raft: Dictionary = l.data.get("raft", {})
	var by_raft := RaftTrip.can_depart(l)
	if by_raft:
		raft_trip = RaftTrip.new(l)
		raft_trip.moment.connect(_on_raft_moment.bind(l))
		l.add_child(raft_trip)
		await raft_trip.depart()
		raft_trip = null
	elif raft.has("talk"):
		await talk.run(l.lines(String(raft["talk"])), true)
	if next == &"":
		if by_raft:
			await fade(1.0, 0.5)
			_show_end(l)
			await fade(0.0, 0.4)
			return
		_show_end(l)
		return
	var line := String(raft.get("card", "Pell poles the raft upriver."))
	if not by_raft:
		Audio.play_sfx(&"raft")
	await fade(1.0, 0.5)
	_arrive_next = true
	hud.visible = false
	await _travel_to(next, line)
	await fade(0.0, 0.4)
	if Game.autoplay:
		Game.qa_log("level_arrived", {"level": String(next)})
		title_ready = true
		_show_intro()
		return
	_show_intro()


func _show_end(l: Level) -> void:
	Game.set_state(Game.STATE_ENDED)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	var secs := (Time.get_ticks_msec() - Game.run_started_msec) / 1000.0
	var head: String = l.data.get("end_text", "")
	if head == "":
		var entry := LevelRegistry.find(l.level_id)
		head = "[font_size=34]%s[/font_size]" % l.display_name
		if l.chapter != "":
			head += "\n\n%s" % l.chapter
		if entry.has("bead"):
			head += "\n\nThe %s bead is on Orimi's cord." % String(entry["bead"])
	var beads := Game.bead_colors().size()
	# The last level of a finished book counts the whole book (each level's latest completion);
	# anywhere else the numbers are this level's and say so.
	var totals := Game.book_totals() if LevelRegistry.in_book(l.level_id) and LevelRegistry.next_after(l.level_id) == &"" else {}
	var scope := "This level"
	var kills := Game.kills
	var deaths := Game.deaths
	if not totals.is_empty():
		scope = "The whole book, %d levels" % int(totals["levels"])
		secs = float(totals["time"])
		kills = int(totals["kills"])
		deaths = int(totals["deaths"])
	_end_stats.text = head + "\n\n[i]%s[/i]\n%s  %d:%02d      %s  %d      %s  %d      %s  %d" % [
		scope, UiKit.key("Time"), int(secs) / 60, int(secs) % 60, UiKit.key("Ink-spawn undone"), kills, UiKit.key("Falls"), deaths, UiKit.key("Beads"), beads]
	# Only a book level without its own ending says the book goes on: never the last level (it
	# has end_text) and never a dev level played on its own.
	var footer := not l.data.has("end_text") and LevelRegistry.in_book(l.level_id) and LevelRegistry.book_unfinished()
	if footer:
		_end_stats.text += "\n\nThe river goes on upstream. More of the book is still being written."
	_end.visible = true
	end_open = true
	_end_opened_at = _now()
	await _fit_card(_end)
	var info := Game.debug_snapshot()
	info["footer"] = footer
	info["stats"] = {"scope": scope, "time": int(secs), "kills": kills, "deaths": deaths, "beads": beads}
	Game.qa_log("end_card", info)


## Grow a card to its text, and shrink the text if even the tallest card would not hold it, so
## nothing runs off the card at any window size.
func _fit_card(card: Control) -> void:
	var body := card.get_meta(&"text") as RichTextLabel
	var panel := body.get_parent().get_parent() as Control
	var room := get_viewport().get_visible_rect().size.y - 40.0
	for font_size: int in [22, 20, 18, 16]:
		body.add_theme_font_size_override(&"normal_font_size", font_size)
		body.add_theme_font_size_override(&"bold_font_size", font_size)
		panel.offset_top = -room * 0.5
		panel.offset_bottom = room * 0.5
		await get_tree().process_frame
		await get_tree().process_frame
		var need := body.get_content_height() + 46.0 + 34.0 + 40.0
		if need <= room or font_size == 16:
			var h := clampf(need, 420.0, room)
			panel.offset_top = -h * 0.5
			panel.offset_bottom = h * 0.5
			Game.qa_log("card_fit", {"font_size": font_size, "height": int(h), "room": int(room)})
			return


func dismiss_end() -> void:
	if not end_open:
		return
	end_open = false
	Audio.play_sfx(&"ui_accept")
	await fade(1.0, 0.4)
	go_to_title()
	await fade(0.0, 0.6)


# --- input --------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo)
	if not pressed:
		return
	if event is InputEventKey and (event as InputEventKey).keycode in [KEY_F2, KEY_O]:
		return
	if raft_trip != null and raft_trip.playing and not talk.is_open and not Game.autoplay:
		raft_trip.skip()
		get_viewport().set_input_as_handled()
		return
	if intro_open:
		dismiss_intro()
		get_viewport().set_input_as_handled()
	elif end_open and _now() - _end_opened_at > 1.2:
		dismiss_end()
		get_viewport().set_input_as_handled()
	elif Game.state == Game.STATE_PLAYING and event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Brush.is_open() and not Game.autoplay:
		Game.capture_mouse()
		_was_captured = true
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not event.is_echo():
		if Game.state == Game.STATE_PLAYING:
			Game.pause_game()
		elif Game.state == Game.STATE_PAUSED and _now() - _pause_opened_at > 0.3:
			Game.resume_game()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and Game.state == Game.STATE_PLAYING and not Game.autoplay and not _unattended():
		Game.pause_game()


# --- per frame ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Game.state == Game.STATE_TITLE and is_instance_valid(level) and level.built:
		_title_time += delta
		_update_title_camera(_title_time)
	if hud.prompt_id in CONTROL_PROMPTS and Game.state == Game.STATE_TALK:
		hud.hide_prompt()
	if Game.state == Game.STATE_PLAYING:
		_watch_capture()
		_direct_prompts()


func _update_title_camera(t: float) -> void:
	level.camera.global_transform = level.title_camera(t)


## In the browser, Escape always releases the pointer lock and the game never sees the key, so
## losing capture during play is treated as a pause. The brush shows the cursor on purpose,
## so capture changes around it are ignored.
func _watch_capture() -> void:
	if Game.autoplay or _unattended():
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _was_captured and not captured and not Brush.is_open() and _now() - _brush_closed_at > 0.6:
		_was_captured = false
		Game.pause_game()
		return
	_was_captured = captured


## Screenshot runs open a window nobody is using; never pause them for lost focus or capture.
func _unattended() -> bool:
	return Boot.options.has("screenshot")


# --- prompts ------------------------------------------------------------------------------

func _prompt(id: StringName) -> void:
	var spec: Array = PROMPTS[id]
	var text: String = spec[0]
	if spec[1] != &"":
		text = text % UiKit.key(KEY_WORDS[spec[1]])
	hud.show_prompt(id, text, spec[1], spec[2])
	_shown[id] = true


## Called by zones and enemies when something needs explaining right now (rate-limited).
func hint(id: StringName) -> void:
	if not PROMPTS.has(id) or Game.state != Game.STATE_PLAYING:
		return
	if _now() - float(_hint_at.get(id, -100.0)) < 6.0:
		return
	_hint_at[id] = _now()
	_prompt(id)


## A level object asks for its prompt while Orimi is near: a PROMPTS id, or its own text
## (BBCode; %s becomes the glyph's name in the accent colour).
func prompt_near(id: StringName, text: String, glyph: StringName) -> void:
	if Game.state != Game.STATE_PLAYING or hud.prompt_id == id:
		return
	if text == "":
		if PROMPTS.has(id):
			_prompt(id)
		return
	if text.contains("%s"):
		text = text % UiKit.key(String(KEY_WORDS.get(glyph, String(glyph).capitalize())))
	hud.show_prompt(id, text, glyph if KEY_WORDS.has(glyph) else &"", 12.0)
	_shown[id] = true


func hide_prompt(id: StringName = &"") -> void:
	hud.hide_prompt(id)


func _direct_prompts() -> void:
	var p := level.player
	if not is_instance_valid(p):
		return
	var pos := p.global_position
	var fighting := _in_fight(pos)
	match hud.prompt_id:
		&"move":
			if pos.distance_to(_spawn_pos) > 3.0 or fighting:
				hud.hide_prompt()
		&"jump":
			if (not p.is_on_floor() and p.velocity.y > 1.0) or fighting:
				hud.hide_prompt()
	if Game.taught(&"move") and not Game.taught(&"jump") and not fighting and pos.distance_to(_spawn_pos) > 5.0 and hud.prompt_id == &"":
		_teach(&"jump")
	if not Game.taught(&"fight") or not _shown.has(&"veil"):
		for e: Node in get_tree().get_nodes_in_group(Layers.GROUP_ENEMY):
			var enemy := e as EnemyBase
			if enemy == null or enemy.global_position.distance_to(pos) > 12.0:
				continue
			if enemy is Reedwraith and (enemy as Reedwraith).veiled and not _shown.has(&"veil"):
				_prompt(&"veil")
				_hint_at[&"veil"] = _now()
			elif enemy is Splotchet and enemy.aggro and not Game.taught(&"fight"):
				_teach(&"fight")


## A control prompt, the first time on this save.
func _teach(id: StringName) -> void:
	if Game.taught(id):
		return
	Game.teach(id)
	_prompt(id)


## True while a sealed fight runs or an ink-spawn near Orimi is after her.
func _in_fight(pos: Vector3) -> bool:
	for f: Node in get_tree().get_nodes_in_group(&"sealed_fight"):
		if f.get(&"started") and not f.get(&"done"):
			return true
	for e: Node in get_tree().get_nodes_in_group(Layers.GROUP_ENEMY):
		var enemy := e as EnemyBase
		if enemy != null and enemy.aggro and enemy.global_position.distance_to(pos) < 14.0:
			return true
	return false


func _on_zone_restored(zone_id: StringName) -> void:
	if not is_instance_valid(level):
		return
	var z: CursedZone = null
	for n: Node in get_tree().get_nodes_in_group(Layers.GROUP_CURSED_ZONE):
		if (n as CursedZone).zone_id == zone_id:
			z = n
	if z == null or z.finale:
		return
	hud.hide_prompt(&"bloom_ready")
	hud.show_banner(z.display_name if z.display_name != "" else String(zone_id), "colour restored")
