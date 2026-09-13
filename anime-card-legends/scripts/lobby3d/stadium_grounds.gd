class_name StadiumGrounds
extends Node3D

# =========================================================
# THE ROAD OUT TO THE STADIUM.
#
# An underground tunnel leaves the city through the gap in its own wall,
# dips below the plain and runs under the mountain ring, then climbs
# back into the open at the stadium: searchlights raking the sky,
# fireworks over the roof, and a forest either side of the approach.
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

# The tunnel: how much clear height it gives a car, and how much of its
# own length is spent climbing or descending rather than running flat.
# Both ramps start OUTSIDE the city's own ground collider - a plain 24 m
# -thick slab under the whole district - or the tunnel would be carved
# into solid rock nobody could ever reach.
const TUNNEL_CLEARANCE := 7.5
const TUNNEL_RAMP_FRACTION := 0.16
const TUNNEL_FLOOR_THICKNESS := 1.0
const TUNNEL_WALL_THICKNESS := 1.0
const TUNNEL_LIGHTS := 10
# Extra clearance below Horizon's own flattened plain, which the tunnel
# has to run entirely under.
const TUNNEL_BURIAL_MARGIN := 6.0


# How far below street level the floor sits. Horizon's plain is flattened
# along the causeway's corridor, but flattened to ITS OWN base height -
# city_half * 0.02 + 1.0 below zero, not to y = 0 the way the district's
# own ground is - so a tunnel dug against world zero would have its
# ceiling poking straight through the ground above it. Matches
# Horizon._plain_base exactly, plus the tunnel's own height and a margin.
func _tunnel_depth() -> float:
	var plain_base := city_half * 0.02 + 1.0
	return plain_base + TUNNEL_CLEARANCE + TUNNEL_FLOOR_THICKNESS * 2.0 + TUNNEL_BURIAL_MARGIN

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


# --- The road out : an underground tunnel -------------------------------
#
# Three straight boxes rather than one displaced mesh - a floor tilted to
# a ramp's own angle is the entire trick, and a tunnel only needs two of
# them either side of a flat run under the mountains. Each box carries a
# floor, a ceiling and two walls, hollow between them, so the car and the
# player pass THROUGH rather than the tunnel being a solid slab with
# scenery painted on it.
var _tunnel_points: Array[Vector3] = []

func _build_causeway(centre: Vector3) -> void:
	# Starting AT the city's wall, not inside it: the ground under the
	# district itself is one solid 24 m-thick collider, and a ramp that
	# started underneath it would be carved into solid rock with no way
	# down into it.
	var from := heading * city_half
	var to := centre
	var width := city_half * CAUSEWAY_WIDTH

	var total := from.distance_to(to)
	var ramp_length := total * TUNNEL_RAMP_FRACTION
	var depth := _tunnel_depth()
	var down_end := from + heading * ramp_length + Vector3.DOWN * depth
	var up_start := to - heading * ramp_length + Vector3.DOWN * depth

	_tunnel_points = [from, down_end, up_start, to]

	_build_tunnel_segment(from, down_end, width)
	_build_tunnel_segment(down_end, up_start, width)
	_build_tunnel_segment(up_start, to, width)

	_build_tunnel_lights(width)


