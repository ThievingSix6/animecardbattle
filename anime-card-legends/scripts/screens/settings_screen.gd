extends Screen

# =========================================================
# Settings. Everything here is global rather than per save slot, so it
# is reachable without an active profile.
# =========================================================

var _sfx_value: Label
var _music_value: Label
var _speed_value: Label


func screen_title() -> String: return "Settings"
# Reachable from the title screen before any profile is open, so back
# has to mean the title in that case rather than a screen that would
# immediately bounce for want of a save slot.
func back_route() -> String:
	if GameState.has_active_slot():
		return Routes.MAIN
	return Routes.TITLE
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

	content.add_child(_asset_report())

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


# --- Asset report ------------------------------------------------------
#
# What the game can actually see on disk. Both the card art and the icon
# systems match on exact filenames, so a file that is present but named
# differently loads nothing - and without this panel that failure is
# completely silent.

func _asset_report() -> Control:
	content.add_child(UI.section("Assets"))

	var panel := UI.panel(Design.SURFACE, Design.S4)
	var body := UI.vbox(Design.S3)
	panel.add_child(body)

	body.add_child(_card_art_row())
	body.add_child(UI.separator())
	body.add_child(_banner_row())
	body.add_child(UI.separator())
	body.add_child(_model_row())
	body.add_child(UI.separator())
	body.add_child(_icon_row())
	body.add_child(UI.separator())
	body.add_child(_audio_row())

	return panel


func _card_art_row() -> Control:
	var files := CardArt.list_files()
	var box := UI.vbox(Design.S1)

	if files.is_empty():
		box.add_child(UI.label("Card art: none found", Design.FS_BODY, Design.DANGER))
		box.add_child(UI.caption(
			"Drop images into res://art/cards/. The filename becomes the card "
			+ "name: ashen_knight.png -> \"Ashen Knight\". Until then the roster "
			+ "falls back to procedural names."))
		return box

	box.add_child(UI.label("Card art: %d file(s) -> %d card(s)" % [
		files.size(), files.size()], Design.FS_BODY, Design.SUCCESS))

	# Show what the filenames actually resolved to, so a bad name is obvious.
	var sample: Array[String] = []
	var shown := mini(6, files.size())
	for i in shown:
		var card := CardLibrary.card_from_path(files[i])
		if card != null:
			sample.append("%s (%s)" % [card.card_name, card.rarity])
	box.add_child(UI.caption("Reads as: " + ", ".join(sample)))
	if files.size() > shown:
		box.add_child(UI.caption("...and %d more" % (files.size() - shown)))

	return box


func _banner_row() -> Control:
	var missing: Array[String] = []
	for id in Banners.ids():
		if not Banners.has_art(id):
			missing.append(id)

	var box := UI.vbox(Design.S1)
	var total := Banners.ids().size()
	var found := total - missing.size()

	var colour := Design.DANGER
	if missing.is_empty():
		colour = Design.SUCCESS
	elif found > 0:
		colour = Design.ACCENT
	box.add_child(UI.label("Banner art: %d of %d matched" % [found, total],
		Design.FS_BODY, colour))

	if missing.is_empty():
		return box

	box.add_child(UI.caption(
		"Banners load by exact filename from res://art/banners/. These are "
		+ "drawing a generated gradient because no file of that name was found:"))
	box.add_child(UI.caption("  " + ", ".join(missing) + "  (.png, .jpg or .webp)"))
	return box


func _model_row() -> Control:
	var box := UI.vbox(Design.S1)

	var missing := Models.missing_zone_models()
	var total := Campaign.ZONES.size()
	var found := total - missing.size()

	var colour := Design.DANGER
	if missing.is_empty():
		colour = Design.SUCCESS
	elif found > 0:
		colour = Design.ACCENT
	box.add_child(UI.label("Zone models: %d of %d matched" % [found, total],
		Design.FS_BODY, colour))

	if not missing.is_empty():
		box.add_child(UI.caption(
			"Models load by exact zone id from res://art/models/zones/. "
			+ "These zones are still building their landmarks from primitives:"))
		box.add_child(UI.caption("  " + ", ".join(missing) + "  (.glb preferred)"))

	box.add_child(UI.caption(_emissive_text()))
	box.add_child(UI.caption(_prop_text()))
	box.add_child(UI.caption(_npc_text()))
	box.add_child(UI.caption(_sky_text()))

	if Models.has_player():
		box.add_child(UI.label("Player model: loaded", Design.FS_BODY, Design.SUCCESS))
		box.add_child(UI.caption(_player_animation_text()))
	else:
		box.add_child(UI.label("Player model: none found", Design.FS_BODY, Design.ACCENT))
		box.add_child(UI.caption(
			"Drop a rigged character at res://art/models/player.glb to replace "
			+ "the placeholder capsule. See res://art/models/README.txt."))

	return box


