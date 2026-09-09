extends Screen

# =========================================================
# Profile select. The game boots here; nothing rolls, saves or loads
# until a slot is chosen.
# =========================================================

var _row: HBoxContainer


func screen_title() -> String: return "Anime Card Legends"
func back_route() -> String: return ""
func shows_currency() -> bool: return false
func shows_weather() -> bool: return false
func requires_slot() -> bool: return false


func build_content() -> void:
	Audio.play_music("music_menu")

	content.add_child(UI.body("Choose a profile."))
	content.add_child(UI.separator())

	_row = UI.hbox(Design.S4)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_row)

	_refresh()


func _refresh() -> void:
	clear(_row)
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		_row.add_child(_build_slot(slot))


func _build_slot(slot: int) -> Control:
	var summary := SaveManager.slot_summary(slot)
	var occupied: bool = summary.get("exists", false)

	var accent := Design.HAIRLINE
	if occupied:
		accent = Design.ACCENT

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 340)
	panel.add_theme_stylebox_override("panel",
		ThemeBuilder.aura_style(Design.SURFACE, accent, 2, 0, Design.R_LG))

	var body := UI.vbox(Design.S3)
	panel.add_child(body)

	body.add_child(UI.section("Slot " + str(slot)))

	if occupied:
		_fill_occupied(body, slot, summary)
	else:
		_fill_empty(body, slot)

	return panel


func _fill_occupied(body: VBoxContainer, slot: int, summary: Dictionary) -> void:
	var best: String = summary.get("best_rarity", "")
	if best != "":
		var crest := UI.label(best.to_upper(), Design.FS_HEADING, Design.rarity_color(best), HORIZONTAL_ALIGNMENT_CENTER)
		CardView.apply_rarity_text_style(crest, best)
		body.add_child(crest)

	body.add_child(UI.separator())

	var cards: int = summary.get("cards", 0)
	var floor_reached: int = summary.get("floor", 0)
	var gems: int = summary.get("gems", 0)
	var gold: int = summary.get("gold", 0)

	_stat_row(body, "Cards", Fmt.commas(cards))
	_stat_row(body, "Tower floor", str(floor_reached))
	_stat_row(body, "Gems", Fmt.compact(gems))
	_stat_row(body, "Gold", Fmt.compact(gold))

	var played: int = summary.get("played_at", 0)
	if played > 0:
		body.add_child(UI.caption("Last played " + _ago(played)))

	body.add_child(UI.spacer())

	var play := UI.primary_button("Continue", func(): _open(slot))
	play.custom_minimum_size = Vector2(0, 48)
	body.add_child(play)

	var wipe := UI.button("Delete", func(): _confirm_delete(slot))
	wipe.add_theme_color_override("font_color", Design.DANGER)
	body.add_child(wipe)


func _fill_empty(body: VBoxContainer, slot: int) -> void:
	body.add_child(UI.spacer())

	var mark := UI.label("＋", Design.FS_DISPLAY, Design.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(mark)

	var caption := UI.caption("Empty slot")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(caption)

	body.add_child(UI.spacer())

	var start := UI.primary_button("New Game", func(): _open(slot))
	start.custom_minimum_size = Vector2(0, 48)
	body.add_child(start)


func _stat_row(parent: VBoxContainer, name_text: String, value_text: String) -> void:
	var row := UI.hbox(Design.S2)
	row.add_child(UI.caption(name_text))
	row.add_child(UI.spacer())
	row.add_child(UI.label(value_text, Design.FS_BODY, Design.TEXT))
	parent.add_child(row)


func _ago(unix_time: int) -> String:
	var seconds := int(Time.get_unix_time_from_system()) - unix_time
	if seconds < 60:
		return "just now"
	if seconds < 3600:
		return str(int(seconds / 60.0)) + " min ago"
	if seconds < 86400:
		return str(int(seconds / 3600.0)) + " hr ago"
	return str(int(seconds / 86400.0)) + " days ago"


func _open(slot: int) -> void:
	GameState.open_slot(slot)
	Routes.go(self, Routes.MAIN)


func _confirm_delete(slot: int) -> void:
	var summary := SaveManager.slot_summary(slot)
	var cards: int = summary.get("cards", 0)
	var floor_reached: int = summary.get("floor", 0)

	confirm(
		"Delete Slot " + str(slot),
		"This permanently erases %s cards and tower progress up to floor %d.\n\nThis cannot be undone." % [
			Fmt.commas(cards), floor_reached],
		func():
			GameState.erase_slot(slot)
			EventBus.toast("Slot " + str(slot) + " deleted.", "info")
			_refresh()
	)
