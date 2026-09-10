class_name Campaign
extends RefCounted

# =========================================================
# THE CAMPAIGN - six zones, each with six encounters and a boss.
#
# Zones are a structured view over the existing linear floor system
# rather than a parallel progression: stage S of zone Z is simply
# floor (Z * STAGES_PER_ZONE + S + 1). That keeps one source of truth
# for difficulty scaling, unlocks, rewards, and save data, so a zone
# cannot drift out of sync with the floor it actually plays.
#
# Config.BOSS_EVERY equals STAGES_PER_ZONE, which is what makes the
# last stage of every zone a boss fight.
#
# Every zone also carries its own architecture description. The 3D zone
# world is generated entirely from these numbers - no imported models -
# so a new zone is a new entry in this table and nothing else.
# =========================================================

const STAGES_PER_ZONE := 7          # 6 encounters + 1 boss
const ENCOUNTERS_PER_ZONE := 6

# structure kinds understood by zone_world.gd:
#   "pillar"   broken columns, a ruined proving ground
#   "spire"    tall organic growths
#   "shard"    jagged volcanic glass
#   "battlement" squared-off fortress blocks
#   "arch"     cathedral arches
#   "crystal"  floating shattered geometry
const ZONES: Array[Dictionary] = [
	{
		"id": "proving",
		"name": "Ashen Proving Grounds",
		"subtitle": "Where every climber is measured.",
		"element": "Earth",
		"boss": "Golem Warlord",
		"names": ["Training Golem", "Rusted Automaton", "Stone Sentinel"],
		"roles": ["Tank", "DPS"],
		"accent": "#c08a4a",
		"ground": "#2b2620",
		"sky_top": "#1d2130",
		"sky_horizon": "#4a3f33",
		"fog": "#2a2419",
		"fog_density": 0.010,
		"structure": "pillar",
		"props": 14,
	},
	{
		"id": "hollow",
		"name": "Verdant Hollow",
		"subtitle": "The forest closed over this road a long time ago.",
		"element": "Wind",
		"boss": "Alpha Direwolf",
		"names": ["Feral Wolf", "Bandit Scout", "Marsh Lurker"],
		"roles": ["DPS", "Assassin", "Support"],
		"accent": "#3ac9a6",
		"ground": "#1b2b24",
		"sky_top": "#101f26",
		"sky_horizon": "#2c4a3c",
		"fog": "#16302a",
		"fog_density": 0.020,
		"structure": "spire",
		"props": 20,
	},
	{
		"id": "emberfall",
		"name": "Emberfall Reach",
		"subtitle": "The mountain has been burning for an age.",
		"element": "Fire",
		"boss": "Cinder Tyrant",
		"names": ["Ash Revenant", "Molten Husk", "Cinder Stalker"],
		"roles": ["DPS", "Tank", "Assassin"],
		"accent": "#e0532c",
		"ground": "#2c1712",
		"sky_top": "#2a0f10",
		"sky_horizon": "#7a2a14",
		"fog": "#3d1a10",
		"fog_density": 0.017,
		"structure": "shard",
		"props": 18,
	},
	{
		"id": "duskmire",
		"name": "Duskmire Bastion",
		"subtitle": "A fortress built by people with nothing left to lose.",
		"element": "Dark",
		"boss": "The Bandit Kingpin",
		"names": ["Bandit Raider", "Rogue Mercenary", "Cutthroat"],
		"roles": ["DPS", "Assassin", "Tank"],
		"accent": "#7a4ae0",
		"ground": "#1e1a2c",
		"sky_top": "#140f22",
		"sky_horizon": "#37265c",
		"fog": "#1d1733",
		"fog_density": 0.022,
		"structure": "battlement",
		"props": 16,
	},
	{
		"id": "choir",
		"name": "Choir of Silence",
		"subtitle": "The hymn never stopped. Nobody is left to sing it.",
		"element": "Light",
		"boss": "High Cultist Mordrai",
		"names": ["Dark Cultist", "Shadow Acolyte", "Void Priest"],
		"roles": ["DPS", "Healer", "Support"],
		"accent": "#e0c840",
		"ground": "#2a2820",
		"sky_top": "#232436",
		"sky_horizon": "#8a7a4a",
		"fog": "#33301f",
		"fog_density": 0.013,
		"structure": "arch",
		"props": 22,
	},
	{
		"id": "heart",
		"name": "The Tower's Heart",
		"subtitle": "Everything above was only the approach.",
		"element": "Dark",
		"boss": "The Tower's Heart",
		"names": ["Tower Wraith", "Voidbound Horror", "Nameless Sentinel"],
		"roles": ["Tank", "DPS", "Assassin"],
		"accent": "#ff2d95",
		"ground": "#16121f",
		"sky_top": "#07060d",
		"sky_horizon": "#2a1038",
		"fog": "#100a1a",
		"fog_density": 0.028,
		"structure": "crystal",
		"props": 24,
	},
]


static func zone_count() -> int:
	return ZONES.size()


static func total_floors() -> int:
	return ZONES.size() * STAGES_PER_ZONE


static func zone_at(zone_index: int) -> Dictionary:
	if zone_index < 0 or zone_index >= ZONES.size():
		return ZONES[0]
	return ZONES[zone_index]


# --- Floor <-> zone mapping -----------------------------------------

static func floor_for(zone_index: int, stage_index: int) -> int:
	return zone_index * STAGES_PER_ZONE + stage_index + 1


static func zone_index_for_floor(floor_number: int) -> int:
	var i := int((floor_number - 1) / float(STAGES_PER_ZONE))
	return clampi(i, 0, ZONES.size() - 1)


static func stage_index_for_floor(floor_number: int) -> int:
	return (floor_number - 1) % STAGES_PER_ZONE


static func zone_for_floor(floor_number: int) -> Dictionary:
	return zone_at(zone_index_for_floor(floor_number))


static func is_boss_stage(stage_index: int) -> bool:
	return stage_index == STAGES_PER_ZONE - 1


# --- Labels ----------------------------------------------------------

# The first word of a zone's name - what fits on a row of buttons.
static func short_name(zone: Dictionary) -> String:
	var parts := str(zone["name"]).split(" ", false)
	if parts.is_empty():
		return str(zone["name"])
	# "The Tower's Heart" reads better as "Heart" than as "The".
	if str(parts[0]).to_lower() == "the" and parts.size() > 1:
		return str(parts[parts.size() - 1])
	return str(parts[0])


static func zone_name_for_floor(floor_number: int) -> String:
	var zone := zone_for_floor(floor_number)
	return str(zone["name"])


# "Ashen Proving Grounds — Stage 3" / "— Boss"
static func stage_label(floor_number: int) -> String:
	var stage := stage_index_for_floor(floor_number)
	if is_boss_stage(stage):
		return "Boss"
	return "Stage %d" % (stage + 1)


static func accent_color(zone: Dictionary) -> Color:
	return Color(str(zone["accent"]))


# --- Progress ---------------------------------------------------------

# A zone opens once the previous zone's boss has fallen.
static func zone_unlocked(zone_index: int, highest_floor: int) -> bool:
	if zone_index <= 0:
		return true
	return highest_floor >= zone_index * STAGES_PER_ZONE


static func stages_cleared_in(zone_index: int, highest_floor: int) -> int:
	var first := zone_index * STAGES_PER_ZONE
	var cleared := highest_floor - first
	return clampi(cleared, 0, STAGES_PER_ZONE)


static func zone_complete(zone_index: int, highest_floor: int) -> bool:
	return stages_cleared_in(zone_index, highest_floor) >= STAGES_PER_ZONE
