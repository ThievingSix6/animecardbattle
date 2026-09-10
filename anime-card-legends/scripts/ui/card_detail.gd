class_name CardDetail
extends Control

# =========================================================
# Full-card inspector: art, lore, abilities, odds, stats, and the
# sell/merge actions. Emits `changed` when it mutates the collection
# so the host screen can refresh without polling.
# =========================================================

signal changed

var card: CardData


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

	var accent := Design.rarity_color(card.rarity)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	panel.add_theme_stylebox_override("panel", ThemeBuilder.aura_style(
		Design.SURFACE, accent,
		Design.RARITY_BORDER.get(card.rarity, 2),
		Design.RARITY_AURA.get(card.rarity, 0)
	))
	center.add_child(panel)

	var body := UI.vbox(Design.S3)
	panel.add_child(body)

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

	var owned: int = GameState.collection.copies_of(card.card_id)
	var column := UI.vbox(Design.S2)
	column.add_child(row)

	if owned > 1:
		var next_tier := Config.next_rarity(card.rarity)
		var text := "Owned: " + Fmt.commas(owned)
		if next_tier != "":
			text += "   ·   " + Fmt.commas(min(owned, Config.MERGE_REQUIREMENT)) + "/" + str(Config.MERGE_REQUIREMENT) + " to merge into " + next_tier
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


func _build_actions() -> Control:
	var row := UI.hbox(Design.S2)

	if GameState.collection.can_merge(card.card_id):
		var next_tier := Config.next_rarity(card.rarity)
		var merge := UI.primary_button("🔀 Merge %d → %s" % [Config.MERGE_REQUIREMENT, next_tier], _on_merge)
		merge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(merge)

	var sell := UI.button("💰 Sell · " + Fmt.compact(card.sell_value), _on_sell)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sell)

	return row


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
	dialog.dialog_text = "Sell %s for %s gold?%s" % [card.card_name, Fmt.commas(card.sell_value), warning]
	add_child(dialog)
	dialog.confirmed.connect(func():
		GameState.sell_card(card.card_id)
		changed.emit()
		close()
	)
	dialog.popup_centered()


func close() -> void:
	queue_free()
