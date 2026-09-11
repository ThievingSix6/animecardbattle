class_name CarBody
extends RigidBody3D

# =========================================================
# THE CAR.
#
# ON ROCKETSIM: it cannot be used here. It is a C++ library with no
# GDScript binding, so it would need a GDExtension built per platform,
# and it simulates Rocket League's arena and ball rather than a car in
# an open city. What it actually contains, though, is Rocket League's
# physics CONSTANTS - and those are public. So they are used directly
# below, which gets the handling without the dependency.
#
# Everything is written in Rocket League's own units (1 uu = 1 cm) and
# converted once, through UU. That is the point: the numbers can be
# checked against RL's published values line by line, and the car is
# scaled by changing CAR_LENGTH alone.
#
# CONTROLS (PlayStation naming)
#   R2 / W          throttle, analogue on a trigger
#   L2 / S          brake, and reverse once stopped
#   left stick      steer on the ground, pitch and yaw in the air
#   R1 / Ctrl       powerslide on the ground, air roll in the air
#   Cross / Space   jump; again within the window to flip
#   Circle / Shift  boost
#   Triangle / F    get out
# =========================================================

# --- Scale: CONSTANTS, deliberately -----------------------------------
#
# These five are `const` and have to stay that way. ArenaBall's radius,
# the arena's pitch dimensions and the chase camera's distances are all
# written as `something * CarBody.UU` at the top of their own files,
# which GDScript resolves at PARSE time - an exported variable cannot be
# used there. The unit scale is not a tuning value anyway: it is the
# bridge between Rocket League's units and metres.
#
# Octane's hitbox is 118.01 uu long. Everything follows from how long
# this car is in metres.
const OCTANE_LENGTH_UU := 118.01
const CAR_LENGTH := 9.45
const UU := CAR_LENGTH / OCTANE_LENGTH_UU

const CAR_WIDTH := 84.2 * UU
const CAR_HEIGHT := 36.16 * UU

# Rocket League's gravity, read by the ball so the two fall together.
const RL_GRAVITY := 650.0
# A full tank, read by the HUD and the arena's kickoff.
const BOOST_MAX := 100.0

# Ride height, and the suspension geometry derived from it. Const
# because the raycasts are built from these in _ready() and because a
# ride height that changed under a car already sitting on its springs
# would just launch it.
const RIDE_HEIGHT_UU := 17.0
const RIDE_HEIGHT := RIDE_HEIGHT_UU * UU
# How far above the body origin each ray begins - a full ride height, so
# the origin has somewhere to sink to before the ray's own start goes
# underground.
const RAY_LIFT := RIDE_HEIGHT
# Ray start to wheel contact with the spring at rest.
const REST_LENGTH := RAY_LIFT + RIDE_HEIGHT
# Plus room for the suspension to droop before the ray gives up.
const RAY_LENGTH := REST_LENGTH + RIDE_HEIGHT * 1.5
# The un-burying probe: how far above the origin it starts and how far
# down it reaches. The lift only has to beat one physics frame of falling.
const PROBE_LIFT := RIDE_HEIGHT * 4.0
const PROBE_REACH := RIDE_HEIGHT * 4.0
# A surface within this of the origin is the road the car is sitting on,
# not a ceiling it is buried under.
const SURFACE_SLACK := RIDE_HEIGHT * 0.25

# The four corners, in the order they are built and indexed.
const WHEEL_NAMES: Array[String] = ["FrontLeft", "FrontRight", "RearLeft", "RearRight"]


# --- Everything else is tunable ---------------------------------------
#
# All of it exported, all of it defaulted to Rocket League's published
# figure, and anything measured in uu says so in its name so a value can
# be checked against RL's own without converting first. Open
# res://scenes/Car.tscn to change any of it.

@export_group("Body")
@export var car_mass := 180.0
# The supplied car.glb is 1.40 long on X against 0.60 on Z, so its
# LENGTH runs along X - it needs a quarter turn, not a half one. Flip
# the sign if it drives backwards.
@export var model_yaw := PI * 0.5
@export var model_pitch := 0.0
@export var model_roll := 0.0

@export_group("Driving")
@export var max_speed_uu := 2300.0
@export var max_speed_no_boost_uu := 1410.0
# Throttle acceleration falls off with speed: full push from a
# standstill, nothing left at the no-boost ceiling.
@export var forward_acceleration_uu := 1600.0
@export var forward_acceleration_top_uu := 160.0
@export var brake_strength_uu := 3500.0
# RL bleeds speed off at a fixed rate when the throttle is released
# rather than rolling on.
@export var coast_deceleration_uu := 525.0

@export_group("Steering")
# RL's turn radius works out to about 2 rad/s of yaw across the whole
# speed range; below the bite speed there is not enough load on the
# wheels to turn at all.
@export var steering_yaw_rate := 2.0
@export var steering_bite_speed_uu := 220.0
@export var handbrake_yaw_bonus := 1.6
# How hard the car refuses to travel sideways. Dropping it is what makes
# a powerslide slide.
@export var sideways_friction := 28.0
@export var handbrake_sideways_friction := 4.0

