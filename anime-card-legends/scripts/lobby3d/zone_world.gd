extends Node3D

# =========================================================
# 3D CAMPAIGN ZONE - a walkable stage select.
#
# Every zone is generated from its entry in Campaign.ZONES: palette,
# fog, lighting and architecture all come from that table, so the six
# zones share this one script and still look nothing like each other.
# Nothing here is imported art.
#
# The seven stages of the zone are laid out along a winding path away
# from the spawn point. Their monoliths grow taller and brighter the
# further in you go, so the difficulty curve is legible before you
# walk it. Walk onto a stage pad and press ENTER to fight it.
#
# The whole path stays at ground level on purpose: a flat arena cannot
# strand the player on a ledge they are unable to climb back onto.
# =========================================================

# How tall a zone's imported landmark stands at each stage. The same
# model is reused for all seven fights and simply grows, so one export
# per zone carries the whole difficulty curve.
const MODEL_HEIGHT_FIRST := 4.5
const MODEL_HEIGHT_LAST := 9.5
const MODEL_HEIGHT_BOSS := 16.0

const GROUND_RADIUS := 46.0
const PATH_RADIUS := 13.0
const PATH_START_Z := -8.0
const PATH_LENGTH := 30.0
const PAD_RADIUS := 5.0

var zone: Dictionary = {}
var zone_index := 0

var player: LobbyPlayer
var hud: LobbyHUD
var _stages: Array[Dictionary] = []
var _current: Dictionary = {}


func _ready() -> void:
	# A Node3D needs its own version of the guard the Screen base class
	# applies to every 2D screen.
	if not GameState.has_active_slot():
		call_deferred("_bounce_to_slots")
		return

	zone_index = GameState.progression.pending_zone
	zone = Campaign.zone_at(zone_index)

	Audio.play_music("music_lobby")
	_build_environment()
	_build_ground()
	_build_stages()
	_build_props()
	_build_player()
	_build_hud()


func _bounce_to_slots() -> void:
	get_tree().change_scene_to_file(Routes.SLOTS)


func _process(_delta: float) -> void:
	if player == null:
		return
	_update_proximity()

	if _current.is_empty():
		return
	if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER):
		var unlocked: bool = _current["unlocked"]
		if not unlocked:
			return
		var floor_number: int = _current["floor"]
		GameState.progression.pending_floor = floor_number
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file(Routes.BATTLE)


# --- World ----------------------------------------------------------

func _accent() -> Color:
	return Color(str(zone["accent"]))


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(str(zone["sky_top"]))
	mat.sky_horizon_color = Color(str(zone["sky_horizon"]))
	mat.ground_bottom_color = Color(str(zone["ground"]))
	mat.ground_horizon_color = Color(str(zone["sky_horizon"]))
	sky.sky_material = mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(str(zone["fog"]))
	env.fog_density = float(zone["fog_density"])

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -40, 0)
	sun.light_energy = 0.9
	sun.light_color = _accent().lerp(Color.WHITE, 0.6)
	sun.shadow_enabled = true
	add_child(sun)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	add_child(ground)

	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = GROUND_RADIUS
	disc.bottom_radius = GROUND_RADIUS
	disc.height = 1.0
	disc.radial_segments = 64
	mesh.mesh = disc
	mesh.position.y = -0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(str(zone["ground"]))
	mat.roughness = 0.95
	mesh.material_override = mat
	ground.add_child(mesh)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_RADIUS * 2.0, 1.0, GROUND_RADIUS * 2.0)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)

	_build_perimeter_wall()


# An invisible ring of walls keeps the player inside the zone.
func _build_perimeter_wall() -> void:
	var segments := 28
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		var body := StaticBody3D.new()
		body.position = Vector3(cos(angle), 2.0, sin(angle)) * GROUND_RADIUS
		body.rotation.y = -angle

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(GROUND_RADIUS * TAU / float(segments) + 1.0, 6.0, 1.0)
		shape.shape = box
		body.add_child(shape)
		add_child(body)


# --- Stages -----------------------------------------------------------

# The path winds left and right as it recedes, so the seven stages read
# as a route rather than a row.
func _stage_position(stage_index: int) -> Vector3:
	var t := float(stage_index) / float(Campaign.STAGES_PER_ZONE - 1)
	var x := sin(t * PI * 1.6) * PATH_RADIUS
	var z := PATH_START_Z - t * PATH_LENGTH
	return Vector3(x, 0.0, z)


