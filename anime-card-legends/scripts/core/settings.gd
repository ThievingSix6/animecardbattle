extends Node

# =========================================================
# SETTINGS (autoload)
#
# Player preferences, stored globally rather than per save slot: volume
# and battle speed belong to the person playing, not to the profile they
# happen to have open.
#
# Written to user://settings.cfg on change, debounced so dragging a
# slider does not hit the disk every frame.
# =========================================================

signal changed

const PATH := "user://settings.cfg"
const SAVE_DEBOUNCE := 0.4

# Battle speed multiplies how fast rounds resolve. 1.0 is the designed
# pace; the labels are what the settings screen and battle HUD show.
const BATTLE_SPEEDS: Array[float] = [0.5, 1.0, 1.5, 2.0, 4.0]
const BATTLE_SPEED_LABELS: Array[String] = ["0.5x", "1x", "1.5x", "2x", "4x"]

# --- Rocket Arena ------------------------------------------------------
#
# The camera numbers are Rocket League's, with RL's own ranges and
# defaults, so anyone who has set a camera up over there can type the
# same values in here and get the same view.
const CAMERA_DEFAULTS := {
	"fov": 110.0,          # 60 - 110
	"distance": 270.0,     # 100 - 400, in uu
	"height": 100.0,       # 40 - 200, in uu
	"angle": -4.0,         # -15 - 0, degrees
	"stiffness": 0.45,     # 0 - 1
	"swivel": 3.0,         # 1 - 10
	"transition": 1.0,     # 0 - 2
}
const CAMERA_RANGES := {
	"fov": [60.0, 110.0],
	"distance": [100.0, 400.0],
	"height": [40.0, 200.0],
	"angle": [-15.0, 0.0],
	"stiffness": [0.0, 1.0],
	"swivel": [1.0, 10.0],
	"transition": [0.0, 2.0],
}
const CAMERA_LABELS := {
	"fov": "Field of View",
	"distance": "Distance",
	"height": "Height",
	"angle": "Angle",
	"stiffness": "Stiffness",
	"swivel": "Swivel Speed",
	"transition": "Transition Speed",
}
# The order they are shown in, which is RL's order.
const CAMERA_KEYS: Array[String] = [
	"fov", "distance", "height", "angle", "stiffness", "swivel", "transition",
]

const TEAM_SIZES: Array[int] = [1, 2]

var sfx_volume := 0.8
var music_volume := 0.5
var battle_speed_index := 1
var reduce_flashing := false

# Rocket Arena. camera is a copy of CAMERA_DEFAULTS; ball_cam is whether
# the view starts locked to the ball; team_size is 1 for 1v1 and 2 for
# 2v2.
var camera: Dictionary = CAMERA_DEFAULTS.duplicate()
var ball_cam := true
var team_size := 1

# Rebound controls, action name -> {"key": scancode, "button": index}.
# Only actions the player actually changed appear here; everything else
# stays on the default Controls registers at startup.
var bindings: Dictionary = {}

# Developer mode. Global rather than per save, so it survives switching
# profiles and never ends up baked into someone's save file.
#
# While it is on, every campaign floor is treated as unlocked, so the
# late zones can be walked into and looked at without grinding to them.
var dev_mode := false

var _dirty := false
var _cooldown := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func _process(delta: float) -> void:
	if not _dirty:
		return
	_cooldown += delta
	if _cooldown >= SAVE_DEBOUNCE:
		_cooldown = 0.0
		_dirty = false
		save_settings()


# --- Values ---------------------------------------------------------

func battle_speed() -> float:
	var i: int = clampi(battle_speed_index, 0, BATTLE_SPEEDS.size() - 1)
	return BATTLE_SPEEDS[i]


func battle_speed_label() -> String:
	var i: int = clampi(battle_speed_index, 0, BATTLE_SPEED_LABELS.size() - 1)
	return BATTLE_SPEED_LABELS[i]


