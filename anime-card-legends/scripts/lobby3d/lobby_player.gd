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

const SPEED := 7.5
const ACCEL := 12.0
const JUMP_VELOCITY := 5.2
const GRAVITY := 18.0
const TURN_SPEED := 11.0

const MOUSE_SENS := 0.0032
const PITCH_MIN := -0.9
const PITCH_MAX := 0.45
const CAM_DISTANCE := 9.0
const CAM_HEIGHT := 3.2

var _yaw := 0.0
var _pitch := -0.25
var _body: Node3D
var _pivot: Node3D
var _camera: Camera3D
var _mouse_captured := false


func _ready() -> void:
	_build_collision()
	_build_body()
	_build_camera()
	_capture_mouse(true)


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.0
	shape.shape = capsule
	shape.position.y = 1.0
	add_child(shape)


func _build_body() -> void:
	_body = Node3D.new()
	add_child(_body)

	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.45
	capsule.height = 1.7
	torso.mesh = capsule
	torso.position.y = 1.0
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


func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.position.y = 1.4
	add_child(_pivot)

	_camera = Camera3D.new()
	_camera.position = Vector3(0, CAM_HEIGHT, CAM_DISTANCE)
	_camera.fov = 68.0
	_camera.current = true
	_pivot.add_child(_camera)


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


func _physics_process(delta: float) -> void:
	_apply_camera()

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_key_pressed(KEY_SPACE):
		velocity.y = JUMP_VELOCITY

	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3.ZERO

	if input != Vector2.ZERO:
		# Movement is relative to where the camera is looking.
		var basis_z := Vector3(sin(_yaw), 0.0, cos(_yaw))
		var basis_x := Vector3(cos(_yaw), 0.0, -sin(_yaw))
		direction = (basis_x * input.x + basis_z * input.y).normalized()

	var target := direction * SPEED
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta * SPEED)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta * SPEED)

	move_and_slide()

	if direction != Vector3.ZERO and _body:
		var want := atan2(direction.x, direction.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, want, TURN_SPEED * delta)


func _apply_camera() -> void:
	if _pivot == null:
		return
	_pivot.rotation.y = _yaw
	_pivot.rotation.x = _pitch
