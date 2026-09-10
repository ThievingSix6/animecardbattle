class_name SkyBuilder
extends RefCounted

# =========================================================
# THE SKY OVER THE CITY.
#
# A 360 panorama is used when one is supplied:
#
#   res://art/sky/city.hdr        (or .exr / .png / .jpg)
#   res://art/sky/<anything>.hdr  any panorama in that folder
#   res://art/ui/lobby_sky.png    the older location, still honoured
#
# With none, it builds a night sky rather than falling back to a flat
# purple gradient: deep navy overhead, the warm haze a city throws onto
# its own clouds at the horizon, and a starfield generated at load.
#
# The starfield is a small texture with pixels plotted into it, not a
# per-pixel loop over a full panorama - that would be far too slow in
# GDScript to do on every scene load.
# =========================================================

const PANORAMA_FOLDERS: Array[String] = ["res://art/sky/", "res://art/ui/"]
const PANORAMA_EXTENSIONS: Array[String] = ["hdr", "exr", "png", "jpg", "jpeg", "webp"]

const STAR_WIDTH := 512
const STAR_HEIGHT := 256
const STAR_COUNT := 900

static var _stars: Texture2D = null


# --- Entry point ----------------------------------------------------------

static func night_city() -> Sky:
	var sky := Sky.new()

	var panorama := find_panorama()
	if panorama != null:
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = panorama
		sky.sky_material = pano
		return sky

	sky.sky_material = _night_material()
	return sky


static func has_panorama() -> bool:
	return find_panorama() != null


# --- Panorama lookup ------------------------------------------------------

static func find_panorama() -> Texture2D:
	# The name the docs tell you to use comes first.
	for folder in PANORAMA_FOLDERS:
		for ext in PANORAMA_EXTENSIONS:
			var named := folder + "city." + ext
			if ResourceLoader.exists(named):
				return load(named)
			var legacy := folder + "lobby_sky." + ext
			if ResourceLoader.exists(legacy):
				return load(legacy)

	# Otherwise take any panorama sitting in art/sky/, so a file
	# downloaded from Poly Haven works without being renamed.
	var found := _scan_folder("res://art/sky/", true)
	if found != "":
		return load(found)

	# art/ui/ holds UI art too, so only obvious sky names count there.
	var fallback := _scan_folder("res://art/ui/", false)
	if fallback != "":
		return load(fallback)

	return null


static func _scan_folder(folder: String, accept_any: bool) -> String:
	var dir := DirAccess.open(folder)
	if dir == null:
		return ""

	var candidates: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower := file_name.to_lower()
			var named_sky := lower.contains("sky") or lower.contains("panorama") or lower.contains("puresky")
			var is_hdr := lower.ends_with(".hdr") or lower.ends_with(".exr")
			var is_image := false
			for ext in PANORAMA_EXTENSIONS:
				if lower.ends_with("." + ext):
					is_image = true
					break
			if is_image and (is_hdr or named_sky or accept_any):
				candidates.append(folder + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if candidates.is_empty():
		return ""
	candidates.sort()
	return candidates[0]


# --- Generated night sky ---------------------------------------------------

static func _night_material() -> ProceduralSkyMaterial:
	var mat := ProceduralSkyMaterial.new()

	# Deep and blue overhead, warm where the city lights bounce off the
	# haze. The old gradient ran to purple at the horizon, which read as
	# "unfinished" rather than "night".
	mat.sky_top_color = Color("#05070f")
	mat.sky_horizon_color = Color("#2a2233")
	mat.sky_curve = 0.18
	mat.ground_bottom_color = Color("#04050a")
	mat.ground_horizon_color = Color("#241b26")
	mat.ground_curve = 0.06

	mat.sky_cover = star_texture()
	mat.sky_cover_modulate = Color(0.9, 0.93, 1.0, 1.0)
	return mat


# A black panorama with stars plotted into it, thinning out toward the
# horizon the way a city's light pollution actually washes them out.
static func star_texture() -> Texture2D:
	if _stars != null:
		return _stars

	var image := Image.create(STAR_WIDTH, STAR_HEIGHT, false, Image.FORMAT_RGB8)
	image.fill(Color.BLACK)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260910

	for i in STAR_COUNT:
		var x := rng.randi() % STAR_WIDTH

		# Bias upward: y = 0 is straight up in a panorama.
		var bias := rng.randf() * rng.randf()
		var y := int(bias * float(STAR_HEIGHT) * 0.62)

		var brightness := rng.randf_range(0.25, 1.0)
		# A few stars are warm, most are white-blue.
		var tint := Color(brightness, brightness, brightness)
		if rng.randf() < 0.12:
			tint = Color(brightness, brightness * 0.85, brightness * 0.7)
		elif rng.randf() < 0.2:
			tint = Color(brightness * 0.8, brightness * 0.9, brightness)

		image.set_pixel(x, y, tint)

		# The brightest ones get a single neighbouring pixel so they
		# survive being resampled onto the sky.
		if brightness > 0.85 and x + 1 < STAR_WIDTH:
			image.set_pixel(x + 1, y, tint * 0.6)

	_stars = ImageTexture.create_from_image(image)
	return _stars
