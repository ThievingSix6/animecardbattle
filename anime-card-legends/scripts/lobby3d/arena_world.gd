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
const FLOOR_DEPTH := 24.0
const CEILING := FIELD_HEIGHT_UU * CarBody.UU
const GOAL_HALF_WIDTH := GOAL_WIDTH_UU * 0.5 * CarBody.UU
const GOAL_HEIGHT := GOAL_HEIGHT_UU * CarBody.UU
const GOAL_DEPTH := GOAL_DEPTH_UU * CarBody.UU

# --- The stadium model --------------------------------------------------
# How far the bowl sits back from the ends of the pitch, and then the
# straight 2x on top of it. One number to turn if it wants to be closer
# in or further out.
const STADIUM_MARGIN := 1.2
const STADIUM_SCALE := 2.0

const MATCH_SECONDS := 300.0
const KICKOFF_PAUSE := 2.0

# --- Crowd ------------------------------------------------------------
#
# soccar_crowd.ogg is NOT a bed. It used to run under the whole match at
# a constant level, which turned a stadium full of people into a hiss you
# stopped hearing within a minute.
#
# It is a one-shot now, played when the crowd has a reason - a goal, a
# big hit - and otherwise at a random quiet moment every so often, the
# way a real crowd murmurs between passages of play. soccar_gasp is the
# same: it fires on a near miss, and rarely on its own.
const CROWD_VOLUME := 0.75
# A reaction is never cut off by an idle murmur, and two murmurs never
# stack: one crowd sound at a time.
const CROWD_GAP_MIN := 22.0
const CROWD_GAP_MAX := 55.0
const CROWD_IDLE_VOLUME := 0.3
# Roughly one idle murmur in five is a gasp rather than a swell.
const GASP_CHANCE := 0.2

# A shot that beats the keeper and misses the mouth: past the goal line
# by depth, outside the posts, and travelling.
const NEAR_MISS_SPEED := 0.2   # fraction of the ball's top speed
const NEAR_MISS_COOLDOWN := 2.5

const WARNING_AT := 30.0

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

var _crowd: AudioStreamPlayer
var _crowd_quiet := 0.0
var _near_miss_cooldown := 0.0
var _warned := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if not GameState.has_active_slot():
		call_deferred("_bounce")
		return

	_rng.randomize()

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

	# res://art/models/props/stadium.glb is dropped in as the stands and
	# the roof - scenery around the pitch. The collision box below is
	# still what the ball and the cars actually bounce off, so the model
	# never has to be watertight or match RL's dimensions.
	_build_stadium_shell()

	# Two metres of visible floor over a much deeper collider: at RL
	# speeds the car covers three metres in one physics tick, and a thin
	# floor is a floor it can end up underneath.
	_slab(body, Vector3(0, -1.0, 0), Vector3(HALF_WIDTH * 2.0, 2.0, HALF_LENGTH * 2.0),
		Textures.sidewalk(HALF_WIDTH, Color("#131a2c")),
		Vector3(HALF_WIDTH * 2.0, FLOOR_DEPTH, HALF_LENGTH * 2.0),
		Vector3(0.0, 1.0 - FLOOR_DEPTH * 0.5, 0.0))

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


# The supplied stadium, wrapped around the pitch. Purely visual - the
# collision boxes above are still what the cars and the ball bounce off.
#
# Sized from its FOOTPRINT, not its height, and the footprint is measured
# across the bulk of the model rather than its full bounding box. One
# stray mesh in stadium.glb runs four times the height of the actual
# bowl; fitting to that made the stadium a quarter of the size it should
# be and floated it sixty metres up, which is why it read as a lump in
# the middle of the pitch with the cars kicking off outside it.
#
# The model's long axis is its X, the pitch's long axis is Z, so it also
# needs a quarter turn to line the two up.
func _build_stadium_shell() -> void:
	var model := Models.spawn_prop("stadium")
	if model == null:
		return

	add_child(model)

	# Long enough to swallow the pitch end to end, with room for the
	# stands to sit back off the touchlines.
	var span := HALF_LENGTH * 2.0 * STADIUM_MARGIN * STADIUM_SCALE
	Models.fit_span(model, span)
	Models.spin(model, PI * 0.5)

	# Dropped a little, so the stands rise from below the pitch surface.
	model.position.y -= CEILING * 0.08


# Two posts and a lintel, leaving the goal mouth open.
func _end_wall(body: StaticBody3D, z: float, material: Material) -> void:
	var side := (HALF_WIDTH - GOAL_HALF_WIDTH)
	var offset := GOAL_HALF_WIDTH + side * 0.5

	_slab(body, Vector3(-offset, CEILING * 0.5, z), Vector3(side, CEILING, 2.0), material)
	_slab(body, Vector3(offset, CEILING * 0.5, z), Vector3(side, CEILING, 2.0), material)
	_slab(body, Vector3(0, GOAL_HEIGHT + (CEILING - GOAL_HEIGHT) * 0.5, z),
		Vector3(GOAL_HALF_WIDTH * 2.0, CEILING - GOAL_HEIGHT, 2.0), material)


