class_name EquipmentSystem
extends RefCounted

# =========================================================
# Paperdoll gear. Items occupy slots and grant percentage stat bonuses
# to the whole team. They are crafted by consuming duplicate cards of a
# required rarity, which gives the endless duplicate pile a purpose.
# =========================================================

const SLOTS: Array[String] = ["Amulet", "Ring I", "Ring II", "Charm", "Relic"]

const STATS: Array[String] = ["attack", "defense", "health", "speed"]

# Each recipe burns `cost` copies of cards at `rarity` or better.
const RECIPES: Array[Dictionary] = [
	{"id": "band_of_embers",   "name": "Band of Embers",    "slot": "Ring I",  "rarity": "Rare",      "cost": 25, "bonus": {"attack": 0.08}},
	{"id": "band_of_stone",    "name": "Band of Stone",     "slot": "Ring II", "rarity": "Rare",      "cost": 25, "bonus": {"defense": 0.10, "health": 0.05}},
	{"id": "sighted_charm",    "name": "Sighted Charm",     "slot": "Charm",   "rarity": "Epic",      "cost": 15, "bonus": {"speed": 0.10, "attack": 0.04}},
	{"id": "heartstone",       "name": "Heartstone Amulet", "slot": "Amulet",  "rarity": "Epic",      "cost": 15, "bonus": {"health": 0.15}},
	{"id": "warlords_signet",  "name": "Warlord's Signet",  "slot": "Ring I",  "rarity": "Legendary", "cost": 8, "bonus": {"attack": 0.20, "defense": 0.05}},
	{"id": "aegis_pendant",    "name": "Aegis Pendant",     "slot": "Amulet",  "rarity": "Legendary", "cost": 8, "bonus": {"defense": 0.22, "health": 0.12}},
	{"id": "mythbound_relic",  "name": "Mythbound Relic",   "slot": "Relic",   "rarity": "Mythic",    "cost": 3, "bonus": {"attack": 0.25, "defense": 0.25, "health": 0.25, "speed": 0.15}},
	{"id": "crown_of_ruin",    "name": "Crown of Ruin",     "slot": "Relic",   "rarity": "Secret",    "cost": 1, "bonus": {"attack": 0.60, "health": 0.40, "speed": 0.25}},
]

# item_id -> how many the player owns
var owned: Dictionary = {}
# slot -> item_id
var equipped: Dictionary = {}


static func recipe(item_id: String) -> Dictionary:
	for r in RECIPES:
		if r["id"] == item_id:
			return r
	return {}


static func bonus_text(item_id: String) -> String:
	var r := recipe(item_id)
	if r.is_empty():
		return ""
	var parts: Array[String] = []
	var bonus: Dictionary = r["bonus"]
	for stat in STATS:
		if bonus.has(stat):
			var pct: float = bonus[stat]
			parts.append("+%d%% %s" % [int(round(pct * 100.0)), stat.to_upper()])
	return "  ".join(parts)


func count(item_id: String) -> int:
	return owned.get(item_id, 0)


func is_equipped(item_id: String) -> bool:
	for slot in equipped.keys():
		if equipped[slot] == item_id:
			return true
	return false


func item_in(slot: String) -> String:
	return str(equipped.get(slot, ""))


func equip(item_id: String) -> bool:
	var r := recipe(item_id)
	if r.is_empty() or count(item_id) <= 0:
		return false
	equipped[str(r["slot"])] = item_id
	return true


func unequip(slot: String) -> void:
	equipped.erase(slot)


# --- Crafting -------------------------------------------------------

# How many eligible duplicate copies the player has for a recipe. Only
# spare copies count, so a card never disappears out of a team.
func craftable_material(collection: CollectionSystem, rarity: String) -> int:
	var needed := Config.rarity_index(rarity)
	var total := 0
	for card in collection.owned.values():
		if Config.rarity_index(card.rarity) < needed:
			continue
		total += collection.duplicate_count(card.card_id)
	return total


func can_craft(collection: CollectionSystem, item_id: String) -> bool:
	var r := recipe(item_id)
	if r.is_empty():
		return false
	return craftable_material(collection, str(r["rarity"])) >= int(r["cost"])


func craft(collection: CollectionSystem, item_id: String) -> bool:
	var r := recipe(item_id)
	if r.is_empty() or not can_craft(collection, item_id):
		return false

	var remaining := int(r["cost"])
	var needed: int = Config.rarity_index(str(r["rarity"]))

	# Burn the least valuable eligible duplicates first.
	var ids: Array[String] = []
	for card in collection.owned.values():
		if Config.rarity_index(card.rarity) >= needed:
			ids.append(card.card_id)
	ids.sort_custom(func(a, b):
		var ca: CardData = collection.owned[a]
		var cb: CardData = collection.owned[b]
		return Config.rarity_index(ca.rarity) < Config.rarity_index(cb.rarity))

	for id in ids:
		if remaining <= 0:
			break
		var spare: int = collection.duplicate_count(id)
		var take: int = min(spare, remaining)
		if take <= 0:
			continue
		collection.duplicates[id] = spare - take
		remaining -= take

	owned[item_id] = count(item_id) + 1
	EventBus.collection_changed.emit()
	return true


# --- Bonuses --------------------------------------------------------

# Aggregate multipliers from everything currently equipped.
func total_bonuses() -> Dictionary:
	var totals := {"attack": 0.0, "defense": 0.0, "health": 0.0, "speed": 0.0}
	for slot in equipped.keys():
		var r := recipe(str(equipped[slot]))
		if r.is_empty():
			continue
		var bonus: Dictionary = r["bonus"]
		for stat in STATS:
			if bonus.has(stat):
				totals[stat] += float(bonus[stat])
	return totals


# Returns a stat-boosted copy so the player's stored card is untouched.
func apply_to(card: CardData) -> CardData:
	var totals := total_bonuses()
	var boosted: CardData = card.duplicate()
	boosted.attack = int(round(card.attack * (1.0 + totals["attack"])))
	boosted.defense = int(round(card.defense * (1.0 + totals["defense"])))
	boosted.health = int(round(card.health * (1.0 + totals["health"])))
	boosted.speed = int(round(card.speed * (1.0 + totals["speed"])))
	return boosted


func has_any_bonus() -> bool:
	for value in total_bonuses().values():
		if value > 0.0:
			return true
	return false
