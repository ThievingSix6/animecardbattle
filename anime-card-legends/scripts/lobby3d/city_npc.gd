class_name CityNPC
extends Node3D

# =========================================================
# A person in the city.
#
# Loads res://art/models/npc/<id>.glb, sizes it, binds whatever
# animation clips it came with, and stands there until the player walks
# up. Wandering NPCs pick a point, walk to it, and stand around before
# picking another - The Boy is meant to be found somewhere different
# every time you come back.
#
# With no model it is a coloured marker that still talks, so the
# writing works before the art does.
# =========================================================

const PROMPT_RADIUS := 10.0

# Wandering.
const WALK_SPEED := 9.0
const TURN_SPEED := 7.0
const ARRIVE_DISTANCE := 4.0
const PAUSE_MIN := 2.0
const PAUSE_MAX := 6.5

var npc_id := ""
var display_name := ""
var title := ""
var tint := Color("#f5a623")
var wanders := false

# The square the NPC is allowed to roam, centred on its spawn.
var roam_centre := Vector3.ZERO
var roam_radius := 60.0

# When set, wander targets are snapped to the nearest street centre
# line, so a roaming NPC walks the roads instead of straight through
# the middle of a city block.
var street_pitch := 0.0

var _model: Node3D
var _anim: AnimationPlayer
var _anim_idle := ""
var _anim_run := ""
var _anim_talk := ""
var _anim_defeat := ""
var _anim_current := ""

var _target := Vector3.ZERO
var _pause := 1.0
var _walking := false
var _frozen := false
var _rng := RandomNumberGenerator.new()


static func create(id: String) -> CityNPC:
	var npc := CityNPC.new()
	var definition := Npcs.get_npc(id)
	npc.npc_id = id
	npc.display_name = str(definition["name"])
	npc.title = str(definition["title"])
	npc.tint = definition["tint"]
	npc.wanders = bool(definition["wanders"])
	return npc


func _ready() -> void:
	_rng.randomize()
	roam_centre = position

	if not _build_model():
		_build_marker()

	_build_plate()
	_build_light()

	_target = position
	_pause = _rng.randf_range(0.5, 2.0)


func interaction_radius() -> float:
	return PROMPT_RADIUS


# --- Body ---------------------------------------------------------------

func _build_model() -> bool:
	_model = Models.spawn_npc(npc_id)
	if _model == null:
		return false

	add_child(_model)
	Models.fit_height(_model, Npcs.height(npc_id))

	_anim = Models.find_animation_player(_model)
	if _anim != null:
		var clips := Models.animation_set(_anim)
		_anim_idle = str(clips["idle"])
		_anim_run = str(clips["run"])
		_anim_talk = str(clips["talk"])
		_anim_defeat = str(clips["defeat"])
		_play(_anim_idle)

	return true


# Stand-in: a coloured capsule with the NPC's own tint, so an NPC with
# no model yet is still findable and still talks.
func _build_marker() -> void:
	_model = Node3D.new()
	add_child(_model)

	var height := Npcs.height(npc_id)

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = height * 0.22
	capsule.height = height
	body.mesh = capsule
	body.position.y = height * 0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.5
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = RenderMode.emission(0.4)
	body.material_override = mat
	_model.add_child(body)


func _build_plate() -> void:
	var plate := Label3D.new()
	plate.text = display_name
	plate.font_size = 80
	plate.pixel_size = 0.006
	plate.position.y = Npcs.height(npc_id) + 0.9
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.modulate = tint
	plate.outline_size = 20
	plate.outline_modulate = Color("#05060b")
	plate.no_depth_test = true
	add_child(plate)


func _build_light() -> void:
	var lamp := OmniLight3D.new()
	lamp.position.y = Npcs.height(npc_id) * 0.7
	lamp.light_color = tint
	lamp.light_energy = RenderMode.light(0.9)
	lamp.omni_range = 9.0
	add_child(lamp)


# --- Animation -----------------------------------------------------------

func _play(anim_name: String) -> void:
	if _anim == null or anim_name == "" or anim_name == _anim_current:
		return
	if not _anim.has_animation(anim_name):
		return
	_anim_current = anim_name
	_anim.play(anim_name)


# Played when the player beats them. Falls back to idle when the model
# has no defeat clip - The Boy's current export has none, and the asset
# report says so rather than this failing quietly.
var defeated := false


func play_defeat() -> void:
	defeated = true
	_frozen = true
	_walking = false
	if _anim_defeat != "":
		_play(_anim_defeat)
	else:
		_play(_anim_idle)


# Stops walking and turns to face whoever is talking to them, playing
# their talk clip if the model came with one.
func face(target: Vector3) -> void:
	_frozen = true
	_walking = false
	_play(_anim_talk)

	var to_target := Vector3(target.x - position.x, 0.0, target.z - position.z)
	if to_target.length() > 0.01:
		rotation.y = atan2(to_target.x, to_target.z)


func release() -> void:
	# A defeated NPC stays down; it is not a pose to snap out of.
	if defeated:
		return
	_frozen = false
	_play(_anim_idle)


# --- Wandering ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not wanders or _frozen or defeated:
		return

	if not _walking:
		_pause -= delta
		if _pause <= 0.0:
			_pick_target()
		return

	var to_target := Vector3(_target.x - position.x, 0.0, _target.z - position.z)
	if to_target.length() < ARRIVE_DISTANCE:
		_walking = false
		_pause = _rng.randf_range(PAUSE_MIN, PAUSE_MAX)
		_play(_anim_idle)
		return

	var direction := to_target.normalized()
	position += direction * WALK_SPEED * delta

	var want := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, want, TURN_SPEED * delta)


func _pick_target() -> void:
	var angle := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(roam_radius * 0.25, roam_radius)
	_target = roam_centre + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)

	if street_pitch > 0.0:
		# One axis snaps to a road, the other stays free, so the walk
		# reads as following a street rather than crossing a car park.
		if _rng.randf() < 0.5:
			_target.x = _nearest_street(_target.x)
		else:
			_target.z = _nearest_street(_target.z)

	_walking = true
	_play(_anim_run)


# Street centre lines sit at (n - 0.5) * pitch, between the blocks.
func _nearest_street(value: float) -> float:
	return (roundf(value / street_pitch + 0.5) - 0.5) * street_pitch
