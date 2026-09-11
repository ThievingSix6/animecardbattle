extends Node3D

# =========================================================
# INSIDE THE PLAYER'S HOUSE.
#
#   res://art/models/props/home/house.glb      the one in the city
#   res://art/models/props/home/interior.glb   this one
#
# Walk onto the pad at the front door in the city and you are put in
# here; walk onto the pad by the door in here and you are put back on the
# doorstep. Two scenes rather than one interior hidden inside the city,
# because an interior modelled at room scale does not want to share a
# world with a district three quarters of a kilometre across.
#
# COLLISION IS GENERATED FROM THE MODEL. An imported .glb has none, so
# without this the player falls through the floor the instant they
# arrive. Every mesh in the interior gets a trimesh collider built from
# its own triangles - walls, floor, furniture, whatever is in there - so
# a model dropped in is walkable without anyone placing boxes by hand.
#
# There is a floor under it regardless, at the height the model's own
# floor turned out to be. A trimesh has no thickness, and a room whose
# floor is a single plane is a room you can fall out of the moment two
# triangles do not quite meet.
# =========================================================

const MODEL := "home/interior"
# How wide the room is made, measured across its longest horizontal axis.
# An interior exported at any scale lands at a size a person fits in.
const ROOM_SPAN := 22.0
const SAFETY_MARGIN := 6.0

# Where the player appears, as a fraction of the room from its centre
# toward the door end.
const ARRIVAL := 0.34
const DOOR_PAD_RADIUS := 2.6

var player: LobbyPlayer
var hud: LobbyHUD

var _door: Vector3 = Vector3.ZERO
var _pad: MeshInstance3D
var _inside := false
var _size := Vector3(ROOM_SPAN, 4.0, ROOM_SPAN)


func _ready() -> void:
	if not GameState.has_active_slot():
		call_deferred("_bounce")
		return

	Audio.play_music("music_lobby")
	_build_environment()
	_build_room()
	_build_door_pad()
	_build_player()
	_build_hud()


func _bounce() -> void:
	get_tree().change_scene_to_file(Routes.TITLE)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0b0d14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#ffd9a8")
	env.ambient_light_energy = 0.55

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Warm and low, like lamps rather than daylight.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	key.light_energy = RenderMode.light(0.5)
	key.light_color = Color("#ffe2bb")
	add_child(key)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 3.2, 0.0)
	lamp.light_color = Color("#ffcf94")
	lamp.light_energy = RenderMode.light(1.6)
	lamp.omni_range = ROOM_SPAN
	add_child(lamp)


# --- The room -----------------------------------------------------------

func _build_room() -> void:
	var model := Models.spawn_prop(MODEL)
	if model == null:
		_build_placeholder_room()
		return

	add_child(model)
	# Sized from its footprint, ignoring outlier meshes, the same way the
	# stadium is - an interior with one stray plane in it would otherwise
	# be scaled to the plane rather than to the room.
	var fitted := Models.fit_span(model, ROOM_SPAN)
	if fitted != Vector3.ZERO:
		_size = fitted

	_add_trimesh_collision(model)
	_build_safety_floor()

	_door = Vector3(0.0, 0.0, _size.z * ARRIVAL)


# Every mesh under the model, given collision built from its own
# triangles. create_trimesh_collision() adds a StaticBody3D child with a
# ConcavePolygonShape3D - which is what makes an imported room something
# you can stand in rather than something you fall through.
func _add_trimesh_collision(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node
		if mesh_node.mesh != null and mesh_node.mesh.get_surface_count() > 0:
			mesh_node.create_trimesh_collision()

	for child in node.get_children():
		_add_trimesh_collision(child)


# A trimesh has no thickness, and a floor that is a single plane is a
# floor you fall through the moment two triangles do not quite meet. This
# sits under whatever the model's own floor turned out to be.
func _build_safety_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "SafetyFloor"
	add_child(body)

	var span := maxf(_size.x, _size.z) + SAFETY_MARGIN
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(span, 4.0, span)
	shape.shape = box
	shape.position.y = -2.05
	body.add_child(shape)

	# And walls, so a door the model leaves open is not a way out into
	# the void.
	var wall_height := maxf(_size.y, 4.0) * 1.5
	var half := span * 0.5
	var sides: Array[Vector3] = [
		Vector3(-half, wall_height * 0.5, 0.0), Vector3(half, wall_height * 0.5, 0.0),
		Vector3(0.0, wall_height * 0.5, -half), Vector3(0.0, wall_height * 0.5, half),
	]
	for i in sides.size():
		var wall := CollisionShape3D.new()
		var slab := BoxShape3D.new()
		if i < 2:
			slab.size = Vector3(1.0, wall_height, span)
		else:
			slab.size = Vector3(span, wall_height, 1.0)
		wall.shape = slab
		wall.position = sides[i]
		body.add_child(wall)


# For before interior.glb lands: a plain room, so the door still works.
func _build_placeholder_room() -> void:
	_size = Vector3(ROOM_SPAN, 4.0, ROOM_SPAN)

	var floor_mesh := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(ROOM_SPAN, 0.4, ROOM_SPAN)
	floor_mesh.mesh = slab
	floor_mesh.position.y = -0.2
	floor_mesh.material_override = Textures.sidewalk(ROOM_SPAN, Color("#2a2320"))
	add_child(floor_mesh)

	_build_safety_floor()
	_door = Vector3(0.0, 0.0, ROOM_SPAN * ARRIVAL)


# --- The way out --------------------------------------------------------

func _build_door_pad() -> void:
	_pad = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = DOOR_PAD_RADIUS
	disc.bottom_radius = DOOR_PAD_RADIUS
	disc.height = 0.12
	_pad.mesh = disc
	_pad.position = _door + Vector3(0.0, 0.06, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#5ad1ff")
	mat.emission_enabled = true
	mat.emission = Color("#5ad1ff")
	mat.emission_energy_multiplier = RenderMode.emission(0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.35
	_pad.material_override = mat
	add_child(_pad)

	var plate := Label3D.new()
	plate.text = "🚪  OUT"
	plate.font_size = 64
	plate.pixel_size = 0.006
	plate.position = _door + Vector3(0.0, 2.4, 0.0)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.modulate = Color("#5ad1ff")
	plate.outline_size = 12
	plate.outline_modulate = Color("#05060b")
	plate.no_depth_test = true
	add_child(plate)


func _build_player() -> void:
	player = LobbyPlayer.new()
	player.position = _door + Vector3(0.0, 1.2, -DOOR_PAD_RADIUS * 1.6)
	add_child(player)


func _build_hud() -> void:
	hud = LobbyHUD.new()
	add_child(hud)


func _process(_delta: float) -> void:
	if player == null:
		return

	var here := player.global_position
	var near := Vector2(here.x - _door.x, here.z - _door.z).length() < DOOR_PAD_RADIUS * 1.4

	if near != _inside:
		_inside = near
		if hud != null:
			if near:
				hud.show_prompt("Press %s to step outside" % Controls.interact_prompt())
			else:
				hud.hide_prompt()

	if near and Controls.interact_pressed():
		_leave()

	# Escape is a way out too, so nobody is ever stuck in a room.
	if Controls.cancel_pressed():
		_leave()


func _leave() -> void:
	Audio.play("click")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Routes.go(self, Routes.LOBBY)
