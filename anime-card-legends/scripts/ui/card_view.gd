class_name CardView
extends Button

# =========================================================
# The card face.
#
# Layout mirrors a modern gacha card: full-bleed art with a rarity
# ribbon and dex number at the top, the card name beneath it, and a
# scrimmed lower third carrying the signature skill's name, its
# description, and the two headline stats.
#
#   var view := CardView.create(card)
#   view.selected = true
#   view.pressed.connect(...)
# =========================================================

var card: CardData
var selected: bool = false:
	set(value):
		selected = value
		if _select_overlay:
			_select_overlay.visible = value
			_check.visible = value

var _select_overlay: ColorRect
var _check: Label
var _style: StyleBoxFlat
var _compact := false


static func create(source: CardData, compact: bool = false) -> CardView:
	var view := CardView.new()
	view.card = source
	view._compact = compact
	view._build()
	return view


func _build() -> void:
	var width := Design.CARD_W
	var height := Design.CARD_H
	if _compact:
		width = Design.CARD_W_SM
		height = Design.CARD_H_SM

	custom_minimum_size = Vector2(width, height)
	flat = true
	focus_mode = Control.FOCUS_NONE
	text = ""
	# Deliberately NOT clipped: the rarity glow is a shadow drawn outside
	# the card's rect, and clipping here is what used to erase it. The
	# artwork gets its own clipped layer instead.
	clip_contents = false

	var aura := Design.rarity_aura(card.rarity)

	_style = ThemeBuilder.rarity_aura_style(card.rarity)
	_style.set_content_margin_all(0)
	var states: Array[String] = ["normal", "hover", "pressed", "focus", "disabled"]
	for state in states:
		add_theme_stylebox_override(state, _style)

	if aura > 0:
		_animate_aura(aura)
	if card.rarity == "Mythic" or card.rarity == "Secret":
		_animate_rainbow()

	_build_art()
	_build_top_scrim()
	_build_header()
	if not _compact:
		_build_skill_panel()
	_build_stat_bar()
	_build_selection_overlay()


# --- Art (fills the entire card, everything else sits on top) ------

func _build_art() -> void:
	# The clip lives here rather than on the card so the rarity glow,
	# which is drawn outside the card's bounds, survives.
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var art := TextureRect.new()
	art.texture = CardArt.for_card(card)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = CardArt.tint_for(card)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)


func _build_top_scrim() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_TOP_WIDE)
	scrim.offset_bottom = 64
	scrim.color = Design.alpha(Design.BG, 0.62)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


# --- Header: rarity ribbon + dex number, then the card name --------

func _build_header() -> void:
	var header := UI.vbox(2)
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = Design.S2
	header.offset_right = -Design.S2
	header.offset_top = Design.S2
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	var top_row := UI.hbox(Design.S1)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(top_row)

	top_row.add_child(_rarity_ribbon())

	if Mutations.is_mutated(card.modifier):
		top_row.add_child(_mutation_ribbon())

	top_row.add_child(UI.spacer())

	var dex := UI.label("#" + str(AbilityText.dex_number(card)), Design.FS_MICRO, Design.TEXT_DIM)
	dex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(dex)

	var name_size := Design.FS_HEADING
	if _compact:
		name_size = Design.FS_SMALL

	var name_label := UI.label(card.card_name.to_upper(), name_size, Design.TEXT)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_rarity_text_style(name_label, card.rarity)
	if Mutations.is_mutated(card.modifier):
		name_label.add_theme_color_override("font_color", Mutations.color(card.modifier))
	header.add_child(name_label)

	# Pull odds, printed on the face.
	var odds := GameState.gacha.card_odds(card)
	if odds > 0.0:
		var odds_label := UI.label(Fmt.odds(odds), Design.FS_MICRO, Design.TEXT_DIM)
		odds_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(odds_label)