func _build_stages() -> void:
	var highest: int = GameState.progression.highest_floor

	for stage_index in Campaign.STAGES_PER_ZONE:
		var floor_number := Campaign.floor_for(zone_index, stage_index)
		var is_boss := Campaign.is_boss_stage(stage_index)
		var cleared := floor_number <= highest
		var unlocked: bool = GameState.progression.is_unlocked(floor_number)
		_build_stage(stage_index, floor_number, is_boss, cleared, unlocked)


func _build_stage(stage_index: int, floor_number: int, is_boss: bool, cleared: bool, unlocked: bool) -> void:
	var origin := _stage_position(stage_index)
	var tint := _accent()
	if is_boss:
		tint = Color("#ef4444")
	if cleared:
		tint = Color("#3ecf7e")
	elif not unlocked:
		tint = Color("#4a5162")

	var root := Node3D.new()
	root.position = origin
	add_child(root)

	# Landmark - taller and broader the deeper into the zone it sits.
	var progress := float(stage_index) / float(Campaign.STAGES_PER_ZONE - 1)
	var height := 3.0 + progress * 5.0
	var width := 1.6 + progress * 0.9
	if is_boss:
		height = 11.0
		width = 3.4

	# An imported model for this zone replaces the procedural monolith,
	# reusing the one export at a size that grows stage by stage.
	var imported := _build_stage_model(root, stage_index, is_boss, tint)
	if imported > 0.0:
		height = imported

	if imported <= 0.0:
		var body := StaticBody3D.new()
		root.add_child(body)

		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width, height, width)
		mesh.mesh = box
		mesh.position.y = height * 0.5
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(str(zone["ground"])).lerp(Color.BLACK, 0.35)
		mat.roughness = 0.7
		mat.emission_enabled = true
		mat.emission = tint
		mat.emission_energy_multiplier = 0.25 + progress * 0.4
		mesh.material_override = mat
		body.add_child(mesh)

		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(width, height, width)
		shape.shape = box_shape
		shape.position.y = height * 0.5
		body.add_child(shape)

	# Crown so the boss monolith reads differently at a distance.
	if is_boss and imported <= 0.0:
		var crown := MeshInstance3D.new()
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 3.0
		spike.height = 4.0
		spike.radial_segments = 6
		crown.mesh = spike
		crown.position.y = height + 2.0
		var crown_mat := StandardMaterial3D.new()
		crown_mat.albedo_color = tint
		crown_mat.emission_enabled = true
		crown_mat.emission = tint
		crown_mat.emission_energy_multiplier = 1.2
		crown.material_override = crown_mat
		root.add_child(crown)

	var lamp := OmniLight3D.new()
	lamp.position.y = height + 1.5
	lamp.light_color = tint
	lamp.light_energy = 2.0
	lamp.omni_range = 18.0
	root.add_child(lamp)

	# Approach pad marking the interaction radius.
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = PAD_RADIUS
	disc.bottom_radius = PAD_RADIUS
	disc.height = 0.08
	disc.radial_segments = 32
	pad.mesh = disc
	pad.position.y = 0.05
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.20)
	pad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pad_mat.emission_enabled = true
	pad_mat.emission = tint
	pad_mat.emission_energy_multiplier = 0.35
	pad.material_override = pad_mat
	root.add_child(pad)

	# Floating nameplate.
	var plate := Label3D.new()
	plate.text = _stage_caption(stage_index, floor_number, is_boss, cleared, unlocked)
	plate.font_size = 84
	plate.pixel_size = 0.006
	plate.position.y = height + 4.6
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.modulate = Color.WHITE
	plate.outline_size = 22
	plate.outline_modulate = Color("#0b0d14")
	plate.no_depth_test = true
	root.add_child(plate)

	_stages.append({
		"name": _stage_caption(stage_index, floor_number, is_boss, cleared, unlocked),
		"floor": floor_number,
		"unlocked": unlocked,
		"pos": origin,
		"radius": PAD_RADIUS,
		"pad": pad,
		"base_color": tint,
	})


