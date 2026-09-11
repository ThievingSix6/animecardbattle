extends Node

# =========================================================
# AUDIO (autoload)
#
# Drop .ogg/.wav files into res://audio/ named after the event and they
# play automatically. Everything is optional - missing files are simply
# skipped, so you can add sounds one at a time.
#
#   click.ogg            button presses
#   hover.ogg            button hover
#   summon.ogg           a pull starts
#   reveal_common.ogg    low-rarity card revealed
#   reveal_rare.ogg      Rare/Epic revealed
#   reveal_legendary.ogg Legendary/Mythic revealed
#   reveal_secret.ogg    Secret/Awakened revealed
#   hit.ogg              a battle attack lands
#   ultimate.ogg         an ultimate fires
#   victory.ogg          battle won
#   defeat.ogg           battle lost
#   levelup.ogg          talent upgraded
#   coin.ogg             currency gained
#   music_menu.ogg       looping menu music
#   music_battle.ogg     looping battle music
# =========================================================

const FOLDER := "res://audio/"
const EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]
const VOICE_COUNT := 8

var sfx_volume := 0.8
var music_volume := 0.5

var _voices: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _cache: Dictionary = {}
var _current_music := ""


func _ready() -> void:
	for i in VOICE_COUNT:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_voices.append(player)

	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.finished.connect(_loop_music)

	_connect_events()


# --- Loading --------------------------------------------------------

func _stream(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]

	var found: AudioStream = null
	for ext in EXTENSIONS:
		var path := FOLDER + key + "." + ext
		if ResourceLoader.exists(path):
			found = load(path)
			break

	_cache[key] = found
	return found


# --- Playback -------------------------------------------------------

func play(key: String, pitch: float = 1.0) -> void:
	var stream := _stream(key)
	if stream == null:
		return

	for voice in _voices:
		if not voice.playing:
			voice.stream = stream
			voice.pitch_scale = pitch
			voice.volume_db = linear_to_db(max(0.001, sfx_volume))
			voice.play()
			return


# The same as play(), with the volume scaled - for a sound whose
# loudness is part of the event rather than a fixed level. A ball
# nudged should not sound like a ball rocketed.
func play_at(key: String, loudness: float, pitch: float = 1.0) -> void:
	var stream := _stream(key)
	if stream == null:
		return

	var level := sfx_volume * clampf(loudness, 0.0, 1.0)
	for voice in _voices:
		if not voice.playing:
			voice.stream = stream
			voice.pitch_scale = pitch
			voice.volume_db = linear_to_db(maxf(0.001, level))
			voice.play()
			return


# A looping voice for something continuous - an engine. Returns the
# player so the caller can keep tuning its pitch and volume, and null
# when the sound is not on disk, so a missing engine loop is silence
# rather than a crash.
func loop(key: String) -> AudioStreamPlayer:
	var stream := _stream(key)
	if stream == null:
		return null

	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.volume_db = linear_to_db(0.001)
	add_child(voice)

	# Streams do not loop unless they are told to, and which property
	# says so depends on the format.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

	voice.play()
	return voice


func play_music(key: String) -> void:
	if _current_music == key:
		return
	var stream := _stream(key)
	if stream == null:
		return

	_current_music = key
	_music.stream = stream
	_music.volume_db = linear_to_db(max(0.001, music_volume))
	_music.play()


func stop_music() -> void:
	_current_music = ""
	_music.stop()


# Applies the current music volume to the track already playing, so a
# settings slider is heard immediately rather than on the next track.
func apply_music_volume() -> void:
	if _music == null:
		return
	_music.volume_db = linear_to_db(max(0.001, music_volume))


# True when a sound with this key is actually present on disk. Lets the
# settings screen tell the player which audio the build is missing.
func has_sound(key: String) -> bool:
	return _stream(key) != null


func _loop_music() -> void:
	if _current_music != "":
		_music.play()


# Picks a reveal sound based on how exciting the pull was.
func reveal_key_for(rarity: String) -> String:
	var tier := Config.rarity_index(rarity)
	if tier >= Config.rarity_index("Secret"):
		return "reveal_secret"
	if tier >= Config.rarity_index("Legendary"):
		return "reveal_legendary"
	if tier >= Config.rarity_index("Rare"):
		return "reveal_rare"
	return "reveal_common"


# --- Automatic hooks ------------------------------------------------

func _connect_events() -> void:
	EventBus.talent_upgraded.connect(func(_t, _l): play("levelup"))
	EventBus.floor_cleared.connect(func(_f, _r): play("victory"))
	EventBus.roll_pack_granted.connect(func(_p): play("coin"))
	EventBus.weather_started.connect(func(_e): play("summon"))
