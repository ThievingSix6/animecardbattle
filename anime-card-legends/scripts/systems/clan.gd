class_name ClanSystem
extends RefCounted

# =========================================================
# CLANS - a roster of AI players the account belongs to.
#
# The members are generated once from a stored seed, so the same clan
# rebuilds identically from a save file rather than reshuffling every
# launch. They stay active while the game runs: contributions tick up
# and raid damage accrues, so the roster reads as a living group rather
# than a static list.
#
# Everything the clan grants flows back through systems that already
# exist - luck, gold, roll speed - rather than inventing a parallel
# economy.
# =========================================================

const MIN_MEMBERS := 8
const MAX_MEMBERS := 24

const RANK_LEADER := "Leader"
const RANK_OFFICER := "Officer"
const RANK_MEMBER := "Member"

const MAX_LEVEL := 10
const XP_BASE := 500
const XP_GROWTH := 1.55

# How often the AI roster does something, in seconds of real time.
const AI_TICK := 6.0

# What each clan level unlocks. Read by GameState rather than applied
# here, so the clan never mutates another system's state directly.
const PERKS: Array[Dictionary] = [
	{"level": 2, "id": "gold",  "value": 0.10, "label": "+10% gold from stages"},
	{"level": 3, "id": "luck",  "value": 0.15, "label": "+15% luck on every pull"},
	{"level": 4, "id": "speed", "value": 0.10, "label": "Auto-rolls arrive 10% faster"},
	{"level": 5, "id": "gems",  "value": 0.10, "label": "+10% gems from stages"},
	{"level": 6, "id": "luck",  "value": 0.20, "label": "+20% luck on every pull"},
	{"level": 7, "id": "gold",  "value": 0.20, "label": "+20% gold from stages"},
	{"level": 8, "id": "speed", "value": 0.20, "label": "Auto-rolls arrive 20% faster"},
	{"level": 9, "id": "gems",  "value": 0.25, "label": "+25% gems from stages"},
	{"level": 10, "id": "luck", "value": 0.35, "label": "+35% luck on every pull"},
]

const RAID_BOSSES: Array[String] = [
	"Gilded Leviathan", "The Sunless Choir", "Warden of Endings",
	"Thousandfold Serpent", "The Last Archivist", "Hollow Empress",
]

var founded := false
var clan_name := ""
var clan_tag := ""
var member_seed := 0
var level := 1
var xp := 0

# Each entry: username, rank, power, weekly, total, trophies
var members: Array[Dictionary] = []

var player_weekly := 0
var player_total := 0

var raid_active := false
var raid_boss := ""
var raid_max_hp := 0
var raid_hp := 0
var raid_player_damage := 0

var _tick_timer := 0.0


# --- Founding ----------------------------------------------------------

func found(chosen_name: String = "") -> void:
	member_seed = int(Time.get_unix_time_from_system()) ^ (randi() & 0xFFFFFF)
	clan_name = chosen_name
	if clan_name == "":
		clan_name = Usernames.clan_name()
	clan_tag = Usernames.clan_tag(clan_name)
	founded = true
	level = 1
	xp = 0
	player_weekly = 0
	player_total = 0
	rebuild_members()


# Members are derived from the seed, so a save only has to store the
# seed and the contribution numbers.
func rebuild_members() -> void:
	members.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = member_seed

	var count := MIN_MEMBERS + rng.randi() % (MAX_MEMBERS - MIN_MEMBERS + 1)
	var handles := Usernames.generate_many(count, rng)

	for i in handles.size():
		var rank := RANK_MEMBER
		if i < 3:
			rank = RANK_OFFICER
		members.append({
			"username": handles[i],
			"rank": rank,
			"power": 1000 + rng.randi() % 48000,
			"weekly": rng.randi() % 900,
			"total": rng.randi() % 40000,
			"trophies": rng.randi() % 3200,
		})


# --- Level and XP -------------------------------------------------------

func xp_for_level(target_level: int) -> int:
	if target_level <= 1:
		return 0
	return int(round(float(XP_BASE) * pow(XP_GROWTH, float(target_level - 2))))


func xp_to_next() -> int:
	if level >= MAX_LEVEL:
		return 0
	return xp_for_level(level + 1)


func level_progress() -> float:
	var needed := xp_to_next()
	if needed <= 0:
		return 1.0
	return clamp(float(xp) / float(needed), 0.0, 1.0)


# Adds clan XP and levels up as far as the total allows.
func contribute(amount: int, from_player: bool) -> int:
	if not founded or amount <= 0:
		return 0

	xp += amount
	if from_player:
		player_weekly += amount
		player_total += amount

	var gained := 0
	while level < MAX_LEVEL and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1

	return gained


# --- Perks ---------------------------------------------------------------