@export_group("Suspension")
# Stiffness is how many times its own weight a wheel pushes back at full
# compression; damping is tuned near critical so the car settles rather
# than pogos. Both are per-wheel and scaled by the car's real weight, so
# they hold it at RIDE_HEIGHT whatever the car masses.
@export var spring_strength := 20.0
@export var damper_strength := 40.0

@export_group("Wheel contact")
# Where one surface stops being another. A contact within slope_min of
# world up is flat floor; out to floor_max it is a slope and still drives
# normally; past ceiling_min it is a ceiling; everything between is wall.
@export var slope_max_degrees := 12.0
@export var floor_max_degrees := 50.0
@export var ceiling_min_degrees := 130.0
# How fast the car has to be going for a wall or a ceiling to hold it.
# Below this a wall is something it touches, not something it drives on -
# which is what stops a car parking halfway up one.
@export var wall_stick_speed_uu := 500.0
# Ordinary floor does not grant flip resets. Turn this on to test the
# reset machinery without having to find a wall first.
@export var reset_allows_floor := false
# How many wheels have to make a valid contact for a reset. Rocket
# League wants all four; three is the usual forgiving setting.
@export var minimum_reset_wheels := 3

@export_group("Air control")
# Rocket League's angular accelerations, in rad/s^2, and the damping
# that stops them. Damping only applies to an axis that is NOT being
# driven, which is what makes RL's air control hold a rotation instead
# of springing back to level.
@export var air_pitch_strength := 12.146
@export var air_yaw_strength := 8.9196
@export var air_roll_strength := 36.0796
@export var air_pitch_damping := 2.7982
@export var air_yaw_damping := 1.8865
@export var air_roll_damping := 4.4717
@export var max_angular_speed := 5.5

@export_group("Jump and flip")
@export var jump_force_uu := 291.667
# Holding jump keeps pushing for a fifth of a second - that is what makes
# RL's jump height depend on how long the button is held.
@export var jump_hold_force_uu := 1458.333
@export var jump_hold_time := 0.2
@export var flip_impulse_uu := 500.0
# How long after leaving the ground a flip is still available.
@export var flip_window := 1.5
@export var flip_rotation_speed := 5.5
# How long the flip owns the car's rotation before control returns.
@export var flip_duration := 0.65
# How far from centre the stick has to be for a second jump to become a
# directional flip.
@export var flip_deadzone := 0.25

@export_group("Boost")
@export var boost_drain_rate := 33.3
@export var boost_recharge_rate := 9.0
@export var boost_acceleration_uu := 991.667

@export_group("Recovery")
# Upside down and barely moving is a dead end, so jump rights the car
# instead of doing nothing.
@export var recover_tilt := 0.35
@export var recover_speed := 2.6
@export var recover_time := 0.55


# Top speeds in metres, which is what the physics actually works in.
func max_speed() -> float:
	return max_speed_uu * UU


func max_speed_no_boost() -> float:
	return max_speed_no_boost_uu * UU


var boost := BOOST_MAX
var driver_seated := false

# EVERYTHING the car reacts to. Filled from the InputMap when a person
# is driving and by drive_inputs() when an agent is.
var input := CarInput.new()

var _shell: Node3D
var _rays: Array[RayCast3D] = []
var _probe: RayCast3D

# One per wheel, in the order _build_suspension() creates them: front
# left, front right, rear left, rear right. Rebuilt every physics frame
# and read by everything that needs to know what the car is touching.
var wheels: Array[WheelContact] = []

var _grounded := false
var _ground_normal := Vector3.UP

var _jumps_used := 0
var _airborne_for := 0.0
var _jump_held_for := 0.0
var _flip_lock := 0.0
var _was_jump_down := false
var _recovering := 0.0

var _trails: Array[CPUParticles3D] = []

# --- Sound ------------------------------------------------------------
#
# ENGINE: two loops crossfaded. engine_idle.ogg sits under the car
# whenever someone is in it; engine.ogg rises as it actually moves, and
# its pitch tracks speed. Crossfading rather than switching means there
# is no click at the moment the car starts rolling.
#
# BOOST: a three-part chain, because that is how the files are cut.
# boost.ogg fires on the press, boost2.ogg follows the instant it ends,
# and boost3.ogg loops from there until the button comes up or the tank
# runs dry. The hand-off is timed from the files' own lengths rather
# than hardcoded, so re-cutting a sound does not desync the chain.
var _engine_idle: AudioStreamPlayer
var _engine_drive: AudioStreamPlayer
var _boost_start: AudioStreamPlayer
var _boost_follow: AudioStreamPlayer
var _boost_loop: AudioStreamPlayer

var _boost_stage := 0
var _boost_timer := 0.0
var _boost_start_length := 0.0
var _boost_follow_length := 0.0

const ENGINE_PITCH_IDLE := 0.7
const ENGINE_PITCH_MAX := 2.1
const ENGINE_VOLUME := 0.55
const IDLE_VOLUME := 0.4
const SOUND_FADE := 6.0
# Above this fraction of top speed the driving loop is fully in.
const ENGINE_BLEND_SPEED := 0.18


