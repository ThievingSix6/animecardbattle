class_name SkillEffects
extends RefCounted

# =========================================================
# What the 100 passives in Skills.ALL actually do.
#
# One function per hook point, each matching on the skill id. Behaviour
# lives here; the roster and its descriptions live in Skills. The engine
# owns sequencing and calls these - a new passive is an entry in Skills
# plus a case in whichever hooks it uses.
#
# Durations are in TURNS. Skills.turns() converts the real-time numbers
# the designs are written in.
# =========================================================


# The card becomes the active fighter.
static func entry(skill_id: String, c: SkillCtx) -> void:
	match skill_id:
		"guardians_oath":
			var ally := c.sim.lowest_hp_ally(c.unit, false)
			if ally != null and not ally.has_buff("oath"):
				ally.add_buff("damageTaken", -0.15, Combatant.INFINITE, "oath", 1)
				c.sim.note(c.unit, "%s swears to guard %s" % [c.unit.data.card_name, ally.data.card_name])

		"fading_shield":
			var gained := c.unit.add_shield(c.pct_max(c.unit, 0.15))
			c.unit.counters["fading"] = Skills.turns(6.0)
			c.sim.note(c.unit, "%s conjures a fading shield" % c.unit.data.card_name, gained)

		"heavy_soul":
			if c.unit.claim("heavy_soul"):
				c.unit.add_buff("energyRate", -0.08, Combatant.INFINITE)

		"reckless_fury":
			if c.unit.claim("reckless"):
				c.unit.add_buff("energyRate", 0.20, Combatant.INFINITE)
				c.unit.add_buff("damageTaken", 0.10, Combatant.INFINITE)

		"blood_pact":
			if c.unit.claim("blood_pact"):
				var ally := c.sim.strongest_ally(c.unit, false)
				if ally != null:
					c.unit.hp = max(1, c.unit.hp - c.pct_max(c.unit, 0.05))
					ally.add_buff("attack", 0.08, Combatant.INFINITE)
					c.sim.note(c.unit, "%s seals a pact with %s" % [c.unit.data.card_name, ally.data.card_name])

		"martyr":
			var guarded := c.sim.lowest_hp_ally(c.unit, false)
			if guarded != null and not guarded.has_buff("martyr"):
				guarded.add_buff("damageTaken", -0.40, Combatant.INFINITE, "martyr", 1)

		"broodmother":
			if c.unit.claim("broodmother"):
				c.sim.summon(c.unit, "Broodling", 0.4, Skills.turns(20.0), 2)

		"battle_standard":
			if c.unit.claim("standard"):
				c.sim.summon(c.unit, "War Standard", 0.25, Skills.turns(24.0), 1)
				for a in c.sim.allies_of(c.unit):
					if a.alive:
						a.add_buff("energyRate", 0.08, Skills.turns(24.0), "standard", 1)

		"familiar":
			if c.unit.claim("familiar"):
				c.sim.summon(c.unit, "Familiar", 0.15, Skills.turns(30.0), 1)

		"war_hounds":
			if c.unit.claim("hounds"):
				c.sim.summon(c.unit, "War Hound", 0.3, Skills.turns(12.0), 2)

		"blood_leech":
			if c.unit.claim("leech"):
				c.unit.add_buff("lifesteal", 0.08, Combatant.INFINITE)

		"rejuvenation":
			if c.unit.claim("rejuv"):
				for a in c.sim.allies_of(c.unit):
					if a.alive:
						a.heal(c.pct_max(a, 0.08))
				c.sim.note(c.unit, "%s rejuvenates the team" % c.unit.data.card_name)

		"disruptor":
			for e in c.sim.enemies_of(c.unit):
				if e.alive:
					e.add_buff("energyRate", -0.10, Skills.turns(4.0), "disrupt", 1)

		"glass_cannon":
			if c.unit.claim("glass"):
				c.unit.add_buff("attack", 0.25, Combatant.INFINITE)
				c.unit.max_hp = max(1, int(round(float(c.unit.max_hp) * 0.9)))
				c.unit.hp = min(c.unit.hp, c.unit.max_hp)

		"cursed_strength":
			if c.unit.claim("cursed"):
				c.unit.add_buff("attack", 0.20, Combatant.INFINITE)
				c.unit.add_buff("healingReceived", -0.25, Combatant.INFINITE)

		"soul_burn":
			if c.unit.claim("soulburn"):
				c.unit.add_buff("energyRate", 0.15, Combatant.INFINITE)

		"hollow_crown":
			if c.unit.claim("crown"):
				var best: Combatant = null
				for e in c.sim.enemies_of(c.unit):
					if not e.alive:
						continue
					if best == null or e.attack_power() > best.attack_power():
						best = e
				if best != null:
					var bonus := float(best.attack_power()) * 0.05 / float(max(1, c.unit.data.attack))
					c.unit.add_buff("attack", bonus, Combatant.INFINITE)


