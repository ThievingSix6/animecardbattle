extends Node3D

# =========================================================
# THE CITY - a night-time district, and the game's hub.
#
# Roughly twenty times the area of the old plaza, laid out as real city
# blocks with streets between them, so there is room for a vehicle or a
# mount later without rebuilding any of this.
#
# The filler buildings are drawn as ONE MultiMesh rather than several
# hundred nodes. That is what makes a district this size affordable:
# the whole skyline is a single draw call, with collision as a set of
# box shapes under one static body.
#
#   res://art/models/props/building.glb        the skyline
#   res://art/models/props/portal.glb          the travel portal
#   res://art/models/props/buildings/<id>.glb  a specific destination
#   res://art/models/npc/<id>.glb              the people
#
# Every one of those is optional. Anything missing is built from
# primitives instead.
# =========================================================

# --- Layout ---------------------------------------------------------
#
# Blocks sit on a grid; the gaps between them are the streets.

# Just over half a square kilometre - 736 m square. Big enough that
# walking it is a journey and a car earns its place, small enough that
# crossing it is not a chore.
const CITY_HALF := 368.0

# One block, plus the street on two of its sides. Streets are 26 m -
# wide enough to drive two ways down - and every third one is an avenue
# at 38 m.
const STREET_WIDTH := 26.0
const AVENUE_WIDTH := 38.0
const AVENUE_EVERY := 3
const BLOCK_SIZE := 52.0
const BLOCK_PITCH := BLOCK_SIZE + STREET_WIDTH
const BLOCKS_OUT := 4

# Each block is four lots with alleys between them, so the district has
# gaps to see through rather than being a solid wall of frontage.
const LOTS_PER_BLOCK := 2
const LOT_SIZE := BLOCK_SIZE / float(LOTS_PER_BLOCK)

# How much of a lot a building actually covers. The rest is the gap.
const FOOTPRINT_MIN := 0.52
const FOOTPRINT_MAX := 0.72

# Lots left empty on purpose - yards, car parks, the odd gap. Sightlines
# are what stop a grid reading as a corridor.
const EMPTY_LOT_CHANCE := 0.2

# How many of those empty lots become parks, and how big the trees in
# them are next to a 5.7 m player.
const PARK_CHANCE := 0.55
const TREE_HEIGHT_MIN := 9.0
const TREE_HEIGHT_MAX := 18.0

# Anything in props/scatter/, spread along the pavements.
const SCATTER_COUNT := 120
const SCATTER_HEIGHT_MIN := 3.0
const SCATTER_HEIGHT_MAX := 7.0
# How far in from a block's edge a prop stands, so it is on the
# pavement rather than in the gutter.
const PAVEMENT_INSET := 3.0
# Empty lots get a prop or two as well, so a gap reads as a yard.
const LOT_PROP_CHANCE := 0.45

# The pavement stands proud of the road, with a kerb down to it.
# Visual only: a kerb the car has to climb and the player cannot step
# up is an obstacle course, not a city.
const PAVEMENT_RISE := 0.55

# Most of the city is low. The handful of towers are what make the
# skyline, and they cluster toward the middle.
const BUILDING_HEIGHT_MIN := 9.0
const BUILDING_HEIGHT_MAX := 32.0
const TOWER_CHANCE := 0.09
const TOWER_HEIGHT_MIN := 44.0
const TOWER_HEIGHT_MAX := 78.0

# The open square in the middle: portal, NPCs, and the destinations
# around its edge.
const PLAZA_RADIUS := 42.0
const STOREFRONT_RING := 66.0

const STOREFRONT_WIDTH := 26.0
const STOREFRONT_HEIGHT := 16.0
const TOWER_WIDTH := 34.0
const TOWER_HEIGHT := 62.0

# Sized against a 5.7 m player: a pad the player barely fits on is
# a pad they walk past.
const PAD_RADIUS := 13.0

# Lights and signs are the expensive part of a city, not the geometry.
# Both are spent near the middle, where the player actually is.
const LIT_RADIUS := 220.0
const MAX_STREET_LIGHTS := 22
const MAX_NEON_SIGNS := 40
# Only some signs get a real light; the rest glow on their own. The
# Compatibility renderer only lets a given surface take eight omni
# lights, so real lights are spent, not scattered.
const NEON_LIGHT_EVERY := 3

# The ground is drawn as tiles rather than one slab for the same
# reason: a single huge mesh would try to take every light in the
# district and silently drop all but eight of them.
const GROUND_TILES := 8

# Destinations, in the order they are placed around the plaza. "model"
# is looked for at props/buildings/<model>.glb, falling back to the
# shared building.
const DESTINATIONS: Array[Dictionary] = [
	{"id": "card_shop", "name": "Card Shop",    "sign": "CARDS",    "icon": "🎴", "route": Routes.COLLECT,  "color": Color("#3b82f6"), "model": "card_shop"},
	{"id": "summon",    "name": "Summon Altar", "sign": "SUMMON",   "icon": "🔮", "route": Routes.PACKS,    "color": Color("#a855f7"), "model": "summon"},
	{"id": "talents",   "name": "Talent Shrine","sign": "TALENT",   "icon": "⭐", "route": Routes.TALENTS,  "color": Color("#f5a623"), "model": "talents"},
	{"id": "team",      "name": "War Camp",     "sign": "TEAM",     "icon": "🛡️", "route": Routes.TEAM,     "color": Color("#3ecf7e"), "model": "team"},
	{"id": "campaign",  "name": "Campaign Gate","sign": "GATE",     "icon": "🗼", "route": Routes.CAMPAIGN, "color": Color("#ef4444"), "model": "campaign"},
	{"id": "clan",      "name": "Clan Hall",    "sign": "CLAN",     "icon": "🏯", "route": Routes.CLAN,     "color": Color("#5ad1ff"), "model": "clan"},
	{"id": "settings",  "name": "Settings Shop","sign": "SETTINGS", "icon": "⚙️", "route": Routes.SETTINGS, "color": Color("#8fa4c8"), "model": "settings"},
]

# Latin only on purpose: the bundled font has no CJK glyphs, and a sign
# full of tofu boxes looks worse than no sign. Drop a CJK font into
# art/fonts/ and these can become kana.
const NEON_WORDS: Array[String] = [
	"RAMEN", "KARAOKE", "SUSHI", "ARCADE", "24H", "BAR", "HOTEL",
	"NOODLES", "CLUB", "IZAKAYA", "COFFEE", "MANGA", "PACHINKO",
	"CURRY", "SAKE", "GAMES", "LOUNGE", "TAXI", "OPEN", "GYOZA",
]