# Total value of every perk of this kind the clan has unlocked. Higher
# tiers replace lower ones rather than stacking, so the numbers on the
# clan screen are the numbers that apply.
func perk_value(perk_id: String) -> float:
	var best := 0.0
	for perk in PERKS:
		if perk["id"] != perk_id:
			continue
		if level < int(perk["level"]):
			continue
		best = max(best, float(perk["value"]))
	return best


func unlocked_perks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for perk in PERKS:
		if level >= int(perk["level"]):
			out.append(perk)
	return out


func next_perk() -> Dictionary:
	for perk in PERKS:
		if level < int(perk["level"]):
			return perk
	return {}


# --- Roster ---------------------------------------------------------------

func member_count() -> int:
	return members.size() + 1     # the player is a member too


func total_power() -> int:
	var total := 0
	for member in members:
		total += int(member["power"])
	return total


func weekly_total() -> int:
	var total := player_weekly
	for member in members:
		total += int(member["weekly"])
	return total


# The roster sorted for display, with the player folded in so their rank
# among the AI members is honest.
func leaderboard(player_power: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for member in members:
		rows.append(member.duplicate())

	rows.append({
		"username": "You",
		"rank": RANK_LEADER,
		"power": player_power,
		"weekly": player_weekly,
		"total": player_total,
		"trophies": 0,
		"is_player": true,
	})

	rows.sort_custom(func(a, b): return int(a["weekly"]) > int(b["weekly"]))
	return rows


# --- Raids -----------------------------------------------------------------

func start_raid() -> void:
	if raid_active or not founded:
		return
	raid_boss = RAID_BOSSES[randi() % RAID_BOSSES.size()]
	raid_max_hp = 40000 * level + 60000
	raid_hp = raid_max_hp
	raid_player_damage = 0
	raid_active = true


func raid_progress() -> float:
	if raid_max_hp <= 0:
		return 0.0
	return clamp(1.0 - float(raid_hp) / float(raid_max_hp), 0.0, 1.0)


# Returns true when this damage finished the boss off.
func damage_raid(amount: int, from_player: bool) -> bool:
	if not raid_active or amount <= 0:
		return false

	raid_hp = max(0, raid_hp - amount)
	if from_player:
		raid_player_damage += amount

	if raid_hp > 0:
		return false

	raid_active = false
	return true


# Share of the boss the player personally took down.
func raid_player_share() -> float:
	if raid_max_hp <= 0:
		return 0.0
	return clamp(float(raid_player_damage) / float(raid_max_hp), 0.0, 1.0)


# --- Background activity ------------------------------------------------------

# Advances the AI roster. Returns a description of anything worth showing
# the player, or "" when nothing happened this tick.
func update(delta: float) -> String:
	if not founded or members.is_empty():
		return ""

	_tick_timer += delta
	if _tick_timer < AI_TICK:
		return ""
	_tick_timer = 0.0

	var member: Dictionary = members[randi() % members.size()]
	var gain := 20 + randi() % 220
	member["weekly"] = int(member["weekly"]) + gain
	member["total"] = int(member["total"]) + gain
	contribute(gain, false)

	if raid_active:
		var hit := 400 + randi() % (900 * level)
		damage_raid(hit, false)
		return "%s hit %s for %s" % [
			str(member["username"]), raid_boss, Fmt.compact(hit)]

	return "%s contributed %s" % [str(member["username"]), Fmt.compact(gain)]


# --- Serialization -------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"founded": founded,
		"name": clan_name,
		"tag": clan_tag,
		"seed": member_seed,
		"level": level,
		"xp": xp,
		"player_weekly": player_weekly,
		"player_total": player_total,
		"members": members,
		"raid_active": raid_active,
		"raid_boss": raid_boss,
		"raid_max_hp": raid_max_hp,
		"raid_hp": raid_hp,
		"raid_player_damage": raid_player_damage,
	}


func from_dict(data: Dictionary) -> void:
	founded = bool(data.get("founded", false))
	if not founded:
		return

	clan_name = str(data.get("name", ""))
	clan_tag = str(data.get("tag", ""))
	member_seed = int(data.get("seed", 0))
	level = clamp(int(data.get("level", 1)), 1, MAX_LEVEL)
	xp = int(data.get("xp", 0))
	player_weekly = int(data.get("player_weekly", 0))
	player_total = int(data.get("player_total", 0))

	raid_active = bool(data.get("raid_active", false))
	raid_boss = str(data.get("raid_boss", ""))
	raid_max_hp = int(data.get("raid_max_hp", 0))
	raid_hp = int(data.get("raid_hp", 0))
	raid_player_damage = int(data.get("raid_player_damage", 0))

	var stored = data.get("members", [])
	members.clear()
	if typeof(stored) == TYPE_ARRAY and not stored.is_empty():
		for entry in stored:
			if typeof(entry) == TYPE_DICTIONARY:
				members.append(entry)
	else:
		# An older save, or one written before the roster existed.
		rebuild_members()