# Which models found a sidecar emissive map. A .glb exported without its
# emission slot assigned looks flat and nothing says why, so this names
# the ones that are currently unlit.
func _emissive_text() -> String:
	var lit: Array[String] = []
	var dark: Array[String] = []

	for zone in Campaign.ZONES:
		var id := str(zone["id"])
		if not Models.has_zone(id):
			continue
		if Models.has_emissive(Models.ZONE_FOLDER + id):
			lit.append(id)
		else:
			dark.append(id)

	if lit.is_empty() and dark.is_empty():
		return ""
	if dark.is_empty():
		return "Emissive maps: all loaded models have one."
	if lit.is_empty():
		return ("Emissive maps: none found. Drop <model>_emissive.png beside "
			+ "the model, or in a folder named after it. See art/models/props/README.txt.")
	return "Emissive maps: %s lit  ·  %s has none" % [", ".join(lit), ", ".join(dark)]


# Which NPC models are in, and for the ones that are, which animation
# clips their names actually matched.
func _npc_text() -> String:
	var lines: Array[String] = []

	for definition in Npcs.DEFINITIONS:
		var id := str(definition["id"])
		if not Models.has_npc(id):
			lines.append("%s: no model" % id)
			continue

		var model := Models.spawn_npc(id)
		var anim := Models.find_animation_player(model)
		if anim == null:
			lines.append("%s: loaded, no animations" % id)
		else:
			var clips := Models.animation_set(anim)
			lines.append("%s: idle %s / run %s / talk %s / defeat %s" % [
				id,
				_or_none(str(clips["idle"])),
				_or_none(str(clips["run"])),
				_or_none(str(clips["talk"])),
				_or_none(str(clips["defeat"]))])
		if model != null:
			model.queue_free()

	return "NPCs — " + "   ·   ".join(lines)


func _sky_text() -> String:
	if SkyBuilder.has_panorama():
		return "Sky: using a supplied panorama."
	return ("Sky: generated night sky with stars. Drop a 360 panorama at "
		+ "res://art/sky/city.hdr to replace it.")


# The two shared props the city and the portal look for.
func _prop_text() -> String:
	var missing: Array[String] = []
	var props: Array[String] = ["building", "portal"]
	for prop in props:
		if not Models.has_prop(prop):
			missing.append(prop)

	if missing.is_empty():
		return "Props: building and portal both loaded."
	return ("Props: %s missing from res://art/models/props/ — "
		+ "using built-in geometry instead.") % ", ".join(missing)


# Which clips the loose name matching actually bound, so a mismatched
# animation name is visible instead of just never playing.
func _player_animation_text() -> String:
	var model := Models.spawn_player()
	if model == null:
		return ""

	var player := Models.find_animation_player(model)
	if player == null:
		model.queue_free()
		return "No AnimationPlayer in the file — the character will not animate."

	var clips := Models.animation_set(player)
	model.queue_free()

	return "Animations — idle: %s   run: %s   jump: %s" % [
		_or_none(str(clips["idle"])),
		_or_none(str(clips["run"])),
		_or_none(str(clips["jump"]))]


func _or_none(value: String) -> String:
	if value == "":
		return "(none matched)"
	return value


func _icon_row() -> Control:
	var found: Array[String] = []
	var missing: Array[String] = []
	for key in Icons.EMOJI_FALLBACK.keys():
		if Icons.has(str(key)):
			found.append(str(key))
		else:
			missing.append(str(key))

	var box := UI.vbox(Design.S1)
	var total := found.size() + missing.size()

	var colour := Design.DANGER
	if found.size() == total:
		colour = Design.SUCCESS
	elif found.size() > 0:
		colour = Design.ACCENT
	box.add_child(UI.label("Icons: %d of %d matched" % [found.size(), total],
		Design.FS_BODY, colour))

	if missing.is_empty():
		return box

	box.add_child(UI.caption(
		"Icons load by exact filename from res://art/icons/. These are still "
		+ "using emoji because no file of that name was found:"))
	box.add_child(UI.caption("  " + ", ".join(missing) + "  (.png or .svg)"))
	return box


func _audio_row() -> Control:
	var expected: Array[String] = [
		"music_menu", "music_lobby", "music_battle",
		"click", "hit", "ultimate", "victory", "defeat", "coin", "summon", "levelup",
	]
	var missing: Array[String] = []
	for key in expected:
		if not Audio.has_sound(key):
			missing.append(key)

	var box := UI.vbox(Design.S1)
	var found_count := expected.size() - missing.size()

	var colour := Design.DANGER
	if missing.is_empty():
		colour = Design.SUCCESS
	elif found_count > 0:
		colour = Design.ACCENT
	box.add_child(UI.label("Audio: %d of %d matched" % [found_count, expected.size()],
		Design.FS_BODY, colour))

	if missing.is_empty():
		return box

	box.add_child(UI.caption(
		"Sounds load by exact filename from res://audio/ (.ogg, .wav or .mp3). "
		+ "Not found:"))
	box.add_child(UI.caption("  " + ", ".join(missing)))
	return box
