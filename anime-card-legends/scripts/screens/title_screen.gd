extends Control

# =========================================================
# TITLE SCREEN - the first thing the game shows.
#
# Deliberately NOT a Screen subclass: it wants none of the shared
# chrome (back arrow, currency readout, weather banner), and it runs
# before any save slot exists.
#
# ARTWORK, all optional, in res://art/ui/
#   title.png   full-bleed splash behind everything
#   logo.png    wordmark drawn over it
#
# If a logo is supplied it is drawn and no text title appears. If only
# a splash is supplied, the splash is assumed to carry the game's name
# already - which is the usual case - so no text is drawn over it. With
# neither, the name is set as type. Set FORCE_WORDMARK to true below to
# always draw the text as well.
# =========================================================

const FORCE_WORDMARK := false

const TITLE_TEXT := "ANIME CARD LEGENDS"
const TAGLINE := "Collect. Ascend. Climb the tower."

# Names that mean "this is the title art" - one of these is assumed to
# already carry the game's name. menu_bg is only a last resort backdrop
# and says nothing about the title, so the wordmark still gets drawn
# over it.
const SPLASH_NAMES: Array[String] = ["title", "splash", "title_bg"]
const FALLBACK_SPLASH: Array[String] = ["menu_bg"]
const LOGO_NAMES: Array[String] = ["logo", "wordmark", "title_logo"]
const IMAGE_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]

# How far the splash drifts, as a fraction of its size. Slow enough to
# read as alive rather than as movement.
const DRIFT_SCALE := 1.07
const DRIFT_SECONDS := 18.0

var _menu: VBoxContainer
var _splash: TextureRect
var _first_button: Button

# True only when the splash came from a title-specific filename, which
# is the case where drawing the name in type would fight the art.
var _splash_is_titled := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.play_music("music_menu")

	# Arriving here means leaving whatever profile was open.
	if GameState.has_active_slot():
		GameState.close_slot()

	_build_background()
	_build_layout()
	_animate_in()


# --- Background -----------------------------------------------------

func _build_background() -> void:
	var base := ColorRect.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.color = Design.BG
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	var splash := _find_image(SPLASH_NAMES)
	_splash_is_titled = splash != null
	if splash == null:
		splash = _find_image(FALLBACK_SPLASH)
	if splash == null:
		return

	# Clipped so the slow drift never shows an edge.
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	_splash = TextureRect.new()
	_splash.texture = splash
	_splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash.resized.connect(_recentre_splash)
	frame.add_child(_splash)

	# A scrim only under the menu column, so the top two thirds of the
	# splash are seen at full strength.
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Design.alpha(Design.BG, 0.34)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


# Scaling happens around the middle of the image, not its corner.
func _recentre_splash() -> void:
	if _splash != null:
		_splash.pivot_offset = _splash.size * 0.5


func _find_image(names: Array[String]) -> Texture2D:
	for base_name in names:
		for ext in IMAGE_EXTENSIONS:
			var path := "res://art/ui/" + base_name + "." + ext
			if ResourceLoader.exists(path):
				return load(path)
	return null


# --- Layout ---------------------------------------------------------

func _build_layout() -> void:
	var margin := UI.margin(Design.S7)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var column := UI.vbox(Design.S4)
	margin.add_child(column)

	column.add_child(UI.spacer())
	_build_masthead(column)
	column.add_child(UI.spacer())

	# The menu sits at the bottom-left, out of the splash's way.
	var row := UI.hbox(0)
	_menu = UI.vbox(Design.S2)
	_menu.custom_minimum_size = Vector2(320, 0)
	row.add_child(_menu)
	row.add_child(UI.spacer())
	column.add_child(row)

	_build_menu()
	column.add_child(_build_footer())


