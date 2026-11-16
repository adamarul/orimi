extends Node
## Autoload "Audio": music and sound effects. Owner: assets/audio.
##
## Everything is pre-rendered (audio/music/*.ogg, audio/sfx/*.ogg, made by tools/audio/); the web
## build cannot synthesise audio and reports no playback position, so nothing here reads one.
## No bus effects are used (the web build has none). Positional sounds are attenuated here by
## distance from the current camera instead of using AudioStreamPlayer3D, which is unreliable on
## the web; they are not panned.
##
## The director plays every event-driven sound itself and picks the music from game state and
## zone events (see _connect_events). It also hooks the level kit's own nodes by group when a
## level loads (kindle targets, tie posts, sealed fights, verse-stones; _hook_kit) and keeps the
## lamp hum on the nearest lit lamp. Gameplay calls play_sfx itself only for footstep, jump, land,
## ui_move, ui_accept, talk_next, pickup and raft (docs/ASSETS.md, Audio). Volumes follow
## Settings (master x music, master x sfx).
##
## Levels add their own tracks and sounds at run time from files under audio/levels/<id>/:
## register_music / register_sfx, then set_level_music to make a registered cursed/restored pair
## what the director plays in that level instead of the vale tracks (docs/ASSETS.md, Audio).

const MUSIC_IDS: Array[StringName] = [&"title", &"vale_cursed", &"vale_restored", &"finale"]
const SFX_IDS: Array[StringName] = [&"footstep", &"jump", &"land", &"swipe", &"hit", &"hurt",
	&"splotchet_hop", &"splotchet_die", &"reedwraith_moan", &"reedwraith_die", &"veil_off",
	&"brush_open", &"brush_close", &"brush_stroke", &"glyph_ok", &"glyph_fail", &"bloom", &"slash",
	&"gust", &"thorns_cut", &"soot_clear", &"zone_restore", &"petals", &"tree_restore", &"ink_pickup",
	&"ui_move", &"ui_accept", &"kindle", &"tie", &"verse_wake", &"talk_open", &"talk_next", &"pickup", &"bead",
	&"splash", &"curse_throwback", &"fight_seal", &"fight_won", &"unravel", &"clean_cut", &"raft", &"lamp_hum"]
## Built-in sounds that loop; the director plays them on their own players, never through play_sfx.
const LOOP_SFX: Array[StringName] = [&"lamp_hum"]
## Kindle targets of these kinds hum while lit.
const HUM_KINDS := ["lamp", "brazier"]
## The lamp hum is full within HUM_NEAR metres of the nearest lit lamp and gone past HUM_FAR.
const HUM_NEAR := 1.5
const HUM_FAR := 9.0
const HUM_DB := -6.0
## Random pitch spread per sound, so repeated sounds do not machine-gun.
const PITCH_SPREAD := {&"footstep": 0.12, &"swipe": 0.08, &"hit": 0.1, &"splotchet_hop": 0.15,
	&"brush_stroke": 0.1, &"ui_move": 0.04, &"land": 0.08, &"jump": 0.06, &"petals": 0.05}
## Per-sound trim in dB on top of the file level.
const TRIM := {&"footstep": -4.0, &"brush_stroke": -3.0, &"splotchet_hop": -3.0, &"reedwraith_moan": -2.0,
	&"unravel": -2.0}
const POOL_SIZE := 14
const SILENT_DB := -60.0
const DUCK_DB := -12.0
const PAUSE_DUCK_DB := -8.0
## Distance attenuation for positional sounds (metres from the camera).
const NEAR := 5.0
const FAR := 45.0
## Minimum seconds between two plays of the same id (footsteps and hops come in bursts).
const MIN_GAP := 0.045

## The music id currently playing or fading in, or &"" when silent.
var current_music: StringName = &""

