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

var sfx_volume := 0.8
var music_volume := 0.5
var battle_speed_index := 1
var reduce_flashing := false

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


func reset_to_defaults() -> void:
	sfx_volume = 0.8
	music_volume = 0.5
	battle_speed_index = 1
	reduce_flashing = false
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

	_apply_to_audio()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("gameplay", "battle_speed_index", battle_speed_index)
	config.set_value("gameplay", "reduce_flashing", reduce_flashing)
	config.set_value("gameplay", "dev_mode", dev_mode)
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
