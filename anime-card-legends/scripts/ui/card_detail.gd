class_name CardDetail
extends Control

# =========================================================
# Full-card inspector: art, lore, abilities, odds, stats, and the
# sell/merge actions. Emits `changed` when it mutates the collection
# so the host screen can refresh without polling.
# =========================================================

signal changed

var card: CardData

var _body: VBoxContainer


static func open(host: Control, source: CardData) -> CardDetail:
	var detail := CardDetail.new()
	detail.card = source
	host.add_child(detail)
	detail._build()
	return detail


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Design.OVERLAY
	add_child(scrim)

	var dismiss := Button.new()
	dismiss.flat = true
	dismiss.text = ""
	dismiss.set_anchors_preset(Control.PRESET_FULL_RECT)
	dismiss.pressed.connect(close)
	add_child(dismiss)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", ThemeBuilder.rarity_aura_style(card.rarity))
	center.add_child(panel)

	# The sheet grew a level track, so it can outgrow a short window.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_child(scroll)

	_body = UI.vbox(Design.S3)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)

	_populate()


# Rebuilt in place after a level-up so every number on the sheet moves
# at once, without closing and reopening it.
func _populate() -> void:
	for child in _body.get_children():
		child.queue_free()

	var body := _body
	body.add_child(_build_topbar())
	body.add_child(_build_hero())
	body.add_child(_build_identity())

	if card.description != "":
		var lore := UI.label(card.description, Design.FS_SMALL, Design.TEXT_DIM)
		lore.autowrap_mode = TextServer.AUTOWRAP_WORD
		body.add_child(lore)

	body.add_child(UI.separator())
	_build_abilities(body)
	body.add_child(UI.separator())
	body.add_child(_build_stats())

	if GameState.collection.has(card.card_id):
		body.add_child(UI.separator())
		body.add_child(_build_level())

	body.add_child(_build_actions())


func _build_topbar() -> HBoxContainer:
	var row := UI.hbox(Design.S2)

	var rarity_text := card.rarity.to_upper()
	if card.modifier != "" and card.modifier != "Normal":
		rarity_text += " · " + card.modifier.to_upper()
	row.add_child(UI.pill(rarity_text, Design.rarity_color(card.rarity)))

	var odds: float = GameState.gacha.card_odds(card)
	if odds > 0.0:
		row.add_child(UI.pill("🎲 " + Fmt.odds(odds)))

	row.add_child(UI.spacer())
	row.add_child(UI.button("✕", close, Vector2(36, 36)))
	return row


func _build_hero() -> Control:
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(0, 190)
	frame.clip_contents = true
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var art := TextureRect.new()
	art.texture = CardArt.for_card(card)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = CardArt.tint_for(card)
	frame.add_child(art)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	scrim.offset_top = -60
	scrim.color = Design.alpha(Design.BG, 0.7)
	frame.add_child(scrim)

	var name_label := UI.label(card.card_name, Design.FS_TITLE, Design.TEXT)
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -46
	name_label.offset_left = Design.S3
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	CardView.apply_rarity_text_style(name_label, card.rarity)
	frame.add_child(name_label)

	return frame


func _build_identity() -> Control:
	var row := UI.hbox(Design.S2)
	var role_mark: String = Design.ROLE_ICON.get(card.role, "")
	row.add_child(UI.pill(role_mark + " " + card.role))
	if card.element != "":
		var elem_mark: String = Design.ELEMENT_ICON.get(card.element, "")
		row.add_child(UI.pill(elem_mark + " " + card.element, Design.element_color(card.element)))
	if card.faction != "":
		row.add_child(UI.pill(card.faction))
	if card.banner_id != "" and card.banner_id != Banners.STANDARD:
		row.add_child(UI.pill("✦ " + Banners.short_name(card.banner_id),
			Banners.accent(card.banner_id)))

	var owned: int = GameState.collection.copies_of(card.card_id)
	var column := UI.vbox(Design.S2)
	column.add_child(row)

	if owned > 1:
		var next_tier := Config.next_rarity(card.rarity)
		var text := "Owned: " + Fmt.commas(owned)
		if next_tier != "":
			text += "   ·   " + Fmt.commas(mini(owned, Config.MERGE_REQUIREMENT)) + "/" + str(Config.MERGE_REQUIREMENT) + " to merge into " + next_tier
		column.add_child(UI.caption(text))

	return column


func _build_abilities(parent: VBoxContainer) -> void:
	_ability_row(parent, "BASIC", card.basic_ability, AbilityText.basic(card))
	_ability_row(parent, "ULTIMATE", card.ultimate_ability, AbilityText.ultimate(card))
	if card.skill_id != "":
		_ability_row(parent, Skills.family_label(card.skill_id).to_upper(),
			AbilityText.passive_name(card), AbilityText.passive(card))


