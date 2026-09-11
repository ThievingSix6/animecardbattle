extends Node3D

# =========================================================
# ROCKET ARENA - the extra mode.
#
# The pitch is Rocket League's, scaled through the same UU the car is:
# 8192 x 10240 x 2044 uu, goals 1786 wide and 642.775 tall. The car and
# the ball already run on RL's constants, so nothing here is a new
# physics system - it is a box with two goals, a clock and an opponent.
#
# Reached from any portal's travel menu.
# =========================================================

# RL's field, in uu.
const FIELD_WIDTH_UU := 8192.0
const FIELD_LENGTH_UU := 10240.0
const FIELD_HEIGHT_UU := 2044.0
const GOAL_WIDTH_UU := 1786.0
const GOAL_HEIGHT_UU := 642.775
const GOAL_DEPTH_UU := 880.0

const HALF_WIDTH := FIELD_WIDTH_UU * 0.5 * CarBody.UU
const HALF_LENGTH := FIELD_LENGTH_UU * 0.5 * CarBody.UU
const CEILING := FIELD_HEIGHT_UU * CarBody.UU
const GOAL_HALF_WIDTH := GOAL_WIDTH_UU * 0.5 * CarBody.UU
const GOAL_HEIGHT := GOAL_HEIGHT_UU * CarBody.UU
const GOAL_DEPTH := GOAL_DEPTH_UU * CarBody.UU

const MATCH_SECONDS := 300.0
const KICKOFF_PAUSE := 2.0

const BLUE := Color("#3b82f6")
const ORANGE := Color("#f5a623")

var car: CarBody
var bot: CarBody
var ball: ArenaBall
var camera: CarCamera
var hud: ArenaHUD

var _score := {"blue": 0, "orange": 0}
var _clock := MATCH_SECONDS
var _kickoff := KICKOFF_PAUSE
var _over := false
var _bot_brain: ArenaBot


func _ready() -> void:
	if not GameState.has_active_slot():
		call_deferred("_bounce")
		return

	Audio.play_music("music_battle")
	_build_environment()
	_build_pitch()
	_build_goals()
	_build_actors()
	_build_hud()
	_kick_off()


func _bounce() -> void:
	get_tree().change_scene_to_file(Routes.TITLE)


# --- World ------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = SkyBuilder.night_city()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6a3ff0")
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color("#2a1b45")
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.0

	if RenderMode.supports_glow():
		env.glow_enabled = true
		env.glow_intensity = 1.0

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-62, -30, 0)
	key.light_energy = RenderMode.light(0.7)
	key.light_color = Color("#c9b6ff")
	key.shadow_enabled = true
	add_child(key)

	# Four corner floods, so the pitch is lit like a stadium rather than
	# by one sun.
	var corners: Array[Vector3] = [
		Vector3(-HALF_WIDTH, CEILING * 0.8, -HALF_LENGTH),
		Vector3(HALF_WIDTH, CEILING * 0.8, -HALF_LENGTH),
		Vector3(-HALF_WIDTH, CEILING * 0.8, HALF_LENGTH),
		Vector3(HALF_WIDTH, CEILING * 0.8, HALF_LENGTH),
	]
	for at in corners:
		var flood := OmniLight3D.new()
		flood.position = at
		flood.light_color = Color("#b9c8ff")
		flood.light_energy = RenderMode.light(1.1)
		flood.omni_range = HALF_LENGTH * 1.4
		add_child(flood)


func _build_pitch() -> void:
	var body := StaticBody3D.new()
	add_child(body)

	_slab(body, Vector3(0, -1.0, 0), Vector3(HALF_WIDTH * 2.0, 2.0, HALF_LENGTH * 2.0),
		Textures.sidewalk(HALF_WIDTH, Color("#131a2c")))

	# Walls. The goal openings are cut by building each end wall as two
	# posts and a lintel rather than one slab.
	var wall := Textures.rock(HALF_WIDTH, Color("#1b2136"))
	_slab(body, Vector3(-HALF_WIDTH, CEILING * 0.5, 0),
		Vector3(2.0, CEILING, HALF_LENGTH * 2.0), wall)
	_slab(body, Vector3(HALF_WIDTH, CEILING * 0.5, 0),
		Vector3(2.0, CEILING, HALF_LENGTH * 2.0), wall)
	_end_wall(body, -HALF_LENGTH, wall)
	_end_wall(body, HALF_LENGTH, wall)

	_slab(body, Vector3(0, CEILING, 0),
		Vector3(HALF_WIDTH * 2.0, 2.0, HALF_LENGTH * 2.0), wall)

	_paint_markings()


# Two posts and a lintel, leaving the goal mouth open.
func _end_wall(body: StaticBody3D, z: float, material: Material) -> void:
	var side := (HALF_WIDTH - GOAL_HALF_WIDTH)
	var offset := GOAL_HALF_WIDTH + side * 0.5

	_slab(body, Vector3(-offset, CEILING * 0.5, z), Vector3(side, CEILING, 2.0), material)
	_slab(body, Vector3(offset, CEILING * 0.5, z), Vector3(side, CEILING, 2.0), material)
	_slab(body, Vector3(0, GOAL_HEIGHT + (CEILING - GOAL_HEIGHT) * 0.5, z),
		Vector3(GOAL_HALF_WIDTH * 2.0, CEILING - GOAL_HEIGHT, 2.0), material)


