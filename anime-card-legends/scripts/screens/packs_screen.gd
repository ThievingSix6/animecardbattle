extends Screen

var _results: GridContainer
var _banner_label: Label
var _buttons: Array[Button] = []
var _origin := ""
var _busy := false


func screen_title() -> String: return "Summon"


func build_content() -> void:
	content.add_child(_build_banner_picker())
	content.add_child(_build_banner_card())
	content.add_child(_build_actions())
	content.add_child(UI.section("Results"))

	var scroll := UI.scroll()
	_results = UI.grid(5, Design.S3)
	scroll.add_child(_results)
	content.add_child(scroll)

	_show_placeholder()


func _build_banner_picker() -> Control:
	var row := UI.hbox(Design.S2)
	var group := ButtonGroup.new()

	for origin in Config.ORIGINS:
		var b := UI.button(Config.ORIGIN_LABELS[origin], Callable(), Vector2(0, 40))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = (origin == _origin)
		b.pressed.connect(func():
			_origin = origin
			_banner_label.text = _banner_text()
		)
		row.add_child(b)

	return row


func _build_banner_card() -> Control:
	var panel := UI.accent_panel(Design.ACCENT, Design.S4)
	var body := UI.vbox(Design.S1)

	_banner_label = UI.label(_banner_text(), Design.FS_HEADING, Design.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_banner_label)

	var odds := []
	for rarity in Config.RARITY_ORDER:
		var chance: float = GameState.gacha.card_odds_for_rarity(rarity)
		odds.append("%s %s" % [rarity, Fmt.odds(chance)])
	var odds_label := UI.label(" · ".join(odds), Design.FS_MICRO, Design.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	odds_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_child(odds_label)

	panel.add_child(body)
	return panel


func _banner_text() -> String:
	return "✦ " + Config.ORIGIN_LABELS[_origin].to_upper() + " BANNER ✦"


func _build_actions() -> Control:
	var row := UI.hbox(Design.S4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var one := UI.button("Summon ×1\n💎 " + Fmt.commas(Config.SUMMON_COST_X1), func(): _summon(1), Vector2(200, 62))
	var ten := UI.primary_button("Summon ×10\n💎 " + Fmt.commas(Config.SUMMON_COST_X10), func(): _summon(10), Vector2(200, 62))
	_buttons = [one, ten]

	row.add_child(one)
	row.add_child(ten)
	return row


func _summon(count: int) -> void:
	if _busy:
		return

	var pulled := GameState.summon(count, _origin)
	if pulled.is_empty():
		return

	_busy = true
	Audio.play("summon")
	_set_enabled(false)
	await _reveal(pulled)
	_set_enabled(true)
	_busy = false


func _set_enabled(enabled: bool) -> void:
	for b in _buttons:
		b.disabled = not enabled


func _show_placeholder() -> void:
	clear(_results)
	_results.add_child(UI.caption("Your pulls will appear here."))


func _reveal(cards: Array) -> void:
	clear(_results)
	await get_tree().process_frame

	# Reveal worst-to-best so the run builds toward its highlight.
	var ordered := cards.duplicate()
	ordered.sort_custom(func(a, b): return Config.rarity_index(a.rarity) < Config.rarity_index(b.rarity))

	for card in ordered:
		var view := CardView.create(card)
		view.pressed.connect(func(): CardDetail.open(self, card))
		_results.add_child(view)
		view.play_reveal()
		Audio.play(Audio.reveal_key_for(card.rarity))

		var pause := 0.11
		if Config.rarity_index(card.rarity) >= Config.rarity_index("Epic"):
			pause = 0.34
		await get_tree().create_timer(pause).timeout