# Instanced from res://scenes/Car.tscn when it is there, so the exported
# tuning above can be changed in the inspector and every car in the game
# picks the new values up. Falls back to a bare new() with the defaults
# if the scene is missing, so nothing breaks for want of a file.
const SCENE := "res://scenes/Car.tscn"


static func create() -> CarBody:
	if ResourceLoader.exists(SCENE):
		var packed: PackedScene = load(SCENE)
		var node := packed.instantiate()
		if node is CarBody:
			return node
		node.queue_free()
	return CarBody.new()


func _ready() -> void:
	mass = car_mass
	# Godot's gravity is 9.8 m/s2; Rocket League's is 650 uu/s2.
	gravity_scale = (RL_GRAVITY * UU) / 9.8
	linear_damp = 0.0
	angular_damp = 0.0
	continuous_cd = true
	can_sleep = false
	# The shell is held up by the springs, so its own centre of mass
	# should sit where the body is, not where the collider happens to be.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3.ZERO

	_build_collision()
	_build_shell()
	_build_suspension()
	_build_trails()

	_engine_idle = Audio.loop("engine_idle")
	_engine_drive = Audio.loop("engine")
	_boost_loop = Audio.loop("boost3")
	_boost_start = Audio.voice("boost")
	_boost_follow = Audio.voice("boost2")
	_boost_start_length = Audio.length_of("boost")
	_boost_follow_length = Audio.length_of("boost2")


func ride_height() -> float:
	return RIDE_HEIGHT


# Audio.loop() and Audio.voice() parent to the Audio autoload, which
# outlives this scene, so the car's five voices have to be taken down
# with it. Otherwise an engine keeps running in the menus.
func _exit_tree() -> void:
	var voices: Array[AudioStreamPlayer] = [
		_engine_idle, _engine_drive, _boost_loop, _boost_start, _boost_follow,
	]
	for voice in voices:
		if voice != null and is_instance_valid(voice):
			voice.queue_free()


# --- Construction ---------------------------------------------------
#
# The body's origin sits at wheel height. The collider is the shell
# ABOVE the wheels, and the raycasts reach down past it. Previously the
# collider's bottom face was at the origin, so it hit the ground before
# the springs could compress - the car rode up on its own collision box
# and never registered as grounded, which is why it floated and why
# jump did nothing.

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CAR_WIDTH, CAR_HEIGHT, CAR_LENGTH)
	shape.shape = box
	shape.position.y = RIDE_HEIGHT + CAR_HEIGHT * 0.5
	add_child(shape)


func _build_shell() -> void:
	_shell = Node3D.new()
	add_child(_shell)

	var model := Models.spawn_prop("car")
	if model != null:
		# Turned FIRST, then measured. Fitting before turning meant the
		# seat height was computed for the wrong axis, so a turned model
		# ended up half-buried in the road.
		#
		# spin(), not `model.rotation =`: car.glb carries its Y-up
		# conversion and a x100 unit conversion on its own root node, and
		# assigning euler angles over that wiped both out.
		Models.spin(model, model_yaw)
		Models.tilt(model, model_pitch, model_roll)

		var holder := Node3D.new()
		_shell.add_child(holder)
		holder.add_child(model)

		# Uniform, so an imported car is never stretched.
		Models.fit_length(holder, CAR_LENGTH)
		# The model is seated on y = 0; its wheels belong on the ground,
		# which is RIDE_HEIGHT below the body's origin.
		holder.position.y -= RIDE_HEIGHT
		return

	_build_placeholder()


# A wedge pointed at -Z, so which way it faces is never in doubt.
func _build_placeholder() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CAR_WIDTH, CAR_HEIGHT, CAR_LENGTH)
	body.mesh = box
	body.position.y = CAR_HEIGHT * 0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#e8552c")
	mat.roughness = 0.35
	mat.metallic = 0.4
	body.material_override = mat
	_shell.add_child(body)

	var nose := MeshInstance3D.new()
	var wedge := BoxMesh.new()
	wedge.size = Vector3(CAR_WIDTH * 0.8, CAR_HEIGHT * 0.5, CAR_LENGTH * 0.3)
	nose.mesh = wedge
	nose.position = Vector3(0.0, CAR_HEIGHT * 1.1, -CAR_LENGTH * 0.3)

	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color("#1b2130")
	nose.material_override = nose_mat
	_shell.add_child(nose)


