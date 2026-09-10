extends Node3D

# =========================================================
# THE CITY - a night-time Tokyo district that doubles as the hub.
#
# The five destinations are storefronts along the plaza; everything
# else is city built to sit behind them. One building model is reused
# for the whole skyline, varied by height, rotation and sign colour, so
# a single export fills a district.
#
#   res://art/models/props/building.glb   every building in the city
#   res://art/models/props/portal.glb     the travel portal
#
# With neither present the district still builds, from boxes and neon.
# =========================================================

# The district is square, walled, and centred on the plaza.
const CITY_HALF := 78.0
const PLAZA_RADIUS := 24.0

# Grid the filler buildings sit on. One per cell, jittered.
const BLOCK := 26.0
const BLOCKS_OUT := 3
const STREET_WIDTH := 9.0

const BUILDING_HEIGHT_MIN := 12.0
const BUILDING_HEIGHT_MAX := 34.0
const STOREFRONT_HEIGHT := 10.0

const PAD_RADIUS := 6.5

# Destinations, laid out around the plaza. The portal takes the centre.
const DESTINATIONS: Array[Dictionary] = [
	{"name": "Card Vault",    "sign": "VAULT",   "icon": "🎴", "route": Routes.COLLECT,  "pos": Vector3(-21, 0, -16), "color": Color("#3b82f6")},
	{"name": "Summon Altar",  "sign": "SUMMON",  "icon": "🔮", "route": Routes.PACKS,    "pos": Vector3(2, 0, -26),   "color": Color("#a855f7")},
	{"name": "Talent Shrine", "sign": "TALENT",  "icon": "⭐", "route": Routes.TALENTS,  "pos": Vector3(24, 0, -16),  "color": Color("#f5a623")},
	{"name": "Campaign Gate", "sign": "GATE",    "icon": "🗼", "route": Routes.CAMPAIGN, "pos": Vector3(25, 0, 14),   "color": Color("#ef4444")},
	{"name": "War Camp",      "sign": "TEAM",    "icon": "🛡️", "route": Routes.TEAM,     "pos": Vector3(-24, 0, 14),  "color": Color("#3ecf7e")},
]

# Latin only on purpose: the bundled font has no CJK glyphs, and a sign
# full of tofu boxes looks worse than no sign.
const NEON_WORDS: Array[String] = [
	"RAMEN", "KARAOKE", "SUSHI", "ARCADE", "24H", "BAR", "HOTEL",
	"NOODLES", "CLUB", "IZAKAYA", "COFFEE", "MANGA", "PACHINKO",
	"CURRY", "SAKE", "GAMES", "LOUNGE", "TAXI",
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
var _current: Dictionary = {}
var _interact_held := false
var _menu: TravelMenu


func _ready() -> void:
	# The city is a Node3D, so it needs its own version of the guard the
	# Screen base class applies to every 2D screen.
	if not GameState.has_active_slot():
		call_deferred("_bounce_to_slots")
		return

	Audio.play_music("music_lobby")
	_build_environment()
	_build_ground()
	_build_streets()
	_build_district()
	for destination in DESTINATIONS:
		_build_storefront(destination)
	_build_portal()
	_build_player()
	_build_companion()
	_build_hud()


func _bounce_to_slots() -> void:
	get_tree().change_scene_to_file(Routes.SLOTS)


func _process(_delta: float) -> void:
	if player == null:
		return
	if _menu != null and is_instance_valid(_menu):
		return

	_update_proximity()
	_handle_interact()


# Edge-triggered: holding ENTER must not reopen the travel menu every
# frame the moment it closes.
func _handle_interact() -> void:
	var pressed := Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER)
	if not pressed:
		_interact_held = false
		return
	if _interact_held:
		return
	_interact_held = true

	if _current.is_empty():
		return

	if str(_current.get("kind", "route")) == "portal":
		_open_travel()
		return

	var route: String = _current["route"]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(route)


func _open_travel() -> void:
	_menu = TravelMenu.open(self, -1)
	_menu.closed.connect(_on_menu_closed)