var _music_streams := {}
var _sfx_streams := {}
var _trim := TRIM.duplicate()
var _spread := PITCH_SPREAD.duplicate()
var _level_cursed: StringName = &""
var _level_restored: StringName = &""
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _music_tweens := {}
var _duck_db := 0.0
var _duck_tween: Tween
var _brush_duck := false
var _pause_duck := false
var _last_played := {}
var _state: StringName = &""
var _inside_zone: StringName = &""
var _restored := {}
var _valley_restored := false
var _finale_timer: SceneTreeTimer
var _hum: AudioStreamPlayer
var _lamps: Array[Node3D] = []
var _stones: Array[Node3D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in MUSIC_IDS:
		var path := "res://audio/music/%s.ogg" % id
		if ResourceLoader.exists(path):
			_music_streams[id] = load(path)
	for id in SFX_IDS:
		var path := "res://audio/sfx/%s.ogg" % id
		if ResourceLoader.exists(path):
			_sfx_streams[id] = load(path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		add_child(p)
		_pool.append(p)
	_music_a = _make_music_player("MusicA")
	_music_b = _make_music_player("MusicB")
	_music_active = _music_a
	_hum = AudioStreamPlayer.new()
	_hum.name = "LampHum"
	_hum.stream = _sfx_streams.get(&"lamp_hum")
	_hum.volume_db = SILENT_DB
	add_child(_hum)
	Settings.volume_changed.connect(_apply_music_volume)
	_connect_events()
	_connect_game.call_deferred()


func _process(_delta: float) -> void:
	for stone in _stones:
		if not is_instance_valid(stone):
			continue
		var reading := bool(stone.get(&"reading"))
		if reading and not stone.get_meta(&"audio_reading", false):
			play_sfx(&"verse_wake", stone.global_position)
		stone.set_meta(&"audio_reading", reading)
	_step_hum()


## Register a music track at run time, usually a level's own under audio/levels/<id>/.
## source is an AudioStream or a res:// path. loop sets the stream's loop flag on a private
## copy, so the import settings of the file do not matter. Built-in ids cannot be replaced;
## registering a level id again replaces it. Returns false (with a warning) when nothing loads.
func register_music(id: StringName, source: Variant, loop: bool = true) -> bool:
	if id in MUSIC_IDS:
		push_warning("Audio: music id '%s' is built in and cannot be replaced" % id)
		return false
	var stream := _load_stream(source)
	if stream == null:
		return false
	if not ("loop" in stream):
		if loop:
			push_warning("Audio: music '%s' cannot loop (%s); use an OGG" % [id, stream.get_class()])
	elif bool(stream.get("loop")) != loop:
		stream = stream.duplicate() as AudioStream
		stream.set("loop", loop)
	_music_streams[id] = stream
	return true


## Register a one-shot sound at run time, with its trim in dB and random pitch spread (0.1 is
## plus or minus 10 %). Built-in ids cannot be replaced; a level id can be registered again.
func register_sfx(id: StringName, source: Variant, trim_db: float = 0.0, pitch_spread: float = 0.0) -> bool:
	if id in SFX_IDS:
		push_warning("Audio: sound id '%s' is built in and cannot be replaced" % id)
		return false
	var stream := _load_stream(source)
	if stream == null:
		return false
	if "loop" in stream and bool(stream.get("loop")):
		stream = stream.duplicate() as AudioStream
		stream.set("loop", false)
	_sfx_streams[id] = stream
	_trim[id] = trim_db
	_spread[id] = pitch_spread
	return true


func has_music(id: StringName) -> bool:
	return _music_streams.has(id)


func has_sfx(id: StringName) -> bool:
	return _sfx_streams.has(id)


## Make a level's registered pair the music the director plays while playing in that level:
## cursed until the zone Orimi stands in, or the whole level, is restored, then restored.
## restored = &"" keeps the cursed track throughout. already_restored starts the level restored
## (re-entering a finished level). set_level_music(&"") goes back to the vale tracks; so does the
## title screen. The change is heard at once when the game is playing.
func set_level_music(cursed: StringName, restored: StringName = &"", already_restored: bool = false) -> void:
	for id in [cursed, restored]:
		if id != &"" and not _music_streams.has(id):
			push_warning("Audio: set_level_music with unregistered id '%s'" % id)
			return
	_level_cursed = cursed
	_level_restored = restored if cursed != &"" else &""
	_valley_restored = already_restored
	_inside_zone = &""
	if _state == &"playing":
		_follow_valley(2.0)


## Play a one-shot sound. at = Vector3.INF plays it non-positionally.
func play_sfx(id: StringName, at: Vector3 = Vector3.INF, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _sfx_streams.get(id)
	if stream == null:
		push_warning("Audio: unknown sound id '%s'" % id)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(id, -1.0)) < MIN_GAP:
		return
	_last_played[id] = now
	var db := volume_db + float(_trim.get(id, 0.0)) + _linear_db(Settings.master_volume * Settings.sfx_volume)
	if at != Vector3.INF:
		var gain := _distance_gain(at)
		if gain <= 0.001:
			return
		db += linear_to_db(gain)
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stop()
	player.stream = stream
	player.volume_db = clampf(db, SILENT_DB, 6.0)
	var spread: float = _spread.get(id, 0.0)
	player.pitch_scale = 1.0 + randf_range(-spread, spread)
	player.play()


## Cross-fade to a music track by id. &"" fades music out.
func play_music(id: StringName, fade: float = 1.5) -> void:
	if id == current_music:
		return
	if id != &"" and not _music_streams.has(id):
		push_warning("Audio: unknown music id '%s'" % id)
		return
	current_music = id
	if _finale_timer and _finale_timer.timeout.is_connected(_after_finale):
		_finale_timer.timeout.disconnect(_after_finale)
	var old := _music_active
	_fade_player(old, SILENT_DB, fade, true)
	print("ORIMI_AUDIO music=%s fade=%.1f" % [id if id != &"" else &"off", fade])
	if id == &"":
		return
	var incoming := _music_b if old == _music_a else _music_a
	_music_active = incoming
	incoming.stop()
	incoming.stream = _music_streams[id]
	incoming.volume_db = SILENT_DB
	incoming.play()
	_fade_player(incoming, _music_target_db(), fade, false)
	if id == &"finale":
		_finale_timer = get_tree().create_timer(maxf(1.0, incoming.stream.get_length() - 1.0), true, false, true)
		_finale_timer.timeout.connect(_after_finale)


## Duck the music while the brush is open.
func set_brush_duck(on: bool) -> void:
	if on == _brush_duck:
		return
	_brush_duck = on
	_update_duck()


## True while the music is ducked for the brush or the pause menu.
func is_ducked() -> bool:
	return _brush_duck or _pause_duck


# --------------------------------------------------------------------------- internals

func _exit_tree() -> void:
	# Stop everything so quitting mid-fade leaves no tween or stream playback alive at exit.
	for t in _music_tweens.values():
		if t and (t as Tween).is_valid():
			(t as Tween).kill()
	_music_tweens.clear()
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	for c in get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).stop()
			(c as AudioStreamPlayer).stream = null
	_music_streams.clear()
	_sfx_streams.clear()
	# The audio thread releases stopped playbacks on its next mix; give it that mix before the
	# engine tears down, or quitting while music plays reports "resources still in use".
	OS.delay_msec(60)


func _make_music_player(node_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.volume_db = SILENT_DB
	add_child(p)
	return p


func _load_stream(source: Variant) -> AudioStream:
	if source is AudioStream:
		return source
	var path := str(source)
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		push_warning("Audio: no audio stream at '%s'" % path)
	return stream


func _linear_db(v: float) -> float:
	return SILENT_DB if v <= 0.001 else linear_to_db(v)


func _music_target_db() -> float:
	return _linear_db(Settings.master_volume * Settings.music_volume) + _duck_db


func _fade_player(p: AudioStreamPlayer, to_db: float, seconds: float, stop_after: bool) -> void:
	var old: Tween = _music_tweens.get(p)
	if old and old.is_valid():
		old.kill()
	if seconds <= 0.0:
		p.volume_db = to_db
		if stop_after:
			p.stop()
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, seconds).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tw.tween_callback(p.stop)
	_music_tweens[p] = tw


func _apply_music_volume() -> void:
	if current_music != &"":
		_fade_player(_music_active, _music_target_db(), 0.15, false)


func _update_duck() -> void:
	var target := 0.0
	if _brush_duck:
		target = DUCK_DB
	elif _pause_duck:
		target = PAUSE_DUCK_DB
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck, _duck_db, target, 0.25)


