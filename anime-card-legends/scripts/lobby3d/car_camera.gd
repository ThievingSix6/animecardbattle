class_name CarCamera
extends Node3D

# =========================================================
# Chase camera for the car.
#
# Sits behind the car's NOSE, so the view is where the car is aimed and
# steering reads the way it should.
#
# The catch a pointing camera has is that a car which spins - and this
# one flips - drags the view around with it. Two guards stop that: the
# heading is taken from the car's forward flattened onto the ground, so
# rolling and pitching do not move it at all, and it is smoothed, so a
# fast yaw arrives as a swing rather than a snap. While the car is
# airborne the heading is held where it was, which is what stops a
# barrel roll turning the camera inside out.
#
# The right stick and the mouse still nudge it, so the player can look
# around without the camera fighting them for it.
# =========================================================

# Measured against the car, so a rescaled car does not leave the camera
# parked in its back bumper.
const DISTANCE := CarBody.CAR_LENGTH * 3.0
const HEIGHT := CarBody.CAR_LENGTH * 1.15
const LOOK_AHEAD := CarBody.CAR_LENGTH * 1.5
# How far above the car's own origin the camera aims.
const AIM_HEIGHT := CarBody.CAR_HEIGHT * 1.2

# How fast the rig catches up. Position is snappier than aim, which is
# what stops the horizon jittering.
const FOLLOW_SPEED := 9.0
const AIM_SPEED := 4.5

# How far the car's nose has to be off the horizontal before its
# flattened forward stops meaning anything - nose straight up or
# straight down, where the camera holds its last heading instead.
const MIN_HEADING := 0.2

# Reversing looks behind the car rather than through it.
const REVERSE_SPEED := 6.0

const MOUSE_SENS := 0.0032
const STICK_SENS := 2.6
const PITCH_MIN := -0.7
const PITCH_MAX := 0.6
# How quickly a manual look drifts back behind the car.
const RECENTRE := 1.6

var target: CarBody

var _camera: Camera3D
var _pitch := -0.16
var _offset_yaw := 0.0
# Where the car is going, and the lagged version the camera actually
# sits behind.
var _heading := Vector3.FORWARD
var _smoothed := Vector3.FORWARD


static func create(car: CarBody) -> CarCamera:
	var rig := CarCamera.new()
	rig.target = car
	return rig


func _ready() -> void:
	# Placed in world space every frame, so it is not parented to a
	# rotating rig. The old rig put local +Z along the heading, which
	# left the camera sitting in front of the car looking backwards.
	_camera = Camera3D.new()
	_camera.top_level = true
	_camera.fov = 78.0
	add_child(_camera)
	set_process(false)


func activate() -> void:
	set_process(true)
	if _camera != null:
		_camera.current = true
	if target != null:
		_heading = -target.global_transform.basis.z
		_heading.y = 0.0
		if _heading.length() < 0.01:
			_heading = Vector3.FORWARD
		_heading = _heading.normalized()
		_smoothed = _heading
		_camera.global_position = _desired_position()


func deactivate() -> void:
	set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_processing():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_offset_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)


# The car's own forward, flattened onto the ground so a roll or a pitch
# does not move the camera. Held where it was while the car is airborne
# or standing on its nose.
func _track_nose() -> void:
	var forward := -target.global_transform.basis.z
	var flat := Vector3(forward.x, 0.0, forward.z)

	# Nose near-vertical: the flattened forward is meaningless, and
	# following it would spin the view.
	if flat.length() < MIN_HEADING:
		return

	# Mid-flip the car is not pointing anywhere useful either.
	if not target.is_grounded() and target.angular_velocity.length() > 1.5:
		return

	flat = flat.normalized()

	# Backing up: look the way the car is travelling, not the way it
	# faces, or reversing means staring at your own bumper.
	var reversing := target.linear_velocity.dot(forward) < -REVERSE_SPEED
	if reversing:
		flat = -flat

	_heading = flat


# Behind the car along its heading, lifted, and offset by however far
# the player has looked around.
func _desired_position() -> Vector3:
	var back := _smoothed.rotated(Vector3.UP, _offset_yaw)
	var lift := HEIGHT + _pitch * -DISTANCE
	return target.global_position - back * DISTANCE + Vector3.UP * lift


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or _camera == null:
		return

	var look := Controls.look_vector()
	if look != Vector2.ZERO:
		_offset_yaw -= look.x * STICK_SENS * delta
		_pitch = clampf(_pitch - look.y * STICK_SENS * delta, PITCH_MIN, PITCH_MAX)
	else:
		_offset_yaw = lerpf(_offset_yaw, 0.0, RECENTRE * delta)

	_track_nose()

	_smoothed = _smoothed.slerp(_heading, clampf(AIM_SPEED * delta, 0.0, 1.0)).normalized()

	_camera.global_position = _camera.global_position.lerp(
		_desired_position(), clampf(FOLLOW_SPEED * delta, 0.0, 1.0))

	# Aimed ahead of the car, so there is road on screen at speed rather
	# than just bumper.
	var aim := target.global_position + _smoothed * LOOK_AHEAD + Vector3.UP * AIM_HEIGHT
	_camera.look_at(aim, Vector3.UP)
