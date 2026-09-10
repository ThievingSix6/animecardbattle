extends Screen

# =========================================================
# Settings. Everything here is global rather than per save slot, so it
# is reachable without an active profile.
# =========================================================

var _sfx_value: Label
var _music_value: Label
var _speed_value: Label


func screen_title() -> String: return "Settings"
func back_route() -> String: return Routes.MAIN
func requires_slot() -> bool: return false
func shows_currency() -> bool: return false
func shows_weather() -> bool: return false


func build_content() -> void:
	content.add_child(UI.section("Audio"))

	var audio_panel := UI.panel(Design.SURFACE, Design.S4)
	var audio_body := UI.vbox(Design.S4)
	audio_panel.add_child(audio_body)

	_sfx_value = UI.label("", Design.FS_BODY, Design.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	audio_body.add_child(_volume_row(
		"Sound effects", "Hits, ultimates, summons and UI clicks.",
		Settings.sfx_volume, _sfx_value, _on_sfx_changed))

	audio_body.add_child(UI.separator())

	_music_value = UI.label("", Design.FS_BODY, Design.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	audio_body.add_child(_volume_row(
		"Music", "Menu, lobby and battle tracks.",
		Settings.music_volume, _music_value, _on_music_changed))

	content.add_child(audio_panel)

	var missing := _missing_audio()
	if not missing.is_empty():
		var warning := UI.accent_panel(Design.INFO, Design.S3)
		var warning_body := UI.vbox(Design.S1)
		warning_body.add_child(UI.label("Audio files not found", Design.FS_BODY, Design.INFO))
		warning_body.add_child(UI.caption(
			"Drop these into res://audio/ as .ogg, .wav or .mp3 — the names hook themselves up:"))
		warning_body.add_child(UI.caption("  " + ", ".join(missing)))
		warning.add_child(warning_body)
		content.add_child(warning)

	# --- Gameplay ---

	content.add_child(UI.section("Gameplay"))

	var play_panel := UI.panel(Design.SURFACE, Design.S4)
	var play_body := UI.vbox(Design.S4)
	play_panel.add_child(play_body)

	play_body.add_child(_battle_speed_row())
	play_body.add_child(UI.separator())
	play_body.add_child(_flashing_row())

	content.add_child(play_panel)

	# --- Actions ---

	var actions := UI.hbox(Design.S3)
	actions.add_child(UI.button("Test sound", func(): Audio.play("click"), Vector2(150, 44)))
	actions.add_child(UI.spacer())
	actions.add_child(UI.button("Reset to defaults", _on_reset, Vector2(190, 44)))
	content.add_child(actions)

	_refresh_labels()


# --- Rows -------------------------------------------------------------

func _volume_row(title: String, blurb: String, value: float, value_label: Label, on_change: Callable) -> Control:
	var row := UI.hbox(Design.S4)

	var text := UI.vbox(Design.S1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(title, Design.FS_BODY))
	text.add_child(UI.caption(blurb))
	row.add_child(text)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(240, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(on_change)
	row.add_child(slider)

	value_label.custom_minimum_size = Vector2(56, 0)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)

	return row


func _battle_speed_row() -> Control:
	var row := UI.hbox(Design.S4)

	var text := UI.vbox(Design.S1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label("Battle speed", Design.FS_BODY))
	text.add_child(UI.caption(
		"How fast rounds resolve. Only affects pacing — never the outcome."))
	row.add_child(text)

	var buttons := UI.hbox(Design.S1)
	for i in Settings.BATTLE_SPEEDS.size():
		var index := i
		var label: String = Settings.BATTLE_SPEED_LABELS[i]
		var button := UI.button(label, func(): _on_speed_selected(index), Vector2(62, 40))
		if i == Settings.battle_speed_index:
			button.add_theme_color_override("font_color", Design.ACCENT)
		buttons.add_child(button)
	row.add_child(buttons)

	_speed_value = UI.label("", Design.FS_BODY, Design.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_speed_value.custom_minimum_size = Vector2(56, 0)
	_speed_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_speed_value)

	return row


func _flashing_row() -> Control:
	var row := UI.hbox(Design.S4)

	var text := UI.vbox(Design.S1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label("Reduce flashing", Design.FS_BODY))
	text.add_child(UI.caption("Tones down hit shakes and rarity auras."))
	row.add_child(text)

	var toggle := CheckButton.new()
	toggle.button_pressed = Settings.reduce_flashing
	toggle.toggled.connect(_on_flashing_toggled)
	row.add_child(toggle)

	return row


# --- Handlers ----------------------------------------------------------

func _on_sfx_changed(value: float) -> void:
	Settings.set_sfx_volume(value)
	Audio.play("click")
	_refresh_labels()


func _on_music_changed(value: float) -> void:
	Settings.set_music_volume(value)
	_refresh_labels()


func _on_speed_selected(index: int) -> void:
	Settings.set_battle_speed_index(index)
	Audio.play("click")
	_rebuild()


func _on_flashing_toggled(pressed: bool) -> void:
	Settings.set_reduce_flashing(pressed)


func _on_reset() -> void:
	Settings.reset_to_defaults()
	show_toast("Settings restored to defaults.", "success")
	_rebuild()


func _rebuild() -> void:
	for child in content.get_children():
		child.queue_free()
	call_deferred("build_content")


func _refresh_labels() -> void:
	if _sfx_value:
		_sfx_value.text = "%d%%" % int(round(Settings.sfx_volume * 100.0))
	if _music_value:
		_music_value.text = "%d%%" % int(round(Settings.music_volume * 100.0))
	if _speed_value:
		_speed_value.text = Settings.battle_speed_label()


# Which of the expected audio files are absent, so the screen can say so
# rather than leaving the player wondering why sliders do nothing.
func _missing_audio() -> Array[String]:
	var expected: Array[String] = [
		"music_menu", "music_lobby", "music_battle",
		"click", "hit", "ultimate", "victory", "defeat",
	]
	var missing: Array[String] = []
	for key in expected:
		if not Audio.has_sound(key):
			missing.append(key)
	return missing
