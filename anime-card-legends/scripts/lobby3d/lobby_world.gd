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

const CITY_HALF := 360.0
const BLOCK_SIZE := 44.0
const STREET_WIDTH := 14.0
const BLOCK_PITCH := BLOCK_SIZE + STREET_WIDTH
const BLOCKS_OUT := 6

# The open square in the middle: portal, NPCs, and the eight
# destinations around its edge.
const PLAZA_RADIUS := 34.0
const STOREFRONT_RING := 52.0

const BUILDING_HEIGHT_MIN := 16.0
const BUILDING_HEIGHT_MAX := 52.0
const STOREFRONT_HEIGHT := 14.0
const TOWER_HEIGHT := 46.0

const PAD_RADIUS := 7.0

# Lights and signs are the expensive part of a city, not the geometry.
# Both are spent near the middle, where the player actually is.
const LIT_RADIUS := 170.0
const MAX_STREET_LIGHTS := 16
const MAX_NEON_SIGNS := 26
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

var _spots: Array[Dictionary] = []
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
	_build_ground()
	_build_streets()
	_build_skyline()
	_build_storefronts()
	_build_portal()
	_build_npcs()
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

	_update_proximity()

	if Controls.interact_pressed():
		_interact()


func _interact() -> void:
	if _current.is_empty():
		return

	match str(_current.get("kind", "route")):
		"portal":
			_open_travel()
		"npc":
			_talk_to(str(_current["npc"]))
		_:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file(str(_current["route"]))


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

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.3

	# Haze is what sells a neon city: it gives every sign a halo, and it
	# hides where the district stops.
	env.fog_enabled = true
	env.fog_light_color = Color("#1d1830")
	env.fog_density = 0.006

	# Bloom needs HDR, which the Compatibility renderer does not have.
	# Asking for it there costs nothing but does nothing either.
	if RenderMode.supports_glow():
		env.glow_enabled = true
		env.glow_intensity = 0.9
		env.glow_bloom = 0.25

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Moonlight only - the city lights itself.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-58, -40, 0)
	moon.light_energy = RenderMode.light(0.4)
	moon.light_color = Color("#8ea6ff")
	moon.shadow_enabled = true
	add_child(moon)


# --- Ground and streets ---------------------------------------------

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	add_child(ground)

	# Dark and smooth, so every sign smears across it like wet asphalt.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#0e1018")
	mat.roughness = 0.22
	mat.metallic = 0.35

	var span := CITY_HALF * 2.0 / float(GROUND_TILES)
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

	for i in range(-BLOCKS_OUT, BLOCKS_OUT + 2):
		var offset := (float(i) - 0.5) * BLOCK_PITCH
		_street_strip(Vector3(0, 0.02, offset), Vector3(CITY_HALF * 2.0, 0.04, STREET_WIDTH))
		_street_strip(Vector3(offset, 0.02, 0), Vector3(STREET_WIDTH, 0.04, CITY_HALF * 2.0))

		# Street lamps along the near stretch of each road only. A lamp
		# every block over the whole district would be hundreds of lights.
		for j in range(-2, 3):
			if lights >= MAX_STREET_LIGHTS:
				continue
			var along := float(j) * BLOCK_PITCH
			if Vector2(along, offset).length() > LIT_RADIUS:
				continue
			_street_lamp(Vector3(along, 0.0, offset))
			_street_lamp(Vector3(offset, 0.0, along))
			lights += 2

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


func _street_strip(at: Vector3, size: Vector3) -> void:
	var strip := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	strip.mesh = box
	strip.position = at

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#141824")
	mat.roughness = 0.28
	mat.metallic = 0.3
	strip.material_override = mat
	add_child(strip)


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

	var placements := _plan_skyline()
	if placements.is_empty():
		return

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.use_colors = fallback
	multi.instance_count = placements.size()

	# One mesh, measured once: every instance is that mesh scaled.
	var fit := Models.mesh_fit(mesh, 1.0)
	var unit_scale := float(fit["scale"])
	var unit_size: Vector3 = fit["size"]
	var unit_offset := float(fit["offset"])

	var body := StaticBody3D.new()
	add_child(body)

	var signs := 0

	for i in placements.size():
		var spot: Dictionary = placements[i]
		var at: Vector3 = spot["pos"]
		var height := float(spot["height"])
		var spin := float(spot["spin"])

		var basis := Basis(Vector3.UP, spin).scaled(
			Vector3(unit_scale * height, unit_scale * height, unit_scale * height))
		var origin := at + Vector3(0.0, unit_offset * height, 0.0)
		multi.set_instance_transform(i, Transform3D(basis, origin))

		if fallback:
			var shade := Color("#161b28").lerp(Color("#232a3d"), _rng.randf())
			multi.set_instance_color(i, shade)

		# Collision as plain boxes under one body.
		var footprint := Vector3(
			maxf(unit_size.x * height, 2.0), height, maxf(unit_size.z * height, 2.0))
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = footprint
		shape.shape = box_shape
		shape.position = at + Vector3(0.0, height * 0.5, 0.0)
		body.add_child(shape)

		# Signage, spent near the plaza where it is actually seen.
		if signs < MAX_NEON_SIGNS and Vector2(at.x, at.z).length() < LIT_RADIUS:
			if _rng.randf() < 0.65:
				_build_neon(at, height, maxf(footprint.x, footprint.z), spin,
					signs % NEON_LIGHT_EVERY == 0)
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