# Start of this card's turn.
static func turn_start(skill_id: String, c: SkillCtx) -> void:
	match skill_id:
		"unbroken":
			if c.unit.count("unbroken_cd") > 0:
				c.unit.stun_turns = 0
				c.unit.bump("unbroken_cd", -1)
			elif c.unit.stun_turns > 0:
				c.unit.counters["unbroken_cd"] = Skills.turns(8.0)

		"fading_shield":
			if c.unit.count("fading") > 0:
				if c.unit.bump("fading", -1) <= 0:
					c.unit.shield = 0

		"heavy_soul":
			c.unit.stun_turns = 0

		"kindled_rage":
			var burning := 0
			for e in c.sim.enemies_of(c.unit):
				if e.alive and e.has_dot("burn"):
					burning += 1
			c.unit.clear_buffs_with_key("kindled")
			if burning > 0:
				c.unit.add_buff("energyRate", min(0.12, float(burning) * 0.04), 2, "kindled", 1)

		"inferno_pulse":
			if c.unit.bump("pulse") % Skills.turns(10.0) == 0:
				for e in c.sim.enemies_of(c.unit):
					if not e.alive:
						continue
					c.sim.direct_damage(c.unit, e, int(round(float(c.unit.attack_power()) * 0.4)), "Inferno Pulse")
					e.apply_dot("burn", 1, int(round(float(c.unit.attack_power()) * 0.05)))

		"nest_of_thorns":
			if c.unit.bump("thorns") % Skills.turns(12.0) == 0:
				c.sim.summon(c.unit, "Thornling", 0.25, Skills.turns(12.0), 1)

		"familiar":
			if c.unit.spent.has("familiar"):
				c.unit.heal(c.pct_max(c.unit, 0.02))

		"swarmkeeper":
			if c.unit.bump("swarm") % Skills.turns(15.0) == 0:
				c.sim.summon(c.unit, "Swarmling", 0.2, Skills.turns(15.0), 1)

		"lifebloom":
			if c.unit.bump("lifebloom") % Skills.turns(6.0) == 0:
				var ally := c.sim.lowest_hp_ally(c.unit, true)
				if ally != null:
					var healed := ally.heal(c.pct_max(ally, 0.05))
					if healed > 0:
						c.sim.note(c.unit, "%s mends %s" % [c.unit.data.card_name, ally.data.card_name], healed)

		"pulse_healer":
			if c.unit.bump("pulseheal") % Skills.turns(10.0) == 0:
				for a in c.sim.allies_of(c.unit):
					if a.alive:
						a.heal(c.pct_max(a, 0.06))
				c.sim.note(c.unit, "%s pulses healing light" % c.unit.data.card_name)

		"desperate_medic":
			for a in c.sim.allies_of(c.unit):
				if a.alive and a.hp_ratio() < 0.30 and not a.has_buff("medic"):
					a.add_buff("healingReceived", 0.20, 2, "medic", 1)

		"regrowth":
			if c.unit.count("regrow") > 0:
				c.unit.bump("regrow", -1)
				c.unit.heal(c.pct_max(c.unit, 0.01))

		"vital_link":
			var linked := c.sim.lowest_hp_ally(c.unit, false)
			if linked != null and c.unit.bump("vital") % Skills.turns(6.0) == 0:
				linked.heal(c.pct_max(c.unit, 0.10))

		"warm_blood":
			for a in c.sim.allies_of(c.unit):
				if a.alive:
					a.heal(c.pct_max(a, 0.01))

		"last_remedy":
			var hurt: Combatant = null
			for a in c.sim.allies_of(c.unit):
				if a.alive and a.hp_ratio() < 0.10:
					hurt = a
					break
			if hurt != null and c.unit.claim("remedy"):
				var mended := hurt.heal(c.pct_max(hurt, 0.15))
				c.sim.note(c.unit, "%s applies a last remedy to %s" % [c.unit.data.card_name, hurt.data.card_name], mended)

		"hexbreaker":
			if c.unit.bump("hex") % Skills.turns(8.0) == 0:
				var removed := false
				for i in c.unit.buffs.size():
					if float(c.unit.buffs[i]["amount"]) < 0.0:
						c.unit.buffs.remove_at(i)
						removed = true
						break
				if not removed and c.unit.dots.size() > 0:
					c.unit.dots.remove_at(0)

		"timekeeper":
			if c.unit.bump("timekeeper") % Skills.turns(12.0) == 0:
				for e in c.sim.enemies_of(c.unit):
					if e.alive:
						e.add_buff("speed", -0.20, 1, "slow", 1)
				c.sim.note(c.unit, "%s bends time" % c.unit.data.card_name)

		"phasewalker":
			if c.unit.bump("phase") % Skills.turns(10.0) == 0:
				c.unit.untargetable_turns = 1
				c.sim.note(c.unit, "%s phases out" % c.unit.data.card_name)

		"blinkstrike":
			if c.unit.bump("blink") % Skills.turns(12.0) == 0:
				var weakest: Combatant = null
				for e in c.sim.enemies_of(c.unit):
					if not e.alive:
						continue
					if weakest == null or e.hp < weakest.hp:
						weakest = e
				if weakest != null:
					c.sim.direct_damage(c.unit, weakest, int(round(float(c.unit.attack_power()) * 0.75)), "Blinkstrike")

		"gravity_well":
			if c.unit.bump("gravity") % Skills.turns(15.0) == 0:
				for e in c.sim.enemies_of(c.unit):
					if e.alive:
						e.add_buff("speed", -0.20, Skills.turns(3.0), "gravity", 1)

		"null_field":
			for e in c.sim.enemies_of(c.unit):
				if e.alive and not e.has_buff("null"):
					e.add_buff("damageDealt", -0.10, 2, "null", 1)

		"desperation":
			if c.unit.hp_ratio() < 0.25 and not c.unit.has_buff("desperation"):
				c.unit.add_buff("energyRate", 0.30, Combatant.INFINITE, "desperation", 1)

		"soul_burn":
			if c.unit.bump("soulburn_t") % Skills.turns(8.0) == 0:
				c.unit.hp = max(1, c.unit.hp - c.pct_max(c.unit, 0.01))

		"doomsday_clock":
			var ticks := c.unit.bump("doom")
			if ticks % Skills.turns(5.0) == 0:
				c.unit.add_buff("attack", 0.02, Combatant.INFINITE, "doom", 10)
			if ticks == Skills.turns(30.0):
				c.unit.max_hp = max(1, int(round(float(c.unit.max_hp) * 0.9)))
				c.unit.hp = min(c.unit.hp, c.unit.max_hp)
				c.sim.note(c.unit, "%s's clock strikes midnight" % c.unit.data.card_name)

		"unstable_core":
			if c.unit.bump("unstable") % Skills.turns(10.0) == 0:
				var stats: Array[String] = ["attack", "defense", "energyRate"]
				c.unit.add_buff(stats[randi() % stats.size()], 0.10, Skills.turns(5.0), "unstable", 1)

		"chainbreaker":
			if c.unit.stun_turns > 0:
				c.unit.stun_turns = 0
				c.unit.add_buff("energyRate", 0.10, Skills.turns(3.0))
				c.sim.note(c.unit, "%s breaks free" % c.unit.data.card_name)

		"soul_anchor":
			if c.unit.hp_ratio() > 0.5:
				c.unit.stun_turns = 0
			elif not c.unit.has_buff("anchor"):
				c.unit.add_buff("speed", 0.10, Combatant.INFINITE, "anchor", 1)