func _set_duck(db: float) -> void:
	_duck_db = db
	var t: Tween = _music_tweens.get(_music_active)
	if current_music != &"" and not (t and t.is_valid()):
		_music_active.volume_db = _music_target_db()


func _distance_gain(at: Vector3) -> float:
	var listener := _listener()
	if listener == Vector3.INF:
		return 1.0
	var d := listener.distance_to(at)
	var t := clampf((d - NEAR) / (FAR - NEAR), 0.0, 1.0)
	return (1.0 - t) * (1.0 - t)


## Where positional sounds are heard from, or Vector3.INF with no camera and no player.
func _listener() -> Vector3:
	var listener := Vector3.INF
	var cam := get_viewport().get_camera_3d()
	if cam:
		listener = cam.global_position
	if Game.player and is_instance_valid(Game.player):
		# Halfway between camera and player keeps sounds near the fox at full level.
		listener = Game.player.global_position if listener == Vector3.INF else listener.lerp(Game.player.global_position, 0.5)
	return listener


## The finale has played out: the level (or the vale) is restored for good.
func _after_finale() -> void:
	if current_music == &"finale":
		_valley_restored = true
		play_music(_valley_music(), 3.0)


## Play the cursed or restored track for where Orimi is, unless the finale is playing: nothing
## interrupts the finale but the title screen; _after_finale moves on from it.
func _follow_valley(fade: float) -> void:
	if current_music != &"finale":
		play_music(_valley_music(), fade)


