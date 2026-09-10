extends Node3D

# =========================================================
# 3D LOBBY - a real walkable hub.
#
# The whole world is generated in code (meshes, materials, lighting,
# collision) so it needs no imported art. Each destination is a
# physical building you walk up to; proximity opens it.
# =========================================================

const GROUND_RADIUS := 34.0

const BUILDINGS: Array[Dictionary] = [
	{"name": "Card Vault",    "icon": "🎴", "route": Routes.COLLECT, "pos": Vector3(-14, 0, -10), "color": Color("#3b82f6")},
	{"name": "Summon Altar",  "icon": "🔮", "route": Routes.PACKS,   "pos": Vector3(0, 0, -18),   "color": Color("#a855f7")},
	{"name": "Talent Shrine", "icon": "⭐", "route": Routes.TALENTS, "pos": Vector3(14, 0, -10),  "color": Color("#f5a623")},
	{"name": "Campaign Gate", "icon": "🗼", "route": Routes.CAMPAIGN, "pos": Vector3(16, 0, 8),   "color": Color("#ef4444")},
	{"name": "War Camp",      "icon": "🛡️", "route": Routes.TEAM,    "pos": Vector3(-16, 0, 8),   "color": Color("#3ecf7e")},
]

var player: LobbyPlayer
var companion: Companion
var hud: LobbyHUD
var _zones: Array[Dictionary] = []
var _current: Dictionary = {}


func _ready() -> void:
	# The lobby is a Node3D, so it needs its own version of the guard the
	# Screen base class applies to every 2D screen.
	if not GameState.has_active_slot():
		call_deferred("_bounce_to_slots")
		return

	Audio.play_music("music_lobby")
	_build_environment()
	_build_ground()
	for building in BUILDINGS:
		_build_building(building)
	_build_player()
	_build_companion()
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
		var route: String = _current["route"]
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file(route)


# --- World ---------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	# A 360 panorama at res://art/ui/lobby_sky.png replaces the procedural
	# sky if present - the easiest way to give the hub a real backdrop.
	var panorama := _load_sky_texture()
	if panorama != null:
		print("[Lobby] sky panorama loaded: ", panorama.resource_path,
			"  (", panorama.get_width(), "x", panorama.get_height(), ")")
		var pano_mat := PanoramaSkyMaterial.new()
		pano_mat.panorama = panorama
		sky.sky_material = pano_mat
	else:
		push_warning("[Lobby] no panorama found in res://art/ui/ - using procedural sky. "
			+ "Expected a .exr/.hdr/.png/.jpg file there.")
		var mat := ProceduralSkyMaterial.new()
		mat.sky_top_color = Color("#141a2e")
		mat.sky_horizon_color = Color("#3a2a4a")
		mat.ground_bottom_color = Color("#0b0d14")
		mat.ground_horizon_color = Color("#2a2038")
		sky.sky_material = mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color("#1b2036")
	env.fog_density = 0.012

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.1
	sun.light_color = Color("#ffd9a8")
	sun.shadow_enabled = true
	add_child(sun)


# Looks for res://art/ui/lobby_sky.<ext> first; failing that, accepts ANY
# .exr/.hdr in art/ui/ so a panorama downloaded from Poly Haven works
# without being renamed.
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
	print("[Lobby] using panorama: ", candidates[0])
	return load(candidates[0])


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	add_child(ground)

	var mesh := MeshInstance3D.new()
	var plane := CylinderMesh.new()
	plane.top_radius = GROUND_RADIUS
	plane.bottom_radius = GROUND_RADIUS
	plane.height = 1.0
	plane.radial_segments = 64
	mesh.mesh = plane
	mesh.position.y = -0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#1d2433")
	mat.roughness = 0.9
	mesh.material_override = mat
	ground.add_child(mesh)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_RADIUS * 2.0, 1.0, GROUND_RADIUS * 2.0)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)

	_build_perimeter_wall()


