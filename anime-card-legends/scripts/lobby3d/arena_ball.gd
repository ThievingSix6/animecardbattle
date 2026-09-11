class_name ArenaBall
extends RigidBody3D

# =========================================================
# The ball, on Rocket League's own numbers.
#
#   radius 91.25 uu, mass 30, restitution 0.6, and RL's drag and
#   angular drag. Scaled through the same UU the car uses, so a hit
#   throws it exactly as far relative to the car as it does in RL.
# =========================================================

const RL_RADIUS_UU := 91.25
const RL_MASS := 30.0
const RESTITUTION := 0.6
const FRICTION := 0.35
# RL's ball loses a little speed every second in the air.
const DRAG := 0.03
const ANGULAR_DRAG := 0.02
const MAX_SPEED_UU := 6000.0

const RADIUS := RL_RADIUS_UU * CarBody.UU
const MAX_SPEED := MAX_SPEED_UU * CarBody.UU

var _glow: OmniLight3D

# Below this a touch is a nudge, not a hit worth a sound.
const HIT_SPEED := 6.0
const HIT_COOLDOWN := 0.08
var _hit_cooldown := 0.0
var _last_velocity := Vector3.ZERO


static func create() -> ArenaBall:
	return ArenaBall.new()


func _ready() -> void:
	mass = RL_MASS
	gravity_scale = (CarBody.RL_GRAVITY * CarBody.UU) / 9.8
	continuous_cd = true
	can_sleep = false
	linear_damp = DRAG
	angular_damp = ANGULAR_DRAG

	var surface := PhysicsMaterial.new()
	surface.bounce = RESTITUTION
	surface.friction = FRICTION
	physics_material_override = surface

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	add_child(shape)

	# Needed for contact_monitor to report anything.
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_contact)

	_build_skin()


func _build_skin() -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	mesh.mesh = sphere

	# res://art/models/props/ball.glb - or soccer_ball.glb, since that
	# is what it tends to get called.
	var model := Models.spawn_prop("ball")
	if model == null:
		model = Models.spawn_prop("soccer_ball")
	if model != null:
		add_child(model)
		Models.fit_length(model, RADIUS * 2.0)
		# Centred on the body's origin, which is the middle of a ball,
		# not its base.
		model.position.y -= RADIUS
		_build_glow()
		return

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#dfe6ff")
	mat.roughness = 0.25
	mat.metallic = 0.5
	mat.emission_enabled = true
	mat.emission = Color("#7ab6ff")
	mat.emission_energy_multiplier = RenderMode.emission(0.45)
	mesh.material_override = mat
	add_child(mesh)

	_build_glow()


func _build_glow() -> void:
	_glow = OmniLight3D.new()
	_glow.light_color = Color("#8fc4ff")
	_glow.light_energy = RenderMode.light(1.1)
	_glow.omni_range = RADIUS * 8.0
	add_child(_glow)


func _physics_process(delta: float) -> void:
	# RL caps the ball rather than letting a stack of hits run away with
	# it; without this a boosted flip can put it into orbit.
	if linear_velocity.length() > MAX_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SPEED

	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	_last_velocity = linear_velocity


# Three recordings, chosen by how much the impact actually changed the
# ball's velocity, with the volume trimmed within each band. A dribble
# gets the light hit quietly; a boosted flip gets the hard one at full
# strength; and the bands overlap enough that the change between them
# is not audible as a switch.
const HIT_MEDIUM_SPEED := 0.16     # fraction of the ball's top speed
const HIT_HARD_SPEED := 0.34


func _on_contact(_body: Node) -> void:
	if _hit_cooldown > 0.0:
		return
	_hit_cooldown = HIT_COOLDOWN

	var change := (linear_velocity - _last_velocity).length()
	if change < HIT_SPEED:
		return

	var strength := change / MAX_SPEED

	var key := "ball_hit_light"
	var floor_speed := 0.0
	var ceiling := HIT_MEDIUM_SPEED
	if strength >= HIT_HARD_SPEED:
		key = "ball_hit_hard"
		floor_speed = HIT_HARD_SPEED
		ceiling = HIT_HARD_SPEED * 2.0
	elif strength >= HIT_MEDIUM_SPEED:
		key = "ball_hit_medium"
		floor_speed = HIT_MEDIUM_SPEED
		ceiling = HIT_HARD_SPEED

	# Loudness within the band, so the quietest hard hit is not as loud
	# as the hardest.
	var within := clampf((strength - floor_speed) / maxf(ceiling - floor_speed, 0.001), 0.0, 1.0)
	Audio.play_at(key, lerpf(0.55, 1.0, within))

	hit.emit(strength)


# How hard, as a fraction of the ball's top speed. The arena listens so
# the crowd can react.
signal hit(strength: float)


func reset_to(at: Vector3) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = at
