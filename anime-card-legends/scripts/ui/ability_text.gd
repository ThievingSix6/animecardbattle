class_name AbilityText
extends RefCounted

# =========================================================
# Generates human-readable skill descriptions from a card's ACTUAL
# mechanics (target mode, multiplier, passive type and values).
#
# Deriving the text instead of hand-writing it means a description
# can never drift from what the battle simulation really does - if
# the balance numbers in Config change, every card's text updates
# with them.
# =========================================================


static func basic(card: CardData) -> String:
	return _attack_text(card.basic_target_mode, Config.BASIC_ABILITY_MULT)


static func ultimate(card: CardData) -> String:
	var text := _attack_text(card.ultimate_target_mode, Config.ULTIMATE_MULT)
	return text + " Charges at full energy."


static func passive(card: CardData) -> String:
	match card.passive_type:
		"guardian_block_heal":
			return "%s chance to intercept an attack aimed at an ally, blocking it entirely and healing %s of max HP." % [
				_pct(card.passive_chance), _pct(card.passive_value)]
		"lifesteal":
			return "Heals for %s of all damage dealt." % _pct(card.passive_value)
		"energy_surge":
			return "Generates +%d bonus energy on every hit." % int(card.passive_value)
	return ""


# The line shown on the card face: prefers the ultimate, since that's
# the card's signature move.
static func headline_name(card: CardData) -> String:
	if card.ultimate_ability != "":
		return card.ultimate_ability
	if card.basic_ability != "":
		return card.basic_ability
	return card.role


static func headline_body(card: CardData) -> String:
	if card.ultimate_ability != "":
		return ultimate(card)
	if card.basic_ability != "":
		return basic(card)
	return card.description


static func _attack_text(mode: String, multiplier: float) -> String:
	var power := _pct(multiplier)
	match mode:
		"aoe":
			return "Deals %s damage to every enemy." % power
		"backline":
			return "Strikes the enemy backline for %s damage, ignoring the front." % power
	return "Deals %s damage to the active enemy." % power


static func _pct(value: float) -> String:
	return str(int(round(value * 100.0))) + "%"


# Stable "dex number" derived from the card id, so the same card always
# shows the same number without needing to be stored in the save file.
static func dex_number(card: CardData) -> int:
	return (abs(hash(card.card_id)) % 999) + 1
