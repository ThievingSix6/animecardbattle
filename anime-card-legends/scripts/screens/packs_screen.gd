extends Screen

# =========================================================
# SUMMON.
#
# Each banner is a real pool with its own artwork, its own themed roster
# and its own pity counters - picking one changes what can actually be
# pulled, not just the label above the button.
# =========================================================

var _results: GridContainer
var _splash: Control
var _info: VBoxContainer
var _tabs: HBoxContainer
var _buttons: Array[Button] = []
var _banner := Banners.STANDARD
var _busy := false


func screen_title() -> String: return "Summon"
# This screen scrolls its own results region, so the base page scroll
# would just nest one scroll inside another.
func scrolls_content() -> bool: return false


func build_content() -> void:
	_tabs = _build_tabs()
	content.add_child(_tabs)

	_splash = _build_splash()
	content.add_child(_splash)

	_info = UI.vbox(Design.S2)
	content.add_child(_info)
	_refresh_info()

	content.add_child(_build_actions())
	content.add_child(UI.section("Results"))

	var scroll := UI.scroll()
	_results = UI.grid(5, Design.S6)
	scroll.add_child(_results)
	content.add_child(scroll)

	_show_placeholder()

	# Re-entered on every banner switch, so this must connect once.
	bind(EventBus.currency_changed, _on_currency)


func _exit_tree() -> void:
	super()
	unbind(EventBus.currency_changed, _on_currency)


func _on_currency(_gems: int, _gold: int) -> void:
	_refresh_actions()


# --- Banner selection ---------------------------------------------------

func _build_tabs() -> HBoxContainer:
	var row := UI.hbox(Design.S2)
	var group := ButtonGroup.new()

	for id in Banners.ids():
		var banner_id := id
		# Short labels: seven full banner names will not fit one row.
		var b := UI.button(Banners.short_name(banner_id), Callable(), Vector2(0, 42))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = (banner_id == _banner)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_color_override("font_pressed_color", Design.TEXT_INVERT)
		if banner_id == _banner:
			b.add_theme_color_override("font_color", Banners.accent(banner_id))
		b.pressed.connect(func(): _select(banner_id))
		row.add_child(b)

	return row


func _select(banner_id: String) -> void:
	if banner_id == _banner:
		return
	_banner = banner_id
	_rebuild()


func _rebuild() -> void:
	for child in content.get_children():
		child.queue_free()
	call_deferred("build_content")


# --- Splash --------------------------------------------------------------

