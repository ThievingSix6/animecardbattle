class_name Horizon
extends Node3D

# =========================================================
# WHAT IS BEYOND THE CITY.
#
# Two things, both built here so the city script stays about the city:
#
#   a ring of mountains, so the district ends in a skyline instead of
#   in the void;
#
#   a purple haze dome over everything, which is what gives the sky its
#   cyberpunk glow.
#
# The dome is geometry rather than a sky shader on purpose. A custom
# sky shader would have to survive the GL Compatibility renderer this
# project runs on; a large inverted sphere with an additive material
# works identically on every renderer, and it tints a supplied
# panorama just as happily as a generated sky.
# =========================================================

# --- Mountains ------------------------------------------------------
const PEAKS_NEAR := 46
const PEAKS_FAR := 34
const NEAR_RADIUS := 1.18      # multiples of the city's half-width
const FAR_RADIUS := 1.75
const NEAR_HEIGHT := 0.34      # multiples of the city's half-width
const FAR_HEIGHT := 0.52
const PEAK_SIDES := 6

# --- The plain ------------------------------------------------------
#
# The land outside the walls used to be one flat disc, which is what made
# the world read as a tabletop with a city glued to it. It is a real
# surface now: a grid displaced by noise into low rolling hills, with
# tufts of grass standing on it so there is something between the eye and
# the ground plane.
#
# Two places have to stay dead level or what is built on them would be
# swallowed: the ring immediately around the city, and the corridor the
# causeway runs down to the stadium. Both are flattened here rather than
# fought with later.
const PLAIN_RADIUS := 4.2      # multiples of the city's half-width
const PLAIN_GRID := 96         # vertices per side; 18k triangles
const HILL_HEIGHT := 0.075     # multiples of the city's half-width
const HILL_SCALE := 0.55       # multiples of the city's half-width, per hill
const FLAT_RADIUS := 1.12      # level out to here
const FLAT_FADE := 0.7         # and rising over this much more

# The causeway corridor, both in multiples of the city's half-width.
const ROAD_HALF_WIDTH := 1.05
const ROAD_LENGTH := 4.0

# --- Grass ------------------------------------------------------------
const TUFT_COUNT := 5200
const TUFT_HEIGHT := 2.6       # metres
const TUFT_WIDTH := 3.4
# Tufts are only worth drawing where they can be seen; past this they are
# smaller than a pixel and cost a draw for nothing.
const TUFT_RADIUS := 2.4       # multiples of the city's half-width

# --- Haze dome ------------------------------------------------------
const DOME_RADIUS := 3.4       # multiples of the city's half-width
const HAZE_TOP := Color(0.30, 0.10, 0.55, 0.0)
const HAZE_MID := Color(0.55, 0.16, 0.85, 0.38)
const HAZE_HORIZON := Color(0.85, 0.30, 0.95, 0.62)

var city_half := 368.0
var rock_tint := Color("#241c33")
var glow := Color("#b04cff")

# The pass the causeway runs through. Peaks inside this arc are left
# out, so the road out of the city has somewhere to go.
var gap_direction := Vector3.ZERO
var gap_arc := 0.0


static func create(half_width: float) -> Horizon:
	var horizon := Horizon.new()
	horizon.city_half = half_width
	return horizon


# Cuts a pass through both rings, centred on `direction`.
static func with_pass(half_width: float, direction: Vector3, arc: float) -> Horizon:
	var horizon := create(half_width)
	horizon.gap_direction = direction.normalized()
	horizon.gap_arc = arc
	return horizon


# The plain's shape, made before anything is placed on it so the
# mountains can be seated on the hills rather than hovering over them.
var _noise: FastNoiseLite
var _plain_base := 0.0


func _ready() -> void:
	_plain_base = -city_half * 0.02 - 1.0
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0 / maxf(city_half * HILL_SCALE, 1.0)
	_noise.fractal_octaves = 3
	_noise.seed = 20260911

	_build_mountains()
	_build_haze_dome()
	_build_ground_beyond()