func _ability_row(parent: VBoxContainer, kind: String, ability_name: String, body_text: String) -> void:
	if ability_name == "":
		return

	var block := UI.vbox(2)
	block.add_child(UI.label(kind, Design.FS_MICRO, Design.TEXT_MUTED))
	block.add_child(UI.label(ability_name, Design.FS_BODY, Design.ACCENT))

	if body_text != "":
		var body := UI.label(body_text, Design.FS_SMALL, Design.TEXT_DIM)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD
		block.add_child(body)

	parent.add_child(block)




func _build_stats() -> Control:
	var row := UI.hbox(Design.S2)
	row.add_child(UI.stat_block("ATK", Fmt.compact(card.attack), Design.DANGER))
	row.add_child(UI.stat_block("DEF", Fmt.compact(card.defense), Design.INFO))
	row.add_child(UI.stat_block("HP", Fmt.compact(card.health), Design.SUCCESS))
	row.add_child(UI.stat_block("SPD", Fmt.compact(card.speed), Design.ENERGY))
	return row


# --- Levels: gold into stats ------------------------------------------

func _build_level() -> Control:
	var box := UI.vbox(Design.S2)

	var ceiling := Leveling.effective_max(card)
	var header := UI.hbox(Design.S2)
	header.add_child(UI.label("Level %d" % card.level, Design.FS_HEADING, Design.ACCENT))
	header.add_child(UI.spacer())
	header.add_child(UI.caption("cap %d for %s" % [ceiling, card.rarity]))
	box.add_child(header)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = float(card.level) / float(maxi(ceiling, 1))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	box.add_child(bar)

	if Leveling.is_maxed(card):
		box.add_child(UI.caption(
			"Fully levelled. Merging into " + Config.next_rarity(card.rarity)
			+ " would raise the cap."))
		return box

	# What the next level actually buys, spelled out rather than implied.
	var gain := Leveling.preview_gain(card)
	box.add_child(UI.caption("Next level:  +%d ATK  ·  +%d DEF  ·  +%d HP  ·  +%d SPD" % [
		int(gain["attack"]), int(gain["defense"]), int(gain["health"]), int(gain["speed"])]))

	var cost := Leveling.cost(card)
	var affordable := GameState.collection.affordable_level(card.card_id, GameState.gold)

	var row := UI.hbox(Design.S2)

	var one := UI.primary_button("Level up · 🪙 " + Fmt.compact(cost), func(): _on_level(1))
	one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	one.disabled = GameState.gold < cost
	row.add_child(one)

	if affordable > card.level + 1:
		var jump := affordable - card.level
		var many := UI.button("+%d · 🪙 %s" % [
			jump, Fmt.compact(Leveling.cost_to_reach(card, affordable))],
			_on_level_max)
		many.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(many)

	box.add_child(row)

	if GameState.gold < cost:
		box.add_child(UI.caption("You have %s gold." % Fmt.compact(GameState.gold)))

	return box


func _on_level(levels: int) -> void:
	var bought := GameState.level_up_card(card.card_id, levels)
	if bought > 0:
		changed.emit()
		_populate()


func _on_level_max() -> void:
	var bought := GameState.level_up_card_max(card.card_id)
	if bought > 0:
		EventBus.toast("%s reached level %d." % [card.card_name, card.level], "success")
		changed.emit()
		_populate()


func _build_actions() -> Control:
	var row := UI.hbox(Design.S2)

	if GameState.collection.can_merge(card.card_id):
		var next_tier := Config.next_rarity(card.rarity)
		var merge := UI.primary_button("🔀 Merge %d → %s" % [Config.MERGE_REQUIREMENT, next_tier], _on_merge)
		merge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(merge)

	var sell := UI.button("💰 Sell · " + Fmt.compact(_sell_price()), _on_sell)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sell)

	return row


# What selling the last copy actually pays: base value plus half the
# gold sunk into its levels.
func _sell_price() -> int:
	var price := card.sell_value
	if GameState.collection.copies_of(card.card_id) <= 1:
		price += int(round(float(Leveling.invested_gold(card)) * Leveling.REFUND_RATE))
	return price


func _on_merge() -> void:
	if GameState.merge_card(card.card_id):
		changed.emit()
		close()


func _on_sell() -> void:
	var owned: int = GameState.collection.copies_of(card.card_id)
	var warning := ""
	if owned <= 1:
		warning = "\n\nThis is your only copy."
		if GameState.collection.in_team(card.card_id):
			warning += " It will also be removed from your team."

	var dialog := ConfirmationDialog.new()
	dialog.title = "Sell Card"
	dialog.dialog_text = "Sell %s for %s gold?%s" % [card.card_name, Fmt.commas(_sell_price()), warning]
	add_child(dialog)
	dialog.confirmed.connect(func():
		GameState.sell_card(card.card_id)
		changed.emit()
		close()
	)
	dialog.popup_centered()


func close() -> void:
	queue_free()
