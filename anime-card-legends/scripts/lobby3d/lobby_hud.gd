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

	# Controls hint
	var hint := UI.caption(_controls_hint())
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_bottom = -Design.S4
	hint.offset_top = -Design.S6
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

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
	if Controls.using_controller():
		return ("Left stick move  ·  Right stick look  ·  A jump  ·  "
			+ "X interact  ·  L3 sprint  ·  B back")
	return ("WASD move  ·  Mouse look  ·  Space jump  ·  E / Enter interact  ·  "
		+ "Shift sprint  ·  Esc free cursor")


func show_prompt(message: String) -> void:
	_prompt_label.text = message
	_prompt_panel.visible = true


func hide_prompt() -> void:
	_prompt_panel.visible = false


func _on_currency(_gems: int, _gold: int) -> void:
	_refresh_currency()


func _refresh_currency() -> void:
	_currency.text = "💎 " + Fmt.compact(GameState.gems) + "    🪙 " + Fmt.compact(GameState.gold)


func _leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(back_route)