# Where the surface of the plain is at a point, in this node's space.
# Mountains stand on it and grass grows out of it, so both ask here.
func ground_height(x: float, z: float) -> float:
	return _plain_base + _plain_height(x, z)


# --- Mountains -------------------------------------------------------

# Two rings of low-poly peaks, drawn as a single MultiMesh. Eighty
# mountains as individual nodes would cost more than the entire city
# does.
func _build_mountains() -> void:
	var placements := _plan_peaks()
	if placements.is_empty():
		return

	# Models from res://art/models/props/mountains/ when there are any:
	# every file in that folder is a variant, and the placements are
	# dealt out between them so a ridge is not one shape repeated.
	var variants := Models.list_props("mountains")
	if not variants.is_empty():
		_build_mountain_models(variants, placements)
		return

	var peak := CylinderMesh.new()
	peak.top_radius = 0.0
	peak.bottom_radius = 1.0
	peak.height = 1.0
	peak.radial_segments = PEAK_SIDES
	peak.rings = 1

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = peak
	multi.instance_count = placements.size()

	for i in placements.size():
		var spot: Dictionary = placements[i]
		var at: Vector3 = spot["pos"]
		var width := float(spot["width"])
		var height := float(spot["height"])
		var spin := float(spot["spin"])

		var orientation := Basis(Vector3.UP, spin).scaled(Vector3(width, height, width))
		# The cylinder is centred on its own origin, so it lifts by half.
		multi.set_instance_transform(i, Transform3D(orientation, at + Vector3.UP * height * 0.5))

	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = Textures.rock(city_half, rock_tint)
	# They are scenery on the horizon; shadowing from them buys nothing
	# and costs a shadow pass over the whole district.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


# One MultiMesh per variant, so N mountain models still cost N draw
# calls rather than eighty.
func _build_mountain_models(variants: Array[String], placements: Array[Dictionary]) -> void:
	for index in variants.size():
		var name := variants[index]
		var sample := Models.spawn_prop(name)
		if sample == null:
			continue

		var info := Models.first_mesh_info(sample)
		var mesh: Mesh = info["mesh"]
		var material := Models.first_material(sample, Models.PROP_FOLDER + name)
		sample.queue_free()
		if mesh == null:
			continue

		# Deal the placements out round-robin between the variants.
		var mine: Array[Dictionary] = []
		for i in placements.size():
			if i % variants.size() == index:
				mine.append(placements[i])
		if mine.is_empty():
			continue

		var fit := Models.mesh_fit_box(info, name)

		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = mine.size()

		for i in mine.size():
			var spot: Dictionary = mine[i]
			var at: Vector3 = spot["pos"]
			var width := float(spot["width"]) * 2.0
			var height := float(spot["height"])
			var spin := float(spot["spin"])
			multi.set_instance_transform(i, Models.box_transform(fit, at, spin, width, height))

		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		if material != null:
			node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


func _plan_peaks() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("horizon:%f" % city_half)

	var out: Array[Dictionary] = []
	out.append_array(_ring(rng, PEAKS_NEAR, NEAR_RADIUS, NEAR_HEIGHT, 0.0))
	# The far ring is offset half a step so the two do not line up into
	# a picket fence.
	out.append_array(_ring(rng, PEAKS_FAR, FAR_RADIUS, FAR_HEIGHT, 0.5))
	return out


# Is this peak inside the arc the causeway needs?
func _in_pass(at: Vector3) -> bool:
	if gap_arc <= 0.0 or gap_direction == Vector3.ZERO:
		return false
	var flat := Vector3(at.x, 0.0, at.z)
	if flat.length() < 0.001:
		return false
	return flat.normalized().angle_to(gap_direction) < gap_arc * 0.5