# An invisible ring of walls keeps the player on the platform.
func _build_perimeter_wall() -> void:
	var segments := 24
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		var body := StaticBody3D.new()
		body.position = Vector3(cos(angle), 1.5, sin(angle)) * GROUND_RADIUS
		body.rotation.y = -angle

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(GROUND_RADIUS * TAU / float(segments) + 1.0, 4.0, 1.0)
		shape.shape = box
		body.add_child(shape)
		add_child(body)


func _build_building(building: Dictionary) -> void:
	var origin: Vector3 = building["pos"]
	var tint: Color = building["color"]

	var root := Node3D.new()
	root.position = origin
	add_child(root)

	# Solid body
	var body := StaticBody3D.new()
	root.add_child(body)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6, 5, 6)
	mesh.mesh = box
	mesh.position.y = 2.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#242b3d")
	mat.roughness = 0.75
	mesh.material_override = mat
	body.add_child(mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(6, 5, 6)
	shape.shape = box_shape
	shape.position.y = 2.5
	body.add_child(shape)

	# Glowing roof beacon in the building's colour
	var roof := MeshInstance3D.new()
	var prism := CylinderMesh.new()
	prism.top_radius = 0.0
	prism.bottom_radius = 4.2
	prism.height = 3.0
	prism.radial_segments = 4
	roof.mesh = prism
	roof.position.y = 6.5
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = tint
	roof_mat.emission_enabled = true
	roof_mat.emission = tint
	roof_mat.emission_energy_multiplier = 0.9
	roof.material_override = roof_mat
	root.add_child(roof)

	var lamp := OmniLight3D.new()
	lamp.position.y = 6.0
	lamp.light_color = tint
	lamp.light_energy = 2.2
	lamp.omni_range = 16.0
	root.add_child(lamp)

	# Floating nameplate that always faces the camera
	var plate := Label3D.new()
	var icon_text: String = building["icon"]
	var name_text: String = building["name"]
	plate.text = "%s  %s" % [icon_text, name_text]
	plate.font_size = 96
	plate.pixel_size = 0.006
	plate.position.y = 9.4
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.modulate = Color.WHITE
	plate.outline_size = 24
	plate.outline_modulate = Color("#0b0d14")
	plate.no_depth_test = true
	root.add_child(plate)

	# Lit approach pad marking the interaction radius
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 6.5
	disc.bottom_radius = 6.5
	disc.height = 0.08
	disc.radial_segments = 32
	pad.mesh = disc
	pad.position.y = 0.05
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.22)
	pad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pad_mat.emission_enabled = true
	pad_mat.emission = tint
	pad_mat.emission_energy_multiplier = 0.35
	pad.material_override = pad_mat
	root.add_child(pad)

	_zones.append({
		"name": building["name"],
		"route": building["route"],
		"pos": origin,
		"radius": 6.5,
		"pad": pad,
		"base_color": tint,
	})


func _build_player() -> void:
	player = LobbyPlayer.new()
	player.position = Vector3(0, 1.2, 12)
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
	add_child(hud)


# --- Proximity -----------------------------------------------------

func _update_proximity() -> void:
	if player == null:
		return

	var closest: Dictionary = {}
	var best := INF

	for zone in _zones:
		var zone_pos: Vector3 = zone["pos"]
		var flat_player := Vector3(player.position.x, 0.0, player.position.z)
		var flat_zone := Vector3(zone_pos.x, 0.0, zone_pos.z)
		var distance := flat_player.distance_to(flat_zone)
		var radius: float = zone["radius"]
		var inside := distance < radius
		_set_pad_active(zone, inside)

		if inside and distance < best:
			best = distance
			closest = zone

	_current = closest
	if hud:
		if closest.is_empty():
			hud.hide_prompt()
		else:
			hud.show_prompt("Press ENTER to visit " + str(closest["name"]))


func _set_pad_active(zone: Dictionary, active: bool) -> void:
	var pad: MeshInstance3D = zone["pad"]
	var mat: StandardMaterial3D = pad.material_override
	var tint: Color = zone["base_color"]
	var alpha := 0.22
	var energy := 0.35
	if active:
		alpha = 0.5
		energy = 1.2
	mat.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	mat.emission_energy_multiplier = energy
