class_name BattleCard
extends PanelContainer

# =========================================================
# A fighter's on-screen presence: portrait, HP/energy bars, active
# marker, floating combat text. Purely reactive - it renders whatever
# state the simulation reports.
# =========================================================

var combatant: Combatant

var _hp_bar: ProgressBar
var _hp_label: Label
var _energy_bar: ProgressBar
var _marker: Label
var _fx_layer: Control
var _style: StyleBoxFlat


static func create(source: Combatant) -> BattleCard:
	var view := BattleCard.new()
	view.combatant = source
	view._build()
	return view


func _build() -> void:
	var card := combatant.data
	custom_minimum_size = Vector2(150, 218)
	pivot_offset = Vector2(75, 109)

	var accent := Design.rarity_color(card.rarity)
	var border_width: int = Design.RARITY_BORDER.get(card.rarity, 2)
	_style = ThemeBuilder.aura_style(Design.SURFACE, accent, border_width, 0, Design.R_MD)
	_style.set_content_margin_all(Design.S2)
	add_theme_stylebox_override("panel", _style)

	var column := UI.vbox(Design.S1)
	add_child(column)

	_marker = UI.label("▶ ACTIVE", Design.FS_MICRO, Design.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_marker.visible = false
	column.add_child(_marker)

	column.add_child(_build_portrait(card))
	column.add_child(UI.label(card.card_name, Design.FS_SMALL, Design.TEXT, HORIZONTAL_ALIGNMENT_CENTER))

	var role_text: String = "%s %s" % [Design.ROLE_ICON.get(card.role, ""), card.role]
	var subtitle := UI.label(role_text, Design.FS_MICRO, Design.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(subtitle)

	column.add_child(_build_hp())
	column.add_child(_build_energy())

	refresh()


func _build_portrait(card: CardData) -> Control:
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(0, 74)
	frame.clip_contents = false

	var clipper := Control.new()
	clipper.set_anchors_preset(Control.PRESET_FULL_RECT)
	clipper.clip_contents = true
	frame.add_child(clipper)

	var art := TextureRect.new()
	art.texture = CardArt.for_card(card)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = CardArt.tint_for(card)
	clipper.add_child(art)

	# Floating numbers live outside the clip so they can rise past the frame.
	_fx_layer = Control.new()
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_fx_layer)

	return frame


func _build_hp() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 18)

	_hp_bar = ProgressBar.new()
	_hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_bar.show_percentage = false
	_hp_bar.max_value = combatant.max_hp
	_hp_bar.value = combatant.hp
	holder.add_child(_hp_bar)

	_hp_label = UI.label("", Design.FS_MICRO, Design.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(_hp_label)

	return holder


func _build_energy() -> Control:
	_energy_bar = ProgressBar.new()
	_energy_bar.custom_minimum_size = Vector2(0, 6)
	_energy_bar.show_percentage = false
	_energy_bar.max_value = Config.ENERGY_MAX
	_energy_bar.value = combatant.energy

	var fill := StyleBoxFlat.new()
	fill.bg_color = Design.ENERGY
	fill.set_corner_radius_all(3)
	_energy_bar.add_theme_stylebox_override("fill", fill)
	return _energy_bar


# --- Reactive updates ---------------------------------------------

func refresh() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_hp_bar, "value", combatant.hp, Design.T_FAST)
	tween.tween_property(_energy_bar, "value", combatant.energy, Design.T_FAST)

	_hp_label.text = "%s / %s" % [Fmt.compact(combatant.hp), Fmt.compact(combatant.max_hp)]

	var ratio := combatant.hp_ratio()
	var bar_color := Design.SUCCESS
	if ratio <= 0.2:
		bar_color = Design.DANGER
	elif ratio <= 0.5:
		bar_color = Design.ACCENT

	var fill := StyleBoxFlat.new()
	fill.bg_color = bar_color
	fill.set_corner_radius_all(Design.R_SM)
	_hp_bar.add_theme_stylebox_override("fill", fill)


func set_active(active: bool) -> void:
	_marker.visible = active and combatant.alive
	var target_scale := Vector2.ONE
	if active:
		target_scale = Vector2(1.06, 1.06)
	var tween := create_tween()
	tween.tween_property(self, "scale", target_scale, Design.T_FAST)


func play_hit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.6, 1.2, 1.2), 0.06)
	tween.tween_property(self, "modulate", Color.WHITE, 0.14)


func play_death() -> void:
	_marker.visible = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(0.35, 0.35, 0.4, 0.55), Design.T_BASE)
	tween.tween_property(self, "scale", Vector2(0.94, 0.94), Design.T_BASE)


func float_text(value: String, tint: Color) -> void:
	if _fx_layer == null:
		return

	var popup := UI.label(value, Design.FS_HEADING, tint, HORIZONTAL_ALIGNMENT_CENTER)
	popup.add_theme_color_override("font_outline_color", Design.BG)
	popup.add_theme_constant_override("outline_size", 4)
	popup.custom_minimum_size = Vector2(48, 0)
	popup.position = Vector2(_fx_layer.size.x * 0.5 - 24.0, _fx_layer.size.y * 0.4)
	_fx_layer.add_child(popup)

	var rise_to := popup.position.y - 46.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", rise_to, 0.7)
	tween.tween_property(popup, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(popup.queue_free)
