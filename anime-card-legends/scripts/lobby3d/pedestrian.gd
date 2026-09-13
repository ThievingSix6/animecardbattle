class_name Pedestrian
extends Node3D

# =========================================================
# Background city walkers.
#
# Decorative only - no name, no dialogue, no interaction prompt. Drop a
# model in res://art/models/props/pedestrians/ and it joins the pool
# the same way a skyline building or a scatter prop does
# (Models.list_props()); nothing here has to be told about a new file.
#
# Deliberately its own class rather than a stripped CityNPC: the two
# diverge in purpose (a story character people talk to, versus ambient
# crowd filler that only ever walks and stands), so sharing a base would
# buy nothing but a name in common.
# =========================================================

const WALK_SPEED := 8.0
const TURN_SPEED := 6.0
const ARRIVE_DISTANCE := 4.0
const PAUSE_MIN := 3.0
const PAUSE_MAX := 8.0
const HEIGHT := 3.2

var roam_centre := Vector3.ZERO
var roam_radius := 60.0

# When set, wander targets snap to the nearest street centre line, same
# as a wandering NPC - so a pedestrian walks the roads, not the blocks.
var street_pitch := 0.0

var _model_name := ""
var _model: Node3D
var _anim: AnimationPlayer
var _anim_idle := ""
var _anim_run := ""
var _anim_current := ""

var _target := Vector3.ZERO
var _pause := 1.0
var _walking := false
var _rng := RandomNumberGenerator.new()


static func create(model_name: String) -> Pedestrian:
	var p := Pedestrian.new()
	p._model_name = model_name
	return p


func _ready() -> void:
	_rng.randomize()
	roam_centre = position

	_model = Models.spawn_prop(_model_name)
	if _model == null:
		queue_free()
		return
	add_child(_model)
	Models.fit_height(_model, HEIGHT)

	_anim = Models.find_animation_player(_model)
	if _anim != null:
		var clips := Models.animation_set(_anim)
		_anim_idle = str(clips["idle"])
		_anim_run = str(clips["run"])
		_play(_anim_idle)

	_target = position
	_pause = _rng.randf_range(0.5, 2.0)


func _play(anim_name: String) -> void:
	if _anim == null or anim_name == "" or anim_name == _anim_current:
		return
	if not _anim.has_animation(anim_name):
		return
	_anim_current = anim_name
	_anim.play(anim_name)


func _physics_process(delta: float) -> void:
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
		if _rng.randf() < 0.5:
			_target.x = _nearest_street(_target.x)
		else:
			_target.z = _nearest_street(_target.z)

	_walking = true
	_play(_anim_run)


# Street centre lines sit at (n - 0.5) * pitch, between the blocks.
func _nearest_street(value: float) -> float:
	return (roundf(value / street_pitch + 0.5) - 0.5) * street_pitch