const NEON_COLORS: Array[Color] = [
	Color("#ff2d95"), Color("#5ad1ff"), Color("#f5a623"),
	Color("#a855f7"), Color("#3ecf7e"), Color("#ef4444"), Color("#ffffff"),
]

var player: LobbyPlayer
var companion: Companion
var hud: LobbyHUD
var portal: Portal
var car: CarBody
var car_camera: CarCamera

# True while the player is behind the wheel rather than on foot.
var _driving := false

var _spots: Array[Dictionary] = []
# Lots the skyline skipped, kept so parks can be dropped into them.
var _empty_lots: Array[Vector3] = []
var _npcs: Dictionary = {}          # npc id -> CityNPC
var _current: Dictionary = {}
var _menu: Node
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# The city is a Node3D, so it needs its own version of the guard the
	# Screen base class applies to every 2D screen.
	if not GameState.has_active_slot():
		call_deferred("_bounce_to_slots")
		return

	# Deterministic per save, so the skyline is the same city every time
	# the player walks back into it.
	_rng.seed = hash("city:%d" % GameState.active_slot)

	Audio.play_music("music_lobby")
	_build_environment()
	_build_horizon()
	_build_ground()
	_build_streets()
	_build_skyline()
	_build_storefronts()
	_build_landmark()
	_build_parks()
	_build_scatter()
	_build_portal()
	_build_npcs()
	_build_car()
	_build_player()
	_build_companion()
	_build_hud()


func _bounce_to_slots() -> void:
	get_tree().change_scene_to_file(Routes.TITLE)


func _process(_delta: float) -> void:
	if player == null:
		return
	if _menu != null and is_instance_valid(_menu):
		return

	if _driving:
		_update_driving()
		return

	_update_proximity()

	if Controls.interact_pressed():
		_interact()
	elif Controls.vehicle_pressed() and str(_current.get("kind", "")) == "car":
		_enter_car()


func _update_driving() -> void:
	if hud != null:
		hud.show_boost(car.boost_fraction(), car.speed())
	# Triangle only. Cancel used to work too, which meant Circle both
	# boosted and got out of the car.
	if Controls.vehicle_pressed():
		_exit_car()


func _interact() -> void:
	if _current.is_empty():
		return

	match str(_current.get("kind", "route")):
		"portal":
			_open_travel()
		"npc":
			_talk_to(str(_current["npc"]))
		"car":
			_enter_car()
		_:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			# Leaving a shop drops the player back on its doorstep, not
			# on the flat menu.
			Routes.enter(self, str(_current["route"]), Routes.LOBBY)


func _open_travel() -> void:
	var menu := TravelMenu.open(self, -1)
	menu.closed.connect(_on_menu_closed)
	_menu = menu


func _on_menu_closed() -> void:
	_menu = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for npc in _npcs.values():
		var person: CityNPC = npc
		person.release()


# --- Environment ----------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	# A supplied panorama, or a generated night sky with stars. The old
	# fallback ran to purple at the horizon, which read as unfinished.
	env.sky = SkyBuilder.night_city()

	# Ambient comes from a colour rather than the sky, so the whole
	# district sits in the same purple wash regardless of which panorama
	# is loaded. This is most of what makes it read as cyberpunk: every
	# unlit surface picks up the city's own glow.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6a3ff0")
	env.ambient_light_energy = 0.55

	# Haze is what sells a neon city: it gives every sign a halo, and it
	# hides where the district stops.
	env.fog_enabled = true
	env.fog_light_color = Color("#3a1f5c")
	env.fog_density = 0.0035
	env.fog_sun_scatter = 0.25

	# THE reason the sky was a flat colour. fog_sky_affect defaults to
	# 1.0, and the sky sits at infinite depth, so exponential fog
	# resolves to 100% at that distance and paints the entire sky in
	# fog_light_color - panorama, stars, gradient and all. Zero here
	# leaves the sky alone; the fog still does its job on geometry.
	env.fog_sky_affect = 0.0

	# Bloom needs HDR, which the Compatibility renderer does not have.
	# Asking for it there costs nothing but does nothing either.
	if RenderMode.supports_glow():
		env.glow_enabled = true
		env.glow_intensity = 0.9
		env.glow_bloom = 0.25

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Moonlight only, and tinted violet so even the shadows are in
	# palette. The city lights everything else.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-58, -40, 0)
	moon.light_energy = RenderMode.light(0.35)
	moon.light_color = Color("#9b7cff")
	moon.shadow_enabled = true
	add_child(moon)


# Mountains so the district ends in a skyline rather than the void, and
# a purple haze dome over the lot.
func _build_horizon() -> void:
	var horizon := Horizon.create(CITY_HALF)
	add_child(horizon)


# --- Ground and streets ---------------------------------------------

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	add_child(ground)

	# Dark and smooth, so every sign smears across it like wet asphalt.
	# res://art/textures/sidewalk.png replaces the flat colour when it
	# is there.
	var span := CITY_HALF * 2.0 / float(GROUND_TILES)
	var mat := Textures.sidewalk(span, Color("#0e1018"))
	var slab := BoxMesh.new()
	slab.size = Vector3(span, 1.0, span)

	for tx in GROUND_TILES:
		for tz in GROUND_TILES:
			var tile := MeshInstance3D.new()
			tile.mesh = slab
			tile.material_override = mat
			tile.position = Vector3(
				-CITY_HALF + span * (float(tx) + 0.5),
				-0.5,
				-CITY_HALF + span * (float(tz) + 0.5))
			ground.add_child(tile)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CITY_HALF * 2.0, 1.0, CITY_HALF * 2.0)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)

	_build_perimeter_wall()


# An invisible box wall keeps the player inside the district.
func _build_perimeter_wall() -> void:
	var sides: Array[Vector3] = [
		Vector3(0, 8, -CITY_HALF), Vector3(0, 8, CITY_HALF),
		Vector3(-CITY_HALF, 8, 0), Vector3(CITY_HALF, 8, 0),
	]
	for i in sides.size():
		var body := StaticBody3D.new()
		body.position = sides[i]

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		if i < 2:
			box.size = Vector3(CITY_HALF * 2.0, 24.0, 2.0)
		else:
			box.size = Vector3(2.0, 24.0, CITY_HALF * 2.0)
		shape.shape = box
		body.add_child(shape)
		add_child(body)