# Four suspension rays, plus one probe that catches the car if it ever
# ends up UNDER the floor.
#
# THIS IS THE MELT-THROUGH FIX. The rays used to start at the body's
# origin, which rides one RIDE_HEIGHT above the ground, and
# RayCast3D.hit_from_inside defaults to FALSE. So the failure was a
# one-way trap:
#
#   1. a hard landing or a kerb pushes the origin below the road surface
#   2. all four rays now START INSIDE the ground collider
#   3. hit_from_inside is false, so they report nothing
#   4. nothing reported means not grounded, which means no spring force
#   5. no spring force means it keeps falling, which means step 2 forever
#
# Two or three seconds of driving was all it took to hit step 1 once, and
# there was no way back out. Three things stop it now: the rays start a
# ride height ABOVE the origin so there is real headroom, they report
# from inside a collider, and the probe below un-sticks the car outright
# if it still manages to get under the world.
func _build_suspension() -> void:
	# -Z is the car's nose, so the first two corners are the front pair.
	var half_w := CAR_WIDTH * 0.42
	var half_l := CAR_LENGTH * 0.36
	var corners: Array[Vector3] = [
		Vector3(-half_w, 0.0, -half_l),
		Vector3(half_w, 0.0, -half_l),
		Vector3(-half_w, 0.0, half_l),
		Vector3(half_w, 0.0, half_l),
	]

	for i in corners.size():
		var ray := RayCast3D.new()
		ray.name = WHEEL_NAMES[i]
		ray.position = corners[i] + Vector3(0.0, RAY_LIFT, 0.0)
		ray.target_position = Vector3(0.0, -RAY_LENGTH, 0.0)
		ray.enabled = true
		ray.exclude_parent = true
		# A ray that begins underground reports the surface it is buried
		# in rather than silently reporting nothing.
		ray.hit_from_inside = true
		add_child(ray)
		_rays.append(ray)

		var wheel := WheelContact.new()
		wheel.index = i
		wheels.append(wheel)

	_probe = RayCast3D.new()
	_probe.name = "BuriedProbe"
	# top_level: it looks straight down in WORLD space, so it still finds
	# the ground when the car is upside down on a ceiling. Parented
	# normally it turned with the car and pointed at the sky.
	_probe.top_level = true
	_probe.target_position = Vector3(0.0, -(PROBE_LIFT + PROBE_REACH), 0.0)
	_probe.enabled = true
	_probe.add_exception(self)
	add_child(_probe)


# CPUParticles3D rather than GPU: the Compatibility renderer runs these
# everywhere, and a boost trail is not worth a renderer dependency.
func _build_trails() -> void:
	var exhausts: Array[Vector3] = [
		Vector3(-CAR_WIDTH * 0.26, CAR_HEIGHT * 0.55, CAR_LENGTH * 0.48),
		Vector3(CAR_WIDTH * 0.26, CAR_HEIGHT * 0.55, CAR_LENGTH * 0.48),
	]

	for at in exhausts:
		var flame := CPUParticles3D.new()
		flame.position = at
		flame.emitting = false
		flame.amount = 56
		flame.lifetime = 0.5
		flame.local_coords = false
		flame.direction = Vector3(0.0, 0.0, 1.0)
		flame.spread = 7.0
		flame.initial_velocity_min = CAR_LENGTH * 1.2
		flame.initial_velocity_max = CAR_LENGTH * 2.2
		flame.scale_amount_min = CAR_LENGTH * 0.08
		flame.scale_amount_max = CAR_LENGTH * 0.16
		flame.gravity = Vector3.ZERO

		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.75, 0.55, 1.0, 1.0))
		ramp.set_color(1, Color(1.0, 0.3, 0.55, 0.0))
		flame.color_ramp = ramp

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		flame.material_override = mat

		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.0) * CAR_LENGTH * 0.1
		flame.mesh = quad

		add_child(flame)
		_trails.append(flame)


# --- Driving --------------------------------------------------------

func take_control() -> void:
	driver_seated = true


func release_control() -> void:
	driver_seated = false
	_set_boosting(false)
	_end_boost_sound()
	_silence(_engine_idle)
	_silence(_engine_drive)


func _silence(voice: AudioStreamPlayer) -> void:
	if voice != null:
		voice.volume_db = linear_to_db(0.0001)


func speed() -> float:
	return linear_velocity.length()


func boost_fraction() -> float:
	return boost / BOOST_MAX


func is_grounded() -> bool:
	return _grounded


# --- Driven by an agent ---------------------------------------------
#
# The same struct the player's controls fill, so a bot's car goes through
# exactly the same physics with no special case anywhere below it. This
# is the seam an AI agent plugs into later: give it the struct and it has
# everything a person has and nothing more.

# True while an agent is filling `input` instead of the InputMap.
var ai_driven := false


func drive_inputs(throttle: float, steer: float, boosting: bool, drifting: bool, jumping: bool) -> void:
	ai_driven = true
	driver_seated = true
	input.drive(throttle, steer, boosting, drifting, jumping, _was_jump_down)
	_was_jump_down = input.jump_held


func _physics_process(delta: float) -> void:
	_read_ground()
	_apply_suspension()

	if not driver_seated:
		input.clear()
		_was_jump_down = false
		if _grounded:
			linear_velocity = linear_velocity.lerp(Vector3.ZERO, 3.0 * delta)
		return

	# ONE place reads the controls, and only when a person is driving.
	# An agent fills the same struct through drive_inputs() instead, so
	# everything below this line cannot tell the two apart.
	if not ai_driven:
		input.read_player(_was_jump_down)
	_was_jump_down = input.jump_held

	var boosting := input.boost_held and boost > 0.0

	if _recovering > 0.0:
		_recovering -= delta
		_right_the_car(delta)
	elif _grounded:
		_airborne_for = 0.0
		_jumps_used = 0
		_drive(input.throttle, boosting)
		_steer(input.steer, input.handbrake_held, delta)
		_grip(input.handbrake_held, delta)
	else:
		_airborne_for += delta
		_air_control(input.pitch, input.yaw, input.handbrake_held, input.roll, delta)

	_apply_boost(boosting, delta)
	_handle_jump(delta)
	_update_sound(input.throttle, boosting, delta)

	if _flip_lock > 0.0:
		_flip_lock -= delta

	_clamp_speed()