# About to deal damage - may modify c.damage.
static func outgoing(skill_id: String, c: SkillCtx) -> void:
	match skill_id:
		"executioners_mark":
			if c.target != null and c.target.hp_ratio() < 0.25:
				c.damage = int(round(float(c.damage) * 1.25))

		"blood_rush":
			if c.target != null:
				var last: String = str(c.unit.counters.get("rush_target", ""))
				var same := last == c.target.id()
				c.unit.counters["rush_target"] = c.target.id()
				var stacks := 0
				if same:
					stacks = min(4, c.unit.bump("rush"))
				else:
					c.unit.counters["rush"] = 0
				c.damage = int(round(float(c.damage) * (1.0 + float(stacks) * 0.05)))

		"third_strike":
			if c.unit.bump("third") % 3 == 0:
				c.damage = int(round(float(c.damage) * 1.75))

		"crushing_blow":
			if c.chance(0.12):
				c.damage = int(round(float(c.damage) * 1.5))
				if c.target != null:
					c.target.stun_turns = max(c.target.stun_turns, 1)
				c.sim.note(c.unit, "%s lands a crushing blow" % c.unit.data.card_name)

		"predator":
			if c.target != null and c.target.hp > c.unit.hp:
				c.damage = int(round(float(c.damage) * 1.2))

		"backstab":
			var active := c.sim.active_enemy(c.unit)
			if c.target != null and active != null and c.target.id() != active.id():
				c.damage = int(round(float(c.damage) * 1.25))

		"overcharge":
			if c.unit.bump("overcharge") % 8 == 0:
				c.damage = int(round(float(c.damage) * 2.0))
				c.unit.hp = max(1, c.unit.hp - c.pct_max(c.unit, 0.03))
				c.sim.note(c.unit, "%s overcharges" % c.unit.data.card_name)

		"bloodied_blade":
			if c.unit.hp_ratio() < 0.5:
				c.damage = int(round(float(c.damage) * 1.1))

		"marked_prey":
			if c.target != null:
				if c.unit.marked.is_empty():
					c.unit.marked[c.target.id()] = true
				if c.unit.marked.has(c.target.id()):
					c.damage = int(round(float(c.damage) * 1.15))

		"finisher":
			if c.target != null and c.target.hp_ratio() < 0.15:
				c.damage = int(round(float(c.damage) * 1.5))

		"blood_price":
			if c.unit.bump("bloodprice") % 6 == 0:
				c.damage = int(round(float(c.damage) * 1.5))
				c.unit.hp = max(1, c.unit.hp - c.pct_max(c.unit, 0.02))

		"blood_debt":
			var owed := c.unit.count("debt")
			if owed > 0:
				c.damage += owed
				c.unit.counters["debt"] = 0

		"predators_mark":
			if c.unit.count("predmark") > 0:
				c.damage = int(round(float(c.damage) * 1.15))
				c.unit.counters["predmark"] = 0

		"kingbreaker":
			if c.target != null and c.target.max_hp > c.unit.max_hp:
				c.damage = int(round(float(c.damage) * 1.15))