# Lit road surface on the grid lines, plus the plaza. Purely visual -
# the ground collider already covers all of it.
func _build_streets() -> void:
	var lights := 0
	var span := CITY_HALF * 2.0

	for i in range(-BLOCKS_OUT, BLOCKS_OUT + 2):
		var offset := (float(i) - 0.5) * BLOCK_PITCH
		var avenue := absi(i) % AVENUE_EVERY == 0
		var width := STREET_WIDTH
		if avenue:
			width = AVENUE_WIDTH

		_street_strip(Vector3(0, 0.02, offset), Vector3(span, 0.04, width), avenue)
		_street_strip(Vector3(offset, 0.02, 0), Vector3(width, 0.04, span), avenue)

		if avenue:
			# A centre line is the cheapest thing that makes a strip of
			# dark ground read as a road you could drive down.
			_centre_line(Vector3(0, 0.05, offset), Vector3(span, 0.02, 0.5))
			_centre_line(Vector3(offset, 0.05, 0), Vector3(0.5, 0.02, span))

		# Lamps only along the stretches near the plaza. A lamp at every
		# junction across a square kilometre would be hundreds of lights.
		for j in range(-3, 4):
			if lights >= MAX_STREET_LIGHTS:
				continue
			var along := float(j) * BLOCK_PITCH
			if Vector2(along, offset).length() > LIT_RADIUS:
				continue
			_street_lamp(Vector3(along, 0.0, offset))
			_street_lamp(Vector3(offset, 0.0, along))
			lights += 2

	_build_pavements()

	var plaza := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = PLAZA_RADIUS
	disc.bottom_radius = PLAZA_RADIUS
	disc.height = 0.06
	disc.radial_segments = 48
	plaza.mesh = disc
	plaza.position.y = 0.03

	var plaza_mat := StandardMaterial3D.new()
	plaza_mat.albedo_color = Color("#171b28")
	plaza_mat.roughness = 0.35
	plaza_mat.metallic = 0.2
	plaza.material_override = plaza_mat
	add_child(plaza)


# A raised slab over each block, so the pavement stands proud of the
# carriageway with a kerb down to it. One MultiMesh for the lot.
#
# No collision: a kerb the car has to climb and the player cannot step
# up is an obstacle course rather than a city, and the flat ground
# collider underneath keeps everything moving cleanly.
func _build_pavements() -> void:
	var slab := BoxMesh.new()
	slab.size = Vector3(BLOCK_SIZE, PAVEMENT_RISE * 2.0, BLOCK_SIZE)

	var blocks: Array[Vector3] = []
	for gx in range(-BLOCKS_OUT, BLOCKS_OUT + 1):
		for gz in range(-BLOCKS_OUT, BLOCKS_OUT + 1):
			var at := Vector3(float(gx) * BLOCK_PITCH, 0.0, float(gz) * BLOCK_PITCH)
			# The plaza is its own surface.
			if Vector2(at.x, at.z).length() < PLAZA_RADIUS:
				continue
			blocks.append(at)

	if blocks.is_empty():
		return

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = slab
	multi.instance_count = blocks.size()

	for i in blocks.size():
		# Half-sunk, so only the top PAVEMENT_RISE shows as a kerb.
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, blocks[i]))

	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = Textures.sidewalk(BLOCK_SIZE, Color("#161a26"))
	add_child(node)


func _street_strip(at: Vector3, size: Vector3, avenue: bool) -> void:
	var strip := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	strip.mesh = box
	strip.position = at

	var tint := Color("#141824")
	if avenue:
		tint = Color("#181d2b")
	strip.material_override = Textures.road(maxf(size.x, size.z), tint)
	add_child(strip)


func _centre_line(at: Vector3, size: Vector3) -> void:
	var line := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	line.mesh = box
	line.position = at

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#c8a24a")
	mat.emission_enabled = true
	mat.emission = Color("#c8a24a")
	mat.emission_energy_multiplier = RenderMode.emission(0.35)
	line.material_override = mat
	add_child(line)


func _street_lamp(at: Vector3) -> void:
	var post := MeshInstance3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.12
	pole.bottom_radius = 0.16
	pole.height = 7.0
	pole.radial_segments = 6
	post.mesh = pole
	post.position = at + Vector3(0.0, 3.5, 0.0)

	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color("#20242f")
	post_mat.roughness = 0.6
	post.material_override = post_mat
	add_child(post)

	var head := OmniLight3D.new()
	head.position = at + Vector3(0.0, 7.2, 0.0)
	head.light_color = Color("#ffd9a8")
	head.light_energy = RenderMode.light(1.0)
	head.omni_range = 22.0
	add_child(head)


# --- The skyline -----------------------------------------------------
#
# Every filler building is one instance in a single MultiMesh. A
# district this size as individual nodes would be several hundred draw
# calls; this is one.

func _build_skyline() -> void:
	var placements := _plan_skyline()
	if placements.is_empty():
		return

	# Any number of models in props/skyline/ become the city's stock of
	# buildings, dealt out between the lots. That is what stops a
	# district being one shape repeated four hundred times.
	var pool := Models.list_props("skyline")
	if not pool.is_empty():
		_build_skyline_pool(pool, placements)
		return

	var model := Models.spawn_prop("building")
	var mesh: Mesh = null
	var material: Material = null

	if model != null:
		mesh = Models.first_mesh(model)
		material = Models.first_material(model, Models.PROP_FOLDER + "building")
		model.queue_free()

	var fallback := mesh == null
	if fallback:
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 1.0, 1.0)
		mesh = box

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.use_colors = fallback
	multi.instance_count = placements.size()

	# Measured once, then each copy is scaled to its own footprint and
	# its own height SEPARATELY. Scaling uniformly is what made the old
	# district a wall of giants: asking for a 50 m tower also gave it a
	# 50 m footprint, so it swallowed its lot and both its streets.
	var fit := Models.mesh_fit_box(mesh)
	var per_width := float(fit["per_width"])
	var per_height := float(fit["per_height"])
	var base_lift := float(fit["base"])

	var body := StaticBody3D.new()
	add_child(body)

	var signs := 0

	for i in placements.size():
		var spot: Dictionary = placements[i]
		var at: Vector3 = spot["pos"]
		var height := float(spot["height"])
		var width := float(spot["width"])
		var spin := float(spot["spin"])

		var orientation := Basis(Vector3.UP, spin).scaled(
			Vector3(per_width * width, per_height * height, per_width * width))
		var origin := at + Vector3(0.0, base_lift * height, 0.0)
		multi.set_instance_transform(i, Transform3D(orientation, origin))

		if fallback:
			var shade := Color("#161b28").lerp(Color("#232a3d"), _rng.randf())
			multi.set_instance_color(i, shade)

		# Collision as plain boxes under one body.
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(width, height, width)
		shape.shape = box_shape
		shape.position = at + Vector3(0.0, height * 0.5, 0.0)
		body.add_child(shape)

		# Signage, spent near the plaza where it is actually seen.
		if signs < MAX_NEON_SIGNS and Vector2(at.x, at.z).length() < LIT_RADIUS:
			if _rng.randf() < 0.65:
				_build_neon(at, height, width, spin, signs % NEON_LIGHT_EVERY == 0)
				signs += 1

	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	if material != null:
		node.material_override = material
	elif fallback:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.WHITE
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.65
		mat.metallic = 0.15
		node.material_override = mat
	add_child(node)


