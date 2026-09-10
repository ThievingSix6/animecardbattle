class_name Banners
extends RefCounted

# =========================================================
# SUMMONING BANNERS.
#
# A banner is a themed slice of the roster plus its own artwork, its own
# rate-up, and its own pity counters. Every card in res://art/cards/ is
# assigned to exactly one banner from its element and role, so a banner
# is a real pool the player can chase - not a cosmetic filter that
# quietly falls back to the full vault.
#
# ARTWORK
#   Drop an image at res://art/banners/<id>.png (or .jpg/.jpeg/.webp)
#   and it becomes that banner's splash. With no image the banner draws
#   its own gradient from its accent colour, so nothing looks unfinished.
#
# The ids below are the filenames to use:
#   standard, ember, abyss, radiance, nightfall, bastion, legends
# =========================================================

const FOLDER := "res://art/banners/"
const EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]

const STANDARD := "standard"
const LEGENDS := "legends"

# "elements"/"roles" decide which cards live on the banner. A card only
# needs to match one of them. The standard banner matches nothing on
# purpose: it is the catch-all every unclaimed card falls back to.
#
# "rate_up" is how many extra times a themed card is entered into its own
# banner's draw, on top of the single entry every card gets.
#
# "floor" is the lowest rarity the banner can produce at all.
const ALL: Array[Dictionary] = [
	{
		"id": "standard",
		"name": "Eternal Archive",
		"tagline": "Every card ever catalogued. No favourites, no exclusions.",
		"accent": Color("#8fa4c8"),
		"elements": [],
		"roles": [],
		"rate_up": 0.0,
		"cost_mult": 1.0,
		"floor": "Common",
		"pity_epic": 10,
		"pity_legendary": 80,
	},
	{
		"id": "ember",
		"name": "Emberfall Ascendant",
		"tagline": "Fire-born duellists and the ruin they leave behind.",
		"accent": Color("#e0532c"),
		"elements": ["Fire"],
		"roles": ["DPS"],
		"rate_up": 3.0,
		"cost_mult": 1.0,
		"floor": "Common",
		"pity_epic": 10,
		"pity_legendary": 70,
	},
	{
		"id": "abyss",
		"name": "Abyssal Tide",
		"tagline": "Water and wind — the patient half of the roster.",
		"accent": Color("#2c86e0"),
		"elements": ["Water", "Wind"],
		"roles": ["Support"],
		"rate_up": 3.0,
		"cost_mult": 1.0,
		"floor": "Common",
		"pity_epic": 10,
		"pity_legendary": 70,
	},
	{
		"id": "radiance",
		"name": "Radiant Choir",
		"tagline": "Light-aligned healers and the walls they keep standing.",
		"accent": Color("#e0c840"),
		"elements": ["Light"],
		"roles": ["Healer"],
		"rate_up": 3.0,
		"cost_mult": 1.0,
		"floor": "Common",
		"pity_epic": 10,
		"pity_legendary": 70,
	},
	{
		"id": "nightfall",
		"name": "Nightmare Court",
		"tagline": "Dark-aligned killers. Nothing here fights fair.",
		"accent": Color("#7a4ae0"),
		"elements": ["Dark"],
		"roles": ["Assassin"],
		"rate_up": 3.0,
		"cost_mult": 1.0,
		"floor": "Common",
		"pity_epic": 10,
		"pity_legendary": 70,
	},
	{
		"id": "bastion",
		"name": "Ironroot Bastion",
		"tagline": "Earth-bound guardians who simply refuse to fall.",
		"accent": Color("#8a6a42"),
		"elements": ["Earth"],
		"roles": ["Tank"],
		"rate_up": 3.0,
		"cost_mult": 1.0,
		"floor": "Common",
		"pity_epic": 10,
		"pity_legendary": 70,
	},
	{
		"id": "legends",
		"name": "Legends Awakened",
		"tagline": "Costs more. Never produces anything below Epic.",
		"accent": Color("#f5a623"),
		"elements": [],
		"roles": [],
		"rate_up": 0.0,
		"cost_mult": 3.0,
		"floor": "Epic",
		"pity_epic": 1,
		"pity_legendary": 40,
	},
]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for banner in ALL:
		out.append(str(banner["id"]))
	return out


static func get_banner(id: String) -> Dictionary:
	for banner in ALL:
		if str(banner["id"]) == id:
			return banner
	return ALL[0]


static func display_name(id: String) -> String:
	return str(get_banner(id)["name"])


# The first word of the name - what fits on a tab.
static func short_name(id: String) -> String:
	var parts := display_name(id).split(" ", false)
	if parts.is_empty():
		return display_name(id)
	return str(parts[0])


static func accent(id: String) -> Color:
	return get_banner(id)["accent"]


static func tagline(id: String) -> String:
	return str(get_banner(id)["tagline"])


static func floor_rarity(id: String) -> String:
	return str(get_banner(id)["floor"])


static func cost(id: String, count: int) -> int:
	var base := Config.SUMMON_COST_X1
	if count >= 10:
		base = Config.SUMMON_COST_X10
	return int(round(float(base) * float(get_banner(id)["cost_mult"])))


# --- Assignment ---------------------------------------------------------

# Which banner a card is themed to. Element wins over role, so a Fire
# healer chases the fire banner rather than the light one; a card that
# matches nothing lands in the standard pool.
#
# The legends banner is deliberately never returned here: it draws from
# every banner's cards at once, filtered by rarity instead of theme.
static func banner_for(element: String, role: String) -> String:
	for banner in ALL:
		if str(banner["id"]) == STANDARD or str(banner["id"]) == LEGENDS:
			continue
		var elements: Array = banner["elements"]
		if element in elements:
			return str(banner["id"])

	for banner in ALL:
		if str(banner["id"]) == STANDARD or str(banner["id"]) == LEGENDS:
			continue
		var roles: Array = banner["roles"]
		if role in roles:
			return str(banner["id"])

	return STANDARD


# Does this banner draw the given card at all?
static func accepts(banner_id: String, card: CardData) -> bool:
	var banner := get_banner(banner_id)
	if Config.rarity_index(card.rarity) < Config.rarity_index(str(banner["floor"])):
		return false
	if banner_id == STANDARD or banner_id == LEGENDS:
		return true
	return card.banner_id == banner_id


# Is this card one of the banner's own, rather than a guest from the
# shared pool? Featured cards get the rate-up and the FEATURED ribbon.
static func is_featured(banner_id: String, card: CardData) -> bool:
	if banner_id == STANDARD:
		return false
	if banner_id == LEGENDS:
		return Config.rarity_index(card.rarity) >= Config.rarity_index("Legendary")
	return card.banner_id == banner_id


# How many entries a card gets in this banner's draw.
static func entries(banner_id: String, card: CardData) -> int:
	if not is_featured(banner_id, card):
		return 1
	return 1 + int(round(float(get_banner(banner_id)["rate_up"])))


# --- Artwork -------------------------------------------------------------

static var _art_cache: Dictionary = {}


static func art(id: String) -> Texture2D:
	if _art_cache.has(id):
		return _art_cache[id]

	var found: Texture2D = null
	for ext in EXTENSIONS:
		var path := FOLDER + id + "." + ext
		if ResourceLoader.exists(path):
			found = load(path)
			break

	_art_cache[id] = found
	return found


static func has_art(id: String) -> bool:
	return art(id) != null