# Instances res://art/models/zones/<zone id>.glb at this stage, sized to
# the stage's place in the run. Returns the height it ended up, or 0.0
# when the zone has no model and the procedural monolith should be used.
func _build_stage_model(root: Node3D, stage_index: int, is_boss: bool, tint: Color) -> float:
	var zone_id := str(zone["id"])
	var model := Models.spawn_zone(zone_id)
	if model == null:
		return 0.0

	var progress := float(stage_index) / float(Campaign.STAGES_PER_ZONE - 1)
	var height := lerpf(MODEL_HEIGHT_FIRST, MODEL_HEIGHT_LAST, progress)
	if is_boss:
		height = MODEL_HEIGHT_BOSS

	root.add_child(model)
	Models.fit_height(model, height)

	# A little rotation per stage so seven copies of one model do not
	# read as seven copies of one model.
	model.rotation.y = float(stage_index) * 0.7

	# Collision matched to whatever was imported, so the landmark is
	# solid without the model needing collision shapes of its own.
	var size := Models.fitted_size(model)
	var body := StaticBody3D.new()
	root.add_child(body)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(maxf(size.x, 1.0), height, maxf(size.z, 1.0))
	shape.shape = box_shape
	shape.position.y = height * 0.5
	body.add_child(shape)

	# The stage's state colour still has to read at a distance, so an
	# uncleared or locked stage is lit rather than repainted - the
	# imported textures stay intact.
	var wash := OmniLight3D.new()
	wash.position = Vector3(0.0, height * 0.55, 0.0)
	wash.light_color = tint
	wash.light_energy = 1.4 + progress * 0.8
	wash.omni_range = maxf(size.x, size.z) + height
	root.add_child(wash)

	return height


func _stage_caption(stage_index: int, floor_number: int, is_boss: bool, cleared: bool, unlocked: bool) -> String:
	var title := "Stage %d" % (stage_index + 1)
	if is_boss:
		title = "☠  " + str(zone["boss"])

	if cleared:
		return "✓  " + title
	if not unlocked:
		return "🔒  " + title
	return "⚔  %s  (Floor %d)" % [title, floor_number]


# --- Architecture ------------------------------------------------------