func _on_menu_closed() -> void:
	_menu = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Environment ----------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	# A 360 panorama at res://art/ui/lobby_sky.png replaces the procedural
	# sky if present - the easiest way to give the city a real skyline.
	var panorama := _load_sky_texture()
	if panorama != null:
		var pano_mat := PanoramaSkyMaterial.new()
		pano_mat.panorama = panorama
		sky.sky_material = pano_mat
	else:
		var mat := ProceduralSkyMaterial.new()
		mat.sky_top_color = Color("#070912")
		mat.sky_horizon_color = Color("#2b1b3d")
		mat.ground_bottom_color = Color("#05060b")
		mat.ground_horizon_color = Color("#1e1430")
		sky.sky_material = mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35

	# Haze is what sells a neon city: it gives every sign a halo.
	env.fog_enabled = true
	env.fog_light_color = Color("#241a38")
	env.fog_density = 0.018

	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.25

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Moonlight only - the city lights itself.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-58, -40, 0)
	moon.light_energy = 0.35
	moon.light_color = Color("#8ea6ff")
	moon.shadow_enabled = true
	add_child(moon)


func _load_sky_texture() -> Texture2D:
	var extensions: Array[String] = ["exr", "hdr", "png", "jpg", "jpeg", "webp"]
	for ext in extensions:
		var path: String = "res://art/ui/lobby_sky." + ext
		if ResourceLoader.exists(path):
			return load(path)

	var dir := DirAccess.open("res://art/ui/")
	if dir == null:
		return null

	var candidates: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower := file_name.to_lower()
			var is_panorama := lower.ends_with(".exr") or lower.ends_with(".hdr")
			# Only treat a plain image as a sky if it is clearly named one,
			# so menu_bg.png is never mistaken for a panorama.
			if lower.contains("sky") or lower.contains("panorama") or lower.contains("puresky"):
				is_panorama = is_panorama or lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg")
			if is_panorama:
				candidates.append("res://art/ui/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if candidates.is_empty():
		return null

	candidates.sort()
	return load(candidates[0])


# --- Ground and streets ---------------------------------------------

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	add_child(ground)

	var mesh := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(CITY_HALF * 2.0, 1.0, CITY_HALF * 2.0)
	mesh.mesh = slab
	mesh.position.y = -0.5

	# Dark and smooth, so every neon sign smears across it like wet
	# asphalt after rain.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#0e1018")
	mat.roughness = 0.22
	mat.metallic = 0.35
	mesh.material_override = mat
	ground.add_child(mesh)

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
		Vector3(0, 4, -CITY_HALF), Vector3(0, 4, CITY_HALF),
		Vector3(-CITY_HALF, 4, 0), Vector3(CITY_HALF, 4, 0),
	]
	for i in sides.size():
		var body := StaticBody3D.new()
		body.position = sides[i]

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		if i < 2:
			box.size = Vector3(CITY_HALF * 2.0, 12.0, 1.0)
		else:
			box.size = Vector3(1.0, 12.0, CITY_HALF * 2.0)
		shape.shape = box
		body.add_child(shape)
		add_child(body)


# Lit road surface on the grid lines, plus the plaza itself. Purely
# visual - the ground collider already covers all of it.
func _build_streets() -> void:
	for i in range(-BLOCKS_OUT, BLOCKS_OUT + 1):
		var offset := float(i) * BLOCK
		_street_strip(Vector3(0, 0.02, offset), Vector3(CITY_HALF * 2.0, 0.04, STREET_WIDTH))
		_street_strip(Vector3(offset, 0.02, 0), Vector3(STREET_WIDTH, 0.04, CITY_HALF * 2.0))

	# Plaza disc under the portal.
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


# --- The district ----------------------------------------------------