# One piece of the arena shell. The collider is normally the same box you
# can see, but the floor passes a deeper one so nothing can be driven
# through it - hence the two optional arguments.
func _slab(body: StaticBody3D, at: Vector3, size: Vector3, material: Material,
		collider_size: Vector3 = Vector3.ZERO, collider_at: Vector3 = Vector3.ZERO) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = material
	body.add_child(mesh)

	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = size if collider_size == Vector3.ZERO else collider_size
	shape.shape = collider
	shape.position = at + collider_at
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
	Audio.play("soccar_goal")
	_swell()
	if hud != null:
		hud.announce("%s SCORES" % scorer.to_upper())
		hud.set_score(int(_score["blue"]), int(_score["orange"]))
	_kick_off()


# --- Actors -------------------------------------------------------------

func _build_actors() -> void:
	ball = ArenaBall.create()
	ball.hit.connect(_on_ball_hit)
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

	_crowd = Audio.voice("soccar_crowd")
	_hold_crowd()


# --- Match flow ---------------------------------------------------------

func _kick_off() -> void:
	_kickoff = KICKOFF_PAUSE
	ball.reset_to(Vector3(0, ArenaBall.RADIUS * 1.2, 0))
	Audio.play("soccar_lets_go")

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

	# The clock crossing half a minute is worth calling.
	if not _warned and _clock <= WARNING_AT:
		_warned = true
		Audio.play("30_second_warning")
		if hud != null:
			hud.announce("30 SECONDS")

	_watch_for_near_miss(delta)
	_idle_crowd(delta)

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
		Audio.play("soccar_game_win")
		_swell()
		# Winning pays, so the mode is worth playing more than once.
		GameState.add_gems(150)
		GameState.add_gold(6000)
		GameState.save_now()
	elif orange > blue:
		verdict = "YOU LOSE"
		Audio.play("defeat")

	if hud != null:
		hud.finish(verdict, blue, orange)


# --- Crowd -----------------------------------------------------------

# A hard touch gets a reaction; a dribble does not.
func _on_ball_hit(strength: float) -> void:
	if strength > ArenaBall.HIT_HARD_SPEED:
		_swell(0.7)


# Past the goal line and outside the posts, moving: the shot that was
# nearly something.
func _watch_for_near_miss(delta: float) -> void:
	_near_miss_cooldown = maxf(0.0, _near_miss_cooldown - delta)
	if _near_miss_cooldown > 0.0 or ball == null:
		return

	var at := ball.global_position
	if absf(at.z) < HALF_LENGTH * 0.9:
		return
	if absf(at.x) < GOAL_HALF_WIDTH:
		return
	if ball.linear_velocity.length() < ArenaBall.MAX_SPEED * NEAR_MISS_SPEED:
		return

	_near_miss_cooldown = NEAR_MISS_COOLDOWN
	Audio.play("soccar_gasp")
	_swell(0.5)


# The crowd reacting to something that just happened. Loud, and it resets
# the idle timer so a murmur cannot follow straight on its heels.
func _swell(amount: float = 1.0) -> void:
	_play_crowd("soccar_crowd", CROWD_VOLUME * (0.55 + 0.45 * amount))


# Between reactions the crowd is heard now and then and not otherwise.
# Half a minute or so of nothing is the point: it is what makes the next
# reaction land.
func _idle_crowd(delta: float) -> void:
	_crowd_quiet -= delta
	if _crowd_quiet > 0.0:
		return

	_hold_crowd()
	if _crowd != null and _crowd.playing:
		return

	var key := "soccar_crowd"
	if _rng.randf() < GASP_CHANCE:
		key = "soccar_gasp"
	_play_crowd(key, CROWD_IDLE_VOLUME)


# Quiet again until somewhere between CROWD_GAP_MIN and CROWD_GAP_MAX
# from now, so the murmurs never fall into a rhythm.
func _hold_crowd() -> void:
	_crowd_quiet = _rng.randf_range(CROWD_GAP_MIN, CROWD_GAP_MAX)


func _play_crowd(key: String, loudness: float) -> void:
	if _crowd == null or not is_instance_valid(_crowd):
		return
	_hold_crowd()

	var stream := Audio.stream_for(key)
	if stream == null:
		return
	_crowd.stream = stream
	_crowd.volume_db = linear_to_db(maxf(0.0001, loudness * Settings.sfx_volume))
	_crowd.play()


func _leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(Routes.back_to_hub())


# Audio.loop() parents its voices to the Audio autoload, which outlives
# this scene - so they have to be taken down by hand or the crowd
# follows you back into the city.
func _exit_tree() -> void:
	if _crowd != null and is_instance_valid(_crowd):
		_crowd.queue_free()
