class_name CarBody
extends RigidBody3D

# =========================================================
# THE CAR - arcade driving, built the way Rocket League's is rather
# than as a simulation.
#
# A RigidBody3D with four raycasts standing in for suspension. Nothing
# here is a wheel joint: the rays hold the shell off the ground, the
# drive is a force along the shell's own forward, and grip is a force
# that cancels sideways slide. That is what makes the handling
# predictable enough to flip a car through the air and land it.
#
# ON THE GROUND
#   throttle    drive forward and back
#   steer       yaw, scaled by how fast it is already going
#   drift       breaks grip for a powerslide
#   jump        pushes off along the shell's up, not the world's
#
# IN THE AIR
#   stick       pitch and yaw
#   drift       turns that yaw into roll
#   jump again  flips: forward, back or sideways depending on the
#               stick, and straight up with no stick at all
#
# BOOST burns fuel, pushes along the shell's forward, and trails from
# two exhaust points. Fuel regenerates slowly - there are no pads.
#
# MODEL: res://art/models/props/car.glb, scaled to CAR_LENGTH and
# assumed to face -Z. Without one it drives as a wedge, so the physics
# can be felt before the art lands.
# =========================================================

# --- Shell ---------------------------------------------------------
const CAR_LENGTH := 2.7
const CAR_WIDTH := 1.5
const CAR_HEIGHT := 0.75
const CAR_MASS := 180.0
# Heavier than real gravity: arcs stay snappy instead of floaty.
const GRAVITY_SCALE := 1.5

# Set to PI if the model faces +Z and drives backwards.
const MODEL_YAW := 0.0

# --- Suspension ----------------------------------------------------
const REST_LENGTH := 0.55
const SPRING := 9000.0
const DAMPING := 900.0

# --- Driving -------------------------------------------------------
const DRIVE_FORCE := 5200.0
const REVERSE_FORCE := 3000.0
const MAX_SPEED := 24.0
const BOOST_MAX_SPEED := 34.0
const BRAKE_FORCE := 6000.0

const STEER_TORQUE := 9000.0
const GRIP := 5200.0
const DRIFT_GRIP := 1100.0
# Steering falls off with speed, so it is not twitchy flat out.
const STEER_SPEED_FALLOFF := 26.0

const ROLLING_DRAG := 0.6

# --- Air -----------------------------------------------------------
const AIR_PITCH_TORQUE := 5200.0
const AIR_YAW_TORQUE := 4200.0
const AIR_ROLL_TORQUE := 6200.0
const AIR_DAMPING := 0.06

# --- Jumps and flips -----------------------------------------------
const JUMP_IMPULSE := 6.2
const SECOND_JUMP_IMPULSE := 5.4
# How long after leaving the ground a second press still counts.
const FLIP_WINDOW := 1.45
const FLIP_IMPULSE := 9.5
const FLIP_TORQUE := 34.0
# A flip locks rotation control briefly, the way it does in RL.
const FLIP_LOCK := 0.65

# --- Boost ---------------------------------------------------------
const BOOST_FORCE := 9000.0
const BOOST_MAX := 100.0
const BOOST_DRAIN := 33.0
const BOOST_REGEN := 8.0

var boost := BOOST_MAX
var driver_seated := false

var _shell: Node3D
var _rays: Array[RayCast3D] = []
var _grounded := false
var _ground_normal := Vector3.UP

var _jumps_used := 0
var _airborne_for := 0.0
var _flip_lock := 0.0
var _jump_held := false

var _trails: Array[CPUParticles3D] = []


static func create() -> CarBody:
	var car := CarBody.new()
	return car


func _ready() -> void:
	mass = CAR_MASS
	gravity_scale = GRAVITY_SCALE
	# The shell is held up by the rays, so the physics engine's own
	# damping only needs to stop it drifting forever.
	linear_damp = 0.1
	angular_damp = 1.2
	continuous_cd = true
	can_sleep = false

	_build_collision()
	_build_shell()
	_build_suspension()
	_build_trails()


