class_name StadiumGrounds
extends Node3D

# =========================================================
# THE ROAD OUT TO THE STADIUM.
#
# A causeway leaves the city through a gap in the mountain ring, runs
# out across the plain, and ends at the stadium: searchlights raking
# the sky, fireworks over the roof, and a forest either side of the
# approach.
#
# The stadium itself is a landmark you drive up to and a marker you
# step onto - the match is played inside res://scenes/Arena.tscn, so
# this is the front of house rather than the pitch.
#
#   res://art/models/props/stadium.glb   the building
#   res://art/models/props/trees/*.glb   the forest, same pool the
#                                        city's parks use
# =========================================================

# All measured in multiples of the city's half-width, so the approach
# scales with the district and always clears the mountain ring.
# The grounds moved further out and got wider when the stadium doubled:
# at the old radius the building filled the whole apron and the forest
# grew through its walls, and the near edge of the grounds reached back
# inside the city.
const CAUSEWAY_LENGTH := 2.6
const CAUSEWAY_WIDTH := 0.18
const GROUNDS_RADIUS := 0.95

# The stadium's long axis, in multiples of the city's half-width, and
# then the straight 2x on top. One number to turn if it wants to be
# bigger or smaller. The HEIGHT is not set here - it is whatever the
# model's own proportions make it once the footprint is fitted.
const STADIUM_SPAN := 0.62
const STADIUM_SCALE := 2.0
# Only used for the placeholder bowl, before stadium.glb lands.
const SHELL_HEIGHT := 0.28

const MARKER_RADIUS := 16.0

# Searchlights.
const BEAM_COUNT := 8
const BEAM_HEIGHT := 2.4        # multiples of the stadium's height
const BEAM_SWEEP := 0.35        # radians either side of vertical
const BEAM_SPEED := 0.35

const FOREST_TREES := 160
const TREE_HEIGHT_MIN := 14.0
const TREE_HEIGHT_MAX := 30.0

var city_half := 368.0
# Which way out of the city the causeway runs.
var heading := Vector3.FORWARD

var marker_position := Vector3.ZERO

# What the stadium actually came out as, once the model was fitted. The
# searchlights, the fireworks and the marker are all placed off the real
# building rather than off the constants it was asked for.
var _stadium_span := 0.0
var _stadium_height := 0.0

var _beams: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


static func create(half_width: float, out_direction: Vector3) -> StadiumGrounds:
	var grounds := StadiumGrounds.new()
	grounds.city_half = half_width
	grounds.heading = out_direction.normalized()
	return grounds


func _ready() -> void:
	_rng.seed = hash("stadium-grounds")

	var centre := heading * city_half * CAUSEWAY_LENGTH

	_build_causeway(centre)
	_build_grounds(centre)
	_build_forest(centre)
	_build_stadium(centre)
	_build_beams(centre)
	_build_fireworks(centre)
	_build_marker(centre)


func interaction_radius() -> float:
	return MARKER_RADIUS


# --- The road out ------------------------------------------------------

# A raised causeway from the city's edge to the grounds. It is solid,
# so it can be driven; everything either side of it is not.
func _build_causeway(centre: Vector3) -> void:
	var from := heading * city_half * 0.9
	var to := centre
	var length := from.distance_to(to)
	var width := city_half * CAUSEWAY_WIDTH

	var body := StaticBody3D.new()
	body.position = (from + to) * 0.5
	body.rotation.y = atan2(heading.x, heading.z)
	add_child(body)

	var deck := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(width, 2.0, length)
	deck.mesh = slab
	deck.position.y = -1.0
	deck.material_override = Textures.road(length, Color("#151a28"))
	body.add_child(deck)

	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = Vector3(width, 2.0, length)
	shape.shape = collider
	shape.position.y = -1.0
	body.add_child(shape)

	# A lit line down the middle, so at night it reads as a road rather
	# than a strip of ground.
	var line := MeshInstance3D.new()
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.8, 0.1, length)
	line.mesh = stripe
	line.position.y = 0.06

	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color("#ff6b35")
	line_mat.emission_enabled = true
	line_mat.emission = Color("#ff6b35")
	line_mat.emission_energy_multiplier = RenderMode.emission(0.8)
	line.material_override = line_mat
	body.add_child(line)

	# Lamps down the causeway, so it is followable in the dark.
	var lamps := 6
	for i in lamps:
		var t := (float(i) + 0.5) / float(lamps)
		var at := from.lerp(to, t)
		var lamp := OmniLight3D.new()
		lamp.position = at + Vector3(0.0, 9.0, 0.0)
		lamp.light_color = Color("#ff9f6b")
		lamp.light_energy = RenderMode.light(1.1)
		lamp.omni_range = width * 2.2
		add_child(lamp)