# --- Ground ---------------------------------------------------------

func _read_ground() -> void:
	_read_wheels()
	# Only after the wheels are known - being under the world is
	# something they report, and unburying moves the car, so what they
	# report has to be taken again afterwards.
	if _unbury():
		_read_wheels()


func _read_wheels() -> void:
	var slope_min := deg_to_rad(slope_max_degrees)
	var floor_max := deg_to_rad(floor_max_degrees)
	var ceiling_min := deg_to_rad(ceiling_min_degrees)
	var fast_enough := speed() >= wall_stick_speed_uu * UU

	var up := global_transform.basis.y
	var normal_sum := Vector3.ZERO
	var driving := 0

	for i in wheels.size():
		var wheel: WheelContact = wheels[i]
		var ray: RayCast3D = _rays[i]
		wheel.clear()

		# Cast NOW, at where the car actually is.
		#
		# A RayCast3D is refreshed by the physics server during its step,
		# so reading one from _physics_process gives last step's answer at
		# last step's position. That is a frame of lag in normal driving
		# and a wrong answer outright the moment anything moves the car
		# between steps - a kickoff placement, a goal reset, _unbury().
		# Phase 9's flip resets hang off these contacts, and a reset
		# granted from a stale hit is a reset granted off thin air.
		ray.force_raycast_update()
		if not ray.is_colliding():
			continue

		wheel.grounded = true
		wheel.position = ray.get_collision_point()
		wheel.collider = ray.get_collider()
		wheel.distance = ray.global_position.distance_to(wheel.position)

		# A ray that started INSIDE a collider reports a zero-length
		# normal, because there is no face to take one from. Standing the
		# car's own up in for it keeps the spring pushing the right way
		# while _unbury() gets it out.
		# A ray that started INSIDE a collider reports a zero-length
		# normal, because there is no face to take one from. That is also
		# the one reliable way to tell that a wheel is under the world
		# rather than on it, so it is recorded rather than just patched
		# over. The car's own up stands in so the spring still pushes the
		# right way while _unbury() gets it out.
		var surface := ray.get_collision_normal()
		wheel.inside_surface = surface.length_squared() <= 0.0001
		wheel.normal = up if wheel.inside_surface else surface.normalized()

		# Measured from the ray's own start, which sits RAY_LIFT above
		# the body origin - so REST_LENGTH, not RIDE_HEIGHT, is where the
		# spring is neither compressed nor extended.
		wheel.compression = clampf((REST_LENGTH - wheel.distance) / RIDE_HEIGHT, 0.0, 1.0)

		var offset := wheel.position - global_position
		wheel.point_velocity = linear_velocity + angular_velocity.cross(offset)
		wheel.surface_velocity = _velocity_of(wheel.collider, wheel.position)
		wheel.closing_speed = (wheel.point_velocity - wheel.surface_velocity).dot(up)

		wheel.surface_angle = wheel.normal.angle_to(Vector3.UP)
		wheel.kind = WheelContact.classify(wheel.normal, floor_max, ceiling_min, slope_min)

		# Floor and slope always hold. A wall or a ceiling only holds
		# while the car is moving fast enough to stay on it.
		var flat := wheel.kind == WheelContact.Kind.FLOOR or wheel.kind == WheelContact.Kind.SLOPE
		wheel.drivable = flat or fast_enough
		# Ordinary floor never grants a reset; everything else can.
		wheel.reset_eligible = (not flat) or reset_allows_floor

		if wheel.drivable:
			driving += 1
			normal_sum += wheel.normal

	_grounded = driving > 0
	if _grounded:
		_ground_normal = (normal_sum / float(driving)).normalized()


# How fast the thing a wheel is resting on is itself moving, at the point
# of contact. The arena is static and returns zero; the ball is not, and
# a flip reset taken off a ball travelling at 40 m/s has to measure the
# closing speed against the BALL rather than against the world.
func _velocity_of(body: Object, at: Vector3) -> Vector3:
	if body is RigidBody3D:
		var rigid: RigidBody3D = body
		return rigid.linear_velocity + rigid.angular_velocity.cross(at - rigid.global_position)
	if body is CharacterBody3D:
		return (body as CharacterBody3D).velocity
	return Vector3.ZERO


# --- What the car is touching, for anything that needs to ask ----------

func grounded_wheels() -> int:
	var count := 0
	for wheel in wheels:
		if wheel.drivable:
			count += 1
	return count


func touching_wheels() -> int:
	var count := 0
	for wheel in wheels:
		if wheel.grounded:
			count += 1
	return count


func reset_eligible_wheels() -> int:
	var count := 0
	for wheel in wheels:
		if wheel.grounded and wheel.reset_eligible:
			count += 1
	return count


func ground_normal() -> Vector3:
	return _ground_normal