func _ring(rng: RandomNumberGenerator, count: int, radius_scale: float,
		height_scale: float, phase: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var radius := city_half * radius_scale

	for i in count:
		var angle := TAU * (float(i) + phase) / float(count)
		var jitter := city_half * 0.07
		var at := Vector3(
			cos(angle) * radius + rng.randf_range(-jitter, jitter),
			0.0,
			sin(angle) * radius + rng.randf_range(-jitter, jitter))
		# Stood on the rolling plain rather than on the flat disc it used
		# to be, or the far ring would hang twenty-five metres clear of
		# the ground it is supposed to be growing out of.
		at.y = ground_height(at.x, at.z)

		# Inside the pass, so the causeway is not blocked by a mountain.
		if _in_pass(at):
			continue

		var height := city_half * height_scale * rng.randf_range(0.55, 1.35)
		out.append({
			"pos": at,
			"width": height * rng.randf_range(0.55, 0.95),
			"height": height,
			"spin": rng.randf_range(0.0, TAU),
		})

	return out


# --- Haze dome --------------------------------------------------------

# An inverted sphere with an additive purple gradient on its inside.
# Transparent overhead, strongest at the horizon, which is where a
# city's own light actually collects.
func _build_haze_dome() -> void:
	var dome := SphereMesh.new()
	dome.radius = city_half * DOME_RADIUS
	dome.height = city_half * DOME_RADIUS * 2.0
	dome.radial_segments = 32
	dome.rings = 16

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# Seen from the inside, and never occluding anything in front of it.
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.no_depth_test = true
	mat.disable_receive_shadows = true
	mat.albedo_texture = _haze_gradient()
	mat.albedo_color = Color.WHITE

	var node := MeshInstance3D.new()
	node.mesh = dome
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Drawn before everything else, as a backdrop.
	node.sorting_offset = -1000.0
	add_child(node)


# A sphere's V runs 0 at the top to 1 at the bottom, so a vertical
# gradient maps straight onto it.
func _haze_gradient() -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.42, 0.52, 1.0])
	ramp.colors = PackedColorArray([HAZE_TOP, HAZE_MID, HAZE_HORIZON, HAZE_TOP])

	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.width = 8
	texture.height = 256
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	return texture


# --- Ground beyond the walls ------------------------------------------

# The district's own ground stops at its wall. This is the land the
# mountains stand on, so there is no visible edge to fall off.
func _build_ground_beyond() -> void:
	var span := city_half * PLAIN_RADIUS

	var plain := MeshInstance3D.new()
	plain.mesh = _plain_mesh(span)
	plain.position.y = _plain_base
	# Tiled by the real width of the surface. It used to be told the
	# city's width for a disc three kilometres across, so one tile of
	# grass was stretched over seventy-five metres of ground.
	plain.material_override = Textures.grass(span * 2.0, Color("#16241c"))
	plain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plain)

	_build_grass(plain)