# The clearing the stadium stands in.
func _build_grounds(centre: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = centre
	add_child(body)

	var radius := city_half * GROUNDS_RADIUS

	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 2.0
	disc.radial_segments = 48
	pad.mesh = disc
	pad.position.y = -1.0
	pad.material_override = Textures.sidewalk(radius, Color("#191f2e"))
	body.add_child(pad)

	var shape := CollisionShape3D.new()
	var collider := CylinderShape3D.new()
	collider.radius = radius
	collider.height = 2.0
	shape.shape = collider
	shape.position.y = -1.0
	body.add_child(shape)


# --- The forest ---------------------------------------------------------

# Trees either side of the approach and around the clearing, from the
# same pool the city's parks use.
func _build_forest(centre: Vector3) -> void:
	var trees := Models.list_props("trees")
	var radius := city_half * GROUNDS_RADIUS
	var road_width := city_half * CAUSEWAY_WIDTH

	var placements: Array[Dictionary] = []
	for i in FOREST_TREES:
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(radius * 1.05, radius * 2.1)
		var at := centre + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)

		# Never on the causeway.
		var along := at.dot(heading)
		var across := at - heading * along
		if along < centre.dot(heading) and across.length() < road_width:
			continue

		placements.append({
			"pos": at,
			"height": _rng.randf_range(TREE_HEIGHT_MIN, TREE_HEIGHT_MAX),
			"spin": _rng.randf_range(0.0, TAU),
		})

	if trees.is_empty() or placements.is_empty():
		return

	_build_clusters(trees, placements)


func _build_clusters(names: Array[String], placements: Array[Dictionary]) -> void:
	for index in names.size():
		var model_name := names[index]
		var sample := Models.spawn_prop(model_name)
		if sample == null:
			continue

		var info := Models.first_mesh_info(sample)
		var mesh: Mesh = info["mesh"]
		var material := Models.first_material(sample, Models.PROP_FOLDER + model_name)
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

			var fit := Models.mesh_fit_upright(info, model_name, height)
			multi.set_instance_transform(i, Models.upright_transform(fit, at, spin))

		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		if material != null:
			node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


# --- The stadium ---------------------------------------------------------

# Sized from its FOOTPRINT, not its height. stadium.glb carries one stray
# mesh four times the height of the actual bowl, so asking for a height
# sized the whole building against geometry that is not the building -
# it came out a quarter of the size and floating clear of the ground.
func _build_stadium(centre: Vector3) -> void:
	var span := city_half * STADIUM_SPAN * STADIUM_SCALE

	var root := Node3D.new()
	root.position = centre
	root.rotation.y = atan2(-heading.x, -heading.z)
	add_child(root)

	var footprint := Vector3(span, city_half * SHELL_HEIGHT, span)

	var model := Models.spawn_prop("stadium")
	if model != null:
		root.add_child(model)
		footprint = Models.fit_span(model, span)
	else:
		_build_stadium_shell(root, span, footprint.y)

	_stadium_span = maxf(footprint.x, footprint.z)
	_stadium_height = footprint.y

	# Solid, so it cannot be driven through. A box, because a stadium is
	# half again as long as it is wide and a cylinder around it would put
	# an invisible wall well outside the building.
	var body := StaticBody3D.new()
	root.add_child(body)
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = Vector3(maxf(footprint.x, 1.0), maxf(footprint.y, 1.0), maxf(footprint.z, 1.0))
	shape.shape = collider
	shape.position.y = footprint.y * 0.5
	body.add_child(shape)

	var plate := Label3D.new()
	plate.text = "🚀  ROCKET ARENA"
	plate.font_size = 128
	plate.pixel_size = 0.03
	plate.position.y = _stadium_height * 1.25
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.modulate = Color("#ff6b35")
	plate.outline_size = 24
	plate.outline_modulate = Color("#05060b")
	plate.no_depth_test = true
	root.add_child(plate)


# A bowl, for before stadium.glb lands.
func _build_stadium_shell(root: Node3D, width: float, height: float) -> void:
	var bowl := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = width * 0.5
	drum.bottom_radius = width * 0.42
	drum.height = height
	drum.radial_segments = 28
	bowl.mesh = drum
	bowl.position.y = height * 0.5
	bowl.material_override = Textures.rock(width, Color("#242a3d"))
	root.add_child(bowl)

	# A lit band around the rim, so it reads as a venue at night.
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = width * 0.5
	ring.outer_radius = width * 0.54
	rim.mesh = ring
	rim.position.y = height * 0.92

	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color("#ff6b35")
	rim_mat.emission_enabled = true
	rim_mat.emission = Color("#ff6b35")
	rim_mat.emission_energy_multiplier = RenderMode.emission(1.0)
	rim.material_override = rim_mat
	root.add_child(rim)


