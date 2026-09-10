class_name LobbyHUD
extends CanvasLayer

# =========================================================
# 2D overlay for any 3D world: title, controls, live currency, and the
# interaction prompt. The hub and the campaign zones share it - the
# caller sets the labels and the back destination before adding it.
# =========================================================

var title_text := "Lobby"
var subtitle_text := ""
var back_route := Routes.MAIN

var _prompt_panel: PanelContainer
var _prompt_label: Label
var _currency: Label
var _hint: Label
var _boost_panel: PanelContainer
var _boost_bar: ProgressBar
var _speed_label: Label
var _driving := false


func _init() -> void:
	layer = 10


func _ready() -> void:
	_build()
	EventBus.currency_changed.connect(_on_currency)
	_refresh_currency()


func _exit_tree() -> void:
	if EventBus.currency_changed.is_connected(_on_currency):
		EventBus.currency_changed.disconnect(_on_currency)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top bar
	var top := UI.hbox(Design.S3)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = Design.S5
	top.offset_right = -Design.S5
	top.offset_top = Design.S4
	root.add_child(top)

	var back := UI.button("← Back", _leave, Vector2(120, 44))
	top.add_child(back)

	var heading := UI.vbox(0)
	var title := UI.title(title_text)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(title)
	if subtitle_text != "":
		heading.add_child(UI.caption(subtitle_text))
	top.add_child(heading)

	top.add_child(UI.spacer())

	_currency = UI.label("", Design.FS_HEADING, Design.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_currency.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_currency)

	# The same way in as every 2D screen has, so settings is never more
	# than one press away wherever the player is standing.
	var cog := UI.button("⚙", _open_settings, Vector2(46, 44))
	cog.tooltip_text = "Settings"
	top.add_child(cog)

	if Settings.dev_mode:
		top.add_child(UI.pill("DEV", Design.DANGER))

	# Controls hint
	_hint = UI.caption(_controls_hint())
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_bottom = -Design.S4
	_hint.offset_top = -Design.S6
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)

	root.add_child(_build_boost_meter())

	# Interaction prompt
	_prompt_panel = UI.accent_panel(Design.ACCENT, Design.S3)
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.offset_left = -170
	_prompt_panel.offset_right = 170
	_prompt_panel.offset_top = -140
	_prompt_panel.offset_bottom = -84
	_prompt_panel.visible = false
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompt_panel)

	_prompt_label = UI.label("", Design.FS_HEADING, Design.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_child(_prompt_label)


# Named for whatever is actually plugged in, rather than always
# telling a controller player to press ENTER.
func _controls_hint() -> String:
	if _driving:
		if Controls.using_controller():
			return ("Left stick drive  ·  RB boost  ·  A jump, again to flip  ·  "
				+ "LB drift / air roll  ·  X or B to get out")
		return ("WASD drive  ·  Shift boost  ·  Space jump, again to flip  ·  "
			+ "Ctrl drift / air roll  ·  E or Esc to get out")

	if Controls.using_controller():
		return ("Left stick move  ·  Right stick look  ·  A jump  ·  "
			+ "X interact  ·  L3 sprint  ·  B back")
	return ("WASD move  ·  Mouse look  ·  Space jump  ·  E / Enter interact  ·  "
		+ "Shift sprint  ·  Esc free cursor")


# --- Driving ------------------------------------------------------------

func _build_boost_meter() -> Control:
	_boost_panel = UI.accent_panel(Color("#f5a623"), Design.S3)
	_boost_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_boost_panel.offset_left = -260
	_boost_panel.offset_right = -Design.S5
	_boost_panel.offset_top = -132
	_boost_panel.offset_bottom = -64
	_boost_panel.visible = false
	_boost_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var body := UI.vbox(Design.S1)
	_boost_panel.add_child(body)

	var row := UI.hbox(Design.S2)
	row.add_child(UI.label("BOOST", Design.FS_MICRO, Design.ACCENT))
	row.add_child(UI.spacer())
	_speed_label = UI.label("", Design.FS_MICRO, Design.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(_speed_label)
	body.add_child(row)

	_boost_bar = ProgressBar.new()
	_boost_bar.min_value = 0.0
	_boost_bar.max_value = 1.0
	_boost_bar.show_percentage = false
	_boost_bar.custom_minimum_size = Vector2(0, 14)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Design.ACCENT
	fill.set_corner_radius_all(4)
	_boost_bar.add_theme_stylebox_override("fill", fill)
	body.add_child(_boost_bar)

	return _boost_panel


func set_driving(driving: bool) -> void:
	_driving = driving
	if _boost_panel != null:
		_boost_panel.visible = driving
	if _hint != null:
		_hint.text = _controls_hint()


func show_boost(fraction: float, speed: float) -> void:
	if _boost_bar != null:
		_boost_bar.value = fraction
	if _speed_label != null:
		# km/h reads better than m/s for something being driven.
		_speed_label.text = "%d km/h" % int(round(speed * 3.6))


func show_prompt(message: String) -> void:
	_prompt_label.text = message
	_prompt_panel.visible = true


func hide_prompt() -> void:
	_prompt_panel.visible = false


func _on_currency(_gems: int, _gold: int) -> void:
	_refresh_currency()


func _refresh_currency() -> void:
	_currency.text = "💎 " + Fmt.compact(GameState.gems) + "    🪙 " + Fmt.compact(GameState.gold)


func _open_settings() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Back out of settings returns here, not to the 2D main menu.
	Routes.settings_return = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file(Routes.SETTINGS)


func _leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(back_route)