func _valley_music() -> StringName:
	var cursed := &"vale_cursed" if _level_cursed == &"" else _level_cursed
	var restored := &"vale_restored" if _level_cursed == &"" else _level_restored
	if restored == &"":
		return cursed
	if _valley_restored or (_inside_zone != &"" and _restored.has(_inside_zone)):
		return restored
	return cursed


# --------------------------------------------------------------------------- event reactions

func _connect_events() -> void:
	Events.brush_opened.connect(func() -> void:
		set_brush_duck(true)
		play_sfx(&"brush_open"))
	Events.brush_closed.connect(func() -> void:
		set_brush_duck(false)
		play_sfx(&"brush_close"))
	Events.glyph_cast.connect(func(glyph: StringName, info: Dictionary) -> void:
		play_sfx(&"glyph_ok", Vector3.INF, -4.0)
		var at: Vector3 = info.get("world_center", Vector3.INF)
		if glyph in [&"bloom", &"slash", &"gust"]:
			play_sfx(glyph, at))
	Events.glyph_failed.connect(func(_info: Dictionary) -> void: play_sfx(&"glyph_fail"))
	Events.player_attacked.connect(func(_attack: StringName, _origin: Transform3D) -> void: play_sfx(&"swipe"))
	Events.player_damaged.connect(func(_hp: int, _max_hp: int) -> void: play_sfx(&"hurt"))
	Events.player_healed.connect(func(_hp: int, _max_hp: int) -> void: play_sfx(&"ink_pickup"))
	Events.player_died.connect(func() -> void:
		play_sfx(&"hurt", Vector3.INF, 2.0)
		play_sfx(&"brush_close", Vector3.INF, -3.0))
	Events.player_respawned.connect(func(_at: Vector3) -> void: play_sfx(&"petals"))
	Events.enemy_hit.connect(func(enemy: Node3D, _damage: float, at: Vector3) -> void:
		play_sfx(&"hit", at)
		var hp: Variant = enemy.get(&"hp") if is_instance_valid(enemy) else null
		if hp != null and float(hp) <= 0.0:
			play_sfx(&"unravel", at))
	Events.enemy_died.connect(func(_enemy: Node3D, kind: StringName, at: Vector3) -> void:
		play_sfx(&"reedwraith_die" if kind == &"reedwraith" else &"splotchet_die", at)
		play_sfx(&"ink_pickup", Vector3.INF, -6.0))
	Events.enemy_unveiled.connect(func(enemy: Node3D) -> void:
		play_sfx(&"veil_off", enemy.global_position if is_instance_valid(enemy) else Vector3.INF))
	Events.thorns_cut.connect(func(_target: Node3D, at: Vector3) -> void: play_sfx(&"thorns_cut", at))
	Events.soot_cleared.connect(func(_target: Node3D, at: Vector3) -> void: play_sfx(&"soot_clear", at))
	Events.zone_entered.connect(func(zone_id: StringName) -> void:
		_inside_zone = zone_id
		if _state == &"playing":
			_follow_valley(2.5))
	Events.zone_exited.connect(func(zone_id: StringName) -> void:
		if _inside_zone == zone_id:
			_inside_zone = &""
		if _state == &"playing":
			_follow_valley(2.5))
	Events.zone_restore_started.connect(func(_zone_id: StringName, _center: Vector3, _radius: float) -> void:
		play_sfx(&"zone_restore")
		play_sfx(&"petals", Vector3.INF, -3.0))
	Events.zone_restored.connect(func(zone_id: StringName) -> void:
		_restored[zone_id] = true
		if _state == &"playing" or _state == &"cutscene":
			_follow_valley(3.0))
	Events.finale_started.connect(func(_center: Vector3) -> void:
		play_sfx(&"tree_restore")
		play_music(&"finale", 2.0))
	Events.valley_restored.connect(func() -> void:
		_valley_restored = true
		play_sfx(&"petals"))
	Events.game_state_changed.connect(_on_state)
	if Events.has_signal(&"bead_awarded"):
		Events.connect(&"bead_awarded", func(_level_id: StringName, _color: Color) -> void: play_sfx(&"bead"))
	if Events.has_signal(&"player_thrown_back"):
		Events.connect(&"player_thrown_back", func(at: Vector3, cause: StringName) -> void:
			play_sfx(&"splash" if cause == &"water" else &"curse_throwback", at))


