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
# Was 2.0. Ten per cent off: the bowl was reaching past the arena shell,
# so the part of the stadium you could see extended beyond anything you
# could drive on.
const STADIUM_SCALE := 1.8

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
var ball: ArenaBall
var camera: CarCamera
var hud: ArenaHUD
var menu: ArenaSettings

# Everyone on the pitch, the player included. In 1v1 that is the player
# and one bot; in 2v2 it is the player, a teammate and two opponents.
var blue_team: Array[CarBody] = []
var orange_team: Array[CarBody] = []

var boost_pads: Array[BoostPad] = []

var _brains: Array[ArenaBot] = []
var _team_size := 1

var _score := {"blue": 0, "orange": 0}
var _clock := MATCH_SECONDS
var _kickoff := KICKOFF_PAUSE
var _over := false

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


# The arena is ONE swept shell now - flat floor, curved transition into
# the walls, rounded corners, curved transition into the ceiling - and
# the triangles you see are the triangles you hit.
#
# What was here before: six box slabs. That is why driving out onto the
# stadium dropped you into the void. The stadium model is bigger than the
# box was, so the part of the arena you could SEE extended past the only
# collision that existed, and there was nothing under it.
func _build_pitch() -> void:
	# The stands and the roof. Scenery only - the shell below is what
	# anything actually touches.
	_build_stadium_shell()

	var shell := ArenaShell.build()

	var body := StaticBody3D.new()
	body.name = "ArenaShell"
	add_child(body)

	# Collision straight from the same triangles. A trimesh rather than
	# boxes, so the curved corners are curved to drive on and not just to
	# look at.
	var shape := CollisionShape3D.new()
	var trimesh := ConcavePolygonShape3D.new()
	trimesh.set_faces(shell["faces"])
	shape.shape = trimesh
	body.add_child(shape)

	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	walls.mesh = ArenaShell.mesh_from(shell["walls"], _glass_material())
	walls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(walls)

	var pitch := MeshInstance3D.new()
	pitch.name = "Pitch"
	pitch.mesh = ArenaShell.mesh_from(shell["floor"],
		Textures.sidewalk(HALF_WIDTH, Color("#131a2c")))
	add_child(pitch)

	_build_goal_boxes(body)
	_build_boost_pads()
	_paint_markings()


# Transparent, so the stadium behind it is the thing you look at while
# still having something solid to drive on.
func _glass_material() -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.42, 0.62, 1.0, 0.10)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Seen from inside the arena, which is the back face of a shell whose
	# normals point in - and from outside when the camera swings wide.
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# A big transparent surface drawn over everything sorts badly against
	# itself; not writing depth is what stops the far wall punching a
	# hole in the near one.
	glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	glass.emission_enabled = true
	glass.emission = Color(0.35, 0.55, 1.0)
	glass.emission_energy_multiplier = RenderMode.emission(0.35)
	return glass


# Behind each goal mouth: a box the ball can enter and cannot leave
# except back through the mouth. The shell has a hole there, so without
# this the ball would fly straight out of the arena.
func _build_goal_boxes(body: StaticBody3D) -> void:
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		var z := HALF_LENGTH * side
		var depth := GOAL_DEPTH
		var mouth := GOAL_HALF_WIDTH
		var tall := GOAL_HEIGHT

		# Back.
		_collider(body, Vector3(0.0, tall * 0.5, z + depth * side),
			Vector3(mouth * 2.0 + 4.0, tall, 2.0))
		# Sides.
		_collider(body, Vector3(-(mouth + 1.0), tall * 0.5, z + depth * 0.5 * side),
			Vector3(2.0, tall, depth))
		_collider(body, Vector3(mouth + 1.0, tall * 0.5, z + depth * 0.5 * side),
			Vector3(2.0, tall, depth))
		# Roof.
		_collider(body, Vector3(0.0, tall + 1.0, z + depth * 0.5 * side),
			Vector3(mouth * 2.0 + 4.0, 2.0, depth))
		# Floor, level with the pitch.
		_collider(body, Vector3(0.0, -1.0, z + depth * 0.5 * side),
			Vector3(mouth * 2.0 + 4.0, 2.0, depth))


