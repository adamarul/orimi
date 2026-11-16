class_name Boot
extends Node
## Main scene. Parses run options, loads the requested scene, and handles screenshot and quit.
## No game logic lives here.
##
## Options come from user command-line arguments on desktop (after "--") and from the URL query
## string on web, with the same keys:
##   scene=res://path.tscn   scene to load (default DEFAULT_SCENE)
##   screenshot=<path>       desktop only: save the viewport image after shot_after seconds, then quit
##   shot_after=<seconds>    delay before the screenshot, counted from the first drawn frame (default 1)
##   quit_after=<seconds>    quit after this long, counted from the first drawn frame
##   paper=light|normal|heavy
## Any other key=value pair is kept and readable with Boot.opt(key, default).
## Prints "ORIMI_FIRST_FRAME ..." once the loaded scene has drawn its first frame.

const DEFAULT_SCENE := "res://scenes/game/main.tscn"
const PAPER_LEVELS: PackedStringArray = ["light", "normal", "heavy"]
const FIRST_FRAME_MARKER := "ORIMI_FIRST_FRAME"

static var options: Dictionary = {}
static var paper: String = "normal"


static func opt(key: String, default_value: Variant = "") -> Variant:
	return options.get(key, default_value)


static func is_web() -> bool:
	return OS.has_feature("web")


func _ready() -> void:
	options = _read_options()
	var requested_paper := String(opt("paper", paper)).to_lower()
	if requested_paper in PAPER_LEVELS:
		paper = requested_paper
		Settings.paper_intensity = PAPER_LEVELS.find(paper)
	else:
		push_warning("Boot: unknown paper level '%s', using '%s'" % [requested_paper, paper])
	print("ORIMI_BOOT t=%.2fs options=%s" % [Time.get_ticks_msec() / 1000.0, JSON.stringify(options)])

	var scene_path := String(opt("scene", DEFAULT_SCENE))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Boot: cannot load scene '%s'" % scene_path)
		get_tree().quit(1)
		return
	var instance := packed.instantiate()
	get_tree().root.add_child.call_deferred(instance)
	await get_tree().process_frame
	get_tree().current_scene = instance

	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	print("%s t=%.2fs scene=%s renderer=%s driver=%s adapter=%s api=%s display=%s" % [
		FIRST_FRAME_MARKER,
		Time.get_ticks_msec() / 1000.0,
		scene_path,
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version(),
		DisplayServer.get_name(),
	])

	if options.has("quit_after"):
		_quit_later(float(opt("quit_after")))
	if options.has("screenshot"):
		if is_web():
			push_warning("Boot: screenshot= is desktop only; the browser smoke check captures web screenshots")
		else:
			_screenshot_later(String(opt("screenshot")), float(opt("shot_after", 1.0)))


func _read_options() -> Dictionary:
	var parsed := {}
	var pairs: PackedStringArray = []
	if is_web():
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		var query := String(search) if search != null else ""
		pairs = query.trim_prefix("?").split("&", false)
	else:
		pairs = OS.get_cmdline_user_args()
	for pair in pairs:
		var item := pair.trim_prefix("--")
		var eq := item.find("=")
		if eq < 0:
			parsed[item.uri_decode()] = "1"
		else:
			parsed[item.substr(0, eq).uri_decode()] = item.substr(eq + 1).uri_decode()
	return parsed


func _quit_later(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	print("ORIMI_QUIT after=%.2f" % seconds)
	get_tree().quit(0)


func _screenshot_later(path: String, seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	if err != OK:
		push_error("Boot: could not save screenshot to '%s' (error %d)" % [path, err])
		get_tree().quit(1)
		return
	print("ORIMI_SCREENSHOT path=%s size=%dx%d" % [path, image.get_width(), image.get_height()])
	get_tree().quit(0)