# The kind of surface the car is mostly on, for the HUD and the debug
# overlay. Whichever kind has the most wheels on it wins.
func surface_kind() -> int:
	var tally := [0, 0, 0, 0, 0]
	for wheel in wheels:
		if wheel.grounded:
			tally[wheel.kind] += 1

	var best := WheelContact.Kind.NONE
	var most := 0
	for i in tally.size():
		if int(tally[i]) > most:
			most = int(tally[i])
			best = i
	return best


# The last line of defence against driving into the floor.
#
# The probe starts well above the roof and looks straight down. In normal
# driving it finds the road BELOW the car and nothing happens. If it ever
# finds a surface ABOVE the car's origin, the car is underneath the world,
# and no amount of spring force is going to argue it back out - so it gets
# put back on top of that surface with its downward speed cancelled.
#
# Checked every physics frame, so the car is only ever a frame's worth of
# fall under the surface when this catches it.
# Returns true if the car was moved.
func _unbury() -> bool:
	if not _buried():
		return false

	# Cast straight DOWN IN WORLD SPACE from above the roof. The probe is
	# top_level, so it keeps pointing down however the car is oriented -
	# as a child it turned with the car, which on a ceiling meant it
	# pointed at the sky.
	_probe.global_transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * PROBE_LIFT)
	_probe.force_raycast_update()
	if not _probe.is_colliding():
		return false

	var surface := _probe.get_collision_point().y
	if surface <= global_position.y + SURFACE_SLACK:
		return false

	var lifted := global_transform
	lifted.origin.y = surface + RIDE_HEIGHT
	global_transform = lifted

	if linear_velocity.y < 0.0:
		linear_velocity.y = 0.0
	return true


# Under the world, as opposed to legitimately upside down under a
# ceiling. The test used to be "the probe found a surface above the car",
# which is TRUE OF EVERY CEILING - so driving on one teleported the car
# up through it. A wheel whose ray began inside a collider is the
# unambiguous version: you cannot be inside the floor and on it.
func _buried() -> bool:
	for wheel in wheels:
		if wheel.inside_surface:
			return true
	# Nothing under any wheel at all is the other way it happens: the car
	# tunnelled clean through in one step and the rays now start below
	# the collider entirely.
	return touching_wheels() == 0


# One spring per corner, pushing along the shell's own up so the car
# banks with a slope rather than fighting it.
func _apply_suspension() -> void:
	var up := global_transform.basis.y
	# A quarter of the car's weight per wheel. Gravity is already scaled,
	# so this holds the car at RIDE_HEIGHT whatever it masses.
	var weight := mass * 9.8 * gravity_scale * 0.25
	var share := mass * 0.25

	for wheel in wheels:
		# DRIVABLE, not merely grounded. A wall the car is too slow to
		# hold has no spring, so it slides off instead of hovering
		# beside it - which is the behaviour that makes a wall a wall.
		if not wheel.drivable:
			continue

		var force := weight * (wheel.compression * spring_strength) \
			- wheel.closing_speed * damper_strength * share
		apply_force(up * maxf(force, 0.0), wheel.position - global_position)


func _drive(throttle: float, boosting: bool) -> void:
	var forward := -global_transform.basis.z
	var along := linear_velocity.dot(forward)

	if absf(throttle) < 0.02:
		# Coasting: RL bleeds off at a fixed rate rather than rolling on.
		if absf(along) > 0.01:
			apply_central_force(-forward * signf(along) * coast_deceleration_uu * UU * mass)
		return

	# Throttle against the way it is already moving is braking.
	if along * throttle < -0.01 and absf(along) > 0.02:
		apply_central_force(forward * signf(throttle) * brake_strength_uu * UU * mass)
		return

	var ceiling := max_speed_no_boost()
	if boosting:
		ceiling = max_speed()
	if absf(along) >= ceiling:
		return

	# RL's throttle curve: full push from rest, nothing left at the
	# no-boost ceiling.
	var fraction := clampf(absf(along) / max_speed_no_boost(), 0.0, 1.0)
	var accel := lerpf(forward_acceleration_uu, forward_acceleration_top_uu, fraction)
	apply_central_force(forward * throttle * accel * UU * mass)


# Yaw about the ground normal, not the world's up, so steering works on
# a slope. Driven as a rate rather than a torque, which is how RL's
# turn radius actually behaves.
func _steer(steer: float, drifting: bool, delta: float) -> void:
	var forward := -global_transform.basis.z
	var along := linear_velocity.dot(forward)
	var bite := clampf(absf(along) / (steering_bite_speed_uu * UU), 0.0, 1.0)

	var rate := steering_yaw_rate * steer * bite * signf(along)
	if drifting:
		rate *= handbrake_yaw_bonus

	# Replace the yaw component, leave pitch and roll to the springs.
	var spin := angular_velocity
	var about_normal := spin.dot(_ground_normal)
	var wanted := rate
	var blended := lerpf(about_normal, wanted, clampf(12.0 * delta, 0.0, 1.0))
	angular_velocity = spin + _ground_normal * (blended - about_normal)