# Decorative geometry that gives each zone its silhouette. Purely visual -
# none of it has collision, so it can never block the path.
func _build_props() -> void:
	var kind := str(zone["structure"])
	var count := int(zone["props"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(zone["id"]))

	for i in count:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(20.0, GROUND_RADIUS - 4.0)
		var origin := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		_build_prop(kind, origin, rng)


func _build_prop(kind: String, origin: Vector3, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = origin
	root.rotation.y = rng.randf_range(0.0, TAU)
	add_child(root)

	match kind:
		"pillar":
			_prop_pillar(root, rng)
		"spire":
			_prop_spire(root, rng)
		"shard":
			_prop_shard(root, rng)
		"battlement":
			_prop_battlement(root, rng)
		"arch":
			_prop_arch(root, rng)
		_:
			_prop_crystal(root, rng)


func _stone_material(darken: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(str(zone["ground"])).lerp(Color.WHITE, darken)
	mat.roughness = 0.9
	return mat


func _glow_material(energy: float) -> StandardMaterial3D:
	var tint := _accent()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint.lerp(Color.BLACK, 0.4)
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = energy
	return mat


func _add_mesh(parent: Node3D, mesh: Mesh, at: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	parent.add_child(node)
	return node


# Broken columns, some snapped off and leaning.
func _prop_pillar(root: Node3D, rng: RandomNumberGenerator) -> void:
	var height := rng.randf_range(3.0, 9.0)
	var column := CylinderMesh.new()
	column.top_radius = 0.85
	column.bottom_radius = 1.0
	column.height = height
	column.radial_segments = 10
	var node := _add_mesh(root, column, Vector3(0, height * 0.5, 0), _stone_material(0.10))
	node.rotation.z = rng.randf_range(-0.16, 0.16)

	var cap := BoxMesh.new()
	cap.size = Vector3(2.4, 0.5, 2.4)
	_add_mesh(root, cap, Vector3(0, 0.25, 0), _stone_material(0.05))


# Tall thin growths reaching for the canopy.
func _prop_spire(root: Node3D, rng: RandomNumberGenerator) -> void:
	var height := rng.randf_range(6.0, 16.0)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = rng.randf_range(0.7, 1.5)
	cone.height = height
	cone.radial_segments = 7
	var node := _add_mesh(root, cone, Vector3(0, height * 0.5, 0), _stone_material(0.16))
	node.rotation.z = rng.randf_range(-0.1, 0.1)

	var bulb := SphereMesh.new()
	bulb.radius = 0.5
	bulb.height = 1.0
	_add_mesh(root, bulb, Vector3(0, height, 0), _glow_material(1.4))


# Jagged plates of volcanic glass punched through the ground.
func _prop_shard(root: Node3D, rng: RandomNumberGenerator) -> void:
	var count := rng.randi_range(2, 4)
	for i in count:
		var height := rng.randf_range(3.0, 10.0)
		var plate := BoxMesh.new()
		plate.size = Vector3(rng.randf_range(0.4, 1.1), height, rng.randf_range(1.4, 3.0))
		var offset := Vector3(rng.randf_range(-2.5, 2.5), height * 0.4, rng.randf_range(-2.5, 2.5))
		var node := _add_mesh(root, plate, offset, _glow_material(0.5))
		node.rotation = Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.0, TAU), rng.randf_range(-0.35, 0.35))


# Squared-off fortress blocks with a crenellated top.
func _prop_battlement(root: Node3D, rng: RandomNumberGenerator) -> void:
	var height := rng.randf_range(3.5, 7.0)
	var width := rng.randf_range(3.0, 5.5)
	var wall := BoxMesh.new()
	wall.size = Vector3(width, height, 2.0)
	_add_mesh(root, wall, Vector3(0, height * 0.5, 0), _stone_material(0.06))

	var merlons := 3
	for i in merlons:
		var block := BoxMesh.new()
		block.size = Vector3(width / float(merlons) * 0.55, 1.0, 2.0)
		var x := (float(i) - 1.0) * (width / float(merlons))
		_add_mesh(root, block, Vector3(x, height + 0.5, 0), _stone_material(0.12))


# Cathedral arches, hollow in the middle.
func _prop_arch(root: Node3D, rng: RandomNumberGenerator) -> void:
	var height := rng.randf_range(5.0, 10.0)
	var span := rng.randf_range(3.0, 5.5)

	var leg := BoxMesh.new()
	leg.size = Vector3(0.9, height, 0.9)
	_add_mesh(root, leg, Vector3(-span * 0.5, height * 0.5, 0), _stone_material(0.14))
	_add_mesh(root, leg, Vector3(span * 0.5, height * 0.5, 0), _stone_material(0.14))

	var lintel := BoxMesh.new()
	lintel.size = Vector3(span + 1.4, 0.9, 0.9)
	_add_mesh(root, lintel, Vector3(0, height, 0), _stone_material(0.2))

	var lamp := SphereMesh.new()
	lamp.radius = 0.35
	lamp.height = 0.7
	_add_mesh(root, lamp, Vector3(0, height - 1.1, 0), _glow_material(1.8))


# Shattered geometry hanging in the air.
func _prop_crystal(root: Node3D, rng: RandomNumberGenerator) -> void:
	var count := rng.randi_range(2, 5)
	for i in count:
		var size := rng.randf_range(0.8, 2.6)
		var gem := CylinderMesh.new()
		gem.top_radius = 0.0
		gem.bottom_radius = size
		gem.height = size * 2.4
		gem.radial_segments = 5
		var offset := Vector3(
			rng.randf_range(-3.5, 3.5),
			rng.randf_range(2.0, 13.0),
			rng.randf_range(-3.5, 3.5)
		)
		var node := _add_mesh(root, gem, offset, _glow_material(1.1))
		node.rotation = Vector3(rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU))


# --- Actors ------------------------------------------------------------

func _build_player() -> void:
	player = LobbyPlayer.new()
	player.position = Vector3(0, 1.2, 8)
	add_child(player)


func _build_hud() -> void:
	hud = LobbyHUD.new()
	hud.title_text = str(zone["name"])
	hud.subtitle_text = str(zone["subtitle"])
	hud.back_route = Routes.CAMPAIGN
	add_child(hud)


# --- Proximity ----------------------------------------------------------

func _update_proximity() -> void:
	if player == null:
		return

	var closest: Dictionary = {}
	var best := INF

	for stage in _stages:
		var stage_pos: Vector3 = stage["pos"]
		var flat_player := Vector3(player.position.x, 0.0, player.position.z)
		var flat_stage := Vector3(stage_pos.x, 0.0, stage_pos.z)
		var distance := flat_player.distance_to(flat_stage)
		var radius: float = stage["radius"]
		var inside := distance < radius
		_set_pad_active(stage, inside)

		if inside and distance < best:
			best = distance
			closest = stage

	_current = closest
	if hud == null:
		return

	if closest.is_empty():
		hud.hide_prompt()
		return

	var unlocked: bool = closest["unlocked"]
	var label: String = closest["name"]
	if unlocked:
		hud.show_prompt("Press ENTER to fight  " + label)
	else:
		hud.show_prompt("Locked — clear the previous stage first")


func _set_pad_active(stage: Dictionary, active: bool) -> void:
	var pad: MeshInstance3D = stage["pad"]
	var mat: StandardMaterial3D = pad.material_override
	var tint: Color = stage["base_color"]
	var alpha := 0.20
	var energy := 0.35
	if active:
		alpha = 0.5
		energy = 1.3
	mat.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	mat.emission_energy_multiplier = energy