# --- Construction ---------------------------------------------------

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CAR_WIDTH, CAR_HEIGHT, CAR_LENGTH)
	shape.shape = box
	shape.position.y = CAR_HEIGHT * 0.5
	add_child(shape)


func _build_shell() -> void:
	_shell = Node3D.new()
	add_child(_shell)

	var model := Models.spawn_prop("car")
	if model != null:
		_shell.add_child(model)
		# Uniform, so an imported car is never stretched. Length is what
		# matters for a vehicle, not height.
		Models.fit_length(model, CAR_LENGTH)
		model.rotation.y = MODEL_YAW
		return

	_build_placeholder()


# A wedge, pointed at -Z, so which way it is facing is never in doubt.
func _build_placeholder() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CAR_WIDTH, CAR_HEIGHT * 0.7, CAR_LENGTH)
	body.mesh = box
	body.position.y = CAR_HEIGHT * 0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#e8552c")
	mat.roughness = 0.35
	mat.metallic = 0.4
	body.material_override = mat
	_shell.add_child(body)

	var nose := MeshInstance3D.new()
	var wedge := PrismMesh.new()
	wedge.size = Vector3(CAR_WIDTH * 0.9, CAR_HEIGHT * 0.5, CAR_LENGTH * 0.35)
	nose.mesh = wedge
	nose.position = Vector3(0.0, CAR_HEIGHT * 0.85, -CAR_LENGTH * 0.3)
	nose.rotation.x = -PI * 0.5

	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color("#1b2130")
	nose_mat.roughness = 0.3
	nose.material_override = nose_mat
	_shell.add_child(nose)


# Four rays at the corners. Nothing rotates; they only measure.
func _build_suspension() -> void:
	var half_w := CAR_WIDTH * 0.42
	var half_l := CAR_LENGTH * 0.38
	var corners: Array[Vector3] = [
		Vector3(-half_w, CAR_HEIGHT * 0.4, -half_l),
		Vector3(half_w, CAR_HEIGHT * 0.4, -half_l),
		Vector3(-half_w, CAR_HEIGHT * 0.4, half_l),
		Vector3(half_w, CAR_HEIGHT * 0.4, half_l),
	]

	for corner in corners:
		var ray := RayCast3D.new()
		ray.position = corner
		ray.target_position = Vector3(0.0, -REST_LENGTH - CAR_HEIGHT * 0.4, 0.0)
		ray.enabled = true
		ray.exclude_parent = true
		add_child(ray)
		_rays.append(ray)


# CPUParticles3D rather than GPU: the Compatibility renderer runs these
# everywhere, and a boost trail is not worth a renderer dependency.
func _build_trails() -> void:
	var exhausts: Array[Vector3] = [
		Vector3(-CAR_WIDTH * 0.28, CAR_HEIGHT * 0.45, CAR_LENGTH * 0.5),
		Vector3(CAR_WIDTH * 0.28, CAR_HEIGHT * 0.45, CAR_LENGTH * 0.5),
	]

	for at in exhausts:
		var flame := CPUParticles3D.new()
		flame.position = at
		flame.emitting = false
		flame.amount = 48
		flame.lifetime = 0.45
		flame.local_coords = false
		flame.direction = Vector3(0.0, 0.0, 1.0)
		flame.spread = 8.0
		flame.initial_velocity_min = 6.0
		flame.initial_velocity_max = 11.0
		flame.scale_amount_min = 0.28
		flame.scale_amount_max = 0.5
		flame.gravity = Vector3.ZERO

		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.85, 0.35, 1.0))
		ramp.set_color(1, Color(1.0, 0.25, 0.1, 0.0))
		flame.color_ramp = ramp

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		flame.material_override = mat

		var quad := QuadMesh.new()
		quad.size = Vector2(0.4, 0.4)
		flame.mesh = quad

		add_child(flame)
		_trails.append(flame)


