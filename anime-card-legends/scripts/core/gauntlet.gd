class_name Gauntlet
extends RefCounted

# =========================================================
# THE HELLFIRE GAUNTLET.
#
# Diablo's challenge: five waves, fought back to back, with the team's
# wounds carried from one wave into the next. There is no retreating
# mid-run and no full heal - only a small mend between waves - so the
# gauntlet asks a different question from a campaign stage. A stage
# asks whether your front-liner beats theirs. This asks whether five
# cards can outlast twenty-three.
#
# It is beatable. The numbers below are tuned so a team that has
# cleared the campaign and levelled its cards gets through, and one
# that has not, does not.
# =========================================================

const WAVES := 5

# Fraction of missing health mended between waves. Enough to matter,
# never enough to reset the run.
const MEND_BETWEEN_WAVES := 0.22

const BOSS_NAME := "Diablo, Lord of Hatred"
const BOSS_TITLE := "Lord of Hatred"

# Per-wave shape. "count" includes the wave's own captain.
const WAVE_TABLE: Array[Dictionary] = [
	{
		"name": "The Doorway",
		"blurb": "What is left of the last people who tried.",
		"count": 4, "scale": 1.0, "captain": "Ash-Choked Herald",
	},
	{
		"name": "The Long Stair",
		"blurb": "They come up the steps faster than you go down them.",
		"count": 5, "scale": 1.5, "captain": "Cinderbound Warden",
	},
	{
		"name": "The Furnace Floor",
		"blurb": "The heat is doing half their work for them.",
		"count": 5, "scale": 2.2, "captain": "Molten Executioner",
	},
	{
		"name": "The Court of Hate",
		"blurb": "His lieutenants. They have been waiting a long time.",
		"count": 5, "scale": 3.1, "captain": "Hatred's Chosen",
	},
	{
		"name": "Diablo, Lord of Hatred",
		"blurb": "He does not get up when he falls. Neither will you.",
		"count": 3, "scale": 4.4, "captain": BOSS_NAME,
	},
]

const MINION_NAMES: Array[String] = [
	"Emberfiend", "Sootblood Reaver", "Hollow Choir", "Ashen Wretch",
	"Slagborn Brute", "Cinder Shade", "Furnace Hound", "Charred Penitent",
	"Screaming Coal", "Pyre Stalker",
]

const ELEMENT := "Fire"


static func wave_count() -> int:
	return WAVES


static func wave(index: int) -> Dictionary:
	return WAVE_TABLE[clampi(index, 0, WAVE_TABLE.size() - 1)]


static func wave_name(index: int) -> String:
	return str(wave(index)["name"])


static func wave_blurb(index: int) -> String:
	return str(wave(index)["blurb"])


static func is_final(index: int) -> bool:
	return index >= WAVES - 1


# --- Rewards ---------------------------------------------------------------
#
# Paid per wave cleared, so a run that dies on wave four is still worth
# having made. Clearing all five pays the rest and a boss pack.

const GEMS_PER_WAVE := 120
const GOLD_PER_WAVE := 3000
const CLEAR_BONUS_GEMS := 900
const CLEAR_BONUS_GOLD := 25000


static func rewards_for(waves_cleared: int) -> Dictionary:
	var cleared := clampi(waves_cleared, 0, WAVES)
	var out := {
		"gems": GEMS_PER_WAVE * cleared,
		"gold": GOLD_PER_WAVE * cleared,
		"pack": "",
	}
	if cleared >= WAVES:
		out["gems"] = int(out["gems"]) + CLEAR_BONUS_GEMS
		out["gold"] = int(out["gold"]) + CLEAR_BONUS_GOLD
		out["pack"] = "boss"
	return out


# --- Diablo's script -------------------------------------------------------

const GREETING: Array[String] = [
	"You climbed a tower to find me. Everyone does.",
	"Hatred is not a mood. It is a discipline. Mine.",
	"Five waves. Nobody heals you between them. Still interested?",
]

const TAUNT_MIDRUN: Array[String] = [
	"You are still standing. That is not the same as winning.",
	"They were the ones I could spare.",
	"Keep going. I want to see the exact moment you stop.",
]

const DEFEAT_LINE := "...Good. Come back when you can do that twice."
const VICTORY_LINE := "Predictable. Mend, and climb again."
