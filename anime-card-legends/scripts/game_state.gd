extends Node

# =========================================================
# GAME STATE (autoload) - a thin coordinator, not a god object.
#
# Owns the wallet and drives the background loop. Everything else is
# delegated to a focused system:
#   collection  - owned cards, team, sell, merge
#   gacha       - card pool, pulls, bulk rolls
#   progression - talents, tower, roll packs
#   weather     - timed global events
#
# Screens read systems directly (GameState.collection.sorted(...)) and
# react to EventBus signals rather than polling.
# =========================================================

var collection: CollectionSystem
var gacha: GachaSystem
var progression: ProgressionSystem
var weather: WeatherSystem
var equipment: EquipmentSystem
var clan: ClanSystem
var chat: ChatSystem

var wallet := {"gems": Config.START_GEMS, "gold": Config.START_GOLD}
var active_slot := -1

var _roll_timer := 0.0
var _save_pending := false
var _save_cooldown := 0.0

const SAVE_DEBOUNCE := 1.5


func _ready() -> void:
	_build_systems()
	SaveManager.migrate_legacy()


func _build_systems() -> void:
	collection = CollectionSystem.new()
	progression = ProgressionSystem.new()
	weather = WeatherSystem.new()
	equipment = EquipmentSystem.new()
	clan = ClanSystem.new()
	chat = ChatSystem.new()
	gacha = GachaSystem.new(
		collection,
		func(): return effective_luck(),
		func(): return weather.boosted_element()
	)


# --- Save slots -----------------------------------------------------

# Loads an existing slot, or starts a fresh profile in it. Everything
# downstream (screens, battle, rolling) only runs once this has happened.
func open_slot(slot: int) -> void:
	active_slot = slot
	wallet = {"gems": Config.START_GEMS, "gold": Config.START_GOLD}
	_build_systems()

	if not SaveManager.load_into(slot, wallet, collection, progression, weather, gacha, equipment, clan, chat):
		_grant_starting_cards()
		save_now()

	if gacha.boss_pool_unlocked:
		gacha.unlock_boss_pool()

	_roll_timer = 0.0
	EventBus.currency_changed.emit(wallet["gems"], wallet["gold"])
	EventBus.collection_changed.emit()


func erase_slot(slot: int) -> bool:
	var removed := SaveManager.delete_slot(slot)
	if removed and slot == active_slot:
		close_slot()
	return removed


func close_slot() -> void:
	save_now()
	active_slot = -1
	_build_systems()


func has_active_slot() -> bool:
	return active_slot >= 1


func _process(delta: float) -> void:
	if not has_active_slot():
		return
	weather.update()
	_tick_clan(delta)
	_tick_chat(delta)
	_tick_auto_roll(delta)
	_tick_save(delta)


# ---------------- STARTING STATE ----------------

func _grant_starting_cards() -> void:
	var ids: Array[String] = []
	for template in CardLibrary.starter_templates(CollectionSystem.TEAM_SIZE):
		var card := collection.add(template)
		if card and ids.size() < CollectionSystem.TEAM_SIZE:
			ids.append(card.card_id)
	collection.set_team(ids)


# ---------------- CLAN ----------------

func _tick_clan(delta: float) -> void:
	if clan == null or not clan.founded:
		return
	var before := clan.level
	var activity := clan.update(delta)
	if activity != "":
		EventBus.clan_activity.emit(activity)
	if clan.level > before:
		EventBus.clan_level_changed.emit(clan.level)
		EventBus.toast("Clan reached level %d!" % clan.level, "success")
		request_save()


# The clan room talks among itself, and answers the player.
func _tick_chat(delta: float) -> void:
	if chat == null or clan == null or not clan.founded:
		return
	for entry in chat.update(delta, clan.members, _chat_context()):
		EventBus.chat_message.emit(
			str(entry["author"]), str(entry["text"]), bool(entry["player"]))


# What the roster is allowed to talk about: real state only.
func _chat_context() -> Dictionary:
	var newest := ""
	var owned := collection.get_all()
	if not owned.is_empty():
		newest = owned[owned.size() - 1].card_name

	var boss := ""
	if clan.raid_active:
		boss = clan.raid_boss

	return {
		"raid_boss": boss,
		"clan_level": clan.level,
		"newest_card": newest,
	}


func send_chat(text: String) -> void:
	if chat == null or clan == null or not clan.founded:
		return
	var entry := chat.send(text, clan.members)
	if entry.is_empty():
		return
	EventBus.chat_message.emit(
		str(entry["author"]), str(entry["text"]), true)
	request_save()


# Clan XP earned by the player. Routed through here so every source
# credits the player's own contribution total.
func credit_clan(amount: int) -> void:
	if clan == null or not clan.founded or amount <= 0:
		return
	var before := clan.level
	clan.contribute(amount, true)
	if clan.level > before:
		EventBus.clan_level_changed.emit(clan.level)
		EventBus.toast("Clan reached level %d!" % clan.level, "success")


func clan_perk(perk_id: String) -> float:
	if clan == null or not clan.founded:
		return 0.0
	return clan.perk_value(perk_id)


# ---------------- BACKGROUND ROLLING ----------------

