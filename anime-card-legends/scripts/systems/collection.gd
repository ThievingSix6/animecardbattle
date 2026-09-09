class_name CollectionSystem
extends RefCounted

# =========================================================
# Owns the player's cards and their team. Knows nothing about
# rolling, currency sources, or UI.
# =========================================================

const TEAM_SIZE := 5

var owned: Dictionary = {}        # card_id -> CardData
var duplicates: Dictionary = {}   # card_id -> extra copies beyond the first
var team_ids: Array[String] = []


func add(template: CardData, copies: int = 1) -> CardData:
	if copies <= 0:
		return null

	var is_new := not owned.has(template.card_id)

	if is_new:
		var copy: CardData = template.duplicate()
		copy.obtained = true
		owned[copy.card_id] = copy
		if copies > 1:
			duplicates[copy.card_id] = copies - 1
	else:
		duplicates[template.card_id] = duplicates.get(template.card_id, 0) + copies

	EventBus.card_acquired.emit(owned[template.card_id], is_new)
	return owned[template.card_id]


func get_all() -> Array[CardData]:
	var list: Array[CardData] = []
	for c in owned.values():
		list.append(c)
	return list


func has(card_id: String) -> bool:
	return owned.has(card_id)


func copies_of(card_id: String) -> int:
	var base := 0
	if owned.has(card_id):
		base = 1
	return duplicates.get(card_id, 0) + base


func duplicate_count(card_id: String) -> int:
	return duplicates.get(card_id, 0)


func unique_count() -> int:
	return owned.size()


# ---------------- SELL ----------------

# Sells one copy: a duplicate if any exist, otherwise the last copy
# (which also drops it from the team). Returns gold earned.
func sell(card_id: String) -> int:
	if not owned.has(card_id):
		return 0

	var card: CardData = owned[card_id]
	var value: int = card.sell_value

	if duplicates.get(card_id, 0) > 0:
		duplicates[card_id] -= 1
	else:
		owned.erase(card_id)
		duplicates.erase(card_id)
		team_ids.erase(card_id)

	EventBus.collection_changed.emit()
	return value


# ---------------- MERGE ----------------

func can_merge(card_id: String) -> bool:
	if not owned.has(card_id):
		return false
	if Config.next_rarity(owned[card_id].rarity) == "":
		return false
	return copies_of(card_id) >= Config.MERGE_REQUIREMENT


func merge(card_id: String) -> bool:
	if not can_merge(card_id):
		return false

	var card: CardData = owned[card_id]
	duplicates[card_id] = duplicates.get(card_id, 0) - (Config.MERGE_REQUIREMENT - 1)

	card.rarity = Config.next_rarity(card.rarity)
	card.attack = int(round(card.attack * Config.MERGE_STAT_GROWTH))
	card.defense = int(round(card.defense * Config.MERGE_STAT_GROWTH))
	card.health = int(round(card.health * Config.MERGE_STAT_GROWTH))
	card.speed = int(round(card.speed * Config.MERGE_SPEED_GROWTH))
	card.sell_value = int(round(card.sell_value * Config.MERGE_SELL_GROWTH))

	EventBus.collection_changed.emit()
	return true


# ---------------- TEAM ----------------

func get_team() -> Array[CardData]:
	var team: Array[CardData] = []
	for id in team_ids:
		if owned.has(id):
			team.append(owned[id])

	# Fall back to the first few owned cards so battle is never empty.
	if team.is_empty():
		var all := get_all()
		for i in min(TEAM_SIZE, all.size()):
			team.append(all[i])

	return team


func set_team(ids: Array) -> void:
	team_ids.clear()
	for id in ids:
		team_ids.append(str(id))
	EventBus.team_changed.emit()


func in_team(card_id: String) -> bool:
	return team_ids.has(card_id)


# ---------------- SORTING ----------------

const SORTS: Array[Dictionary] = [
	{"label": "Rarity",     "key": "rarity"},
	{"label": "Attack",     "key": "attack"},
	{"label": "Defense",    "key": "defense"},
	{"label": "Health",     "key": "health"},
	{"label": "Speed",      "key": "speed"},
	{"label": "Copies",     "key": "copies"},
	{"label": "Name (A-Z)", "key": "name"},
]


func sorted(key: String) -> Array[CardData]:
	var list := get_all()
	match key:
		"rarity":
			list.sort_custom(func(a, b):
				var ra := Config.rarity_index(a.rarity)
				var rb := Config.rarity_index(b.rarity)
				if ra != rb:
					return ra > rb
				return a.attack > b.attack)
		"name":
			list.sort_custom(func(a, b): return a.card_name.naturalnocasecmp_to(b.card_name) < 0)
		"copies":
			list.sort_custom(func(a, b): return copies_of(a.card_id) > copies_of(b.card_id))
		_:
			list.sort_custom(func(a, b): return a.get(key) > b.get(key))
	return list
