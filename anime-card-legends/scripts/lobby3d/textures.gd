class_name Textures
extends RefCounted

# =========================================================
# SURFACE TEXTURES, loaded by filename like everything else.
#
#   res://art/textures/road.png       the streets
#   res://art/textures/sidewalk.png   the blocks between them
#   res://art/textures/grass.png      the ground outside the district
#   res://art/textures/rock.png       the mountains on the horizon
#
# Any of these missing falls back to the flat colour that was there
# before, so the city never breaks for want of a texture.
#
# Everything is tiled by world size rather than stretched: a road
# texture stretched across a 700 m strip is a smear, so uv1_scale is
# set from how many metres the surface actually covers.
# =========================================================

const FOLDER := "res://art/textures/"
const EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]

# How many metres one tile of texture covers. Set per surface so a road
# and a field do not repeat at the same rate.
const ROAD_TILE := 12.0
const SIDEWALK_TILE := 10.0
const GRASS_TILE := 18.0
const ROCK_TILE := 60.0

static var _cache: Dictionary = {}


static func get_texture(surface: String) -> Texture2D:
	if _cache.has(surface):
		return _cache[surface]

	var found: Texture2D = null
	for ext in EXTENSIONS:
		var path := FOLDER + surface + "." + ext
		if ResourceLoader.exists(path):
			found = load(path)
			break

	_cache[surface] = found
	return found


static func has(surface: String) -> bool:
	return get_texture(surface) != null


static func missing(surfaces: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for surface in surfaces:
		if not has(surface):
			out.append(surface)
	return out


# A material for a surface of `world_size` metres. With a texture it
# tiles; without one it is the flat tint, so the same call site works
# either way.
static func material(surface: String, world_size: float, tint: Color,
		tile_metres: float, roughness: float = 0.7, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = roughness
	mat.metallic = metallic

	var texture := get_texture(surface)
	if texture == null:
		mat.albedo_color = tint
		return mat

	mat.albedo_texture = texture
	# Tinted rather than replaced, so the city's palette still reads
	# through whatever photograph gets dropped in.
	mat.albedo_color = tint.lerp(Color.WHITE, 0.55)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var repeats := maxf(1.0, world_size / maxf(tile_metres, 0.5))
	mat.uv1_scale = Vector3(repeats, repeats, repeats)

	var normal := get_texture(surface + "_normal")
	if normal != null:
		mat.normal_enabled = true
		mat.normal_texture = normal

	return mat


static func road(world_size: float, tint: Color) -> StandardMaterial3D:
	return material("road", world_size, tint, ROAD_TILE, 0.3, 0.25)


static func sidewalk(world_size: float, tint: Color) -> StandardMaterial3D:
	return material("sidewalk", world_size, tint, SIDEWALK_TILE, 0.55, 0.1)


static func grass(world_size: float, tint: Color) -> StandardMaterial3D:
	return material("grass", world_size, tint, GRASS_TILE, 0.9, 0.0)


static func rock(world_size: float, tint: Color) -> StandardMaterial3D:
	return material("rock", world_size, tint, ROCK_TILE, 0.85, 0.0)


# --- Campaign zones --------------------------------------------------------
#
# Each zone can have its own ground and stone, so Emberfall is not the
# same rock as the Verdant Hollow with a different light on it:
#
#   res://art/textures/zones/emberfall_ground.png
#   res://art/textures/zones/emberfall_stone.png
#
# Anything a zone does not supply falls back to the shared grass/rock,
# and then to the zone's own palette colour - so one zone can be
# textured without doing all six.

const ZONE_GROUND_TILE := 22.0
const ZONE_STONE_TILE := 14.0


static func zone_ground(zone_id: String, world_size: float, tint: Color) -> StandardMaterial3D:
	var named := "zones/" + zone_id + "_ground"
	if has(named):
		return material(named, world_size, tint, ZONE_GROUND_TILE, 0.9, 0.0)
	return grass(world_size, tint)


static func zone_stone(zone_id: String, world_size: float, tint: Color) -> StandardMaterial3D:
	var named := "zones/" + zone_id + "_stone"
	if has(named):
		return material(named, world_size, tint, ZONE_STONE_TILE, 0.8, 0.05)
	return rock(world_size, tint)


# Which zones have supplied textures, for the asset report.
static func zones_with_textures() -> Array[String]:
	var out: Array[String] = []
	for zone in Campaign.ZONES:
		var id := str(zone["id"])
		if has("zones/" + id + "_ground") or has("zones/" + id + "_stone"):
			out.append(id)
	return out
