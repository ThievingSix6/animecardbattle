class_name Screen
extends Control

# =========================================================
# BASE SCREEN - owns all shared chrome: background, header bar with
# back navigation and title, live currency readout, weather banner,
# content region, and toast notifications.
#
# Subclasses implement build_content() and get nothing else to worry
# about. Previously every screen re-implemented all of this by hand.
# =========================================================

var content: VBoxContainer
var header_actions: HBoxContainer

var _currency_label: Label
var _weather_banner: PanelContainer
var _weather_label: Label
var _toast_layer: VBoxContainer


# --- Subclass API -------------------------------------------------

func screen_title() -> String:
	return ""

func back_route() -> String:
	return Routes.MAIN

func shows_currency() -> bool:
	return true

func shows_weather() -> bool:
	return true

func requires_slot() -> bool:
	return true

func build_content() -> void:
	pass

# ------------------------------------------------------------------


func _ready() -> void:
	# Every screen except profile select needs an open save slot.
	if requires_slot() and not GameState.has_active_slot():
		call_deferred("_bounce_to_slots")
		return

	_build_chrome()
	build_content()
	_connect_signals()
	_refresh_currency()
	_refresh_weather()


# Drop an image at res://art/ui/<name>.png to use it as this screen's
# backdrop. Falls back to the flat theme colour when absent.
func background_image() -> String:
	return "menu_bg"


func _bounce_to_slots() -> void:
	Routes.go(self, Routes.SLOTS)


func _build_chrome() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Design.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var splash := _load_background(background_image())
	if splash != null:
		var art := TextureRect.new()
		art.texture = splash
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)

		# Scrim keeps UI legible over any artwork.
		var scrim := ColorRect.new()
		scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		scrim.color = Design.alpha(Design.BG, 0.72)
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(scrim)

	var margin := UI.margin(Design.S5)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var root := UI.vbox(Design.S4)
	margin.add_child(root)

	root.add_child(_build_header())

	if shows_weather():
		_weather_banner = UI.accent_panel(Design.DANGER, Design.S3)
		_weather_banner.visible = false
		_weather_label = UI.label("", Design.FS_SMALL, Design.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		_weather_banner.add_child(_weather_label)
		root.add_child(_weather_banner)

	content = UI.vbox(Design.S4)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	# Toasts float above everything.
	_toast_layer = UI.vbox(Design.S2)
	_toast_layer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toast_layer.offset_top = -140
	_toast_layer.offset_bottom = -Design.S5
	_toast_layer.offset_left = Design.S5
	_toast_layer.offset_right = -Design.S5
	_toast_layer.alignment = BoxContainer.ALIGNMENT_END
	_toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_layer)


func _load_background(key: String) -> Texture2D:
	if key == "":
		return null
	var extensions: Array[String] = ["png", "jpg", "jpeg", "webp"]
	for ext in extensions:
		var path: String = "res://art/ui/" + key + "." + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _build_header() -> HBoxContainer:
	var header := UI.hbox(Design.S3)

	var route := back_route()
	if route != "":
		header.add_child(UI.button("←", func(): Routes.go(self, route), Vector2(52, 44)))

	var title := UI.title(screen_title())
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	header.add_child(UI.spacer())

	header_actions = UI.hbox(Design.S2)
	header.add_child(header_actions)

	if shows_currency():
		_currency_label = UI.label("", Design.FS_HEADING, Design.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		_currency_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header.add_child(_currency_label)

	return header


func _connect_signals() -> void:
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.weather_started.connect(_on_weather_changed)
	EventBus.weather_ended.connect(_refresh_weather)
	EventBus.weather_tick.connect(_on_weather_tick)
	EventBus.toast_requested.connect(show_toast)


func _exit_tree() -> void:
	unbind(EventBus.currency_changed, _on_currency_changed)
	unbind(EventBus.weather_started, _on_weather_changed)
	unbind(EventBus.weather_ended, _refresh_weather)
	unbind(EventBus.weather_tick, _on_weather_tick)
	unbind(EventBus.toast_requested, show_toast)


# Shared by subclasses so signal cleanup is one readable line each.
func unbind(sig: Signal, handler: Callable) -> void:
	if sig.is_connected(handler):
		sig.disconnect(handler)


# --- Currency -----------------------------------------------------

func _on_currency_changed(_gems: int, _gold: int) -> void:
	_refresh_currency()


func _refresh_currency() -> void:
	if _currency_label == null:
		return
	_currency_label.text = "💎 " + Fmt.compact(GameState.gems) + "    🪙 " + Fmt.compact(GameState.gold)


# --- Weather ------------------------------------------------------

func _on_weather_changed(_event: Dictionary) -> void:
	_refresh_weather()


func _on_weather_tick(seconds: float) -> void:
	if _weather_banner and _weather_banner.visible:
		_weather_label.text = _weather_text(seconds)


func _refresh_weather() -> void:
	if _weather_banner == null:
		return
	var active: bool = GameState.weather.is_active()
	_weather_banner.visible = active
	if active:
		_weather_label.text = _weather_text(GameState.weather.seconds_remaining())


func _weather_text(seconds: float) -> String:
	var e: Dictionary = GameState.weather.active
	return "%s  ·  %s  ·  2× luck  ·  %s left" % [e.get("name", ""), e.get("desc", ""), Fmt.clock(seconds)]


# --- Toasts -------------------------------------------------------

func show_toast(message: String, kind: String = "info") -> void:
	if _toast_layer == null:
		return

	var color := Design.ACCENT
	match kind:
		"success": color = Design.SUCCESS
		"error":   color = Design.DANGER
		"info":    color = Design.INFO

	var toast := UI.accent_panel(color, Design.S3)
	toast.modulate.a = 0.0
	toast.add_child(UI.label(message, Design.FS_BODY, Design.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	_toast_layer.add_child(toast)

	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, Design.T_FAST)
	tween.tween_interval(2.2)
	tween.tween_property(toast, "modulate:a", 0.0, Design.T_BASE)
	tween.tween_callback(toast.queue_free)


# --- Helpers ------------------------------------------------------

func clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func confirm(title_text: String, body_text: String, on_yes: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = title_text
	dialog.dialog_text = body_text
	add_child(dialog)
	dialog.confirmed.connect(on_yes)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