func cycle_battle_speed() -> void:
	battle_speed_index = (battle_speed_index + 1) % BATTLE_SPEEDS.size()
	_announce()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	Audio.sfx_volume = sfx_volume
	_announce()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	Audio.music_volume = music_volume
	Audio.apply_music_volume()
	_announce()


func set_battle_speed_index(value: int) -> void:
	battle_speed_index = clampi(value, 0, BATTLE_SPEEDS.size() - 1)
	_announce()


func set_reduce_flashing(value: bool) -> void:
	reduce_flashing = value
	_announce()


func set_dev_mode(value: bool) -> void:
	dev_mode = value
	EventBus.toast("Developer mode " + ("ON" if value else "OFF"), "info")
	_announce()


# --- Rocket Arena ------------------------------------------------------

func camera_value(key: String) -> float:
	return float(camera.get(key, CAMERA_DEFAULTS.get(key, 0.0)))


func set_camera_value(key: String, value: float) -> void:
	if not CAMERA_RANGES.has(key):
		return
	var span: Array = CAMERA_RANGES[key]
	camera[key] = clampf(value, float(span[0]), float(span[1]))
	_announce()


func reset_camera() -> void:
	camera = CAMERA_DEFAULTS.duplicate()
	_announce()


func set_ball_cam(value: bool) -> void:
	ball_cam = value
	_announce()


func set_team_size(value: int) -> void:
	team_size = clampi(value, 1, 2)
	_announce()


func set_binding(action: String, key: int, button: int) -> void:
	bindings[action] = {"key": key, "button": button}
	_announce()


func clear_binding(action: String) -> void:
	if bindings.erase(action):
		_announce()


func clear_bindings() -> void:
	bindings = {}
	_announce()


func reset_to_defaults() -> void:
	sfx_volume = 0.8
	music_volume = 0.5
	battle_speed_index = 1
	reduce_flashing = false
	camera = CAMERA_DEFAULTS.duplicate()
	ball_cam = true
	team_size = 1
	bindings = {}
	_apply_to_audio()
	_announce()


func _announce() -> void:
	_dirty = true
	changed.emit()


# --- Persistence -----------------------------------------------------

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		_apply_to_audio()
		return

	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	battle_speed_index = clampi(
		int(config.get_value("gameplay", "battle_speed_index", battle_speed_index)),
		0, BATTLE_SPEEDS.size() - 1)
	reduce_flashing = bool(config.get_value("gameplay", "reduce_flashing", reduce_flashing))
	dev_mode = bool(config.get_value("gameplay", "dev_mode", dev_mode))

	ball_cam = bool(config.get_value("arena", "ball_cam", ball_cam))
	team_size = clampi(int(config.get_value("arena", "team_size", team_size)), 1, 2)

	# Read key by key rather than as one blob, so a settings file written
	# by an older build still loads and just uses the defaults for
	# anything it does not mention.
	camera = CAMERA_DEFAULTS.duplicate()
	for key in CAMERA_KEYS:
		var span: Array = CAMERA_RANGES[key]
		camera[key] = clampf(
			float(config.get_value("camera", key, CAMERA_DEFAULTS[key])),
			float(span[0]), float(span[1]))

	bindings = {}
	var stored: Dictionary = config.get_value("controls", "bindings", {})
	for action in stored:
		var entry: Dictionary = stored[action]
		bindings[str(action)] = {
			"key": int(entry.get("key", 0)),
			"button": int(entry.get("button", -1)),
		}

	_apply_to_audio()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("gameplay", "battle_speed_index", battle_speed_index)
	config.set_value("gameplay", "reduce_flashing", reduce_flashing)
	config.set_value("gameplay", "dev_mode", dev_mode)
	config.set_value("arena", "ball_cam", ball_cam)
	config.set_value("arena", "team_size", team_size)
	for key in CAMERA_KEYS:
		config.set_value("camera", key, camera_value(key))
	config.set_value("controls", "bindings", bindings)
	config.save(PATH)


func _apply_to_audio() -> void:
	Audio.sfx_volume = sfx_volume
	Audio.music_volume = music_volume
	Audio.apply_music_volume()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if _dirty:
			save_settings()
			_dirty = false
