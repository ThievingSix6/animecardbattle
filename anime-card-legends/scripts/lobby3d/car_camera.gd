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
#
# ON THE PHYSICS CLOCK, not the render clock. The car only moves when
# physics steps. A camera that lerped toward it every DRAWN frame was
# moving smoothly between steps the car was not moving between, and the
# car appeared to stutter forward in jumps - which at 185 m/s is a jump
# of a metre and a half. Both on the same clock, the two stay locked
# together.
# =========================================================

# Distance and height come from the player's camera settings now, which
# are Rocket League's own numbers in RL's own units, so a camera set up
# over there can be typed in here and behave the same. Everything else
# stays measured against the car, so a rescaled car does not leave the
# camera parked in its back bumper.
const LOOK_AHEAD := CarBody.CAR_LENGTH * 1.5
# How far above the car's own origin the camera aims.
const AIM_HEIGHT := CarBody.CAR_HEIGHT * 1.2

# How fast the rig catches up. Position is snappier than aim, which is
# what stops the horizon jittering. Both are scaled by the Stiffness and
# Transition Speed settings, the way RL scales them.
const FOLLOW_SPEED := 9.0
const AIM_SPEED := 4.5

# What a stiffness of 0 and of 1 mean in terms of FOLLOW_SPEED. RL's
# stiffness is how hard the camera is pinned to the car: at 1 it does not
# lag at all, at 0 it trails a long way behind.
const STIFFNESS_LOOSE := 0.45
const STIFFNESS_TIGHT := 2.2

# How far the car's nose has to be off the horizontal before its
# flattened forward stops meaning anything - nose straight up or
# straight down, where the camera holds its last heading instead.
const MIN_HEADING := 0.2

# Reversing looks behind the car rather than through it.
const REVERSE_SPEED := 6.0

const MOUSE_SENS := 0.0032
# Multiplied by the Swivel Speed setting, which is RL's name for how
# fast the right stick moves the view.
const STICK_SENS := 0.87
const PITCH_MIN := -0.7
const PITCH_MAX := 0.6
# How quickly a manual look drifts back behind the car.
const RECENTRE := 1.6

var target: CarBody
# What the ball camera locks onto. Left null and there is no ball camera,
# which is how the city uses this rig.
var ball: Node3D

var _camera: Camera3D
var _ball_cam := false
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
	add_child(_camera)
	_apply_settings()
	Settings.changed.connect(_apply_settings)
	set_physics_process(false)

	_ball_cam = ball != null and Settings.ball_cam


func _exit_tree() -> void:
	if Settings.changed.is_connected(_apply_settings):
		Settings.changed.disconnect(_apply_settings)


# --- The player's camera settings --------------------------------------
#
# Rocket League's units, converted where they are not metres: distance
# and height are in uu, angle is in degrees.

func _apply_settings() -> void:
	if _camera != null:
		_camera.fov = Settings.camera_value("fov")


func _distance() -> float:
	return Settings.camera_value("distance") * CarBody.UU


func _height() -> float:
	return Settings.camera_value("height") * CarBody.UU


# RL's Angle is a downward tilt in degrees, on top of whatever the
# player has looked to with the stick.
func _angle() -> float:
	return deg_to_rad(Settings.camera_value("angle"))


func _follow_speed() -> float:
	return FOLLOW_SPEED * lerpf(STIFFNESS_LOOSE, STIFFNESS_TIGHT,
		Settings.camera_value("stiffness"))


func _aim_speed() -> float:
	return AIM_SPEED * maxf(0.15, Settings.camera_value("transition"))


# Ball camera: RL's single most-used camera control. Swings the view
# round so the ball stays in frame instead of sitting behind the nose.
func toggle_ball_cam() -> void:
	if ball == null:
		return
	_ball_cam = not _ball_cam
	Settings.set_ball_cam(_ball_cam)


func activate() -> void:
	set_physics_process(true)
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
	set_physics_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_physics_processing():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_offset_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)


# The car's own forward, flattened onto the ground so a roll or a pitch
# does not move the camera. Held where it was while the car is airborne
# or standing on its nose.
func _track_nose() -> void:
	# Ball cam: the heading is the line from the car to the ball, so the
	# rig sits on the far side of the car from it and both are in shot.
	if _ball_cam and is_instance_valid(ball):
		var toward := ball.global_position - target.global_position
		toward.y = 0.0
		if toward.length() > MIN_HEADING:
			_heading = toward.normalized()
			return

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
	var distance := _distance()
	var back := _smoothed.rotated(Vector3.UP, _offset_yaw)
	var lift := _height() + (_pitch + _angle()) * -distance
	return target.global_position - back * distance + Vector3.UP * lift


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or _camera == null:
		return

	if ball != null and Controls.ball_cam_pressed():
		toggle_ball_cam()

	var swivel := STICK_SENS * Settings.camera_value("swivel")
	var look := Controls.look_vector()
	if look != Vector2.ZERO:
		_offset_yaw -= look.x * swivel * delta
		_pitch = clampf(_pitch - look.y * swivel * delta, PITCH_MIN, PITCH_MAX)
	else:
		_offset_yaw = lerpf(_offset_yaw, 0.0, RECENTRE * delta)

	_track_nose()

	_smoothed = _smoothed.slerp(_heading, clampf(_aim_speed() * delta, 0.0, 1.0)).normalized()

	_camera.global_position = _camera.global_position.lerp(
		_desired_position(), clampf(_follow_speed() * delta, 0.0, 1.0))

	# Aimed ahead of the car, so there is road on screen at speed rather
	# than just bumper. On ball cam it is aimed at the ball instead, so
	# the car and the ball are both in frame.
	var aim := target.global_position + _smoothed * LOOK_AHEAD + Vector3.UP * AIM_HEIGHT
	if _ball_cam and is_instance_valid(ball):
		aim = ball.global_position
	_camera.look_at(aim, Vector3.UP)