# One MultiMesh per building model, plus the collision and signage the
# single-model path builds. Footprint and height stay independent here
# - a tower IS meant to be told how tall to be, unlike a bench.
func _build_skyline_pool(pool: Array[String], placements: Array[Dictionary]) -> void:
	var body := StaticBody3D.new()
	add_child(body)

	var signs := 0

	for index in pool.size():
		var model_name := pool[index]
		var sample := Models.spawn_prop(model_name)
		if sample == null:
			continue

		var mesh := Models.first_mesh(sample)
		var material := Models.first_material(sample, Models.PROP_FOLDER + model_name)
		sample.queue_free()
		if mesh == null:
			continue

		var mine: Array[Dictionary] = []
		for i in placements.size():
			if i % pool.size() == index:
				mine.append(placements[i])
		if mine.is_empty():
			continue

		var fit := Models.mesh_fit_box(mesh)
		var per_width := float(fit["per_width"])
		var per_height := float(fit["per_height"])
		var base_lift := float(fit["base"])

		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = mine.size()

		for i in mine.size():
			var spot: Dictionary = mine[i]
			var at: Vector3 = spot["pos"]
			var height := float(spot["height"])
			var width := float(spot["width"])
			var spin := float(spot["spin"])

			var orientation := Basis(Vector3.UP, spin).scaled(
				Vector3(per_width * width, per_height * height, per_width * width))
			multi.set_instance_transform(i, Transform3D(orientation, at + Vector3.UP * base_lift * height))

			var shape := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(width, height, width)
			shape.shape = box_shape
			shape.position = at + Vector3(0.0, height * 0.5, 0.0)
			body.add_child(shape)

			if signs < MAX_NEON_SIGNS and Vector2(at.x, at.z).length() < LIT_RADIUS:
				if _rng.randf() < 0.65:
					_build_neon(at, height, width, spin, signs % NEON_LIGHT_EVERY == 0)
					signs += 1

		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		if material != null:
			node.material_override = material
		add_child(node)


# Four lots to a block, with alleys between them, the odd lot left
# empty, and the plaza and storefront ring kept clear.
func _plan_skyline() -> Array[Dictionary]:
	var out: Array[Dictionary] = []

	for gx in range(-BLOCKS_OUT, BLOCKS_OUT + 1):
		for gz in range(-BLOCKS_OUT, BLOCKS_OUT + 1):
			var block := Vector3(float(gx) * BLOCK_PITCH, 0.0, float(gz) * BLOCK_PITCH)

			for lx in LOTS_PER_BLOCK:
				for lz in LOTS_PER_BLOCK:
					var lot := block + Vector3(
						(float(lx) + 0.5 - float(LOTS_PER_BLOCK) * 0.5) * LOT_SIZE,
						0.0,
						(float(lz) + 0.5 - float(LOTS_PER_BLOCK) * 0.5) * LOT_SIZE)

					if Vector2(lot.x, lot.z).length() < STOREFRONT_RING + 26.0:
						continue
					# Gaps are what stop a grid reading as a corridor, and
					# the emptier ones become parks.
					if _rng.randf() < EMPTY_LOT_CHANCE:
						_empty_lots.append(lot)
						continue

					out.append(_plan_building(lot))

	return out


func _plan_building(lot: Vector3) -> Dictionary:
	# The footprint never fills its lot, so there is always an alley.
	var width := LOT_SIZE * _rng.randf_range(FOOTPRINT_MIN, FOOTPRINT_MAX)

	# Jitter within whatever room the footprint left.
	# Kept tight enough that a jittered building cannot poke into the
	# street: lot half-width, minus half the footprint, is the budget.
	var slack := (LOT_SIZE - width) * 0.25
	var at := lot + Vector3(
		_rng.randf_range(-slack, slack), 0.0, _rng.randf_range(-slack, slack))

	# Most of the city is low. Towers are rare and cluster toward the
	# middle, which is what gives the skyline a centre.
	var closeness := 1.0 - clampf(Vector2(at.x, at.z).length() / CITY_HALF, 0.0, 1.0)
	var height := _rng.randf_range(
		BUILDING_HEIGHT_MIN,
		lerpf(BUILDING_HEIGHT_MIN + 6.0, BUILDING_HEIGHT_MAX, closeness))

	if _rng.randf() < TOWER_CHANCE * (0.35 + closeness):
		height = _rng.randf_range(TOWER_HEIGHT_MIN, TOWER_HEIGHT_MAX)
		# A tower is narrower than its neighbours, not wider.
		width *= 0.8

	return {
		"pos": at,
		"width": width,
		"height": height,
		"spin": float(_rng.randi() % 4) * (PI * 0.5),
	}


