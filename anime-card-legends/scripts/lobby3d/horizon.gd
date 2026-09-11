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


func _ready() -> void:
	_build_mountains()
	_build_haze_dome()
	_build_ground_beyond()


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
			-city_half * 0.02,
			sin(angle) * radius + rng.randf_range(-jitter, jitter))

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
	var plain := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = city_half * FAR_RADIUS * 2.4
	disc.bottom_radius = disc.top_radius
	disc.height = 2.0
	disc.radial_segments = 48
	plain.mesh = disc
	plain.position.y = -city_half * 0.02 - 1.0
	plain.material_override = Textures.grass(city_half * 2.0, Color("#16241c"))
	plain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plain)