# --- Driving --------------------------------------------------------

func take_control() -> void:
	driver_seated = true


func release_control() -> void:
	driver_seated = false
	_set_boosting(false)


func speed() -> float:
	return linear_velocity.length()


func boost_fraction() -> float:
	return boost / BOOST_MAX


# Runs whether or not anyone is driving: the suspension is what keeps
# the shell sitting on its wheels rather than sunk into its own
# collider while parked. Only the controls are gated.
func _physics_process(delta: float) -> void:
	_read_ground()
	_apply_suspension(delta)

	if not driver_seated:
		if _grounded:
			# Parked: bleed off any push it was given.
			linear_velocity = linear_velocity.lerp(Vector3.ZERO, 3.0 * delta)
		return

	var throttle := Input.get_axis("acl_back", "acl_forward")
	var steer := Input.get_axis("acl_right", "acl_left")
	var drifting := Input.is_action_pressed("acl_drift")
	var boosting := Input.is_action_pressed("acl_boost") and boost > 0.0

	if _grounded:
		_airborne_for = 0.0
		_jumps_used = 0
		_drive(throttle, delta)
		_steer(steer, drifting, delta)
		_grip(drifting, delta)
	else:
		_airborne_for += delta
		_air_control(throttle, steer, drifting, delta)

	_apply_boost(boosting, delta)
	_handle_jump()

	if _flip_lock > 0.0:
		_flip_lock -= delta


# --- Ground ---------------------------------------------------------

func _read_ground() -> void:
	_grounded = false
	var normal := Vector3.ZERO
	var hits := 0

	for ray in _rays:
		if not ray.is_colliding():
			continue
		hits += 1
		normal += ray.get_collision_normal()

	if hits > 0:
		_grounded = true
		_ground_normal = (normal / float(hits)).normalized()


# A spring per corner, pushed along the shell's own up so the car
# banks with a slope instead of fighting it.
func _apply_suspension(delta: float) -> void:
	var up := global_transform.basis.y

	for ray in _rays:
		if not ray.is_colliding():
			continue

		var contact := ray.get_collision_point()
		var offset := contact - global_position
		var travel := REST_LENGTH - (ray.global_position.distance_to(contact) - CAR_HEIGHT * 0.4)
		travel = clampf(travel, 0.0, REST_LENGTH)

		var point_velocity := linear_velocity + angular_velocity.cross(offset)
		var closing := point_velocity.dot(up)

		var force := up * (travel * SPRING - closing * DAMPING) * delta * 60.0
		apply_force(force * 0.25, offset)


func _drive(throttle: float, delta: float) -> void:
	var forward := -global_transform.basis.z
	var along := linear_velocity.dot(forward)

	if absf(throttle) < 0.05:
		# Coasting: bleed off speed rather than rolling forever.
		apply_central_force(-forward * along * ROLLING_DRAG * mass)
		return

	# Throttle against the direction of travel is braking, not reverse.
	if throttle * along < -0.5:
		apply_central_force(forward * signf(throttle) * BRAKE_FORCE)
		return

	var ceiling := MAX_SPEED
	if Input.is_action_pressed("acl_boost") and boost > 0.0:
		ceiling = BOOST_MAX_SPEED
	if absf(along) >= ceiling and signf(along) == signf(throttle):
		return

	var force := DRIVE_FORCE
	if throttle < 0.0:
		force = REVERSE_FORCE
	apply_central_force(forward * throttle * force)


# Yaw about the ground normal, not the world's up, so steering works on
# a slope. Falls off with speed so it is not twitchy flat out.
func _steer(steer: float, drifting: bool, delta: float) -> void:
	if absf(steer) < 0.05:
		return

	var forward := -global_transform.basis.z
	var along := linear_velocity.dot(forward)
	if absf(along) < 0.4:
		return

	var authority := 1.0 - clampf(absf(along) / STEER_SPEED_FALLOFF, 0.0, 0.6)
	var torque := STEER_TORQUE * steer * authority * signf(along)
	if drifting:
		torque *= 1.35

	apply_torque(_ground_normal * torque * delta * 60.0)