# A lit word and a glowing bar on the side of a building that faces the
# plaza, so it is readable from the street.
func _build_neon(at: Vector3, height: float, footprint: float, spin: float, lit: bool) -> void:
	var tint: Color = NEON_COLORS[_rng.randi() % NEON_COLORS.size()]
	var word: String = NEON_WORDS[_rng.randi() % NEON_WORDS.size()]

	var toward := -Vector2(at.x, at.z).normalized()
	var reach := footprint * 0.5 + 0.4

	var sign_root := Node3D.new()
	sign_root.position = at + Vector3(0.0, _rng.randf_range(height * 0.4, height * 0.75), 0.0)
	sign_root.rotation.y = atan2(toward.x, toward.y)
	add_child(sign_root)

	# Label3D reads from its own +Z, and sign_root's +Z already points at
	# the plaza, so no extra turn.
	var label := Label3D.new()
	label.text = word
	label.font_size = 120
	label.pixel_size = 0.016
	label.position.z = reach
	label.modulate = tint
	label.outline_size = 18
	label.outline_modulate = Color("#05060b")
	label.shaded = false
	sign_root.add_child(label)

	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(_rng.randf_range(4.0, 8.0), 0.3, 0.3)
	bar.mesh = box
	bar.position = Vector3(0.0, -2.0, reach)

	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = tint
	bar_mat.emission_enabled = true
	bar_mat.emission = tint
	bar_mat.emission_energy_multiplier = RenderMode.emission(1.0)
	bar.material_override = bar_mat
	sign_root.add_child(bar)

	if lit:
		var glow := OmniLight3D.new()
		glow.position = Vector3(0.0, -1.0, reach + 1.5)
		glow.light_color = tint
		glow.light_energy = RenderMode.light(1.1)
		glow.omni_range = 24.0
		sign_root.add_child(glow)

	# `spin` is the building's own rotation; the sign is placed in world
	# space so it does not need it, but keeping it here documents that
	# the two are deliberately independent.
	sign_root.set_meta("building_spin", spin)


# --- Storefronts (the destinations) -----------------------------------

func _build_storefronts() -> void:
	var count := DESTINATIONS.size() + 1   # +1 for the tower
	for i in DESTINATIONS.size():
		var angle := TAU * float(i) / float(count) - PI * 0.5
		var at := Vector3(cos(angle) * STOREFRONT_RING, 0.0, sin(angle) * STOREFRONT_RING)
		_build_storefront(DESTINATIONS[i], at, STOREFRONT_HEIGHT)

	# The tower gets the last slot and twice the height.
	var tower_angle := TAU * float(DESTINATIONS.size()) / float(count) - PI * 0.5
	var tower_at := Vector3(
		cos(tower_angle) * STOREFRONT_RING, 0.0, sin(tower_angle) * STOREFRONT_RING)
	_build_tower(tower_at)


func _build_storefront(destination: Dictionary, at: Vector3, height: float) -> Node3D:
	var tint: Color = destination["color"]

	var root := Node3D.new()
	root.position = at
	# Turn the shopfront toward the plaza.
	root.rotation.y = atan2(-at.x, -at.z)
	add_child(root)

	var model_id := str(destination["model"])
	var footprint := _place_destination_building(root, model_id, STOREFRONT_WIDTH, height)

	_build_sign(root, str(destination["sign"]), tint, height, footprint)
	_build_plate(root, "%s  %s" % [str(destination["icon"]), str(destination["name"])], height)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, height * 0.5, footprint * 0.5 + 3.0)
	lamp.light_color = tint
	lamp.light_energy = RenderMode.light(1.4)
	lamp.omni_range = 30.0
	root.add_child(lamp)

	# The pad sits between the shopfront and the plaza, not inside it.
	var pad_pos := at - at.normalized() * (footprint * 0.5 + 4.0)
	pad_pos.y = 0.0
	var pad := _build_pad(pad_pos, tint)

	_spots.append({
		"kind": "route",
		"name": str(destination["name"]),
		"route": str(destination["route"]),
		"pos": pad_pos,
		"radius": PAD_RADIUS,
		"pad": pad,
		"base_color": tint,
	})
	return root


# The tower is not a shop: it is a fight. Diablo waits at its door.
func _build_tower(at: Vector3) -> void:
	var tint := Color("#ef4444")

	var root := Node3D.new()
	root.position = at
	root.rotation.y = atan2(-at.x, -at.z)
	add_child(root)

	var footprint := _place_destination_building(root, "tower", TOWER_WIDTH, TOWER_HEIGHT)
	_build_sign(root, "TOWER", tint, TOWER_HEIGHT, footprint)
	_build_plate(root, "🔥  The Tower", TOWER_HEIGHT)

	var beacon := OmniLight3D.new()
	beacon.position = Vector3(0.0, TOWER_HEIGHT + 4.0, 0.0)
	beacon.light_color = tint
	beacon.light_energy = RenderMode.light(1.4)
	beacon.omni_range = 60.0
	root.add_child(beacon)

	# Diablo stands in front of the door, facing the plaza.
	var door := at - at.normalized() * (footprint * 0.5 + 3.5)
	door.y = 0.0
	_place_npc(Npcs.DIABLO, door, tint)


# Width and height are set independently here too, so a tall tower is a
# tower rather than a cube that fills the plaza.
func _place_destination_building(root: Node3D, model_id: String, width: float, height: float) -> float:
	# A model named after the destination wins; otherwise the shared
	# building stands in, so the city is complete either way.
	var model := Models.spawn_prop("buildings/" + model_id)
	if model == null:
		model = Models.spawn_prop("building")

	if model != null:
		root.add_child(model)
		Models.fit_box(model, width, height)
		_add_box_collider(root, Vector3(width, height, width))
		return width

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, width)
	mesh.mesh = box
	mesh.position.y = height * 0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#1b2130")
	mat.roughness = 0.65
	mesh.material_override = mat
	root.add_child(mesh)

	_add_box_collider(root, Vector3(width, height, width))
	return width


