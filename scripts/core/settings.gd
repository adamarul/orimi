extends Node
## Autoload "Settings": player-facing options. Owner: lead (OKAA-1).

signal paper_intensity_changed(level: int)
signal volume_changed
signal controls_changed

enum Paper { LIGHT, NORMAL, HEAVY }
const PAPER_NAMES: Array[StringName] = [&"light", &"normal", &"heavy"]
const PAPER_LABELS: Array[String] = ["Light", "Normal", "Heavy"]

var paper_intensity: int = Paper.NORMAL:
	set(value):
		value = clampi(value, Paper.LIGHT, Paper.HEAVY)
		if value == paper_intensity:
			return
		paper_intensity = value
		_push_paper_global()
		paper_intensity_changed.emit(value)

var master_volume: float = 1.0:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		volume_changed.emit()
var music_volume: float = 0.8:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		volume_changed.emit()
var sfx_volume: float = 1.0:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		volume_changed.emit()

var mouse_sensitivity: float = 1.0:
	set(value):
		mouse_sensitivity = clampf(value, 0.1, 4.0)
		controls_changed.emit()
var invert_y: bool = false:
	set(value):
		invert_y = value
		controls_changed.emit()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_push_paper_global()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"paper_cycle"):
		cycle_paper()


func cycle_paper() -> void:
	paper_intensity = (paper_intensity + 1) % PAPER_NAMES.size()


func paper_name() -> StringName:
	return PAPER_NAMES[paper_intensity]


func paper_label() -> String:
	return PAPER_LABELS[paper_intensity]


## 0.0 for Light, 0.5 for Normal, 1.0 for Heavy. Also pushed to the
## "paper_intensity" global shader uniform.
func paper_amount() -> float:
	return float(paper_intensity) / float(Paper.HEAVY)


func _push_paper_global() -> void:
	RenderingServer.global_shader_parameter_set(&"paper_intensity", paper_amount())
