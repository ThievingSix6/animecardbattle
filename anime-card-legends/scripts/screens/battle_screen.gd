extends Screen

# =========================================================
# Battle presentation. Owns no combat rules - it listens to BattleSim
# and animates what it reports.
# =========================================================

var sim: BattleSim
var floor_number := 1

var _enemy_row: HBoxContainer
var _player_row: HBoxContainer
var _log: RichTextLabel
var _views := {}          # Combatant -> BattleCard
var _result_layer: Control
var _speed_button: Button
var _is_raid := false


func screen_title() -> String:
	if _is_raid:
		return "Clan Raid — " + GameState.clan.raid_boss
	return "%s — %s" % [
		Campaign.zone_name_for_floor(floor_number),
		Campaign.stage_label(floor_number),
	]

func back_route() -> String:
	if _is_raid:
		return Routes.CLAN
	return Routes.ZONE

func shows_weather() -> bool:
	return false


func build_content() -> void:
	# The clan screen sets this flag; consume it so a later ordinary
	# battle does not accidentally run as a raid.
	_is_raid = GameState.progression.pending_raid
	GameState.progression.pending_raid = false

	floor_number = GameState.progression.pending_floor
	# Keep the zone in step with the floor, so leaving the fight returns to
	# the zone this floor actually belongs to however the player got here.
	GameState.progression.pending_zone = Campaign.zone_index_for_floor(floor_number)
	Audio.play_music("music_battle")

	_speed_button = UI.button(_speed_text(), _cycle_speed, Vector2(96, 40))
	header_actions.add_child(_speed_button)

	content.add_child(UI.section("Enemy"))
	_enemy_row = _build_row()
	content.add_child(_enemy_row)

	var divider := UI.label("⚔  VS  ⚔", Design.FS_HEADING, Design.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(divider)

	_player_row = _build_row()
	content.add_child(_player_row)
	content.add_child(UI.section("Your team"))

	var log_panel := UI.panel(Design.SURFACE, Design.S2)
	log_panel.custom_minimum_size = Vector2(0, 92)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	log_panel.add_child(_log)
	content.add_child(log_panel)

	_start()


# Pacing only - the simulation resolves identically at any speed.
func _turn_delay() -> float:
	return max(0.05, Config.ROUND_INTERVAL * 0.5 / Settings.battle_speed())


func _build_row() -> HBoxContainer:
	var row := UI.hbox(Design.S3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return row


func _speed_text() -> String:
	return "\u23E9 " + Settings.battle_speed_label()


func _cycle_speed() -> void:
	Settings.cycle_battle_speed()
	if _speed_button:
		_speed_button.text = _speed_text()


# --- Setup --------------------------------------------------------

func _start() -> void:
	sim = BattleSim.new()
	var opposition: Array[CardData] = []
	if _is_raid:
		opposition = EnemyFactory.build_raid(GameState.clan.level, GameState.clan.raid_boss)
	else:
		opposition = EnemyFactory.build_floor(floor_number, GameState.progression)
	sim.setup(GameState.get_battle_team(), opposition)

	for c in sim.enemies:
		_add_view(c, _enemy_row)
	for c in sim.players:
		_add_view(c, _player_row)

	sim.attack_performed.connect(_on_attack)
	sim.ability_used.connect(_on_ability)
	sim.skill_triggered.connect(_on_skill)
	sim.combatant_summoned.connect(_on_summoned)
	sim.healed.connect(_on_healed)
	sim.combatant_died.connect(_on_died)
	sim.actives_changed.connect(_on_actives_changed)
	sim.battle_ended.connect(_on_ended)

	_write("[center][color=#%s]%s — BEGIN[/color][/center]" % [
		Design.ACCENT.to_html(false), screen_title().to_upper()])

	await get_tree().create_timer(0.7).timeout
	_run()


func _add_view(c: Combatant, row: HBoxContainer) -> void:
	var view := BattleCard.create(c)
	_views[c] = view
	row.add_child(view)


func _run() -> void:
	while sim.running:
		var order := sim.prepare_round()
		if not sim.running or order.is_empty():
			break

		for side in order:
			sim.take_turn(side)
			if not sim.running:
				return
			await get_tree().create_timer(_turn_delay()).timeout


# --- Simulation event handlers ------------------------------------

func _on_attack(attacker: Combatant, target: Combatant, damage: int, _kind: String) -> void:
	_hit(target, damage)
	_write("[color=#%s]%s[/color] strikes %s for %s" % [
		Design.INFO.to_html(false), attacker.data.card_name,
		target.data.card_name, Fmt.compact(damage)])


func _on_ability(user: Combatant, ability: String, targets: Array, damage: int, kind: String) -> void:
	for t in targets:
		_hit(t, damage)

	var color := Design.ACCENT
	var verb := "uses"
	if kind == "ultimate":
		Audio.play("ultimate")
		color = Design.rarity_color("Mythic")
		verb = "unleashes"
	var scope := ""
	if targets.size() > 1:
		scope = " (×%d)" % targets.size()
	_write("[color=#%s]%s %s %s%s for %s[/color]" % [
		color.to_html(false), user.data.card_name, verb, ability, scope, Fmt.compact(damage)])


func _on_skill(source: Combatant, skill: String, note: String, amount: int) -> void:
	var view: BattleCard = _views.get(source)
	if view:
		view.refresh()
		if amount > 0:
			view.float_text(Fmt.compact(amount), Design.rarity_color("Epic"))
	_write("[color=#%s]\u2726 %s \u2014 %s[/color]" % [
		Design.rarity_color("Epic").to_html(false), skill, note])


# A summon joins the back of its owner's lane mid-battle.
func _on_summoned(owner: Combatant, who: Combatant) -> void:
	var row := _player_row
	if who.side == "enemy":
		row = _enemy_row
	_add_view(who, row)
	_write("[color=#%s]%s summons %s[/color]" % [
		Design.rarity_color("Uncommon").to_html(false),
		owner.data.card_name, who.data.card_name])


func _on_healed(target: Combatant, amount: int) -> void:
	var view: BattleCard = _views.get(target)
	if view:
		view.refresh()
		view.float_text("+" + Fmt.compact(amount), Design.SUCCESS)


func _on_died(who: Combatant) -> void:
	var view: BattleCard = _views.get(who)
	if view:
		view.play_death()
	_write("[color=#%s]%s is defeated[/color]" % [
		Design.TEXT_MUTED.to_html(false), who.data.card_name])


func _on_actives_changed(player_idx: int, enemy_idx: int) -> void:
	for c in sim.players:
		_views[c].set_active(c.index == player_idx)
	for c in sim.enemies:
		_views[c].set_active(c.index == enemy_idx)


func _hit(target: Combatant, damage: int) -> void:
	Audio.play("hit", randf_range(0.92, 1.08))
	var view: BattleCard = _views.get(target)
	if view == null:
		return
	view.refresh()
	view.play_hit()
	view.float_text("-" + Fmt.compact(damage), Design.DANGER)


func _write(line: String) -> void:
	_log.append_text("\n" + line)


# --- Result -------------------------------------------------------

func _on_ended(player_won: bool) -> void:
	var rewards := {}
	if _is_raid:
		_finish_raid()
	elif player_won:
		rewards = GameState.clear_floor(floor_number)
	else:
		Audio.play("defeat")

	var result_color := Design.DANGER
	var result_word := "DEFEAT"
	if player_won:
		result_color = Design.SUCCESS
		result_word = "VICTORY"
	_write("[center][color=#%s]%s[/color][/center]" % [result_color.to_html(false), result_word])

	_show_result(player_won, rewards)


# A raid sortie always counts: whatever the team managed before falling
# is credited to the clan's shared boss.
func _finish_raid() -> void:
	var dealt := sim.player_damage_dealt
	var clan: ClanSystem = GameState.clan
	var killed := clan.damage_raid(dealt, true)
	GameState.credit_clan(int(dealt / 20.0))

	if killed:
		var reward_gems := 200 + clan.level * 60
		var reward_gold := 2000 + clan.level * 800
		GameState.add_gems(reward_gems)
		GameState.add_gold(reward_gold)
		Audio.play("victory")
		_write("[center][color=#%s]%s FALLS — the clan shares the spoils[/color][/center]" % [
			Design.SUCCESS.to_html(false), clan.raid_boss.to_upper()])
	else:
		_write("[center][color=#%s]Contributed %s damage to the raid[/color][/center]" % [
			Design.ACCENT.to_html(false), Fmt.compact(dealt)])

	GameState.save_now()


func _show_result(player_won: bool, rewards: Dictionary) -> void:
	_result_layer = Control.new()
	_result_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_result_layer)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Design.OVERLAY
	_result_layer.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(center)

	var accent := Design.DANGER
	if player_won:
		accent = Design.SUCCESS
	var panel := UI.accent_panel(accent, Design.S5)
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)

	var body := UI.vbox(Design.S4)
	panel.add_child(body)

	var headline := "DEFEAT"
	if player_won:
		headline = "VICTORY"
	if _is_raid:
		headline = "SORTIE OVER"
		accent = Design.ACCENT
	body.add_child(UI.label(headline, Design.FS_DISPLAY, accent, HORIZONTAL_ALIGNMENT_CENTER))

	if _is_raid:
		body.add_child(UI.label(
			"%s damage dealt" % Fmt.compact(sim.player_damage_dealt),
			Design.FS_HEADING, Design.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
		var actions := UI.hbox(Design.S3)
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		actions.add_child(UI.primary_button("Back to clan",
			func(): Routes.go(self, Routes.CLAN), Vector2(180, 48)))
		body.add_child(actions)
		return

	if player_won:
		var gem_reward: int = rewards.get("gems", 0)
		var gold_reward: int = rewards.get("gold", 0)
		var reward_text := "+%s 💎    +%s 🪙" % [Fmt.commas(gem_reward), Fmt.commas(gold_reward)]
		body.add_child(UI.label(reward_text, Design.FS_HEADING, Design.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))

		if rewards.get("pack", "") != "":
			var pack_label: String = Config.ROLL_PACKS[rewards["pack"]]["label"]
			body.add_child(UI.label("🎁 " + pack_label + " earned!",
				Design.FS_BODY, Design.SUCCESS, HORIZONTAL_ALIGNMENT_CENTER))

	var actions := UI.hbox(Design.S3)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER

	if player_won and floor_number < Config.MAX_FLOOR:
		actions.add_child(UI.primary_button("Next floor", func():
			GameState.progression.pending_floor = floor_number + 1
			get_tree().reload_current_scene()
		, Vector2(150, 48)))
	elif not player_won:
		actions.add_child(UI.button("Retry", func():
			GameState.progression.pending_floor = floor_number
			get_tree().reload_current_scene()
		, Vector2(150, 48)))

	actions.add_child(UI.button("Zone map", func(): Routes.go(self, Routes.ZONE), Vector2(150, 48)))
	body.add_child(actions)
