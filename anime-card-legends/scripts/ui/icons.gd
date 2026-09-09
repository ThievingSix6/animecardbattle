class_name Icons
extends RefCounted

# =========================================================
# Drop-in icon system.
#
# Put PNG/SVG files in res://art/icons/ named after what they represent
# and they replace the emoji fallbacks everywhere automatically:
#
#   role_tank.png  role_dps.png  role_assassin.png  role_healer.png  role_support.png
#   element_fire.png  element_water.png  element_earth.png
#   element_wind.png  element_light.png  element_dark.png
#   gem.png  gold.png  pack.png  dice.png  sword.png  shield.png  heart.png  bolt.png
#
# Anything missing falls back to the emoji, so partial sets work fine.
# =========================================================

const FOLDER := "res://art/icons/"
const EXTENSIONS: Array[String] = ["png", "svg", "webp", "jpg"]

const EMOJI_FALLBACK := {
	"role_tank": "🛡️", "role_dps": "⚔️", "role_assassin": "🗡️",
	"role_healer": "💚", "role_support": "🔮",
	"element_fire": "🔥", "element_water": "💧", "element_earth": "⛰️",
	"element_wind": "🌪️", "element_light": "✨", "element_dark": "🌑",
	"gem": "💎", "gold": "🪙", "pack": "🎁", "dice": "🎲",
	"sword": "⚔", "shield": "🛡", "heart": "❤", "bolt": "💨",
}

static var _cache: Dictionary = {}


static func texture(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]

	var found: Texture2D = null
	for ext in EXTENSIONS:
		var path := FOLDER + key + "." + ext
		if ResourceLoader.exists(path):
			found = load(path)
			break

	_cache[key] = found
	return found


static func has(key: String) -> bool:
	return texture(key) != null


static func emoji(key: String) -> String:
	return EMOJI_FALLBACK.get(key, "")


static func role_key(role: String) -> String:
	return "role_" + role.to_lower()


static func element_key(element: String) -> String:
	return "element_" + element.to_lower()


# Returns a TextureRect when a real icon exists, otherwise a Label with
# the emoji - so callers never have to branch.
static func node(key: String, size: int = 20, tint: Color = Color.WHITE) -> Control:
	var tex := texture(key)
	if tex != null:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(size, size)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.modulate = tint
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return rect

	var label := Label.new()
	label.text = emoji(key)
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# Inline text form, for use inside a formatted string.
static func inline(key: String) -> String:
	return emoji(key)