# Cancels sideways slide. Without this the car handles like it is on
# ice; with it, it corners.
func _grip(drifting: bool, delta: float) -> void:
	var side := global_transform.basis.x
	var sideways := linear_velocity.dot(side)

	var strength := sideways_friction
	if drifting:
		strength = handbrake_sideways_friction

	linear_velocity -= side * sideways * clampf(strength * delta, 0.0, 1.0)


# --- Air ------------------------------------------------------------

# Angular acceleration applied directly, the way Rocket League does it -
# torque divided by an inertia tensor we would only have to guess at.
# `directional` is Rocket League's Air Roll Left / Air Roll Right: hold it
# and the car turns that way by itself, at full rate, while the stick
# carries on pitching and yawing underneath. That is what separates it
# from the free air roll on the powerslide button, where the stick has to
# be given over to the roll and cannot do anything else.
func _air_control(pitch: float, yaw_or_roll: float, rolling: bool,
		directional: float, delta: float) -> void:
	if _flip_lock > 0.0:
		return

	var frame := global_transform.basis
	var local := Vector3(
		frame.x.dot(angular_velocity),
		frame.y.dot(angular_velocity),
		frame.z.dot(angular_velocity))

	var yaw := 0.0
	var roll := 0.0
	if not is_zero_approx(directional):
		roll = directional
		yaw = yaw_or_roll
	elif rolling:
		roll = yaw_or_roll
	else:
		yaw = yaw_or_roll

	# Damping only applies on an axis that is not being driven, which is
	# what makes RL's air control hold a rotation instead of snapping
	# back to level.
	# Negated: a positive rotation about the car's right axis drops the
	# nose, so stick-up would tilt the car down without this.
	local.x += (air_pitch_strength * -pitch - air_pitch_damping * local.x * (1.0 - absf(pitch))) * delta
	local.y += (air_yaw_strength * yaw - air_yaw_damping * local.y * (1.0 - absf(yaw))) * delta
	local.z += (air_roll_strength * roll - air_roll_damping * local.z * (1.0 - absf(roll))) * delta

	var world := frame.x * local.x + frame.y * local.y + frame.z * local.z
	if world.length() > max_angular_speed:
		world = world.normalized() * max_angular_speed
	angular_velocity = world


# --- Jumps and flips -------------------------------------------------

func _handle_jump(delta: float) -> void:
	var down := input.jump_held
	var pressed := input.jump_pressed
	# Consumed, so one press is one jump however many times this runs.
	input.jump_pressed = false

	if _recovering > 0.0:
		return

	# Landed on its roof: jump rights it rather than doing nothing.
	if pressed and _is_stranded():
		_start_recovery()
		return

	# Holding jump keeps pushing for a fifth of a second - that is what
	# makes RL's jump height depend on how long the button is held.
	if down and _jump_held_for > 0.0 and _jump_held_for < jump_hold_time:
		_jump_held_for += delta
		apply_central_force(global_transform.basis.y * jump_hold_force_uu * UU * mass)
	elif not down:
		_jump_held_for = 0.0

	if not pressed:
		return

	if _grounded:
		_jump()
		return

	if _jumps_used >= 2 or _airborne_for > flip_window:
		return

	if input.flip_aimed(flip_deadzone):
		_flip(input.flip_forward, input.flip_side)
	else:
		_second_jump()


# Upside down, or nearly, and not going anywhere.
func _is_stranded() -> bool:
	if global_transform.basis.y.dot(Vector3.UP) > recover_tilt:
		return false
	return _grounded or linear_velocity.length() < max_speed_no_boost() * 0.08


func _start_recovery() -> void:
	_recovering = recover_time
	_jumps_used = 2
	_flip_lock = 0.0
	# A nudge off the ground, so it rolls clear instead of grinding on
	# its roof.
	linear_velocity += Vector3.UP * jump_force_uu * UU * 0.6
	Audio.play("click")


# Rotates the shortest way back to level, about the axis between where
# its roof points and where up is.
func _right_the_car(delta: float) -> void:
	var up := global_transform.basis.y
	var axis := up.cross(Vector3.UP)
	if axis.length() < 0.001:
		# Exactly inverted: no unique shortest way, so pick the car's
		# own length as the axis and roll it end over end.
		axis = global_transform.basis.z
	axis = axis.normalized()

	var error := up.angle_to(Vector3.UP)
	angular_velocity = axis * minf(error / maxf(recover_time, 0.01), max_angular_speed) * recover_speed * 0.5

	# Held up just long enough to finish the roll.
	apply_central_force(Vector3.UP * mass * 9.8 * gravity_scale * 0.45)

	if error < 0.25:
		_recovering = 0.0
		angular_velocity = Vector3.ZERO
	elif delta <= 0.0:
		_recovering = 0.0


func _jump() -> void:
	_jumps_used = 1
	_airborne_for = 0.0
	_jump_held_for = 0.001
	linear_velocity += global_transform.basis.y * jump_force_uu * UU
	Audio.play("click")


func _second_jump() -> void:
	_jumps_used = 2
	linear_velocity += global_transform.basis.y * jump_force_uu * UU


