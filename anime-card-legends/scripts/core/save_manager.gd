class_name SaveManager
extends RefCounted

# =========================================================
# Serialization only. Knows the shape of a save file and nothing
# about game rules. Versioned so old saves can be migrated rather
# than silently corrupted.
# =========================================================

const SLOT_COUNT := 3
const VERSION := 5

# Legacy single-slot file, migrated into slot 1 on first run.
const LEGACY_PATH := "user://save.json"


static func slot_path(slot: int) -> String:
	return "user://save_%d.json" % slot


static func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


static func delete_slot(slot: int) -> bool:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return err == OK


# Reads just enough to render a slot on the profile screen, without
# rebuilding the whole game state.
static func slot_summary(slot: int) -> Dictionary:
	var empty := {"exists": false}
	if not slot_exists(slot):
		return empty

	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return empty
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return empty

	var cards = parsed.get("cards", [])
	var team = parsed.get("team", [])

	return {
		"exists": true,
		"gems": int(parsed.get("gems", 0)),
		"gold": int(parsed.get("gold", 0)),
		"cards": cards.size() if typeof(cards) == TYPE_ARRAY else 0,
		"team": team.size() if typeof(team) == TYPE_ARRAY else 0,
		"floor": int(parsed.get("highest_floor", 0)),
		"played_at": int(parsed.get("played_at", 0)),
		"best_rarity": str(parsed.get("best_rarity", "")),
	}


# Moves a pre-slots save into slot 1 so existing progress isn't lost.
static func migrate_legacy() -> void:
	if not FileAccess.file_exists(LEGACY_PATH):
		return
	if slot_exists(1):
		return

	var src := FileAccess.open(LEGACY_PATH, FileAccess.READ)
	if src == null:
		return
	var text := src.get_as_text()
	src.close()

	var dst := FileAccess.open(slot_path(1), FileAccess.WRITE)
	if dst == null:
		return
	dst.store_string(text)
	dst.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_PATH))
	print("[Save] migrated legacy save into slot 1")

const CARD_FIELDS: Array[String] = [
	"card_id", "card_name", "description", "faction", "element", "role", "origin_tag",
	"banner_id", "art_path",
	"rarity", "modifier", "level", "max_level", "attack", "defense", "health", "speed",
	"base_attack", "base_defense", "base_health", "base_speed",
	"crit_chance", "crit_damage", "basic_ability", "ultimate_ability",
	"basic_target_mode", "ultimate_target_mode", "skill_id",
	"stars", "max_stars", "experience", "sell_value", "upgrade_cost", "obtained", "locked",
]


static func card_to_dict(card: CardData) -> Dictionary:
	var d := {}
	for f in CARD_FIELDS:
		d[f] = card.get(f)
	return d


static func dict_to_card(d: Dictionary) -> CardData:
	var card := CardData.new()
	for f in CARD_FIELDS:
		if d.has(f):
			card.set(f, d[f])

	# Saves written before v5 have no baseline stats and no banner. Both
	# are reconstructed here rather than left at their defaults, so an
	# older card levels and filters exactly like a freshly pulled one.
	if card.banner_id == "":
		card.banner_id = Banners.banner_for(card.element, card.role)
	Leveling.apply(card)
	return card


static func save(slot: int, wallet: Dictionary, collection: CollectionSystem, progression: ProgressionSystem, weather: WeatherSystem, gacha: GachaSystem, equipment: EquipmentSystem, clan: ClanSystem, chat: ChatSystem) -> bool:
	var cards := []
	for c in collection.owned.values():
		cards.append(card_to_dict(c))

	var payload := {
		"version": VERSION,
		"played_at": int(Time.get_unix_time_from_system()),
		"best_rarity": _best_rarity(collection),
		"gems": wallet.get("gems", 0),
		"gold": wallet.get("gold", 0),
		"cards": cards,
		"duplicates": collection.duplicates,
		"team": collection.team_ids,
		"talents": progression.talents,
		"highest_floor": progression.highest_floor,
		"roll_packs": progression.roll_packs,
		"boss_pool_unlocked": gacha.boss_pool_unlocked,
		"pity": gacha.pity,
		"items_owned": equipment.owned,
		"items_equipped": equipment.equipped,
		"clan": clan.to_dict(),
		"chat": chat.to_array(),
		"weather": {
			"active": weather.active,
			"ends_at": weather.ends_at,
			"next_check_at": weather.next_check_at,
		},
	}

	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not open save file for writing.")
		return false

	file.store_string(JSON.stringify(payload))
	file.close()
	return true