# Cancels sideways slide. Without this the car handles like it is on
# ice; with it, it corners.
func _grip(drifting: bool, delta: float) -> void:
	var side := global_transform.basis.x
	var sideways := linear_velocity.dot(side)

	var strength := GRIP
	if drifting:
		strength = DRIFT_GRIP

	apply_central_force(-side * sideways * strength * delta * 60.0 * 0.016)


# --- Air ------------------------------------------------------------

func _air_control(pitch_input: float, yaw_input: float, rolling: bool, delta: float) -> void:
	# A flip owns the car's rotation until it finishes.
	if _flip_lock > 0.0:
		return

	var basis_now := global_transform.basis
	var torque := Vector3.ZERO

	torque += basis_now.x * pitch_input * AIR_PITCH_TORQUE
	if rolling:
		torque += basis_now.z * yaw_input * AIR_ROLL_TORQUE
	else:
		torque += basis_now.y * yaw_input * AIR_YAW_TORQUE

	apply_torque(torque * delta * 60.0 * 0.016)

	# Without this the car keeps spinning after the stick is released.
	angular_velocity = angular_velocity.lerp(Vector3.ZERO, AIR_DAMPING)


# --- Jumps and flips -------------------------------------------------

func _handle_jump() -> void:
	var pressed := Input.is_action_pressed("acl_jump")
	if not pressed:
		_jump_held = false
		return
	if _jump_held:
		return
	_jump_held = true

	if _grounded:
		_jump()
		return

	# Second press in the air: a flip if the stick is held, a straight
	# jump if it is not - and only while the window is open.
	if _jumps_used >= 2 or _airborne_for > FLIP_WINDOW:
		return

	var throttle := Input.get_axis("acl_back", "acl_forward")
	var steer := Input.get_axis("acl_right", "acl_left")

	if absf(throttle) < 0.25 and absf(steer) < 0.25:
		_second_jump()
	else:
		_flip(throttle, steer)


func _jump() -> void:
	_jumps_used = 1
	_airborne_for = 0.0
	apply_central_impulse(global_transform.basis.y * JUMP_IMPULSE * mass * 0.05)
	Audio.play("click")


func _second_jump() -> void:
	_jumps_used = 2
	apply_central_impulse(global_transform.basis.y * SECOND_JUMP_IMPULSE * mass * 0.05)


# Front, back and side flips are the same move with a different axis:
# a shove in the stick's direction, and a spin about the axis at right
# angles to it.
func _flip(throttle: float, steer: float) -> void:
	_jumps_used = 2
	_flip_lock = FLIP_LOCK

	var basis_now := global_transform.basis
	var direction := (-basis_now.z * throttle - basis_now.x * steer).normalized()

	# Cancel whatever sideways drift there was, so the flip goes where
	# it was aimed rather than where the car was already sliding.
	var flat := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	linear_velocity -= flat * 0.35

	apply_central_impulse(direction * FLIP_IMPULSE * mass * 0.05)

	var spin := basis_now.x * throttle - basis_now.z * steer
	angular_velocity = spin.normalized() * FLIP_TORQUE * 0.35
	Audio.play("click")


# --- Boost ------------------------------------------------------------

func _apply_boost(boosting: bool, delta: float) -> void:
	if boosting and boost > 0.0:
		boost = maxf(0.0, boost - BOOST_DRAIN * delta)
		apply_central_force(-global_transform.basis.z * BOOST_FORCE)
		_set_boosting(true)
		return

	boost = minf(BOOST_MAX, boost + BOOST_REGEN * delta)
	_set_boosting(false)


func _set_boosting(on: bool) -> void:
	for flame in _trails:
		if flame.emitting != on:
			flame.emitting = on