func _mutation_ribbon() -> PanelContainer:
	var tint := Mutations.color(card.modifier)

	var ribbon := PanelContainer.new()
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Design.alpha(Design.BG, 0.85)
	style.set_border_width_all(1)
	style.border_color = tint
	style.set_corner_radius_all(3)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	ribbon.add_theme_stylebox_override("panel", style)

	var label := UI.label(Mutations.display_name(card.modifier).to_upper(), Design.FS_MICRO, tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.add_child(label)
	return ribbon


func _rarity_ribbon() -> PanelContainer:
	var accent := Design.rarity_color(card.rarity)

	var ribbon := PanelContainer.new()
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.set_corner_radius_all(3)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	ribbon.add_theme_stylebox_override("panel", style)

	var text_color := Design.TEXT_INVERT
	if card.rarity == "Secret":
		text_color = Design.BG

	var label := UI.label(card.rarity.to_upper(), Design.FS_MICRO, text_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.add_child(label)
	return ribbon


# --- Skill panel: signature move name + what it actually does ------

func _build_skill_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -112
	panel.offset_bottom = -28
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Design.alpha(Design.BG, 0.82)
	style.content_margin_left = Design.S2
	style.content_margin_right = Design.S2
	style.content_margin_top = Design.S2
	style.content_margin_bottom = Design.S1
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := UI.vbox(1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	var skill_name := UI.label(AbilityText.headline_name(card).to_upper(), Design.FS_SMALL, Design.ACCENT)
	skill_name.clip_text = true
	skill_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(skill_name)

	var body := UI.label(AbilityText.headline_body(card), Design.FS_MICRO, Design.TEXT_DIM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)


# --- Bottom bar: the two numbers that matter -----------------------

func _build_stat_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -26
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Design.alpha(Design.BG, 0.92)
	style.content_margin_left = Design.S2
	style.content_margin_right = Design.S2
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	bar.add_theme_stylebox_override("panel", style)
	add_child(bar)

	var row := UI.hbox(Design.S1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)

	var size := Design.FS_SMALL
	if _compact:
		size = Design.FS_MICRO

	row.add_child(_stat_chunk("sword", "DMG", Fmt.compact(card.attack), size, Design.ACCENT))
	row.add_child(UI.spacer())

	# A levelled card should be obvious in a grid of otherwise identical
	# copies, so the level only shows once it has been invested in.
	if card.level > 1:
		var level_label := UI.label("Lv%d" % card.level, size, Design.INFO)
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(level_label)
		row.add_child(UI.spacer())

	row.add_child(_stat_chunk("heart", "HP", Fmt.compact(card.health), size, Design.SUCCESS))


# Uses a real icon when one exists in art/icons/, otherwise just the label.
func _stat_chunk(icon_key: String, caption: String, value: String, size: int, tint: Color) -> HBoxContainer:
	var chunk := UI.hbox(3)
	chunk.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if Icons.has(icon_key):
		chunk.add_child(Icons.node(icon_key, size + 2, tint))

	var label := UI.label(caption + " " + value, size, tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chunk.add_child(label)
	return chunk


# --- Selection ------------------------------------------------------

func _build_selection_overlay() -> void:
	_select_overlay = ColorRect.new()
	_select_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_select_overlay.color = Design.alpha(Design.SUCCESS, 0.25)
	_select_overlay.visible = false
	_select_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_select_overlay)

	_check = UI.label("✓", Design.FS_DISPLAY, Design.SUCCESS, HORIZONTAL_ALIGNMENT_CENTER)
	_check.set_anchors_preset(Control.PRESET_FULL_RECT)
	_check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_check.visible = false
	_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_check)


# --- Animation ------------------------------------------------------

# Higher rarities breathe wider and slower, so the tier reads even in
# peripheral vision. "Reduce flashing" pins the glow at a steady size
# rather than removing it - the rarity is still legible.
func _animate_aura(base: int) -> void:
	if Settings.reduce_flashing:
		return

	var swing := Design.rarity_pulse(card.rarity)
	if swing <= 0:
		return
	var beat := Design.rarity_pulse_speed(card.rarity)

	var tween := create_tween().set_loops()
	tween.tween_property(_style, "shadow_size", base + swing, beat).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_style, "shadow_size", base, beat).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_rainbow() -> void:
	if Settings.reduce_flashing:
		return
	var tween := create_tween().set_loops()
	var steps := 6
	for i in range(steps + 1):
		var hue := float(i % steps) / float(steps)
		tween.tween_property(_style, "border_color", Color.from_hsv(hue, 0.75, 1.0), 0.45)


func play_reveal() -> void:
	modulate.a = 0.0
	scale = Vector2(0.6, 0.6)
	pivot_offset = custom_minimum_size / 2.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, Design.T_BASE)
	tween.tween_property(self, "scale", Vector2.ONE, Design.T_SLOW).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func apply_rarity_text_style(label: Label, rarity: String) -> void:
	label.add_theme_color_override("font_outline_color", Design.BG)
	label.add_theme_constant_override("outline_size", 4)

	match rarity:
		"Epic":
			label.add_theme_color_override("font_color", Design.rarity_color("Epic"))
		"Legendary":
			label.add_theme_color_override("font_color", Design.rarity_color("Legendary"))
		"Mythic":
			label.add_theme_color_override("font_color", Design.rarity_color("Mythic"))
		"Secret":
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_constant_override("outline_size", 6)