# About to receive damage - may modify c.damage or set c.blocked.
static func incoming(skill_id: String, c: SkillCtx) -> void:
	match skill_id:
		"ironhide":
			if c.chance(0.20):
				c.blocked = true
				var blocks := c.unit.bump("ironhide")
				c.sim.note(c.unit, "%s blocks the blow" % c.unit.data.card_name)
				if blocks % 3 == 0:
					c.unit.add_buff("damageTaken", -0.30, Skills.turns(4.0), "ironhide", 1)

		"stoneheart":
			if c.unit.bump("stoneheart") % 5 == 0:
				c.damage = int(round(float(c.damage) * 0.6))

		"thornmail":
			if c.attacker != null and c.chance(0.15):
				c.blocked = true
				c.sim.direct_damage(c.unit, c.attacker, int(round(float(c.unit.attack_power()) * 0.2)), "Thornmail")

		"mirror_guard":
			if c.attacker != null and c.chance(0.15):
				var back := int(round(float(c.damage) * 0.5))
				c.damage -= back
				c.sim.direct_damage(c.unit, c.attacker, back, "Mirror Guard")

		"spell_mirror":
			if c.attacker != null and c.chance(0.12):
				c.sim.direct_damage(c.unit, c.attacker, int(round(float(c.damage) * 0.5)), "Spell Mirror")


