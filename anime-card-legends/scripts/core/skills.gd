class_name Skills
extends RefCounted

# =========================================================
# THE SKILL LIBRARY - 100 passives across nine effect families.
#
# This file is DATA ONLY: id, display name, family, and the description
# shown on the card. The behaviour lives in SkillEffects, which matches
# on the id at each hook point. Keeping them apart means a designer can
# read the whole roster here without wading through combat code.
#
# ---------------------------------------------------------------------
# TRANSLATION NOTES
#
# The designs are written for a real-time auto-battler; combat here
# resolves in discrete turns. Rather than rewrite the engine (every
# balance number in Config assumes turns), each real-time concept maps
# onto its turn-based equivalent:
#
#   "N seconds"      -> turns(N), one turn per two seconds
#   "attack speed"   -> energy_rate, how fast the ultimate charges
#   "movement speed" -> speed, which decides turn order
#   "armor"          -> defense
#   "ability charge" -> energy
#   "nearby enemies" -> every living enemy
#   "adjacent ally"  -> the next living ally in the lane
#   "displacement"   -> not modelled; those skills grant the closest
#                       equivalent (stun resistance) instead
#
# Every description states what the simulation actually does, in turns.
# If a skill's behaviour changes, its text has to change with it.
# =========================================================

const SECONDS_PER_TURN := 2.0

const FAMILIES: Array[String] = [
	"defense", "offense", "element", "death",
	"summon", "support", "control", "risk", "legendary",
]

const FAMILY_LABEL := {
	"defense": "Defense", "offense": "Offense", "element": "Element",
	"death": "Death", "summon": "Summon", "support": "Support",
	"control": "Control", "risk": "Risk", "legendary": "Legendary",
}

const FAMILY_ICON := {
	"defense": "\u{1F6E1}", "offense": "\u2694", "element": "\u{1F525}",
	"death": "\u2620", "summon": "\u{1F479}", "support": "\u2764",
	"control": "\u{1F9E0}", "risk": "\u{1FA78}", "legendary": "\u{1F451}",
}

const FAMILY_COLOR := {
	"defense": "#3ecf7e", "offense": "#ef4444", "element": "#e0532c",
	"death": "#7a4ae0", "summon": "#8a6a42", "support": "#3b82f6",
	"control": "#3ac9a6", "risk": "#f5c518", "legendary": "#ff2d95",
}

# Families a role naturally draws from, so a Tank feels like a Tank.
const ROLE_FAMILIES := {
	"Tank": ["defense", "defense", "control", "death"],
	"DPS": ["offense", "offense", "element", "risk"],
	"Assassin": ["offense", "risk", "control", "element"],
	"Healer": ["support", "support", "defense", "death"],
	"Support": ["support", "control", "summon", "death"],
}

# Chance a card that qualifies rolls a build-defining legendary skill.
const LEGENDARY_SKILL_CHANCE := 0.4