# Front, back and side flips are one move with a different axis: a shove
# in the stick's direction and a spin about the axis at right angles.
func _flip(throttle: float, steer: float) -> void:
	_jumps_used = 2
	_flip_lock = flip_duration

	var frame := global_transform.basis
	var aim := Vector2(steer, throttle).normalized()
	var direction := (-frame.z * aim.y - frame.x * aim.x).normalized()

	# RL cancels the car's existing planar speed into the dodge, so the
	# flip goes where it was aimed rather than where it was drifting.
	var flat := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	linear_velocity -= flat * 0.25
	linear_velocity += direction * flip_impulse_uu * UU

	angular_velocity = (frame.x * -aim.y - frame.z * aim.x).normalized() * flip_rotation_speed
	Audio.play("click")


# --- Boost ------------------------------------------------------------

func _apply_boost(boosting: bool, delta: float) -> void:
	if boosting and boost > 0.0:
		# Drained whether or not it is still adding speed, which is what
		# RL does - boosting at supersonic costs boost and buys nothing.
		boost = maxf(0.0, boost - boost_drain_rate * delta)
		_set_boosting(true)

		var forward := -global_transform.basis.z
		if linear_velocity.dot(forward) < max_speed():
			apply_central_force(forward * boost_acceleration_uu * UU * mass)
		return

	boost = minf(BOOST_MAX, boost + boost_recharge_rate * delta)
	_set_boosting(false)


# Rocket League clamps a car to 2300 uu/s in EVERY direction - boost,
# gravity, collisions and flips included - and that clamp was missing.
#
# The only thing limiting speed was the throttle curve, and boost does
# not go through the throttle curve: _apply_boost() pushed at a flat
# 991.667 uu/s^2 for as long as there was boost in the tank and nothing
# ever said stop. The acceptance test measured 286 m/s against a ceiling
# of 184.
func _clamp_speed() -> void:
	var top := max_speed()
	var moving := linear_velocity.length()
	if moving > top:
		linear_velocity = linear_velocity * (top / moving)

	# The same for rotation, which flips and collisions can otherwise
	# push past what air control is able to pull back.
	var spin := angular_velocity.length()
	if spin > max_angular_speed:
		angular_velocity = angular_velocity * (max_angular_speed / spin)


func _update_sound(throttle: float, boosting: bool, delta: float) -> void:
	_update_engine(throttle, delta)
	_update_boost_sound(boosting, delta)


# The two loops crossfade on how much the car is actually doing, so
# idle is what you hear sitting still and the driving loop takes over
# as it rolls.
func _update_engine(throttle: float, delta: float) -> void:
	var fraction := clampf(speed() / max_speed(), 0.0, 1.0)
	var effort := clampf(fraction / ENGINE_BLEND_SPEED, 0.0, 1.0)
	effort = maxf(effort, absf(throttle))

	if _engine_drive != null:
		_engine_drive.pitch_scale = lerpf(ENGINE_PITCH_IDLE, ENGINE_PITCH_MAX, fraction)
		_fade(_engine_drive, ENGINE_VOLUME * effort * Settings.sfx_volume, delta)

	if _engine_idle != null:
		_fade(_engine_idle, IDLE_VOLUME * (1.0 - effort) * Settings.sfx_volume, delta)


# boost -> boost2 -> boost3 looping, each handing over as the last one
# ends. Stage 0 is silent.
func _update_boost_sound(boosting: bool, delta: float) -> void:
	if not boosting:
		if _boost_stage != 0:
			_end_boost_sound()
		if _boost_loop != null:
			_fade(_boost_loop, 0.0, delta)
		return

	if _boost_stage == 0:
		_boost_stage = 1
		_boost_timer = _boost_start_length
		_play_once(_boost_start)
		# No first file: skip straight to the loop rather than stalling.
		if _boost_start_length <= 0.0:
			_boost_stage = 2
			_boost_timer = _boost_follow_length
			_play_once(_boost_follow)

	elif _boost_stage == 1:
		_boost_timer -= delta
		if _boost_timer <= 0.0:
			_boost_stage = 2
			_boost_timer = _boost_follow_length
			_play_once(_boost_follow)

	elif _boost_stage == 2:
		_boost_timer -= delta
		if _boost_timer <= 0.0:
			_boost_stage = 3

	if _boost_stage == 3 and _boost_loop != null:
		_fade(_boost_loop, Settings.sfx_volume, delta)


func _play_once(voice: AudioStreamPlayer) -> void:
	if voice == null:
		return
	voice.volume_db = linear_to_db(maxf(0.0001, Settings.sfx_volume))
	voice.play()


func _end_boost_sound() -> void:
	_boost_stage = 0
	_boost_timer = 0.0
	if _boost_start != null:
		_boost_start.stop()
	if _boost_follow != null:
		_boost_follow.stop()


func _fade(voice: AudioStreamPlayer, target: float, delta: float) -> void:
	var current := db_to_linear(voice.volume_db)
	var next := lerpf(current, target, clampf(SOUND_FADE * delta, 0.0, 1.0))
	voice.volume_db = linear_to_db(maxf(0.0001, next))


func _set_boosting(on: bool) -> void:
	for flame in _trails:
		if flame.emitting != on:
			flame.emitting = on
