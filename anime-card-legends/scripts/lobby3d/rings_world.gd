extends Node3D

# =========================================================
# THE RINGS COURSE.
#
# Thirty rings hung in the air, unlimited boost, and the whole thing is
# flown rather than driven. Miss one and you drop back to the start pad
# and go again - the deaths counter is the score, the same way Rocket
# League's own rings maps work.
#
# THE COURSE IS GENERATED, NOT PLACED BY HAND. A hand-placed course of
# thirty rings is thirty numbers to retune every time the car's boost
# changes. This one is a path: it climbs, it turns, it rolls, and each
# of those gets harder as you go, driven by one difficulty value that
# runs 0 to 1 across the course. Change RING_COUNT and you get a longer
# course with the same shape of progression.
#
#   rings 1-8    gentle climb, wide rings, nearly straight
#   rings 9-18   the path starts to weave and the rings shrink
#   rings 19-30  banked turns, vertical climbs, rings barely wider
#                than the car is long
#
# Reached from any portal's travel menu, same as the arena.
# =========================================================

const RING_COUNT := 30

# The gap between rings, which opens up as the course gets faster.
const SPACING_NEAR := 34.0
const SPACING_FAR := 58.0

# Rings shrink as the course goes on. The car is 9.45 m long, so the
# last rings are about two car lengths across - tight, not impossible.
const RADIUS_EASY := 11.0
const RADIUS_HARD := 4.6

# How far the path wanders sideways and how much it climbs, at the two
# ends of the course.
const WEAVE_EASY := 10.0
const WEAVE_HARD := 62.0
const CLIMB_EASY := 4.0
const CLIMB_HARD := 26.0
# How fast the weave oscillates. Higher means tighter switchbacks.
const WEAVE_RATE_EASY := 0.35
const WEAVE_RATE_HARD := 0.95

const START_HEIGHT := 6.0
const PAD_RADIUS := 9.0

# Fallen this far below the course and it counts as a miss.
const FLOOR_Y := -40.0

var car: CarBody
var camera: CarCamera
var menu: ArenaSettings

var _gates: Array[RingGate] = []
var _next_ring := 0
var _deaths := 0
var _clock := 0.0
var _running := false
var _finished := false
var _start := Transform3D.IDENTITY

var _hud: CanvasLayer
var _progress: Label
var _timer: Label
var _deaths_label: Label
var _banner: Label


func _ready() -> void:
	if not GameState.has_active_slot():
		call_deferred("_bounce")
		return

	Audio.play_music("music_lobby")
	_build_environment()
	_build_course()
	_build_start_pad()
	_build_car()
	_build_hud()
	_respawn(false)


func _bounce() -> void:
	get_tree().change_scene_to_file(Routes.TITLE)


# --- World --------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = SkyBuilder.night_city()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7fd0e8")
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color("#173040")
	env.fog_density = 0.0009
	# The sky sits at infinite depth, so fog with sky_affect at its
	# default of 1.0 paints the entire sky one flat colour.
	env.fog_sky_affect = 0.0

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	key.light_energy = RenderMode.light(0.9)
	key.light_color = Color("#cfefff")
	add_child(key)


# --- The course ---------------------------------------------------------

# Where ring `i` sits, and which way it points. The path is built by
# walking forwards and steering, so each ring faces the way the last one
# was heading - which is what makes them flyable in sequence rather than
# a row of hoops you cross at an angle.
func _build_course() -> void:
	var at := Vector3(0.0, START_HEIGHT + 8.0, -SPACING_NEAR)
	var heading := Vector3.FORWARD

	for i in RING_COUNT:
		# 0 at the first ring, 1 at the last.
		var hard := float(i) / float(maxi(RING_COUNT - 1, 1))

		var weave := lerpf(WEAVE_EASY, WEAVE_HARD, hard)
		var climb := lerpf(CLIMB_EASY, CLIMB_HARD, hard)
		var rate := lerpf(WEAVE_RATE_EASY, WEAVE_RATE_HARD, hard)
		var spacing := lerpf(SPACING_NEAR, SPACING_FAR, hard)

		# Two waves out of phase: one across, one up. Out of phase is
		# what turns a flat slalom into a corkscrew.
		var phase := float(i) * rate
		var sideways := sin(phase) * weave
		var lift := sin(phase * 0.7 + 1.1) * climb

		var target := at + heading * spacing + Vector3(sideways, lift, 0.0)
		# Never let the course dip into the pad.
		target.y = maxf(target.y, START_HEIGHT + 6.0)

		var step := (target - at)
		if step.length() < 1.0:
			step = heading * spacing
		heading = step.normalized()
		at = target

		var gate := RingGate.create(at, heading, lerpf(RADIUS_EASY, RADIUS_HARD, hard), i)
		gate.passed.connect(_on_ring_passed)
		add_child(gate)
		_gates.append(gate)