func _build_sign(root: Node3D, text: String, tint: Color, height: float, footprint: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 150
	label.pixel_size = 0.016
	label.position = Vector3(0.0, height * 0.62, footprint * 0.5 + 0.6)
	label.modulate = tint
	label.outline_size = 22
	label.outline_modulate = Color("#05060b")
	label.shaded = false
	root.add_child(label)

	var awning := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(footprint * 0.85, 0.45, 0.45)
	awning.mesh = box
	awning.position = Vector3(0.0, height * 0.45, footprint * 0.5 + 0.6)

	var awning_mat := StandardMaterial3D.new()
	awning_mat.albedo_color = tint
	awning_mat.emission_enabled = true
	awning_mat.emission = tint
	awning_mat.emission_energy_multiplier = RenderMode.emission(1.0)
	awning.material_override = awning_mat
	root.add_child(awning)


func _build_plate(root: Node3D, text: String, height: float) -> void:
	var plate := Label3D.new()
	plate.text = text
	plate.font_size = 96
	plate.pixel_size = 0.008
	plate.position.y = height + 4.0
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.modulate = Color.WHITE
	plate.outline_size = 24
	plate.outline_modulate = Color("#05060b")
	plate.no_depth_test = true
	root.add_child(plate)


func _add_box_collider(root: Node3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	root.add_child(body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	body.add_child(shape)


func _build_pad(at: Vector3, tint: Color) -> MeshInstance3D:
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = PAD_RADIUS
	disc.bottom_radius = PAD_RADIUS
	disc.height = 0.08
	disc.radial_segments = 32
	pad.mesh = disc
	pad.position = at + Vector3(0.0, 0.06, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = RenderMode.emission(0.4)
	pad.material_override = mat
	add_child(pad)
	return pad


# --- Landmarks -----------------------------------------------------------

# The centrepiece of the square. res://art/models/props/statue.glb, or
# an obelisk built from primitives so the square is never empty.
func _build_landmark() -> void:
	var root := Node3D.new()
	add_child(root)

	var height := STOREFRONT_HEIGHT * 2.4
	var width := STOREFRONT_WIDTH * 0.8

	var model := Models.spawn_prop("statue")
	if model != null:
		root.add_child(model)
		# Upright and undistorted: the supplied statue is Z-up, and
		# fit_box would have squashed it to a cube anyway.
		Models.fit_upright(model, "statue", height)
	else:
		_build_obelisk(root, width, height)

	_add_box_collider(root, Vector3(width * 0.6, height, width * 0.6))

	# Lit from below, the way a monument in a square actually is.
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(side * width * 0.7, height * 0.12, width * 0.5)
		lamp.light_color = Color("#b04cff")
		lamp.light_energy = RenderMode.light(1.3)
		lamp.omni_range = height * 1.6
		root.add_child(lamp)

	var plinth := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = width * 0.95
	disc.bottom_radius = width * 1.15
	disc.height = 1.6
	disc.radial_segments = 24
	plinth.mesh = disc
	plinth.position.y = 0.8
	plinth.material_override = Textures.rock(width, Color("#20263a"))
	root.add_child(plinth)


func _build_obelisk(root: Node3D, width: float, height: float) -> void:
	var shaft := MeshInstance3D.new()
	var taper := CylinderMesh.new()
	taper.top_radius = width * 0.12
	taper.bottom_radius = width * 0.3
	taper.height = height
	taper.radial_segments = 4
	shaft.mesh = taper
	shaft.position.y = height * 0.5 + 1.6
	shaft.material_override = Textures.rock(height, Color("#2a3049"))
	root.add_child(shaft)

	var crown := MeshInstance3D.new()
	var gem := SphereMesh.new()
	gem.radius = width * 0.2
	gem.height = width * 0.4
	crown.mesh = gem
	crown.position.y = height + 2.4

	var crown_mat := StandardMaterial3D.new()
	crown_mat.albedo_color = Color("#b04cff")
	crown_mat.emission_enabled = true
	crown_mat.emission = Color("#d08cff")
	crown_mat.emission_energy_multiplier = RenderMode.emission(1.0)
	crown.material_override = crown_mat
	root.add_child(crown)


# --- Parks ---------------------------------------------------------------

# The lots the skyline left empty become parks rather than bare
# pavement: a grass pad and a few trees, which is what gives the grid
# somewhere to look that is not a wall.
func _build_parks() -> void:
	if _empty_lots.is_empty():
		return

	var trees := Models.list_props("trees")
	var placements: Array[Dictionary] = []

	for lot in _empty_lots:
		if _rng.randf() > PARK_CHANCE:
			continue
		_build_park_ground(lot)

		var count := _rng.randi_range(2, 5)
		for i in count:
			var at := lot + Vector3(
				_rng.randf_range(-LOT_SIZE * 0.35, LOT_SIZE * 0.35),
				0.0,
				_rng.randf_range(-LOT_SIZE * 0.35, LOT_SIZE * 0.35))
			placements.append({
				"pos": at,
				"height": _rng.randf_range(TREE_HEIGHT_MIN, TREE_HEIGHT_MAX),
				"spin": _rng.randf_range(0.0, TAU),
			})

	if trees.is_empty() or placements.is_empty():
		_build_simple_trees(placements)
		return

	_build_model_clusters(trees, placements)


func _build_park_ground(at: Vector3) -> void:
	var pad := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(LOT_SIZE * 0.9, 0.3, LOT_SIZE * 0.9)
	pad.mesh = slab
	pad.position = at + Vector3(0.0, 0.12, 0.0)
	pad.material_override = Textures.grass(LOT_SIZE, Color("#1d3326"))
	add_child(pad)


# Cones and trunks, for before the tree models land.
func _build_simple_trees(placements: Array[Dictionary]) -> void:
	for spot in placements:
		var at: Vector3 = spot["pos"]
		var height := float(spot["height"])

		var trunk := MeshInstance3D.new()
		var post := CylinderMesh.new()
		post.top_radius = height * 0.05
		post.bottom_radius = height * 0.08
		post.height = height * 0.4
		trunk.mesh = post
		trunk.position = at + Vector3(0.0, height * 0.2, 0.0)
		trunk.material_override = Textures.rock(height, Color("#2b2119"))
		add_child(trunk)

		var canopy := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = height * 0.3
		cone.height = height * 0.75
		cone.radial_segments = 7
		canopy.mesh = cone
		canopy.position = at + Vector3(0.0, height * 0.72, 0.0)

		var leaf := StandardMaterial3D.new()
		leaf.albedo_color = Color("#20402c")
		leaf.roughness = 0.9
		canopy.material_override = leaf
		add_child(canopy)


# --- Scatter -------------------------------------------------------------

# Anything dropped into res://art/models/props/scatter/ turns up along
# the streets. No registration, no list to maintain - the folder IS the
# list, which is the cheapest way to keep adding things to look at.
func _build_scatter() -> void:
	var props := Models.list_props("scatter")
	if props.is_empty():
		return

	var placements: Array[Dictionary] = []

	# On the pavement, along a block's edge. Picking a random point and
	# nudging one axis to a kerb left the other axis free, which is how
	# props ended up standing in the middle of the cross street.
	for i in SCATTER_COUNT:
		var spot := _pavement_spot()
		if spot == Vector3.ZERO:
			continue
		placements.append({
			"pos": spot,
			"height": _rng.randf_range(SCATTER_HEIGHT_MIN, SCATTER_HEIGHT_MAX),
			"spin": _rng.randf_range(0.0, TAU),
		})

	# And a few filling the empty lots, so a gap is a yard rather than
	# a hole.
	for lot in _empty_lots:
		if _rng.randf() > LOT_PROP_CHANCE:
			continue
		placements.append({
			"pos": lot + Vector3(
				_rng.randf_range(-LOT_SIZE * 0.3, LOT_SIZE * 0.3), 0.0,
				_rng.randf_range(-LOT_SIZE * 0.3, LOT_SIZE * 0.3)),
			"height": _rng.randf_range(SCATTER_HEIGHT_MIN, SCATTER_HEIGHT_MAX),
			"spin": _rng.randf_range(0.0, TAU),
		})

	_build_model_clusters(props, placements)


# A point on a block's pavement: inside the block's own footprint, a
# little in from its edge, so it is never on the carriageway.
func _pavement_spot() -> Vector3:
	var gx := _rng.randi_range(-BLOCKS_OUT, BLOCKS_OUT)
	var gz := _rng.randi_range(-BLOCKS_OUT, BLOCKS_OUT)
	var block := Vector3(float(gx) * BLOCK_PITCH, 0.0, float(gz) * BLOCK_PITCH)

	# Inside the plaza the blocks are storefronts, not pavement.
	if Vector2(block.x, block.z).length() < STOREFRONT_RING + 20.0:
		return Vector3.ZERO

	var inset := BLOCK_SIZE * 0.5 - PAVEMENT_INSET
	var along := _rng.randf_range(-inset, inset)

	# One of the block's four edges.
	match _rng.randi() % 4:
		0: return block + Vector3(along, 0.0, -inset)
		1: return block + Vector3(along, 0.0, inset)
		2: return block + Vector3(-inset, 0.0, along)
		_: return block + Vector3(inset, 0.0, along)


# One MultiMesh per model, placements dealt out between them.
func _build_model_clusters(names: Array[String], placements: Array[Dictionary]) -> void:
	if names.is_empty() or placements.is_empty():
		return

	for index in names.size():
		var prop_name := names[index]
		var sample := Models.spawn_prop(prop_name)
		if sample == null:
			continue

		var mesh := Models.first_mesh(sample)
		var material := Models.first_material(sample, Models.PROP_FOLDER + prop_name)
		sample.queue_free()
		if mesh == null:
			continue

		var mine: Array[Dictionary] = []
		for i in placements.size():
			if i % names.size() == index:
				mine.append(placements[i])
		if mine.is_empty():
			continue

		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = mine.size()

		for i in mine.size():
			var spot: Dictionary = mine[i]
			var at: Vector3 = spot["pos"]
			var height := float(spot["height"])
			var spin := float(spot["spin"])

			# Uniform, and stood upright if the model came in Z-up.
			# Scaling a bench's width and height independently to hit a
			# target height is what turned these into thin slabs on
			# their sides.
			var fit := Models.mesh_fit_upright(mesh, prop_name, height)
			var scale := float(fit["scale"])
			var upright: Vector3 = fit["rotation"]
			var frame := Basis.from_euler(upright)
			var orientation := Basis(Vector3.UP, spin) * frame.scaled(Vector3(scale, scale, scale))
			multi.set_instance_transform(i, Transform3D(orientation, at + Vector3.UP * float(fit["base"])))

		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		if material != null:
			node.material_override = material
		add_child(node)


# --- Portal ------------------------------------------------------------

func _build_portal() -> void:
	portal = Portal.create(Color("#5ad1ff"))
	# Off-centre now: the statue has the middle of the square.
	portal.position = Vector3(0.0, 0.0, PLAZA_RADIUS * 0.55)
	add_child(portal)

	_spots.append({
		"kind": "portal",
		"name": "the portal",
		"route": "",
		"pos": portal.position,
		"radius": portal.interaction_radius(),
		"pad": null,
		"base_color": portal.tint,
	})


# --- The car -------------------------------------------------------------

func _build_car() -> void:
	car = CarBody.create()
	# Parked on the plaza's edge, clear of the portal and the shopfronts.
	car.position = Vector3(26.0, CarBody.RIDE_HEIGHT + 0.5, 34.0)
	car.rotation.y = PI
	add_child(car)

	car_camera = CarCamera.create(car)
	add_child(car_camera)
	car_camera.visible = false

	_spots.append({
		"kind": "car",
		"name": "the car",
		"route": "",
		"pos": car.position,
		"radius": CarBody.CAR_LENGTH * 1.3,
		"pad": null,
		"base_color": Color("#e8552c"),
	})


func _enter_car() -> void:
	if car == null or _driving:
		return

	_driving = true
	player.visible = false
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	# Collision off as well as physics: an invisible parked body would
	# otherwise sit in the plaza for the car to bump into.
	player.collision_layer = 0
	player.collision_mask = 0
	if companion != null:
		companion.visible = false

	car.take_control()
	car_camera.visible = true
	car_camera.activate()

	if hud != null:
		hud.hide_prompt()
		hud.set_driving(true)
	Audio.play("click")


func _exit_car() -> void:
	if not _driving:
		return

	_driving = false
	car.release_control()
	car_camera.visible = false
	car_camera.deactivate()

	# Set down beside the car rather than inside it.
	var beside := car.global_position + car.global_transform.basis.x * 2.6
	beside.y = car.global_position.y + 1.2
	player.global_position = beside
	player.velocity = Vector3.ZERO
	player.visible = true
	player.collision_layer = 1
	player.collision_mask = 1
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	player.make_current()

	if companion != null:
		companion.visible = true
		companion.global_position = beside

	if hud != null:
		hud.set_driving(false)
	Audio.play("click")


# --- People --------------------------------------------------------------

func _build_npcs() -> void:
	# The Boy roams the district, so he is somewhere different every
	# time the player comes back.
	var boy_angle := _rng.randf_range(0.0, TAU)
	var boy_at := Vector3(cos(boy_angle), 0.0, sin(boy_angle)) * _rng.randf_range(90.0, 220.0)
	var boy := _place_npc(Npcs.THE_BOY, boy_at, Npcs.tint(Npcs.THE_BOY))
	if boy != null:
		boy.roam_radius = 180.0
		boy.street_pitch = BLOCK_PITCH

		# Walking back in straight after beating him finds him where he
		# fell, once. After that he is up and running again.
		if GameState.progression.boy_just_lost:
			GameState.progression.boy_just_lost = false
			boy.play_defeat()

	# The Jokester turns up wherever she likes, but inside the plaza ring
	# so she is never standing in the middle of a building.
	var joke_angle := _rng.randf_range(0.0, TAU)
	var joke_at := Vector3(cos(joke_angle), 0.0, sin(joke_angle)) * _rng.randf_range(18.0, 38.0)
	_place_npc(Npcs.THE_JOKESTER, joke_at, Npcs.tint(Npcs.THE_JOKESTER))


func _place_npc(npc_id: String, at: Vector3, tint: Color) -> CityNPC:
	var npc := CityNPC.create(npc_id)
	npc.position = at
	add_child(npc)
	_npcs[npc_id] = npc

	_spots.append({
		"kind": "npc",
		"npc": npc_id,
		"name": Npcs.display_name(npc_id),
		"route": "",
		"pos": at,
		"radius": npc.interaction_radius(),
		"pad": null,
		"base_color": tint,
	})
	return npc


func _talk_to(npc_id: String) -> void:
	var npc: CityNPC = _npcs.get(npc_id)
	if npc != null:
		npc.face(player.position)

	match npc_id:
		Npcs.DIABLO:
			_talk_diablo()
		Npcs.THE_BOY:
			_talk_boy()
		Npcs.THE_JOKESTER:
			_talk_jokester()


func _talk_diablo() -> void:
	var progression := GameState.progression
	var line := Npcs.pick(Gauntlet.GREETING, _rng)
	if progression.gauntlet_cleared:
		line = Gauntlet.DEFEAT_LINE
	elif progression.gauntlet_best > 0:
		line = "Wave %d. That is where you stopped last time." % (progression.gauntlet_best + 1)

	var box := DialogueBox.open(self, Gauntlet.BOSS_NAME, Gauntlet.BOSS_TITLE,
		line, Npcs.tint(Npcs.DIABLO))
	box.option("Not yet", Callable())
	box.option("Enter the Hellfire Gauntlet", func():
		GameState.progression.start_gauntlet()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file(Routes.BATTLE))
	box.closed.connect(_on_menu_closed)
	_menu = box


func _talk_boy() -> void:
	var lines := Npcs.BOY_GREETING
	if GameState.progression.boy_defeated:
		lines = Npcs.BOY_REMATCH

	var box := DialogueBox.open(self, Npcs.display_name(Npcs.THE_BOY),
		Npcs.title(Npcs.THE_BOY), Npcs.pick(lines, _rng), Npcs.tint(Npcs.THE_BOY))
	box.option("Walk away", Callable())
	box.option("Challenge him", func():
		GameState.progression.queue_duel()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file(Routes.BATTLE))
	box.closed.connect(_on_menu_closed)
	_menu = box


func _talk_jokester() -> void:
	var box := DialogueBox.open(self, Npcs.display_name(Npcs.THE_JOKESTER),
		Npcs.title(Npcs.THE_JOKESTER), Npcs.jokester_line(_rng),
		Npcs.tint(Npcs.THE_JOKESTER))
	box.closed.connect(_on_menu_closed)
	_menu = box


# --- Inhabitants --------------------------------------------------------

func _build_player() -> void:
	player = LobbyPlayer.new()
	player.position = Vector3(0, 3.5, 26)
	add_child(player)


# Projects the rarest card the player owns. Mutations outrank plain
# rarity, so a Prismatic Epic beats a plain Legendary.
func _build_companion() -> void:
	var best: CardData = null
	var best_score := -1

	for card in GameState.collection.get_all():
		var score: int = Config.rarity_index(card.rarity) * 100 + Mutations.index_of(card.modifier)
		if score > best_score:
			best_score = score
			best = card

	if best == null:
		return

	companion = Companion.create(best, player)
	add_child(companion)
	companion.global_position = player.global_position


func _build_hud() -> void:
	hud = LobbyHUD.new()
	hud.title_text = "The City"
	hud.subtitle_text = "Neon district  ·  the portal is in the plaza"
	add_child(hud)


# --- Proximity -----------------------------------------------------

func _update_proximity() -> void:
	var closest: Dictionary = {}
	var best := INF
	var flat_player := Vector2(player.position.x, player.position.z)

	for spot in _spots:
		# A wandering NPC moves, so its position is read from the node
		# rather than from where it was first placed.
		var spot_pos: Vector3 = spot["pos"]
		# NPCs wander and the car gets driven away, so both are read
		# from the node rather than from where they were first placed.
		var kind := str(spot.get("kind", "route"))
		if kind == "npc":
			var npc: CityNPC = _npcs.get(str(spot["npc"]))
			if npc != null:
				spot_pos = npc.position
		elif kind == "car" and car != null:
			spot_pos = car.global_position

		var distance := flat_player.distance_to(Vector2(spot_pos.x, spot_pos.z))
		var radius: float = spot["radius"]
		var inside := distance < radius
		_set_spot_active(spot, inside)

		if inside and distance < best:
			best = distance
			closest = spot

	_current = closest
	if hud == null:
		return

	if closest.is_empty():
		hud.hide_prompt()
		return

	var key := Controls.interact_prompt()
	match str(closest.get("kind", "route")):
		"portal":
			hud.show_prompt("Press %s to travel" % key)
		"npc":
			hud.show_prompt("Press %s to talk to %s" % [key, str(closest["name"])])
		"car":
			hud.show_prompt("Press %s to drive" % Controls.vehicle_prompt())
		_:
			hud.show_prompt("Press %s to visit %s" % [key, str(closest["name"])])


func _set_spot_active(spot: Dictionary, active: bool) -> void:
	match str(spot.get("kind", "route")):
		"portal":
			if portal != null:
				portal.set_active(active)
			return
		"npc", "car":
			return

	var pad: MeshInstance3D = spot["pad"]
	if pad == null:
		return
	var mat: StandardMaterial3D = pad.material_override
	var tint: Color = spot["base_color"]
	var alpha := 0.22
	var energy := 0.4
	if active:
		alpha = 0.55
		energy = 1.0
	mat.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	mat.emission_energy_multiplier = RenderMode.emission(energy)