func _collider(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


# --- Boost pads ---------------------------------------------------------

# The six big pads are at Rocket League's own coordinates. The small ones
# are a symmetric arrangement rather than RL's exact list of twenty-eight,
# which is not something to write down from memory - they are in the
# right places to be worth driving over, and the layout is one table to
# correct if you want the real thing.
const BIG_PADS_UU: Array[Vector2] = [
	Vector2(-3584.0, 0.0), Vector2(3584.0, 0.0),
	Vector2(-3072.0, -4096.0), Vector2(3072.0, -4096.0),
	Vector2(-3072.0, 4096.0), Vector2(3072.0, 4096.0),
]

const SMALL_PADS_UU: Array[Vector2] = [
	Vector2(0.0, -4240.0), Vector2(0.0, 4240.0),
	Vector2(-1792.0, -4184.0), Vector2(1792.0, -4184.0),
	Vector2(-1792.0, 4184.0), Vector2(1792.0, 4184.0),
	Vector2(-940.0, -3308.0), Vector2(940.0, -3308.0),
	Vector2(-940.0, 3308.0), Vector2(940.0, 3308.0),
	Vector2(0.0, -2816.0), Vector2(0.0, 2816.0),
	Vector2(-3584.0, -2484.0), Vector2(3584.0, -2484.0),
	Vector2(-3584.0, 2484.0), Vector2(3584.0, 2484.0),
	Vector2(-1788.0, -2300.0), Vector2(1788.0, -2300.0),
	Vector2(-1788.0, 2300.0), Vector2(1788.0, 2300.0),
	Vector2(-2048.0, -1036.0), Vector2(2048.0, -1036.0),
	Vector2(-2048.0, 1036.0), Vector2(2048.0, 1036.0),
	Vector2(-1024.0, 0.0), Vector2(1024.0, 0.0),
	Vector2(0.0, -1024.0), Vector2(0.0, 1024.0),
]


func _build_boost_pads() -> void:
	for spot in BIG_PADS_UU:
		_add_pad(spot, true)
	for spot in SMALL_PADS_UU:
		_add_pad(spot, false)


func _add_pad(spot: Vector2, big: bool) -> void:
	var pad := BoostPad.create(Vector3(spot.x * CarBody.UU, 0.0, spot.y * CarBody.UU), big)
	add_child(pad)
	boost_pads.append(pad)


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
	# Only the player's goals. The bot's card is not riding with anyone.
	if scorer == "blue":
		Passenger.add(Passenger.GOAL_BONUS)
	_swell()
	if hud != null:
		hud.announce("%s SCORES" % scorer.to_upper())
		hud.set_score(int(_score["blue"]), int(_score["orange"]))
	_kick_off()


# --- Actors -------------------------------------------------------------

# Blue defends +Z and attacks -Z; orange is the other way round. The
# player is always blue, and always the first car on the team, so the
# kickoff spots line up the same way in 1v1 and 2v2.
func _build_actors() -> void:
	ball = ArenaBall.create()
	ball.hit.connect(_on_ball_hit)
	add_child(ball)

	_team_size = clampi(Settings.team_size, 1, 2)

	for i in _team_size:
		var blue := CarBody.create()
		add_child(blue)
		blue_team.append(blue)
		# The first blue car is the player's; anything after it is a
		# teammate, and gets a brain like the opposition.
		if i == 0:
			car = blue
			car.take_control()
		else:
			_add_brain(blue, HALF_LENGTH, i)

		var orange := CarBody.create()
		add_child(orange)
		orange_team.append(orange)
		_add_brain(orange, -HALF_LENGTH, i)

	camera = CarCamera.create(car)
	camera.ball = ball
	add_child(camera)
	camera.activate()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _add_brain(who: CarBody, own_goal_z: float, index: int) -> void:
	var brain := ArenaBot.new()
	brain.setup(who, ball, HALF_LENGTH, own_goal_z)
	# One car challenges, the other covers, so a pair does not both leave
	# the net at once.
	brain.role = ArenaBot.ROLE_FIRST if index == 0 else ArenaBot.ROLE_SECOND
	add_child(brain)
	_brains.append(brain)


func _build_hud() -> void:
	hud = ArenaHUD.new()
	add_child(hud)
	hud.set_score(0, 0)

	_crowd = Audio.voice("soccar_crowd")
	_hold_crowd()

	menu = ArenaSettings.new()
	menu.leave_requested.connect(_leave)
	menu.restart_requested.connect(_restart)
	add_child(menu)


# --- Match flow ---------------------------------------------------------

# RL's kickoff spots: dead centre in a 1v1, and the two diagonals in a
# 2v2. Every car faces the middle.
const KICKOFF_SPREAD := 0.29    # across the pitch, as a fraction of half its width
const KICKOFF_BACK := 0.62      # down the pitch, as a fraction of half its length
const KICKOFF_BACK_WIDE := 0.72


func _kickoff_spots(count: int) -> Array[Vector3]:
	if count < 2:
		return [Vector3(0.0, 0.0, HALF_LENGTH * KICKOFF_BACK)]
	return [
		Vector3(-HALF_WIDTH * KICKOFF_SPREAD, 0.0, HALF_LENGTH * KICKOFF_BACK_WIDE),
		Vector3(HALF_WIDTH * KICKOFF_SPREAD, 0.0, HALF_LENGTH * KICKOFF_BACK_WIDE),
	]


func _kick_off() -> void:
	_kickoff = KICKOFF_PAUSE
	ball.reset_to(Vector3(0, ArenaBall.RADIUS * 1.2, 0))
	Audio.play("soccar_lets_go")

	var spots := _kickoff_spots(_team_size)
	for i in blue_team.size():
		_place(blue_team[i], spots[i % spots.size()], 1.0)
	for i in orange_team.size():
		_place(orange_team[i], spots[i % spots.size()], -1.0)


# `side` is +1 for blue, which defends +Z, and -1 for orange. Mirroring
# the spot rather than listing both sets keeps the two ends identical.
func _place(who: CarBody, spot: Vector3, side: float) -> void:
	who.global_position = Vector3(
		spot.x * side, who.ride_height() + 0.5, spot.z * side)
	who.linear_velocity = Vector3.ZERO
	who.angular_velocity = Vector3.ZERO
	var facing: float = 0.0 if side > 0.0 else PI
	who.global_rotation = Vector3(0.0, facing, 0.0)
	who.boost = CarBody.BOOST_MAX


func _process(delta: float) -> void:
	if _over or car == null:
		return

	if menu != null and menu.is_open():
		return

	if _kickoff > 0.0:
		_kickoff -= delta
		var live := _kickoff <= 0.0
		car.driver_seated = live
		for brain in _brains:
			brain.active = live
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

	# Escape opens the menu rather than walking straight out of a match
	# you are in the middle of. Leaving is one of its buttons.
	if Controls.cancel_pressed() and menu != null:
		menu.open()


func _finish() -> void:
	_over = true
	car.driver_seated = false
	for brain in _brains:
		brain.active = false

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


# Changing the team size mid-match means a different number of cars on
# the pitch, so the match starts again rather than trying to grow a team
# out from under the player.
func _restart() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


func _leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(Routes.back_to_hub())


# Audio.loop() parents its voices to the Audio autoload, which outlives
# this scene - so they have to be taken down by hand or the crowd
# follows you back into the city.
func _exit_tree() -> void:
	if _crowd != null and is_instance_valid(_crowd):
		_crowd.queue_free()