# A square grid displaced by noise. Anything past PLAIN_RADIUS is behind
# the mountains and inside the haze either way, so the square edge of it
# is never in shot.
func _plain_mesh(span: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var step := span * 2.0 / float(PLAIN_GRID - 1)

	for iz in PLAIN_GRID:
		for ix in PLAIN_GRID:
			var x := -span + step * float(ix)
			var z := -span + step * float(iz)
			verts.append(Vector3(x, _plain_height(x, z), z))
			normals.append(_plain_normal(x, z, step))
			uvs.append(Vector2(float(ix), float(iz)) / float(PLAIN_GRID - 1))

	for iz in PLAIN_GRID - 1:
		for ix in PLAIN_GRID - 1:
			var here := iz * PLAIN_GRID + ix
			var below := here + PLAIN_GRID
			indices.push_back(here)
			indices.push_back(below)
			indices.push_back(here + 1)
			indices.push_back(here + 1)
			indices.push_back(below)
			indices.push_back(below + 1)

	var surface: Array = []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = verts
	surface[Mesh.ARRAY_NORMAL] = normals
	surface[Mesh.ARRAY_TEX_UV] = uvs
	surface[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return mesh


# The normal at a point, taken from the slope of the height function
# either side of it. Real normals are the entire point of the exercise:
# with a flat Vector3.UP at every vertex the hills would still be lit as
# though they were the disc this replaced, and none of the relief would
# show.
func _plain_normal(x: float, z: float, step: float) -> Vector3:
	var reach := maxf(step, 0.01)
	var slope_x := (_plain_height(x + reach, z) - _plain_height(x - reach, z)) / (reach * 2.0)
	var slope_z := (_plain_height(x, z + reach) - _plain_height(x, z - reach)) / (reach * 2.0)
	return Vector3(-slope_x, 1.0, -slope_z).normalized()


# How high the land stands at a point. Zero under the city and under the
# causeway, rolling everywhere else.
func _plain_height(x: float, z: float) -> float:
	var ramp := minf(_city_ramp(x, z), _road_ramp(x, z))
	if ramp <= 0.0:
		return 0.0
	return _noise.get_noise_2d(x, z) * city_half * HILL_HEIGHT * ramp


# 0 inside the city's ring, rising to 1 over FLAT_FADE beyond it.
func _city_ramp(x: float, z: float) -> float:
	var distance := Vector2(x, z).length() / maxf(city_half, 1.0)
	return clampf((distance - FLAT_RADIUS) / maxf(FLAT_FADE, 0.01), 0.0, 1.0)


# The same, across the causeway's corridor. Returns 1 - no flattening -
# when there is no pass, which is how a city with no stadium behaves.
func _road_ramp(x: float, z: float) -> float:
	if gap_direction == Vector3.ZERO:
		return 1.0

	var here := Vector2(x, z)
	var out_direction := Vector2(gap_direction.x, gap_direction.z)
	var along := here.dot(out_direction) / maxf(city_half, 1.0)
	if along <= 0.0 or along > ROAD_LENGTH:
		return 1.0

	var side := Vector2(-out_direction.y, out_direction.x)
	var across := absf(here.dot(side)) / maxf(city_half, 1.0)
	return clampf((across - ROAD_HALF_WIDTH) / maxf(FLAT_FADE, 0.01), 0.0, 1.0)


# --- Grass ------------------------------------------------------------

# Crossed quads, one MultiMesh, seated on the plain's own surface. Two
# quads at right angles read as a tuft from any direction, which is the
# oldest trick there is and still the cheapest.
func _build_grass(plain: MeshInstance3D) -> void:
	var texture := Textures.get_texture("grass")
	if texture == null:
		return

	var blade := QuadMesh.new()
	blade.size = Vector2(TUFT_WIDTH, TUFT_HEIGHT)
	blade.center_offset = Vector3(0.0, TUFT_HEIGHT * 0.5, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.albedo_color = Color("#2f5a38").lerp(Color.WHITE, 0.5)
	# Cut out rather than blended: an alpha-blended tuft has to be sorted
	# against every other tuft, and five thousand of them cannot be.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.4
	# Seen from both sides, and lit on both, or half of every tuft is a
	# black rectangle.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.95

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = blade
	multi.instance_count = TUFT_COUNT * 2

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("plain-grass")
	var reach := city_half * TUFT_RADIUS
	var inner := city_half * FLAT_RADIUS

	for i in TUFT_COUNT:
		# Sampled on the ring between the wall and TUFT_RADIUS BY AREA -
		# the square root is what stops them bunching towards the middle.
		var angle := rng.randf() * TAU
		var area := lerpf(inner * inner, reach * reach, rng.randf())
		var radius: float = sqrt(area)
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var at := Vector3(x, _plain_height(x, z), z)

		var spin := rng.randf() * TAU
		var size := rng.randf_range(0.7, 1.5)
		var frame := Basis(Vector3.UP, spin).scaled(Vector3(size, size, size))
		multi.set_instance_transform(i * 2, Transform3D(frame, at))
		# The second quad crossed through the first.
		var crossed := Basis(Vector3.UP, spin + PI * 0.5).scaled(Vector3(size, size, size))
		multi.set_instance_transform(i * 2 + 1, Transform3D(crossed, at))

	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plain.add_child(node)