const ALL: Array[Dictionary] = [
	{"id": "ironhide", "name": "Ironhide", "family": "defense", "text": "20% chance to block an attack outright. After 3 blocks, gain 30% damage reduction for 2 turns."},
	{"id": "last_stand", "name": "Last Stand", "family": "defense", "text": "The first lethal blow leaves this card at 1 HP and grants 25% faster ultimate charge for 3 turns."},
	{"id": "gravebound", "name": "Gravebound", "family": "defense", "text": "Falling below 20% HP grants a shield worth 12% of max HP. Once per battle."},
	{"id": "stoneheart", "name": "Stoneheart", "family": "defense", "text": "Every 5th attack against this card deals 40% less damage."},
	{"id": "second_wind", "name": "Second Wind", "family": "defense", "text": "Falling below 35% HP restores 10% max HP and grants 15% speed for 2 turns. Once per battle."},
	{"id": "thornmail", "name": "Thornmail", "family": "defense", "text": "15% chance to block an attack outright and return 20% of this card's attack to the attacker."},
	{"id": "bloodguard", "name": "Bloodguard", "family": "defense", "text": "Below 50% HP, gain 10% lifesteal for the rest of the battle."},
	{"id": "unbroken", "name": "Unbroken", "family": "defense", "text": "Cannot be stunned more than once every 4 turns."},
	{"id": "guardians_oath", "name": "Guardian's Oath", "family": "defense", "text": "While this card lives, the lowest-HP ally takes 15% less damage."},
	{"id": "fading_shield", "name": "Fading Shield", "family": "defense", "text": "On entry, gain a shield worth 15% of max HP. It fades after 3 turns."},
	{"id": "bulwark", "name": "Bulwark", "family": "defense", "text": "Every 3rd hit received grants 5% defense, stacking up to 3 times."},
	{"id": "death_denied", "name": "Death Denied", "family": "defense", "text": "Once per battle, a lethal blow instead leaves this card at 5% HP."},
	{"id": "heavy_soul", "name": "Heavy Soul", "family": "defense", "text": "Immune to stun, but the ultimate charges 8% slower."},
	{"id": "mirror_guard", "name": "Mirror Guard", "family": "defense", "text": "15% chance to reflect half of an incoming attack back at the attacker."},
	{"id": "undying_ember", "name": "Undying Ember", "family": "defense", "text": "On death, burn the whole enemy team for 10% of this card's max HP over 2 turns."},
	{"id": "executioners_mark", "name": "Executioner's Mark", "family": "offense", "text": "Attacks against enemies below 25% HP deal 25% bonus damage."},
	{"id": "blood_rush", "name": "Blood Rush", "family": "offense", "text": "Each consecutive attack on the same enemy deals 5% more damage, up to 20%."},
	{"id": "third_strike", "name": "Third Strike", "family": "offense", "text": "Every 3rd attack deals 75% bonus damage."},
	{"id": "crushing_blow", "name": "Crushing Blow", "family": "offense", "text": "12% chance to deal 150% damage and stun the target for a turn."},
	{"id": "momentum", "name": "Momentum", "family": "offense", "text": "Killing an enemy grants 15% faster ultimate charge for 3 turns."},
	{"id": "predator", "name": "Predator", "family": "offense", "text": "Deals 20% bonus damage to enemies with more current HP than this card."},
	{"id": "backstab", "name": "Backstab", "family": "offense", "text": "Deals 25% bonus damage to enemies that are not the active fighter."},
	{"id": "overcharge", "name": "Overcharge", "family": "offense", "text": "Every 8th attack deals 200% damage but costs 3% of max HP."},
	{"id": "rend", "name": "Rend", "family": "offense", "text": "Every 4th attack bleeds the target for 3% of its max HP over 2 turns."},
	{"id": "bonebreaker", "name": "Bonebreaker", "family": "offense", "text": "Every 5th attack strips 8% defense from the target for 2 turns."},
	{"id": "wild_swing", "name": "Wild Swing", "family": "offense", "text": "10% chance to also strike a second enemy for half damage."},
	{"id": "bloodied_blade", "name": "Bloodied Blade", "family": "offense", "text": "Deals 10% more damage while below 50% HP."},
	{"id": "marked_prey", "name": "Marked Prey", "family": "offense", "text": "The first enemy attacked is marked; this card deals 15% bonus damage to it."},
	{"id": "reckless_fury", "name": "Reckless Fury", "family": "offense", "text": "Ultimate charges 20% faster, but this card takes 10% more damage."},
	{"id": "finisher", "name": "Finisher", "family": "offense", "text": "Attacks against enemies below 15% HP deal 50% bonus damage."},
	{"id": "cinderbrand", "name": "Cinderbrand", "family": "element", "text": "20% chance to burn the target for 3% of this card's attack per turn, for 2 turns."},
	{"id": "ashen_touch", "name": "Ashen Touch", "family": "element", "text": "Every 3rd attack burns the target. Burning enemies deal 5% less damage."},
	{"id": "kindled_rage", "name": "Kindled Rage", "family": "element", "text": "Gain 4% ultimate charge rate per burning enemy, up to 12%."},
	{"id": "scorching_death", "name": "Scorching Death", "family": "element", "text": "On death, burn the killer for 8% of this card's max HP over 3 turns."},
	{"id": "ember_chain", "name": "Ember Chain", "family": "element", "text": "When a burning enemy dies, the burn jumps to another enemy at 60% strength."},
	{"id": "firebrand", "name": "Firebrand", "family": "element", "text": "Attacks that roll a critical apply a strong burn for 2 turns."},
	{"id": "smoldering_armor", "name": "Smoldering Armor", "family": "element", "text": "Attackers have a 15% chance to catch fire for 2 turns."},
	{"id": "inferno_pulse", "name": "Inferno Pulse", "family": "element", "text": "Every 5 turns, scorch every enemy and burn them for a turn."},
	{"id": "blackened_wound", "name": "Blackened Wound", "family": "element", "text": "Burning enemies receive 8% less healing."},
	{"id": "funeral_flame", "name": "Funeral Flame", "family": "element", "text": "When a burning enemy dies, every other enemy takes 5% of its max HP as fire damage."},
	{"id": "grave_gift", "name": "Grave Gift", "family": "death", "text": "On death, restore 8% max HP to the lowest-HP ally."},
	{"id": "dead_mans_hand", "name": "Dead Man's Hand", "family": "death", "text": "On death, the killer's ultimate charges 10% slower for 3 turns."},
	{"id": "final_offering", "name": "Final Offering", "family": "death", "text": "On death, the next ally gains 15% attack for 3 turns."},
	{"id": "corpsewalker", "name": "Corpsewalker", "family": "death", "text": "Each allied death grants 5% faster ultimate charge, stacking twice."},
	{"id": "soul_shard", "name": "Soul Shard", "family": "death", "text": "On death, the next ally to enter combat gains 10% max HP as a shield."},
	{"id": "blood_pact", "name": "Blood Pact", "family": "death", "text": "On entry, spend 5% max HP to grant the strongest ally 8% attack."},
	{"id": "martyr", "name": "Martyr", "family": "death", "text": "Takes 40% of the damage aimed at the lowest-HP ally."},
	{"id": "rotting_curse", "name": "Rotting Curse", "family": "death", "text": "On death, the killer receives 20% less healing for 3 turns."},
	{"id": "death_echo", "name": "Death Echo", "family": "death", "text": "On death, strike the active enemy once more for 50% of this card's attack."},
	{"id": "grim_inheritance", "name": "Grim Inheritance", "family": "death", "text": "On death, pass this card's remaining buffs to the next ally."},
	{"id": "broodmother", "name": "Broodmother", "family": "summon", "text": "On entry, summon 2 broodlings with 40% of this card's stats."},
	{"id": "battle_standard", "name": "Battle Standard", "family": "summon", "text": "On entry, plant a standard; allies gain 8% faster ultimate charge while it stands."},
	{"id": "gravecaller", "name": "Gravecaller", "family": "summon", "text": "The first allied death raises a skeleton with 30% of that card's stats."},
	{"id": "nest_of_thorns", "name": "Nest of Thorns", "family": "summon", "text": "Every 6 turns, summon a thornling with 25% of this card's stats."},
	{"id": "splitspawn", "name": "Splitspawn", "family": "summon", "text": "Below 40% HP, split off a copy with 20% of this card's stats. Once per battle."},
	{"id": "familiar", "name": "Familiar", "family": "summon", "text": "On entry, summon a familiar. It restores 2% max HP to this card each turn."},
	{"id": "war_hounds", "name": "War Hounds", "family": "summon", "text": "On entry, summon 2 hounds with 30% of this card's stats. They last 6 turns."},
	{"id": "last_brood", "name": "Last Brood", "family": "summon", "text": "On death, summon 3 broodlings with 15% of this card's stats."},
	{"id": "soul_collector", "name": "Soul Collector", "family": "summon", "text": "Each kill strengthens this card's summons by 10%, up to 30%."},
	{"id": "swarmkeeper", "name": "Swarmkeeper", "family": "summon", "text": "Every 7 turns, summon a swarmling with 20% of this card's stats."},
	{"id": "lifebloom", "name": "Lifebloom", "family": "support", "text": "Every 3 turns, heal the lowest-HP ally for 5% of their max HP."},
	{"id": "blood_leech", "name": "Blood Leech", "family": "support", "text": "Converts 8% of damage dealt into healing."},
	{"id": "rejuvenation", "name": "Rejuvenation", "family": "support", "text": "On entry, restore 8% max HP to every ally."},
	{"id": "pulse_healer", "name": "Pulse Healer", "family": "support", "text": "Every 5 turns, heal every ally for 6% of their max HP."},
	{"id": "desperate_medic", "name": "Desperate Medic", "family": "support", "text": "Allies below 30% HP receive 20% more healing."},
	{"id": "soul_mend", "name": "Soul Mend", "family": "support", "text": "When an ally dies, restore 12% max HP to the lowest-HP survivor."},
	{"id": "regrowth", "name": "Regrowth", "family": "support", "text": "After taking damage, regenerate 1% max HP per turn for 3 turns."},
	{"id": "vital_link", "name": "Vital Link", "family": "support", "text": "Each turn, share 10% of this card's max HP as healing with the lowest-HP ally."},
	{"id": "warm_blood", "name": "Warm Blood", "family": "support", "text": "Allies regenerate 1% max HP every turn while this card lives."},
	{"id": "last_remedy", "name": "Last Remedy", "family": "support", "text": "Once per battle, when an ally drops below 10% HP, heal them for 15% max HP."},
	{"id": "hexbreaker", "name": "Hexbreaker", "family": "control", "text": "Every 4 turns, clear one negative effect from this card."},
	{"id": "timekeeper", "name": "Timekeeper", "family": "control", "text": "Every 6 turns, slow every enemy by 20% for a turn."},
	{"id": "silencer", "name": "Silencer", "family": "control", "text": "Every 5th attack has a 25% chance to silence the target for a turn."},
	{"id": "disruptor", "name": "Disruptor", "family": "control", "text": "On entry, slow the enemy's ultimate charge by 10% for 2 turns."},
	{"id": "phasewalker", "name": "Phasewalker", "family": "control", "text": "Every 5 turns, become untargetable for a turn."},
	{"id": "blinkstrike", "name": "Blinkstrike", "family": "control", "text": "Every 6 turns, strike the lowest-HP enemy for 75% of this card's attack."},
	{"id": "gravity_well", "name": "Gravity Well", "family": "control", "text": "Every 7 turns, slow every enemy by 20% for 2 turns."},
	{"id": "mana_leech", "name": "Mana Leech", "family": "control", "text": "Whenever an enemy lands a hit, gain 5% ultimate charge."},
	{"id": "null_field", "name": "Null Field", "family": "control", "text": "Enemy attack buffs are 10% less effective while this card lives."},
	{"id": "spell_mirror", "name": "Spell Mirror", "family": "control", "text": "12% chance to reflect half of an incoming ability back at the caster."},
	{"id": "glass_cannon", "name": "Glass Cannon", "family": "risk", "text": "25% more attack, but 10% less max HP."},
	{"id": "blood_price", "name": "Blood Price", "family": "risk", "text": "Every 6th attack costs 2% max HP and deals 50% bonus damage."},
	{"id": "desperation", "name": "Desperation", "family": "risk", "text": "Below 25% HP, the ultimate charges 30% faster."},
	{"id": "cursed_strength", "name": "Cursed Strength", "family": "risk", "text": "20% more attack, but 25% less healing received."},
	{"id": "soul_burn", "name": "Soul Burn", "family": "risk", "text": "Ultimate charges 15% faster, but this card loses 1% max HP every 4 turns."},
	{"id": "rage_engine", "name": "Rage Engine", "family": "risk", "text": "Every 10% of max HP lost grants 3% faster ultimate charge, up to 15%."},
	{"id": "frenzy", "name": "Frenzy", "family": "risk", "text": "Taking damage grants 5% faster ultimate charge for 2 turns, stacking twice."},
	{"id": "blood_debt", "name": "Blood Debt", "family": "risk", "text": "Stores 5% of damage taken; the next attack deals it as bonus damage."},
	{"id": "doomsday_clock", "name": "Doomsday Clock", "family": "risk", "text": "Gain 2% attack every 3 turns; after 15 turns, lose 10% max HP."},
	{"id": "unstable_core", "name": "Unstable Core", "family": "risk", "text": "Every 5 turns, gain 10% attack, defense, or charge rate at random for 2 turns."},
	{"id": "echo_blade", "name": "Echo Blade", "family": "legendary", "text": "Every 7th attack strikes again for 40% damage."},
	{"id": "blood_trail", "name": "Blood Trail", "family": "legendary", "text": "Enemies hit take 5% more damage from all sources for 2 turns."},
	{"id": "chainbreaker", "name": "Chainbreaker", "family": "legendary", "text": "Breaks a stun immediately and grants 10% faster charge for 2 turns."},
	{"id": "hollow_crown", "name": "Hollow Crown", "family": "legendary", "text": "Gains 5% of the strongest enemy's attack as bonus attack."},
	{"id": "soul_anchor", "name": "Soul Anchor", "family": "legendary", "text": "Immune to stun above 50% HP; below it, gain 10% speed."},
	{"id": "predators_mark", "name": "Predator's Mark", "family": "legendary", "text": "Damaging an enemy below 30% HP makes the next attack 15% stronger."},
	{"id": "echo_of_pain", "name": "Echo of Pain", "family": "legendary", "text": "The first attacker is marked; every later hit costs them 3% of their attack."},
	{"id": "rallying_cry", "name": "Rallying Cry", "family": "legendary", "text": "Below 50% HP, every ally gains 8% faster charge for 3 turns. Once per battle."},
	{"id": "ashes_to_ashes", "name": "Ashes to Ashes", "family": "legendary", "text": "On death, deal 10% of max HP to every enemy and burn them for a turn."},
	{"id": "kingbreaker", "name": "Kingbreaker", "family": "legendary", "text": "Deals 15% bonus damage to enemies with more max HP. Killing one grants 5% max HP for the battle."},
]