func _tick_auto_roll(delta: float) -> void:
	_roll_timer += delta
	var interval := effective_roll_interval()
	if _roll_timer < interval:
		return

	_roll_timer -= interval
	var pulled := gacha.pull_many(progression.rolls_per_tick())
	if pulled.is_empty():
		return

	EventBus.auto_rolled.emit(pulled)
	request_save()


func effective_luck() -> float:
	return (progression.luck_bonus() + clan_perk("luck")) * weather.luck_multiplier()


# The clan's roll-speed perk shortens the gap between auto-rolls.
func effective_roll_interval() -> float:
	var interval := progression.roll_interval()
	return maxf(Config.ROLL_INTERVAL_MIN, interval * (1.0 - clan_perk("speed")))


# ---------------- WALLET ----------------

var gems: int:
	get: return wallet["gems"]
var gold: int:
	get: return wallet["gold"]


func spend_gems(amount: int) -> bool:
	if wallet["gems"] < amount:
		return false
	wallet["gems"] -= amount
	_announce_currency()
	return true


func spend_gold(amount: int) -> bool:
	if wallet["gold"] < amount:
		return false
	wallet["gold"] -= amount
	_announce_currency()
	return true


func add_gems(amount: int) -> void:
	wallet["gems"] += amount
	_announce_currency()


func add_gold(amount: int) -> void:
	wallet["gold"] += amount
	_announce_currency()


func _announce_currency() -> void:
	EventBus.currency_changed.emit(wallet["gems"], wallet["gold"])
	request_save()


# ---------------- ACTIONS (cross-system operations) ----------------

func summon(count: int, origin: String = "") -> Array[CardData]:
	var cost := Config.SUMMON_COST_X10
	if count == 1:
		cost = Config.SUMMON_COST_X1
	if not spend_gems(cost):
		EventBus.toast("Not enough gems — you need " + Fmt.commas(cost) + ".", "error")
		return []

	var pulled := gacha.pull_many(count, origin)
	credit_clan(pulled.size() * 5)
	request_save()
	return pulled


func sell_card(card_id: String) -> int:
	var earned := collection.sell(card_id)
	if earned > 0:
		add_gold(earned)
		EventBus.toast("Sold for " + Fmt.commas(earned) + " gold.", "success")
	return earned


func merge_card(card_id: String) -> bool:
	if not collection.can_merge(card_id):
		return false
	var card: CardData = collection.owned[card_id]
	var new_rarity := Config.next_rarity(card.rarity)
	var ok := collection.merge(card_id)
	if ok:
		EventBus.toast(card.card_name + " ascended to " + new_rarity + "!", "success")
		request_save()
	return ok


func craft_item(item_id: String) -> bool:
	if not equipment.craft(collection, item_id):
		EventBus.toast("Not enough spare cards of the required rarity.", "error")
		return false
	var recipe := EquipmentSystem.recipe(item_id)
	EventBus.toast(str(recipe.get("name", "Item")) + " crafted!", "success")
	request_save()
	return true


func equip_item(item_id: String) -> void:
	if equipment.equip(item_id):
		request_save()


func unequip_slot(slot: String) -> void:
	equipment.unequip(slot)
	request_save()


# The team as it fights: stored cards with equipment bonuses layered on.
func get_battle_team() -> Array[CardData]:
	var team: Array[CardData] = []
	for card in collection.get_team():
		team.append(equipment.apply_to(card))
	return team


func upgrade_talent(talent: String) -> bool:
	if progression.is_maxed(talent):
		return false
	var cost := progression.cost(talent)
	if not spend_gold(cost):
		EventBus.toast("Not enough gold — you need " + Fmt.commas(cost) + ".", "error")
		return false
	progression.apply_upgrade(talent)
	request_save()
	return true


func use_roll_pack(pack_id: String) -> Dictionary:
	if not progression.consume_pack(pack_id):
		return {}
	var rolls: int = Config.ROLL_PACKS[pack_id]["rolls"]
	var summary := gacha.bulk(rolls)
	request_save()
	return summary


func clear_floor(floor_number: int) -> Dictionary:
	var rewards := progression.clear_floor(floor_number)

	# Clan perks are applied to the payout, so the numbers the result
	# screen shows are the numbers actually banked.
	rewards["gems"] = int(round(float(rewards["gems"]) * (1.0 + clan_perk("gems"))))
	rewards["gold"] = int(round(float(rewards["gold"]) * (1.0 + clan_perk("gold"))))

	add_gems(rewards["gems"])
	add_gold(rewards["gold"])
	credit_clan(30 + floor_number * 6)

	if progression.is_boss_floor(floor_number):
		gacha.unlock_boss_pool()
	save_now()
	return rewards


# ---------------- SAVING ----------------

# Debounced so bursts of rolls don't hit the disk every frame.
func request_save() -> void:
	_save_pending = true


func _tick_save(delta: float) -> void:
	if not _save_pending:
		return
	_save_cooldown += delta
	if _save_cooldown >= SAVE_DEBOUNCE:
		_save_cooldown = 0.0
		_save_pending = false
		save_now()


func save_now() -> void:
	if not has_active_slot():
		return
	SaveManager.save(active_slot, wallet, collection, progression, weather, gacha, equipment, clan, chat)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()