# Four buildings to a block, jittered, with the plaza and the
# storefront ring left clear.
func _plan_skyline() -> Array[Dictionary]:
	var out: Array[Dictionary] = []

	for gx in range(-BLOCKS_OUT, BLOCKS_OUT + 1):
		for gz in range(-BLOCKS_OUT, BLOCKS_OUT + 1):
			var block := Vector3(float(gx) * BLOCK_PITCH, 0.0, float(gz) * BLOCK_PITCH)

			for lx in 2:
				for lz in 2:
					var at := block + Vector3(
						(float(lx) - 0.5) * BLOCK_SIZE * 0.5,
						0.0,
						(float(lz) - 0.5) * BLOCK_SIZE * 0.5)
					at.x += _rng.randf_range(-2.5, 2.5)
					at.z += _rng.randf_range(-2.5, 2.5)

					if Vector2(at.x, at.z).length() < STOREFRONT_RING + 22.0:
						continue

					# Taller toward the middle, so the district has a
					# centre rather than being flat everywhere.
					var closeness := 1.0 - clampf(
						Vector2(at.x, at.z).length() / CITY_HALF, 0.0, 1.0)
					var height := _rng.randf_range(
						BUILDING_HEIGHT_MIN,
						lerpf(BUILDING_HEIGHT_MIN + 8.0, BUILDING_HEIGHT_MAX, closeness))

					out.append({
						"pos": at,
						"height": height,
						"spin": float(_rng.randi() % 4) * (PI * 0.5),
					})

	return out


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
	var footprint := _place_destination_building(root, model_id, height)

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

	var footprint := _place_destination_building(root, "tower", TOWER_HEIGHT)
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


func _place_destination_building(root: Node3D, model_id: String, height: float) -> float:
	# A model named after the destination wins; otherwise the shared
	# building stands in, so the city is complete either way.
	var model := Models.spawn_prop("buildings/" + model_id)
	if model == null:
		model = Models.spawn_prop("building")

	if model != null:
		root.add_child(model)
		Models.fit_height(model, height)
		var size := Models.fitted_size(model)
		_add_box_collider(root, Vector3(maxf(size.x, 4.0), height, maxf(size.z, 4.0)))
		return maxf(size.x, size.z)

	var width := 16.0
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


# --- Portal ------------------------------------------------------------

func _build_portal() -> void:
	portal = Portal.create(Color("#5ad1ff"))
	portal.position = Vector3.ZERO
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


# --- People --------------------------------------------------------------

func _build_npcs() -> void:
	# The Boy roams the district, so he is somewhere different every
	# time the player comes back.
	var boy_angle := _rng.randf_range(0.0, TAU)
	var boy_at := Vector3(cos(boy_angle), 0.0, sin(boy_angle)) * _rng.randf_range(70.0, 150.0)
	var boy := _place_npc(Npcs.THE_BOY, boy_at, Npcs.tint(Npcs.THE_BOY))
	if boy != null:
		boy.roam_radius = 110.0
		boy.street_pitch = BLOCK_PITCH

		# Walking back in straight after beating him finds him where he
		# fell, once. After that he is up and running again.
		if GameState.progression.boy_just_lost:
			GameState.progression.boy_just_lost = false
			boy.play_defeat()

	# The Jokester turns up wherever she likes, but inside the plaza ring
	# so she is never standing in the middle of a building.
	var joke_angle := _rng.randf_range(0.0, TAU)
	var joke_at := Vector3(cos(joke_angle), 0.0, sin(joke_angle)) * _rng.randf_range(16.0, 32.0)
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
	player.position = Vector3(0, 1.2, 18)
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
		if str(spot.get("kind", "route")) == "npc":
			var npc: CityNPC = _npcs.get(str(spot["npc"]))
			if npc != null:
				spot_pos = npc.position

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
		_:
			hud.show_prompt("Press %s to visit %s" % [key, str(closest["name"])])


func _set_spot_active(spot: Dictionary, active: bool) -> void:
	match str(spot.get("kind", "route")):
		"portal":
			if portal != null:
				portal.set_active(active)
			return
		"npc":
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