## Game is a later autoload than Audio, so its signals are connected once both are in the tree.
func _connect_game() -> void:
	Game.level_loaded.connect(func(_level: Node) -> void:
		_lamps.clear()
		_stones.clear()
		hook_kit()
		hook_kit.call_deferred())
	Game.enemy_finished.connect(func(enemy: Node3D) -> void:
		play_sfx(&"clean_cut", enemy.global_position if is_instance_valid(enemy) else Vector3.INF))


## Hook the level kit's nodes in the tree (by group) that are not hooked yet. Called on every
## level load; call it again after adding kit nodes to a running level.
func hook_kit() -> void:
	var tree := get_tree()
	for n: Node in tree.get_nodes_in_group(&"kindle_target"):
		if not n.has_meta(&"audio_hooked") and n.has_signal(&"kindled"):
			n.set_meta(&"audio_hooked", true)
			n.connect(&"kindled", func() -> void: play_sfx(&"kindle", (n as Node3D).global_position))
			if String(n.get(&"kind")) in HUM_KINDS:
				_lamps.append(n as Node3D)
	for n: Node in tree.get_nodes_in_group(&"tie_post"):
		if not n.has_meta(&"audio_hooked") and n.has_signal(&"tied_up"):
			n.set_meta(&"audio_hooked", true)
			n.connect(&"tied_up", func(other: Node) -> void:
				if is_instance_valid(other) and n.get_instance_id() < other.get_instance_id():
					play_sfx(&"tie", ((n as Node3D).global_position + (other as Node3D).global_position) * 0.5))
	for n: Node in tree.get_nodes_in_group(&"sealed_fight"):
		if not n.has_meta(&"audio_hooked") and n.has_signal(&"fight_started"):
			n.set_meta(&"audio_hooked", true)
			n.connect(&"fight_started", func() -> void: play_sfx(&"fight_seal", (n as Node3D).global_position))
			n.connect(&"fight_won", func() -> void: play_sfx(&"fight_won", (n as Node3D).global_position))
	for n: Node in tree.get_nodes_in_group(&"verse_stone"):
		if not n.has_meta(&"audio_hooked"):
			n.set_meta(&"audio_hooked", true)
			_stones.append(n as Node3D)


## The lamp hum: one looping player whose level follows the nearest lit lamp, so a street of
## lamps costs one voice. Silent outside play.
func _step_hum() -> void:
	var nearest := INF
	if _state == &"playing" and _hum.stream != null:
		var listener := _listener()
		for lamp in _lamps:
			if is_instance_valid(lamp) and bool(lamp.get(&"lit")) and lamp.is_inside_tree():
				nearest = minf(nearest, 0.0 if listener == Vector3.INF else listener.distance_to(lamp.global_position))
	if nearest >= HUM_FAR:
		if _hum.playing:
			_hum.stop()
		return
	var t := clampf((nearest - HUM_NEAR) / (HUM_FAR - HUM_NEAR), 0.0, 1.0)
	_hum.volume_db = clampf(HUM_DB + linear_to_db(maxf((1.0 - t) * (1.0 - t), 0.001)) + _linear_db(Settings.master_volume * Settings.sfx_volume), SILENT_DB, 0.0)
	if not _hum.playing:
		_hum.play()


## True while the lamp hum is sounding.
func is_humming() -> bool:
	return _hum.playing


func _on_state(state: StringName) -> void:
	var previous := _state
	_state = state
	_pause_duck = state == &"paused"
	_update_duck()
	match state:
		&"title":
			_restored.clear()
			_valley_restored = false
			_inside_zone = &""
			_level_cursed = &""
			_level_restored = &""
			play_music(&"title", 2.0)
		&"playing":
			if previous != &"paused":
				_follow_valley(2.0)
		&"talk":
			if previous != &"talk":
				play_sfx(&"talk_open")