# --- Searchlights ---------------------------------------------------------

# Long thin cones standing on the rim, raked back and forth. They are
# additive geometry rather than SpotLights: a beam you can SEE is the
# point, and eight real spotlights would cost far more than they show.
func _build_beams(centre: Vector3) -> void:
	var width := _stadium_span
	var height := _stadium_height
	var length := height * BEAM_HEIGHT

	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = length * 0.09
	beam_mesh.bottom_radius = length * 0.012
	beam_mesh.height = length
	beam_mesh.radial_segments = 10

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.75, 0.55, 1.0, 0.16)
	mat.disable_receive_shadows = true

	for i in BEAM_COUNT:
		var angle := TAU * float(i) / float(BEAM_COUNT)
		var at := centre + Vector3(cos(angle), 0.0, sin(angle)) * width * 0.46

		var pivot := Node3D.new()
		pivot.position = at + Vector3(0.0, height, 0.0)
		# Staggered, so they do not sweep as one.
		pivot.set_meta("phase", float(i) * 0.7)
		add_child(pivot)

		var beam := MeshInstance3D.new()
		beam.mesh = beam_mesh
		beam.material_override = mat
		beam.position.y = length * 0.5
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(beam)

		_beams.append(pivot)


func _process(_delta: float) -> void:
	var now := float(Time.get_ticks_msec()) * 0.001
	for pivot in _beams:
		var phase := float(pivot.get_meta("phase", 0.0))
		pivot.rotation.z = sin(now * BEAM_SPEED + phase) * BEAM_SWEEP
		pivot.rotation.x = cos(now * BEAM_SPEED * 0.7 + phase) * BEAM_SWEEP * 0.6


# --- Fireworks -------------------------------------------------------------

# CPUParticles3D, one burst emitter per corner of the roof, set to
# explode rather than stream. Same reasoning as the car's boost trail:
# these run on every renderer.
func _build_fireworks(centre: Vector3) -> void:
	var width := _stadium_span
	var height := _stadium_height

	var colours: Array[Color] = [
		Color("#ff6b35"), Color("#5ad1ff"), Color("#b04cff"), Color("#3ecf7e"),
	]

	for i in colours.size():
		var angle := TAU * float(i) / float(colours.size()) + PI * 0.25
		var at := centre + Vector3(cos(angle), 0.0, sin(angle)) * width * 0.55

		var burst := CPUParticles3D.new()
		burst.position = at + Vector3(0.0, height * 1.5, 0.0)
		burst.amount = 90
		burst.lifetime = 2.6
		burst.explosiveness = 0.95
		burst.randomness = 0.4
		# Staggered so the sky is never quiet and never all at once.
		burst.preprocess = float(i) * 0.9
		burst.local_coords = false
		burst.direction = Vector3.UP
		burst.spread = 180.0
		burst.initial_velocity_min = height * 0.25
		burst.initial_velocity_max = height * 0.55
		burst.gravity = Vector3(0.0, -height * 0.35, 0.0)
		burst.scale_amount_min = height * 0.012
		burst.scale_amount_max = height * 0.026

		var ramp := Gradient.new()
		ramp.set_color(0, colours[i])
		ramp.set_color(1, Color(colours[i].r, colours[i].g, colours[i].b, 0.0))
		burst.color_ramp = ramp

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		burst.material_override = mat

		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.0) * height * 0.03
		burst.mesh = quad

		burst.emitting = true
		add_child(burst)


# --- The way in -------------------------------------------------------------

# A lit pad at the stadium's door. Walk or drive onto it and the match
# loads.
func _build_marker(centre: Vector3) -> void:
	var width := _stadium_span
	marker_position = centre - heading * width * 0.75
	marker_position.y = 0.0

	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = MARKER_RADIUS
	disc.bottom_radius = MARKER_RADIUS
	disc.height = 0.4
	disc.radial_segments = 32
	pad.mesh = disc
	pad.position = marker_position + Vector3(0.0, 0.2, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.42, 0.21, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color("#ff6b35")
	mat.emission_energy_multiplier = RenderMode.emission(1.0)
	pad.material_override = mat
	add_child(pad)

	var glow := OmniLight3D.new()
	glow.position = marker_position + Vector3(0.0, 6.0, 0.0)
	glow.light_color = Color("#ff6b35")
	glow.light_energy = RenderMode.light(1.3)
	glow.omni_range = MARKER_RADIUS * 4.0
	add_child(glow)