# --- Start pad ----------------------------------------------------------

# Somewhere to be put back to, and something to look at while you work
# out where ring one went.
func _build_start_pad() -> void:
	var pad := StaticBody3D.new()
	pad.position = Vector3(0.0, START_HEIGHT, 0.0)
	add_child(pad)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(PAD_RADIUS * 2.0, 2.0, PAD_RADIUS * 2.6)
	shape.shape = box
	shape.position.y = -1.0
	pad.add_child(shape)

	var deck := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(PAD_RADIUS * 2.0, 2.0, PAD_RADIUS * 2.6)
	deck.mesh = slab
	deck.position.y = -1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#1b2740")
	mat.emission_enabled = true
	mat.emission = Color("#35d6ff")
	mat.emission_energy_multiplier = RenderMode.emission(0.25)
	deck.material_override = mat
	pad.add_child(deck)

	var glow := OmniLight3D.new()
	glow.position.y = 3.0
	glow.light_color = Color("#35d6ff")
	glow.light_energy = RenderMode.light(1.1)
	glow.omni_range = PAD_RADIUS * 4.0
	pad.add_child(glow)

	_start = Transform3D(Basis.IDENTITY, Vector3(0.0, START_HEIGHT + CarBody.RIDE_HEIGHT, 0.0))


func _build_car() -> void:
	car = CarBody.create()
	add_child(car)
	car.take_control()

	camera = CarCamera.create(car)
	add_child(camera)
	camera.activate()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	menu = ArenaSettings.new()
	menu.leave_requested.connect(_leave)
	menu.restart_requested.connect(_restart)
	add_child(menu)


# --- HUD ----------------------------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)

	var top := UI.vbox(Design.S1)
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = Design.S4
	top.offset_left = -220
	top.offset_right = 220
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(top)

	_progress = UI.label("", Design.FS_TITLE, Design.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(_progress)

	_timer = UI.label("", Design.FS_BODY, Design.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(_timer)

	_deaths_label = UI.label("", Design.FS_BODY, Design.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_deaths_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_deaths_label.offset_left = Design.S5
	_deaths_label.offset_top = Design.S4
	_deaths_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_deaths_label)

	_banner = UI.label("", Design.FS_DISPLAY, Design.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = -60
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_banner)

	var hint := UI.label("", Design.FS_SMALL, Design.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hint.text = "%s  respawn at the pad      ESC  menu" % Controls.binding_text("acl_interact")
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -46
	hint.offset_left = -400
	hint.offset_right = 400
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(hint)

	_refresh_hud()


func _refresh_hud() -> void:
	if _progress != null:
		_progress.text = "Ring %d / %d" % [mini(_next_ring + 1, RING_COUNT), RING_COUNT]
	if _timer != null:
		_timer.text = "Time  %s" % Fmt.clock(_clock)
	if _deaths_label != null:
		_deaths_label.text = "Resets: %d" % _deaths


# --- Running ------------------------------------------------------------

func _process(delta: float) -> void:
	if car == null or (menu != null and menu.is_open()):
		return

	# The tank never empties. That is the mode: the skill is aiming the
	# car, not rationing boost.
	car.boost = CarBody.BOOST_MAX

	if _running and not _finished:
		_clock += delta

	if Controls.interact_pressed():
		_respawn(true)
	elif car.global_position.y < FLOOR_Y:
		_respawn(true)

	if Controls.cancel_pressed() and menu != null:
		menu.open()

	_refresh_hud()


func _on_ring_passed(index: int) -> void:
	if index != _next_ring:
		return

	_running = true
	_next_ring += 1
	Audio.play_at("coin", 0.5, 1.0 + 0.02 * float(index))

	if _next_ring >= RING_COUNT:
		_finish()
		return

	_aim_at_next()
	_banner.text = ""


func _aim_at_next() -> void:
	for i in _gates.size():
		_gates[i].set_next(i == _next_ring)


func _finish() -> void:
	_finished = true
	_running = false
	_banner.text = "COURSE CLEAR  ·  %s  ·  %d resets" % [Fmt.clock(_clock), _deaths]
	Audio.play("victory")
	# Worth something, so the mode is not only for its own sake.
	GameState.add_gems(60)
	GameState.add_gold(2500)
	GameState.save_now()


# Back to the pad. The course restarts from ring one - a rings run is
# the whole course or nothing, which is what makes the reset count mean
# something.
func _respawn(counts: bool) -> void:
	if counts and not _finished:
		_deaths += 1

	car.global_transform = _start
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.boost = CarBody.BOOST_MAX

	_next_ring = 0
	_clock = 0.0
	_running = false
	_finished = false
	for gate in _gates:
		gate.reset()
	_aim_at_next()

	if _banner != null:
		_banner.text = ""
	_refresh_hud()


func _restart() -> void:
	_deaths = 0
	_respawn(false)


func _leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(Routes.back_to_hub())
