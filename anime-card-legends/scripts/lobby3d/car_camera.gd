class_name CarCamera
extends Node3D

# =========================================================
# Chase camera for the car.
#
# Follows where the car is GOING rather than where it is pointing.
# Pointing-based chase cameras whip around every time the car spins,
# which is unusable the moment flips are involved - and flips are the
# whole point of this car.
#
# The right stick and the mouse still nudge it, so the player can look
# around without the camera fighting them for it.
# =========================================================

const DISTANCE := 9.5
const HEIGHT := 3.6
const LOOK_AHEAD := 6.0

# How fast the rig catches up. Position is snappier than aim, which is
# what stops the horizon jittering.
const FOLLOW_SPEED := 9.0
const AIM_SPEED := 4.5

# Below this the car has no meaningful direction of travel, so the
# camera holds its last one instead of spinning on the spot.
const MIN_TRACK_SPEED := 2.5

const MOUSE_SENS := 0.0032
const STICK_SENS := 2.6
const PITCH_MIN := -0.7
const PITCH_MAX := 0.6
# How quickly a manual look drifts back behind the car.
const RECENTRE := 1.6

var target: CarBody

var _camera: Camera3D
var _yaw := 0.0
var _pitch := -0.16
var _offset_yaw := 0.0
var _heading := Vector3.FORWARD


static func create(car: CarBody) -> CarCamera:
	var rig := CarCamera.new()
	rig.target = car
	return rig


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, HEIGHT, DISTANCE)
	_camera.fov = 78.0
	add_child(_camera)
	set_process(false)


func activate() -> void:
	set_process(true)
	if _camera != null:
		_camera.current = true
	if target != null:
		global_position = target.global_position
		_heading = -target.global_transform.basis.z
		_yaw = atan2(_heading.x, _heading.z)


func deactivate() -> void:
	set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_processing():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_offset_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	var look := Controls.look_vector()
	if look != Vector2.ZERO:
		_offset_yaw -= look.x * STICK_SENS * delta
		_pitch = clampf(_pitch - look.y * STICK_SENS * delta, PITCH_MIN, PITCH_MAX)
	else:
		_offset_yaw = lerpf(_offset_yaw, 0.0, RECENTRE * delta)

	# Track the direction of travel, falling back to the last one while
	# the car is slow or stationary.
	var velocity := target.linear_velocity
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() > MIN_TRACK_SPEED:
		_heading = flat.normalized()

	var want_yaw := atan2(_heading.x, _heading.z)
	_yaw = lerp_angle(_yaw, want_yaw, AIM_SPEED * delta)

	global_position = global_position.lerp(
		target.global_position, clampf(FOLLOW_SPEED * delta, 0.0, 1.0))

	rotation.y = _yaw + _offset_yaw
	rotation.x = _pitch

	# Aimed slightly ahead of the car so there is road on screen at
	# speed, not just bumper.
	if _camera != null:
		_camera.look_at_from_position(
			_camera.global_position,
			target.global_position + _heading * LOOK_AHEAD + Vector3.UP,
			Vector3.UP)