# Damage has landed on c.target.
static func dealt(skill_id: String, c: SkillCtx) -> void:
	match skill_id:
		"rend":
			if c.target != null and c.unit.bump("rend") % 4 == 0:
				var total := c.pct_max(c.target, 0.03)
				c.target.apply_dot("bleed", Skills.turns(4.0), int(round(float(total) / float(Skills.turns(4.0)))))

		"bonebreaker":
			if c.target != null and c.unit.bump("bone") % 5 == 0:
				c.target.add_buff("defense", -0.08, Skills.turns(4.0), "bone", 3)

		"wild_swing":
			if c.chance(0.10):
				for e in c.sim.enemies_of(c.unit):
					if e.alive and (c.target == null or e.id() != c.target.id()):
						c.sim.direct_damage(c.unit, e, int(round(float(c.damage) * 0.5)), "Wild Swing")
						break

		"cinderbrand":
			if c.target != null and c.chance(0.20):
				c.target.apply_dot("burn", Skills.turns(4.0), int(round(float(c.unit.attack_power()) * 0.03)))

		"ashen_touch":
			if c.target != null and c.unit.bump("ashen") % 3 == 0:
				c.target.apply_dot("burn", Skills.turns(4.0), int(round(float(c.unit.attack_power()) * 0.04)))
				c.target.add_buff("damageDealt", -0.05, Skills.turns(4.0), "ashen", 1)

		"firebrand":
			if c.target != null and c.chance(0.15):
				c.target.apply_dot("burn", Skills.turns(3.0), int(round(float(c.unit.attack_power()) * 0.08)))

		"blackened_wound":
			if c.target != null and c.target.has_dot("burn") and not c.target.has_buff("blackened"):
				c.target.add_buff("healingReceived", -0.08, Skills.turns(6.0), "blackened", 1)

		"silencer":
			if c.target != null and c.unit.bump("silencer") % 5 == 0 and c.chance(0.25):
				c.target.silence_turns = max(c.target.silence_turns, 1)
				c.sim.note(c.unit, "%s is silenced" % c.target.data.card_name)

		"echo_blade":
			if c.target != null and c.unit.bump("echo") % 7 == 0:
				c.sim.direct_damage(c.unit, c.target, int(round(float(c.damage) * 0.4)), "Echo Blade")

		"blood_trail":
			if c.target != null and not c.target.has_buff("trail"):
				c.target.add_buff("damageTaken", 0.05, Skills.turns(3.0), "trail", 1)

		"predators_mark":
			if c.target != null and c.target.hp_ratio() < 0.30:
				c.unit.counters["predmark"] = 1