static var _by_id: Dictionary = {}


# Converts a real-time duration from a skill design into whole turns.
static func turns(seconds: float) -> int:
	return max(1, int(round(seconds / SECONDS_PER_TURN)))


static func _index() -> Dictionary:
	if _by_id.is_empty():
		for skill in ALL:
			_by_id[skill["id"]] = skill
	return _by_id


static func by_id(skill_id: String) -> Dictionary:
	if skill_id == "":
		return {}
	return _index().get(skill_id, {})


static func has(skill_id: String) -> bool:
	return not by_id(skill_id).is_empty()


static func display_name(skill_id: String) -> String:
	var skill := by_id(skill_id)
	if skill.is_empty():
		return ""
	return str(skill["name"])


static func text_of(skill_id: String) -> String:
	var skill := by_id(skill_id)
	if skill.is_empty():
		return ""
	return str(skill["text"])


static func family_of(skill_id: String) -> String:
	var skill := by_id(skill_id)
	if skill.is_empty():
		return ""
	return str(skill["family"])


static func family_label(skill_id: String) -> String:
	var family := family_of(skill_id)
	if family == "":
		return ""
	return str(FAMILY_LABEL[family])


static func family_color(skill_id: String) -> Color:
	var family := family_of(skill_id)
	if family == "":
		return Color("#646c7e")
	return Color(str(FAMILY_COLOR[family]))