static func load_into(slot: int, wallet: Dictionary, collection: CollectionSystem, progression: ProgressionSystem, weather: WeatherSystem, gacha: GachaSystem, equipment: EquipmentSystem, clan: ClanSystem, chat: ChatSystem) -> bool:
	if not slot_exists(slot):
		return false

	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: save file unreadable, starting fresh.")
		return false

	wallet["gems"] = int(parsed.get("gems", Config.START_GEMS))
	wallet["gold"] = int(parsed.get("gold", Config.START_GOLD))

	collection.owned.clear()
	collection.duplicates.clear()
	collection.team_ids.clear()

	# v3 renamed owned_cards -> cards; accept both so older saves survive.
	var card_list = parsed.get("cards", parsed.get("owned_cards", []))
	for entry in card_list:
		var card := dict_to_card(entry)
		collection.owned[card.card_id] = card

	var dupes = parsed.get("duplicates", parsed.get("duplicate_counts", {}))
	for key in dupes.keys():
		collection.duplicates[key] = int(dupes[key])

	for id in parsed.get("team", parsed.get("team_card_ids", [])):
		collection.team_ids.append(str(id))

	var talents = parsed.get("talents", parsed.get("talent_levels", {}))
	for key in progression.talents.keys():
		if talents.has(key):
			progression.talents[key] = int(talents[key])

	progression.highest_floor = int(parsed.get("highest_floor", parsed.get("highest_floor_cleared", 0)))

	progression.roll_packs.clear()
	for key in parsed.get("roll_packs", {}).keys():
		progression.roll_packs[key] = int(parsed["roll_packs"][key])

	gacha.boss_pool_unlocked = bool(parsed.get("boss_pool_unlocked", false))

	gacha.pity.clear()
	var stored_pity = parsed.get("pity", {})
	if typeof(stored_pity) == TYPE_DICTIONARY:
		for key in stored_pity.keys():
			var counters = stored_pity[key]
			if typeof(counters) != TYPE_DICTIONARY:
				continue
			gacha.pity[str(key)] = {
				"epic": int(counters.get("epic", 0)),
				"legendary": int(counters.get("legendary", 0)),
			}

	equipment.owned.clear()
	for key in parsed.get("items_owned", {}).keys():
		equipment.owned[key] = int(parsed["items_owned"][key])
	equipment.equipped.clear()
	for key in parsed.get("items_equipped", {}).keys():
		equipment.equipped[key] = str(parsed["items_equipped"][key])

	# Saves written before v4 have no clan; the player simply has not
	# founded one yet.
	var clan_data = parsed.get("clan", {})
	if typeof(clan_data) == TYPE_DICTIONARY:
		clan.from_dict(clan_data)

	chat.from_array(parsed.get("chat", []))

	var w = parsed.get("weather", {})
	if typeof(w) == TYPE_DICTIONARY:
		var act = w.get("active", {})
		if typeof(act) == TYPE_DICTIONARY:
			weather.active = act
		else:
			weather.active = {}
		weather.ends_at = float(w.get("ends_at", 0.0))
		weather.next_check_at = float(w.get("next_check_at", 0.0))

	return true


# Rarest card owned, shown on the profile card as a bragging line.
static func _best_rarity(collection: CollectionSystem) -> String:
	var best := ""
	var best_index := -1
	for card in collection.owned.values():
		var idx := Config.rarity_index(card.rarity)
		if idx > best_index:
			best_index = idx
			best = card.rarity
	return best