# Damage has landed on this card.
static func taken(skill_id: String, c: SkillCtx) -> void:
	match skill_id:
		"gravebound":
			if c.unit.hp_ratio() < 0.20 and c.unit.claim("gravebound"):
				var gained := c.unit.add_shield(c.pct_max(c.unit, 0.12))
				c.sim.note(c.unit, "%s raises a grave shield" % c.unit.data.card_name, gained)

		"second_wind":
			if c.unit.hp_ratio() < 0.35 and c.unit.claim("second_wind"):
				var healed := c.unit.heal(c.pct_max(c.unit, 0.10))
				c.unit.add_buff("speed", 0.15, Skills.turns(4.0))
				c.sim.note(c.unit, "%s catches a second wind" % c.unit.data.card_name, healed)

		"bloodguard":
			if c.unit.hp_ratio() < 0.5 and c.unit.claim("bloodguard"):
				c.unit.add_buff("lifesteal", 0.10, Combatant.INFINITE)
				c.sim.note(c.unit, "%s fights on blood" % c.unit.data.card_name)

		"bulwark":
			if c.unit.bump("bulwark") % 3 == 0:
				c.unit.add_buff("defense", 0.05, Combatant.INFINITE, "bulwark", 3)

		"splitspawn":
			if c.unit.hp_ratio() < 0.40 and c.unit.claim("splitspawn"):
				c.sim.summon(c.unit, c.unit.data.card_name + " Spawn", 0.2, Skills.turns(20.0), 1)

		"regrowth":
			if not c.unit.has_buff("regrowth"):
				c.unit.add_buff("healingReceived", 0.0, Skills.turns(5.0), "regrowth", 1)
				c.unit.counters["regrow"] = Skills.turns(5.0)

		"smoldering_armor":
			if c.attacker != null and c.chance(0.15):
				c.attacker.apply_dot("burn", Skills.turns(4.0), int(round(float(c.unit.attack_power()) * 0.03)))

		"mana_leech":
			c.unit.energy = min(Config.ENERGY_MAX, c.unit.energy + 5)

		"rage_engine":
			var lost := int(floor((1.0 - c.unit.hp_ratio()) * 10.0))
			var have := c.unit.count_buffs_with_key("rage")
			if lost > have and have < 5:
				c.unit.add_buff("energyRate", 0.03, Combatant.INFINITE, "rage", 5)

		"frenzy":
			c.unit.add_buff("energyRate", 0.05, Skills.turns(3.0), "frenzy", 2)

		"blood_debt":
			c.unit.bump("debt", int(round(float(c.damage) * 0.05)))

		"echo_of_pain":
			if c.attacker != null:
				if c.unit.marked.is_empty():
					c.unit.marked[c.attacker.id()] = true
				elif c.unit.marked.has(c.attacker.id()):
					c.sim.direct_damage(c.unit, c.attacker, max(1, int(round(float(c.attacker.attack_power()) * 0.03))), "Echo of Pain")

		"rallying_cry":
			if c.unit.hp_ratio() < 0.5 and c.unit.claim("rally"):
				for a in c.sim.allies_of(c.unit):
					if a.alive:
						a.add_buff("energyRate", 0.08, Skills.turns(5.0))
				c.sim.note(c.unit, "%s rallies the team" % c.unit.data.card_name)


# A blow that would reduce this card to 0 - may set c.prevented.
static func lethal(skill_id: String, c: SkillCtx) -> void:
	match skill_id:
		"last_stand":
			if c.unit.claim("last_stand"):
				c.prevented = true
				c.unit.hp = 1
				c.unit.add_buff("energyRate", 0.25, Skills.turns(5.0))
				c.sim.note(c.unit, "%s refuses to fall" % c.unit.data.card_name)

		"death_denied":
			if c.unit.claim("death_denied"):
				c.prevented = true
				c.unit.hp = max(1, c.pct_max(c.unit, 0.05))
				c.sim.note(c.unit, "%s denies death" % c.unit.data.card_name)


# This card killed c.other.
static func kill(skill_id: String, c: SkillCtx) -> void:
	match skill_id:
		"momentum":
			c.unit.add_buff("energyRate", 0.15, Skills.turns(5.0))

		"ember_chain":
			if c.other != null and c.other.has_dot("burn"):
				var source := c.other.first_dot("burn")
				for e in c.sim.enemies_of(c.unit):
					if e.alive and not source.is_empty():
						e.apply_dot("burn", int(source["turns"]), int(round(float(source["per_turn"]) * 0.6)))
						break

		"funeral_flame":
			if c.other != null and c.other.has_dot("burn"):
				var blast := c.pct_max(c.other, 0.05)
				for e in c.sim.enemies_of(c.unit):
					if e.alive and e.id() != c.other.id():
						c.sim.direct_damage(c.unit, e, blast, "Funeral Flame")

		"soul_collector":
			c.unit.bump("souls")

		"kingbreaker":
			if c.other != null and c.other.max_hp > c.unit.max_hp:
				var gain := c.pct_max(c.unit, 0.05)
				c.unit.max_hp += gain
				c.unit.heal(gain)
				c.sim.note(c.unit, "%s breaks a king" % c.unit.data.card_name, gain)