func _slab(body: StaticBody3D, at: Vector3, size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = material
	body.add_child(mesh)

	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = size
	shape.shape = collider
	shape.position = at
	body.add_child(shape)


# A halfway line and a centre circle, so the pitch reads as a pitch.
func _paint_markings() -> void:
	var line := MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(HALF_WIDTH * 2.0, 0.1, 1.2)
	line.mesh = strip
	line.position.y = 0.06
	line.material_override = _glow_material(Color("#8fa4c8"), 0.5)
	add_child(line)

	var circle := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = ArenaBall.RADIUS * 3.0
	ring.outer_radius = ArenaBall.RADIUS * 3.0 + 1.2
	circle.mesh = ring
	circle.position.y = 0.06
	circle.material_override = _glow_material(Color("#8fa4c8"), 0.5)
	add_child(circle)


func _glow_material(tint: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = RenderMode.emission(energy)
	return mat


# --- Goals -------------------------------------------------------------

func _build_goals() -> void:
	_build_goal(-HALF_LENGTH, BLUE, "orange")
	_build_goal(HALF_LENGTH, ORANGE, "blue")


# `scorer` is who is credited when the ball crosses this line.
func _build_goal(z: float, tint: Color, scorer: String) -> void:
	var inward := -signf(z)

	# The net: a lit back wall set behind the mouth.
	var back := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(GOAL_HALF_WIDTH * 2.0, GOAL_HEIGHT, 1.0)
	back.mesh = box
	back.position = Vector3(0, GOAL_HEIGHT * 0.5, z - inward * GOAL_DEPTH)
	back.material_override = _glow_material(tint, 0.7)
	add_child(back)

	var glow := OmniLight3D.new()
	glow.position = Vector3(0, GOAL_HEIGHT * 0.6, z - inward * GOAL_DEPTH * 0.5)
	glow.light_color = tint
	glow.light_energy = RenderMode.light(1.2)
	glow.omni_range = GOAL_HALF_WIDTH * 3.0
	add_child(glow)

	# The trigger sits just inside the mouth, so a ball that rattles the
	# post without crossing does not score.
	var area := Area3D.new()
	area.position = Vector3(0, GOAL_HEIGHT * 0.5, z - inward * GOAL_DEPTH * 0.5)
	add_child(area)

	var shape := CollisionShape3D.new()
	var trigger := BoxShape3D.new()
	trigger.size = Vector3(GOAL_HALF_WIDTH * 2.0, GOAL_HEIGHT, GOAL_DEPTH)
	shape.shape = trigger
	area.add_child(shape)

	area.body_entered.connect(func(entered: Node): _on_goal(entered, scorer))


func _on_goal(entered: Node, scorer: String) -> void:
	if _over or entered != ball:
		return
	_score[scorer] = int(_score[scorer]) + 1
	Audio.play("victory")
	if hud != null:
		hud.announce("%s SCORES" % scorer.to_upper())
		hud.set_score(int(_score["blue"]), int(_score["orange"]))
	_kick_off()


# --- Actors -------------------------------------------------------------

func _build_actors() -> void:
	ball = ArenaBall.create()
	add_child(ball)

	car = CarBody.create()
	add_child(car)
	car.take_control()

	bot = CarBody.create()
	add_child(bot)

	_bot_brain = ArenaBot.new()
	_bot_brain.setup(bot, ball, HALF_LENGTH)
	add_child(_bot_brain)

	camera = CarCamera.create(car)
	add_child(camera)
	camera.activate()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_hud() -> void:
	hud = ArenaHUD.new()
	add_child(hud)
	hud.set_score(0, 0)


# --- Match flow ---------------------------------------------------------

func _kick_off() -> void:
	_kickoff = KICKOFF_PAUSE
	ball.reset_to(Vector3(0, ArenaBall.RADIUS * 1.2, 0))

	car.global_position = Vector3(0, car.ride_height() + 0.5, HALF_LENGTH * 0.62)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.global_rotation = Vector3(0, 0, 0)
	car.boost = CarBody.BOOST_MAX

	bot.global_position = Vector3(0, bot.ride_height() + 0.5, -HALF_LENGTH * 0.62)
	bot.linear_velocity = Vector3.ZERO
	bot.angular_velocity = Vector3.ZERO
	bot.global_rotation = Vector3(0, PI, 0)
	bot.boost = CarBody.BOOST_MAX


func _process(delta: float) -> void:
	if _over or car == null:
		return

	if _kickoff > 0.0:
		_kickoff -= delta
		var live := _kickoff <= 0.0
		car.driver_seated = live
		_bot_brain.active = live
		if hud != null:
			hud.announce("" if live else "KICKOFF")

	_clock = maxf(0.0, _clock - delta)
	if hud != null:
		hud.set_clock(_clock)
		hud.show_boost(car.boost_fraction(), car.speed())

	if _clock <= 0.0:
		_finish()
		return

	if Controls.cancel_pressed():
		_leave()


func _finish() -> void:
	_over = true
	car.driver_seated = false
	_bot_brain.active = false

	var blue := int(_score["blue"])
	var orange := int(_score["orange"])
	var verdict := "DRAW"
	if blue > orange:
		verdict = "YOU WIN"
		# Winning pays, so the mode is worth playing more than once.
		GameState.add_gems(150)
		GameState.add_gold(6000)
		GameState.save_now()
	elif orange > blue:
		verdict = "YOU LOSE"

	if hud != null:
		hud.finish(verdict, blue, orange)


func _leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(Routes.LOBBY)