# One straight run of tunnel between two floor-surface points. Tilted to
# whatever slope `start` to `end` actually is, so the same function
# builds both ramps and the flat middle.
func _build_tunnel_segment(start: Vector3, end: Vector3, width: float) -> void:
	var direction := end - start
	var length := direction.length()
	if length <= 0.01:
		return

	var body := StaticBody3D.new()
	body.transform = Transform3D(Basis.looking_at(direction.normalized(), Vector3.UP), (start + end) * 0.5)
	add_child(body)

	var floor_mat := Textures.road(length, Color("#10131e"))
	var rock_mat := Textures.rock(length, Color("#1c2233"))

	# Floor: top face at the segment's own y = 0, which is the surface a
	# car actually drives on.
	_tunnel_slab(body, Vector3(width, TUNNEL_FLOOR_THICKNESS, length),
		Vector3(0.0, -TUNNEL_FLOOR_THICKNESS * 0.5, 0.0), floor_mat)
	# Ceiling, TUNNEL_CLEARANCE above the floor.
	_tunnel_slab(body, Vector3(width, TUNNEL_FLOOR_THICKNESS, length),
		Vector3(0.0, TUNNEL_CLEARANCE + TUNNEL_FLOOR_THICKNESS * 0.5, 0.0), rock_mat)
	# Both walls, spanning floor to ceiling.
	var wall_x := width * 0.5 + TUNNEL_WALL_THICKNESS * 0.5
	_tunnel_slab(body, Vector3(TUNNEL_WALL_THICKNESS, TUNNEL_CLEARANCE, length),
		Vector3(-wall_x, TUNNEL_CLEARANCE * 0.5, 0.0), rock_mat)
	_tunnel_slab(body, Vector3(TUNNEL_WALL_THICKNESS, TUNNEL_CLEARANCE, length),
		Vector3(wall_x, TUNNEL_CLEARANCE * 0.5, 0.0), rock_mat)

	# A lit line down the middle of the floor, so at night it still reads
	# as a road rather than a strip of ground.
	var line := MeshInstance3D.new()
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.8, 0.06, length)
	line.mesh = stripe
	line.position = Vector3(0.0, 0.04, 0.0)

	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color("#ff6b35")
	line_mat.emission_enabled = true
	line_mat.emission = Color("#ff6b35")
	line_mat.emission_energy_multiplier = RenderMode.emission(0.8)
	line.material_override = line_mat
	body.add_child(line)


func _tunnel_slab(body: StaticBody3D, size: Vector3, offset: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = offset
	mesh.material_override = material
	body.add_child(mesh)

	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = size
	shape.shape = collider
	shape.position = offset
	body.add_child(shape)


# Ceiling-mounted rather than floating overhead the way the old surface
# causeway's lamps did - there is a roof six feet up now to hang them
# from. Spaced across all three segments by distance, not by segment, so
# the ramps are not left darker than the flat run just for being shorter.
func _build_tunnel_lights(width: float) -> void:
	var lengths: Array[float] = []
	var total := 0.0
	for i in _tunnel_points.size() - 1:
		var d := _tunnel_points[i].distance_to(_tunnel_points[i + 1])
		lengths.append(d)
		total += d
	if total <= 0.01:
		return

	for i in TUNNEL_LIGHTS:
		var target := (float(i) + 0.5) / float(TUNNEL_LIGHTS) * total
		var at := _tunnel_point_at(lengths, target)

		var lamp := OmniLight3D.new()
		lamp.position = at + Vector3(0.0, TUNNEL_CLEARANCE * 0.82, 0.0)
		lamp.light_color = Color("#ff9f6b")
		lamp.light_energy = RenderMode.light(1.1)
		lamp.omni_range = width * 2.2
		add_child(lamp)


# Walks the three-point tunnel path `target` metres in and returns the
# floor position there, straight-line interpolating within whichever
# segment it falls in.
func _tunnel_point_at(lengths: Array[float], target: float) -> Vector3:
	var walked := 0.0
	for i in lengths.size():
		var seg_length: float = lengths[i]
		if target <= walked + seg_length or i == lengths.size() - 1:
			var t := 0.0 if seg_length <= 0.01 else clampf((target - walked) / seg_length, 0.0, 1.0)
			return _tunnel_points[i].lerp(_tunnel_points[i + 1], t)
		walked += seg_length
	return _tunnel_points[_tunnel_points.size() - 1]


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

		var info := Models.merged_mesh_info(sample, Models.PROP_FOLDER + model_name)
		var mesh: Mesh = info["mesh"]
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
		# NO material_override. The merged mesh carries a material per
		# surface, and an override would replace all of them with one.
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