# This card died.
static func death(skill_id: String, c: SkillCtx) -> void:
	match skill_id:
		"undying_ember":
			var burn := int(round(float(c.pct_max(c.unit, 0.10)) / float(Skills.turns(4.0))))
			for e in c.sim.enemies_of(c.unit):
				if e.alive:
					e.apply_dot("burn", Skills.turns(4.0), burn)
			c.sim.note(c.unit, "%s bursts into embers" % c.unit.data.card_name)

		"scorching_death":
			if c.attacker != null:
				var total := c.pct_max(c.unit, 0.08)
				c.attacker.apply_dot("burn", Skills.turns(5.0), int(round(float(total) / float(Skills.turns(5.0)))))

		"grave_gift":
			var ally := c.sim.lowest_hp_ally(c.unit, false)
			if ally != null:
				var healed := ally.heal(c.pct_max(ally, 0.08))
				c.sim.note(c.unit, "%s leaves a parting gift to %s" % [c.unit.data.card_name, ally.data.card_name], healed)

		"dead_mans_hand":
			if c.attacker != null:
				c.attacker.add_buff("energyRate", -0.10, Skills.turns(5.0))

		"final_offering":
			var heir := c.sim.next_ally(c.unit)
			if heir != null:
				heir.add_buff("attack", 0.15, Skills.turns(6.0))

		"soul_shard":
			var bearer := c.sim.next_ally(c.unit)
			if bearer != null:
				bearer.add_shield(c.pct_max(bearer, 0.10))

		"rotting_curse":
			if c.attacker != null:
				c.attacker.add_buff("healingReceived", -0.20, Skills.turns(5.0))

		"death_echo":
			var enemy := c.sim.active_enemy(c.unit)
			if enemy != null:
				c.sim.direct_damage(c.unit, enemy, int(round(float(c.unit.attack_power()) * 0.5)), "Death Echo")

		"grim_inheritance":
			var successor := c.sim.next_ally(c.unit)
			if successor != null:
				var passed := 0
				for buff in c.unit.buffs:
					if float(buff["amount"]) > 0.0 and int(buff["turns"]) < Combatant.INFINITE:
						successor.add_buff(str(buff["stat"]), float(buff["amount"]), int(buff["turns"]), str(buff["key"]))
						passed += 1
				if passed > 0:
					c.sim.note(c.unit, "%s bequeaths its power to %s" % [c.unit.data.card_name, successor.data.card_name])

		"last_brood":
			c.sim.summon(c.unit, "Broodling", 0.15, Skills.turns(16.0), 3)

		"ashes_to_ashes":
			var blast := c.pct_max(c.unit, 0.10)
			for e in c.sim.enemies_of(c.unit):
				if not e.alive:
					continue
				c.sim.direct_damage(c.unit, e, blast, "Ashes to Ashes")
				e.apply_dot("burn", Skills.turns(3.0), int(round(float(blast) * 0.1)))


# An ally died.
static func ally_death(skill_id: String, c: SkillCtx) -> void:
	match skill_id:
		"corpsewalker":
			c.unit.add_buff("energyRate", 0.05, Combatant.INFINITE, "corpse", 2)

		"gravecaller":
			if c.unit.claim("gravecaller"):
				c.sim.summon(c.unit, "Risen Skeleton", 0.3, Skills.turns(10.0), 1)

		"soul_mend":
			var ally := c.sim.lowest_hp_ally(c.unit, true)
			if ally != null:
				var healed := ally.heal(c.pct_max(ally, 0.12))
				if healed > 0:
					c.sim.note(c.unit, "%s mends a broken soul" % c.unit.data.card_name, healed)