static func family_icon(skill_id: String) -> String:
	var family := family_of(skill_id)
	if family == "":
		return ""
	return str(FAMILY_ICON[family])


static func in_family(family: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for skill in ALL:
		if skill["family"] == family:
			out.append(skill)
	return out


# Picks the card's passive.
#
# Every card gets one. The rarity curve is deliberately brutal - roughly
# four cards in five are Common - so gating passives behind rarity, as the
# old three-passive system did, left about 2% of the roster carrying a
# skill and made the library effectively invisible. Rarity instead governs
# which families are reachable; the passive is what makes each card
# mechanically distinct.
static func pick_for(role: String, rarity: String, rng: RandomNumberGenerator = null) -> String:
	var apex := Config.rarity_index(rarity) >= Config.rarity_index("Legendary")

	var legendary_roll := randf()
	if rng != null:
		legendary_roll = rng.randf()

	var family := ""
	if apex and legendary_roll < LEGENDARY_SKILL_CHANCE:
		family = "legendary"
	else:
		var pool: Array = ROLE_FAMILIES.get(role, ["offense"])
		var pick := randi() % pool.size()
		if rng != null:
			pick = rng.randi() % pool.size()
		family = str(pool[pick])

	var options := in_family(family)
	if options.is_empty():
		return ""

	var index := randi() % options.size()
	if rng != null:
		index = rng.randi() % options.size()
	return str(options[index]["id"])