# Fills the grid outside the plaza with buildings. Deterministic, so the
# city looks the same every time it is walked into.
func _build_district() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("city:" + str(GameState.active_slot))

	for gx in range(-BLOCKS_OUT, BLOCKS_OUT + 1):
		for gz in range(-BLOCKS_OUT, BLOCKS_OUT + 1):
			var centre := Vector3(
				float(gx) * BLOCK + BLOCK * 0.5,
				0.0,
				float(gz) * BLOCK + BLOCK * 0.5)

			# Keep the plaza and the storefronts clear.
			if Vector2(centre.x, centre.z).length() < PLAZA_RADIUS + 10.0:
				continue
			if _too_close_to_storefront(centre):
				continue

			centre.x += rng.randf_range(-3.0, 3.0)
			centre.z += rng.randf_range(-3.0, 3.0)
			_build_city_block(centre, rng)


func _too_close_to_storefront(at: Vector3) -> bool:
	for destination in DESTINATIONS:
		var pos: Vector3 = destination["pos"]
		if Vector2(at.x - pos.x, at.z - pos.z).length() < 16.0:
			return true
	return false


func _build_city_block(centre: Vector3, rng: RandomNumberGenerator) -> void:
	var height := rng.randf_range(BUILDING_HEIGHT_MIN, BUILDING_HEIGHT_MAX)

	var root := Node3D.new()
	root.position = centre
	root.rotation.y = float(rng.randi() % 4) * (PI * 0.5)
	add_child(root)

	var footprint := _place_building(root, height, rng)

	# Neon on the face that looks toward the plaza.
	if rng.randf() < 0.85:
		_build_neon(root, centre, height, footprint, rng)

	# Windows glow so an unlit imported model still reads as inhabited.
	var window_light := OmniLight3D.new()
	window_light.position.y = height * 0.4
	window_light.light_color = Color("#ffd9a8")
	window_light.light_energy = 0.7
	window_light.omni_range = 16.0
	root.add_child(window_light)


# Uses the imported building when it exists, a box when it does not.
# Returns the footprint width so the signage can be hung off the facade.
func _place_building(root: Node3D, height: float, rng: RandomNumberGenerator) -> float:
	var model := Models.spawn_prop("building")

	if model != null:
		root.add_child(model)
		Models.fit_height(model, height)
		var size := Models.fitted_size(model)
		_add_box_collider(root, Vector3(maxf(size.x, 2.0), height, maxf(size.z, 2.0)))
		return maxf(size.x, size.z)

	var width := rng.randf_range(9.0, 15.0)
	var depth := rng.randf_range(9.0, 15.0)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, depth)
	mesh.mesh = box
	mesh.position.y = height * 0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#161b28").lerp(Color("#232a3d"), rng.randf())
	mat.roughness = 0.65
	mat.metallic = 0.15
	mesh.material_override = mat
	root.add_child(mesh)

	_add_box_collider(root, Vector3(width, height, depth))
	return maxf(width, depth)


