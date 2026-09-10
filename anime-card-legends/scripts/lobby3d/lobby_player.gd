class_name LobbyPlayer
extends CharacterBody3D

# =========================================================
# Third-person controller for the 3D lobby. Builds its own visual
# body, collision, and orbiting camera rig so the world script only
# has to instantiate it.
#
# WASD / arrows to move, mouse to look, Space to jump, Esc to free
# the cursor.
# =========================================================

const SPEED := 9.5
const SPRINT_MULT := 2.6
# Developer mode gets a serious boost, because crossing a square
# kilometre to check one building otherwise takes two minutes.
const DEV_SPRINT_MULT := 7.0
const ACCEL := 12.0
const JUMP_VELOCITY := 5.2
const GRAVITY := 18.0
const TURN_SPEED := 11.0

const MOUSE_SENS := 0.0032
# Radians per second at full right-stick deflection.
const STICK_SENS := 2.6
const PITCH_MIN := -0.9
const PITCH_MAX := 0.45
const CAM_DISTANCE := 9.0
const CAM_HEIGHT := 3.2

# How tall the character stands, imported or not. The capsule collider
# is built to this, and an imported model is rescaled to match it, so a
# model exported at any scale walks the world correctly.
const BODY_HEIGHT := 1.9

# Godot's forward is -Z. Set this to PI if the imported character faces
# the camera while running away.
const MODEL_YAW := 0.0

var _yaw := 0.0
var _pitch := -0.25
var _body: Node3D
var _pivot: Node3D
var _camera: Camera3D
var _mouse_captured := false

# Set only when res://art/models/player.* supplied an AnimationPlayer.
var _anim: AnimationPlayer
var _anim_idle := ""
var _anim_run := ""
var _anim_jump := ""
var _anim_current := ""


func _ready() -> void:
	_build_collision()
	_build_body()
	_build_camera()
	_capture_mouse(true)


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = BODY_HEIGHT
	shape.shape = capsule
	shape.position.y = BODY_HEIGHT * 0.5
	add_child(shape)


func _build_body() -> void:
	_body = Node3D.new()
	add_child(_body)

	# An imported character replaces the placeholder entirely.
	if _build_imported_body():
		return

	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.45
	capsule.height = BODY_HEIGHT * 0.9
	torso.mesh = capsule
	torso.position.y = BODY_HEIGHT * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#f5a623")
	mat.roughness = 0.5
	torso.material_override = mat
	_body.add_child(torso)

	# Small forward fin so facing direction is readable.
	var nose := MeshInstance3D.new()
	var prism := BoxMesh.new()
	prism.size = Vector3(0.25, 0.25, 0.6)
	nose.mesh = prism
	nose.position = Vector3(0, 1.35, -0.55)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color("#ffffff")
	nose_mat.emission_enabled = true
	nose_mat.emission = Color("#ffe9c0")
	nose_mat.emission_energy_multiplier = 0.6
	nose.material_override = nose_mat
	_body.add_child(nose)

	var glow := OmniLight3D.new()
	glow.position.y = 1.4
	glow.light_color = Color("#ffd9a8")
	glow.light_energy = 1.0
	glow.omni_range = 7.0
	_body.add_child(glow)


# Drops res://art/models/player.glb in as the character, rescaled to
# BODY_HEIGHT and re-seated so its feet are on the ground. Returns false
# when there is no model, in which case the capsule placeholder is used.
#
# The model is expected to face -Z, which is Godot's forward. If it walks
# backwards, set MODEL_YAW at the top of this file to PI.
func _build_imported_body() -> bool:
	var model := Models.spawn_player()
	if model == null:
		return false

	_body.add_child(model)
	Models.fit_height(model, BODY_HEIGHT)
	model.rotation.y = MODEL_YAW

	_anim = Models.find_animation_player(model)
	if _anim != null:
		var clips := Models.animation_set(_anim)
		_anim_idle = str(clips["idle"])
		_anim_run = str(clips["run"])
		_anim_jump = str(clips["jump"])
		_play_animation(_anim_idle)

	return true


# Switching only on a change keeps the clip from restarting every frame.
func _play_animation(anim_name: String) -> void:
	if _anim == null or anim_name == "" or anim_name == _anim_current:
		return
	if not _anim.has_animation(anim_name):
		return
	_anim_current = anim_name
	_anim.play(anim_name)


func _update_animation(moving: bool) -> void:
	if _anim == null:
		return
	if not is_on_floor() and _anim_jump != "":
		_play_animation(_anim_jump)
	elif moving and _anim_run != "":
		_play_animation(_anim_run)
		# The run clip plays faster while sprinting rather than the feet
		# sliding across the ground.
		if Input.is_action_pressed("acl_sprint"):
			_anim.speed_scale = SPRINT_MULT * 0.7
		else:
			_anim.speed_scale = 1.0
	elif _anim_idle != "":
		_play_animation(_anim_idle)
		_anim.speed_scale = 1.0


func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.position.y = 1.4
	add_child(_pivot)

	_camera = Camera3D.new()
	_camera.position = Vector3(0, CAM_HEIGHT, CAM_DISTANCE)
	_camera.fov = 68.0
	_camera.current = true
	_pivot.add_child(_camera)


# Hands the viewport back to the player's own camera - used when
# stepping out of the car.
func make_current() -> void:
	if _camera != null:
		_camera.current = true


func _capture_mouse(capture: bool) -> void:
	_mouse_captured = capture
	if capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clamp(_pitch - event.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)

	elif event is InputEventMouseButton and not _mouse_captured:
		if event.pressed:
			_capture_mouse(true)

	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_capture_mouse(false)


# Right-stick look. Frame-rate independent, unlike mouse motion, which
# already arrives as a per-event delta.
func _apply_stick_look(delta: float) -> void:
	var look := Controls.look_vector()
	if look == Vector2.ZERO:
		return
	_yaw -= look.x * STICK_SENS * delta
	_pitch = clampf(_pitch - look.y * STICK_SENS * delta, PITCH_MIN, PITCH_MAX)


func _physics_process(delta: float) -> void:
	_apply_stick_look(delta)
	_apply_camera()

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_pressed("acl_jump"):
		velocity.y = JUMP_VELOCITY

	# Bound to WASD, the arrows, the d-pad and the left stick at once -
	# see scripts/core/controls.gd. The old ui_* actions were arrows and
	# d-pad only, which is why WASD did nothing.
	var input := Controls.move_vector()
	var direction := Vector3.ZERO

	if input != Vector2.ZERO:
		# Movement is relative to where the camera is looking.
		var basis_z := Vector3(sin(_yaw), 0.0, cos(_yaw))
		var basis_x := Vector3(cos(_yaw), 0.0, -sin(_yaw))
		direction = (basis_x * input.x + basis_z * input.y).normalized()

	var speed := SPEED
	if Input.is_action_pressed("acl_sprint"):
		if Settings.dev_mode:
			speed *= DEV_SPRINT_MULT
		else:
			speed *= SPRINT_MULT

	var target := direction * speed
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta * speed)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta * speed)

	move_and_slide()

	if direction != Vector3.ZERO and _body:
		var want := atan2(direction.x, direction.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, want, TURN_SPEED * delta)

	_update_animation(direction != Vector3.ZERO)


func _apply_camera() -> void:
	if _pivot == null:
		return
	_pivot.rotation.y = _yaw
	_pivot.rotation.x = _pitch