# Uses res://art/banners/<id>.png when it exists. With no image the
# banner paints its own gradient from its accent colour, so a missing
# file looks deliberate rather than broken.
func _build_splash() -> Control:
	var accent := Banners.accent(_banner)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",
		ThemeBuilder.aura_style(Design.SURFACE, accent, 2, 14, 0.35, Design.R_LG))

	# The clip sits on the inner stack, not the panel, so the panel's own
	# glow is not shaved off along with the artwork's overflow.
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, 168)
	stack.clip_contents = true
	frame.add_child(stack)

	var art := TextureRect.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var supplied := Banners.art(_banner)
	if supplied != null:
		art.texture = supplied
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		art.texture = _gradient_for(accent)
		art.stretch_mode = TextureRect.STRETCH_SCALE
	stack.add_child(art)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Design.alpha(Design.BG, 0.5)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(scrim)

	var text := UI.vbox(Design.S1)
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.offset_left = Design.S5
	text.offset_right = -Design.S5
	text.offset_top = Design.S4
	text.offset_bottom = -Design.S4
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(text)

	var title := UI.label("✦ " + Banners.display_name(_banner).to_upper() + " ✦",
		Design.FS_DISPLAY, accent, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_outline_color", Design.BG)
	title.add_theme_constant_override("outline_size", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)

	var tagline := UI.label(Banners.tagline(_banner), Design.FS_BODY, Design.TEXT_DIM,
		HORIZONTAL_ALIGNMENT_CENTER)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(tagline)

	if supplied == null:
		text.add_child(UI.label(_theme_glyphs(), Design.FS_TITLE, Design.alpha(accent, 0.8),
			HORIZONTAL_ALIGNMENT_CENTER))

	return frame


# A diagonal wash in the banner's colour, generated rather than shipped.
func _gradient_for(accent: Color) -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.set_color(0, accent.darkened(0.25))
	ramp.set_color(1, Design.BG)

	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.width = 512
	texture.height = 178
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(1.0, 1.0)
	return texture


# The elements and roles this banner is built around, as their icons.
func _theme_glyphs() -> String:
	var banner := Banners.get_banner(_banner)
	var marks: Array[String] = []
	for element in banner["elements"]:
		marks.append(str(Design.ELEMENT_ICON.get(str(element), "")))
	for role in banner["roles"]:
		marks.append(str(Design.ROLE_ICON.get(str(role), "")))
	if marks.is_empty():
		return "✦"
	return "   ".join(marks)


# --- Odds, featured roster and pity -------------------------------------

func _refresh_info() -> void:
	clear(_info)

	var pool_size := GameState.gacha.banner_pool_size(_banner)
	var featured := GameState.gacha.featured_cards(_banner)

	var summary := UI.hbox(Design.S3)
	if pool_size == 0:
		summary.add_child(UI.pill("no cards match this banner yet", Design.DANGER))
	else:
		summary.add_child(UI.pill("%d cards in this pool" % pool_size, Banners.accent(_banner)))

	var floor_rarity := Banners.floor_rarity(_banner)
	if floor_rarity != "Common":
		summary.add_child(UI.pill("never below " + floor_rarity, Design.rarity_color(floor_rarity)))

	summary.add_child(UI.pill(_pity_text(), Design.INFO))
	summary.add_child(UI.spacer())
	_info.add_child(summary)

	if not featured.is_empty():
		var names: Array[String] = []
		for i in mini(6, featured.size()):
			names.append("%s (%s)" % [featured[i].card_name, featured[i].rarity])
		var line := UI.label("Rate-up: " + ", ".join(names), Design.FS_SMALL, Design.TEXT_DIM)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info.add_child(line)

	# Odds are printed for the tiers this banner can actually produce.
	var odds: Array[String] = []
	for rarity in Config.RARITY_ORDER:
		if Config.rarity_index(rarity) < Config.rarity_index(floor_rarity):
			continue
		if GameState.gacha.candidates(rarity, _banner).is_empty():
			continue
		odds.append("%s %s" % [rarity, Fmt.odds(GameState.gacha.card_odds_for_rarity(rarity))])
	var odds_label := UI.label(" · ".join(odds), Design.FS_MICRO, Design.TEXT_MUTED)
	odds_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.add_child(odds_label)


func _pity_text() -> String:
	var remaining := GameState.gacha.pulls_until_legendary(_banner)
	if remaining <= 0:
		return "Legendary guaranteed on the next pull"
	return "Legendary guaranteed in %d pull(s)" % remaining


# --- Actions -------------------------------------------------------------

func _build_actions() -> Control:
	var row := UI.hbox(Design.S4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var one := UI.button("Summon ×1\n💎 " + Fmt.commas(Banners.cost(_banner, 1)),
		func(): _summon(1), Vector2(210, 62))
	var ten := UI.primary_button("Summon ×10\n💎 " + Fmt.commas(Banners.cost(_banner, 10)),
		func(): _summon(10), Vector2(210, 62))
	_buttons = [one, ten]

	row.add_child(one)
	row.add_child(ten)
	_refresh_actions()
	return row


# Greys out what the player cannot currently afford, rather than letting
# them press it and get a toast.
func _refresh_actions() -> void:
	if _buttons.size() < 2:
		return
	if _busy:
		return

	var empty := GameState.gacha.banner_pool_size(_banner) == 0
	_buttons[0].disabled = empty or GameState.gems < Banners.cost(_banner, 1)
	_buttons[1].disabled = empty or GameState.gems < Banners.cost(_banner, 10)


func _summon(count: int) -> void:
	if _busy:
		return

	var pulled := GameState.summon(count, _banner)
	if pulled.is_empty():
		return

	_busy = true
	Audio.play("summon")
	_set_enabled(false)
	await _reveal(pulled)
	_busy = false
	_set_enabled(true)
	_refresh_info()


func _set_enabled(enabled: bool) -> void:
	for b in _buttons:
		b.disabled = not enabled
	if enabled:
		_refresh_actions()


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