func _add_box_collider(root: Node3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	root.add_child(body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	body.add_child(shape)


# A lit word and a glowing bar, hung on the side of the building that
# faces the plaza so it is readable from the street.
func _build_neon(root: Node3D, centre: Vector3, height: float, footprint: float, rng: RandomNumberGenerator) -> void:
	var tint: Color = NEON_COLORS[rng.randi() % NEON_COLORS.size()]
	var word: String = NEON_WORDS[rng.randi() % NEON_WORDS.size()]

	# Face the plaza, in the building's own rotated space.
	var toward := -Vector2(centre.x, centre.z).normalized()
	var facing := atan2(toward.x, toward.y) - root.rotation.y
	var reach := footprint * 0.5 + 0.4

	var sign_root := Node3D.new()
	sign_root.rotation.y = facing
	sign_root.position.y = rng.randf_range(height * 0.45, height * 0.8)
	root.add_child(sign_root)

	var label := Label3D.new()
	label.text = word
	label.font_size = 110
	label.pixel_size = 0.012
	# Label3D reads from its own +Z, and sign_root's +Z already points at
	# the plaza, so no extra turn - a flip here puts the sign inside the
	# building.
	label.position.z = reach
	label.modulate = tint
	label.outline_size = 18
	label.outline_modulate = Color("#05060b")
	label.shaded = false
	sign_root.add_child(label)

	# The bar under the word is what actually throws light.
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(rng.randf_range(3.0, 6.0), 0.28, 0.28)
	bar.mesh = box
	bar.position = Vector3(0.0, -1.4, reach)

	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = tint
	bar_mat.emission_enabled = true
	bar_mat.emission = tint
	bar_mat.emission_energy_multiplier = 3.0
	bar.material_override = bar_mat
	sign_root.add_child(bar)

	var glow := OmniLight3D.new()
	glow.position = Vector3(0.0, -0.6, reach + 1.0)
	glow.light_color = tint
	glow.light_energy = 2.6
	glow.omni_range = 18.0
	sign_root.add_child(glow)


# --- Storefronts (the five destinations) ------------------------------

func _build_storefront(destination: Dictionary) -> void:
	var origin: Vector3 = destination["pos"]
	var tint: Color = destination["color"]

	var root := Node3D.new()
	root.position = origin
	# Turn the shopfront toward the plaza.
	root.rotation.y = atan2(-origin.x, -origin.z)
	add_child(root)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("storefront:" + str(destination["name"]))

	var footprint := _place_building(root, STOREFRONT_HEIGHT, rng)

	# The destination's own sign, in its own colour, large enough to be
	# picked out from across the plaza.
	var sign_label := Label3D.new()
	sign_label.text = str(destination["sign"])
	sign_label.font_size = 150
	sign_label.pixel_size = 0.013
	sign_label.position = Vector3(0.0, STOREFRONT_HEIGHT * 0.72, footprint * 0.5 + 0.5)
	sign_label.modulate = tint
	sign_label.outline_size = 22
	sign_label.outline_modulate = Color("#05060b")
	sign_label.shaded = false
	root.add_child(sign_label)

	var awning := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(footprint * 0.9, 0.4, 0.4)
	awning.mesh = box
	awning.position = Vector3(0.0, STOREFRONT_HEIGHT * 0.55, footprint * 0.5 + 0.5)

	var awning_mat := StandardMaterial3D.new()
	awning_mat.albedo_color = tint
	awning_mat.emission_enabled = true
	awning_mat.emission = tint
	awning_mat.emission_energy_multiplier = 3.2
	awning.material_override = awning_mat
	root.add_child(awning)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, STOREFRONT_HEIGHT * 0.5, footprint * 0.5 + 2.0)
	lamp.light_color = tint
	lamp.light_energy = 3.2
	lamp.omni_range = 22.0
	root.add_child(lamp)

	# Floating nameplate that always faces the camera.
	var plate := Label3D.new()
	plate.text = "%s  %s" % [str(destination["icon"]), str(destination["name"])]
	plate.font_size = 96
	plate.pixel_size = 0.006
	plate.position.y = STOREFRONT_HEIGHT + 3.0
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.modulate = Color.WHITE
	plate.outline_size = 24
	plate.outline_modulate = Color("#05060b")
	plate.no_depth_test = true
	root.add_child(plate)

	# The approach pad sits between the shopfront and the plaza, not
	# inside the building.
	var pad_pos := origin - origin.normalized() * 6.0
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
	mat.emission_energy_multiplier = 0.4
	pad.material_override = mat
	add_child(pad)
	return pad


# --- Portal ------------------------------------------------------------

func _build_portal() -> void:
	portal = Portal.create(Color("#5ad1ff"))
	portal.position = Vector3(0, 0, 0)
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


# --- Inhabitants --------------------------------------------------------

func _build_player() -> void:
	player = LobbyPlayer.new()
	player.position = Vector3(0, 1.2, 14)
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

	for spot in _spots:
		var spot_pos: Vector3 = spot["pos"]
		var flat_player := Vector2(player.position.x, player.position.z)
		var flat_spot := Vector2(spot_pos.x, spot_pos.z)
		var distance := flat_player.distance_to(flat_spot)
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
	elif str(closest.get("kind", "route")) == "portal":
		hud.show_prompt("Press ENTER to travel")
	else:
		hud.show_prompt("Press ENTER to visit " + str(closest["name"]))


func _set_spot_active(spot: Dictionary, active: bool) -> void:
	if str(spot.get("kind", "route")) == "portal":
		if portal != null:
			portal.set_active(active)
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
		energy = 1.4
	mat.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	mat.emission_energy_multiplier = energy