func _build_masthead(column: VBoxContainer) -> void:
	var logo := _find_image(LOGO_NAMES)

	if logo != null:
		var art := TextureRect.new()
		art.texture = logo
		art.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		art.custom_minimum_size = Vector2(0, 190)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(art)
		return

	# A splash named title/splash/title_bg almost certainly has the name
	# painted into it already, so setting it again in type would just
	# fight the art. A generic backdrop tells us nothing, so the name is
	# still drawn over that one.
	if _splash_is_titled and not FORCE_WORDMARK:
		return

	var title := UI.label(TITLE_TEXT, 64, Design.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_outline_color", Design.BG)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_color", Design.ACCENT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	var tagline := UI.label(TAGLINE, Design.FS_HEADING, Design.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tagline)


func _build_menu() -> void:
	var recent := _most_recent_slot()

	if recent > 0:
		var summary := SaveManager.slot_summary(recent)
		_add_item("Continue", "Slot %d  ·  %s cards" % [
			recent, Fmt.commas(int(summary.get("cards", 0)))],
			func(): _enter(recent), true)

	_add_item("New Game", _new_game_blurb(), _on_new_game, recent <= 0)
	_add_item("Load Game", "Choose a profile", func(): Routes.go(self, Routes.SLOTS), false)
	_add_item("Settings", "Audio, battle speed, assets", func(): Routes.go(self, Routes.SETTINGS), false)
	_add_item("Quit", "", func(): get_tree().quit(), false)


func _add_item(label: String, blurb: String, on_press: Callable, primary: bool) -> void:
	var button: Button
	if primary:
		button = UI.primary_button(label, on_press, Vector2(0, 56))
	else:
		button = UI.button(label, on_press, Vector2(0, 52))

	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mark_focus(button)

	# Arrow keys, the d-pad and the controller's A button drive this for
	# free, because Godot's own UI focus handling uses ui_* - which is
	# exactly what those actions are for, unlike walking around a city.
	if _first_button == null:
		_first_button = button

	_menu.add_child(button)

	if blurb != "":
		var caption := UI.caption("    " + blurb)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu.add_child(caption)


# The shared button theme draws focus exactly like rest, which is fine
# for a mouse and useless for a controller: nothing shows which item is
# selected. These get a lit left edge instead.
func _mark_focus(button: Button) -> void:
	var focused := ThemeBuilder.bordered_style(Design.ACCENT_SOFT, Design.ACCENT, 0, Design.R_MD)
	focused.border_width_left = 4
	focused.content_margin_left = Design.S4
	focused.content_margin_right = Design.S4
	focused.content_margin_top = Design.S3
	focused.content_margin_bottom = Design.S3
	button.add_theme_stylebox_override("focus", focused)

	button.focus_entered.connect(func():
		button.add_theme_color_override("font_color", Design.ACCENT)
		Audio.play("hover"))
	button.focus_exited.connect(func():
		button.remove_theme_color_override("font_color"))


func _build_footer() -> Control:
	var row := UI.hbox(Design.S3)
	row.add_child(UI.caption(TITLE_TEXT.capitalize()))
	row.add_child(UI.spacer())
	if Controls.using_controller():
		row.add_child(UI.caption("D-pad to choose  ·  A to confirm"))
	else:
		row.add_child(UI.caption("↑ ↓ to choose  ·  Enter to confirm"))
	return row


# --- Profiles -------------------------------------------------------

# The slot played most recently, or 0 when there are no saves at all.
func _most_recent_slot() -> int:
	var best := 0
	var best_time := -1

	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var summary := SaveManager.slot_summary(slot)
		if not summary.get("exists", false):
			continue
		var played := int(summary.get("played_at", 0))
		if played > best_time:
			best_time = played
			best = slot

	return best


func _first_empty_slot() -> int:
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		if not SaveManager.slot_exists(slot):
			return slot
	return 0


func _new_game_blurb() -> String:
	var free := _first_empty_slot()
	if free > 0:
		return "Start in slot %d" % free
	return "All profiles are full — pick one to replace"


func _on_new_game() -> void:
	var free := _first_empty_slot()
	if free > 0:
		_enter(free)
		return
	# Nothing free: the profile screen is where a slot gets deleted.
	EventBus.toast("All three profiles are in use. Delete one to start fresh.", "info")
	Routes.go(self, Routes.SLOTS)


# Both New Game and Continue land in the city - it is the hub now, and
# arriving anywhere else would make the player walk to it.
func _enter(slot: int) -> void:
	GameState.open_slot(slot)
	# The city is the hub from here on.
	Routes.hub_return = Routes.LOBBY
	Routes.go(self, Routes.LOBBY)


# --- Motion ---------------------------------------------------------

func _animate_in() -> void:
	if _splash != null:
		_recentre_splash()
		var drift := create_tween().set_loops()
		drift.tween_property(_splash, "scale", Vector2(DRIFT_SCALE, DRIFT_SCALE),
			DRIFT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(_splash, "scale", Vector2.ONE,
			DRIFT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Menu items arrive one after another rather than all at once.
	var delay := 0.0
	for child in _menu.get_children():
		var item := child as Control
		if item == null:
			continue
		item.modulate.a = 0.0
		var fade := create_tween()
		fade.tween_interval(delay)
		fade.tween_property(item, "modulate:a", 1.0, Design.T_BASE)
		delay += 0.06

	if _first_button != null:
		_first_button.call_deferred("grab_focus")
