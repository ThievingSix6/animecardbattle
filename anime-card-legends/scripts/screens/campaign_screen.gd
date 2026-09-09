extends Screen

# =========================================================
# Zone select. Each zone opens its own 3D world; this screen is the
# map that gets you there and shows how far through each one you are.
# =========================================================


func screen_title() -> String: return "Campaign"


func build_content() -> void:
	var p: ProgressionSystem = GameState.progression

	var header := UI.hbox(Design.S3)
	header.add_child(UI.caption(
		"Six zones, %d stages each, ending in a boss. Clear a zone's boss to open the next."
		% Campaign.STAGES_PER_ZONE))
	header.add_child(UI.spacer())
	header.add_child(UI.label(
		"%d / %d stages cleared" % [p.highest_floor, Config.MAX_FLOOR],
		Design.FS_BODY, Design.ACCENT))
	content.add_child(header)

	var scroll := UI.scroll()
	var list := UI.vbox(Design.S3)
	scroll.add_child(list)
	content.add_child(scroll)

	for zone_index in Campaign.zone_count():
		list.add_child(_build_row(zone_index))


func _build_row(zone_index: int) -> Control:
	var p: ProgressionSystem = GameState.progression
	var zone := Campaign.zone_at(zone_index)
	var unlocked := Campaign.zone_unlocked(zone_index, p.highest_floor)
	var cleared := Campaign.stages_cleared_in(zone_index, p.highest_floor)
	var complete := Campaign.zone_complete(zone_index, p.highest_floor)
	var accent := Campaign.accent_color(zone)

	var edge := accent
	if not unlocked:
		edge = Design.HAIRLINE

	var panel := UI.accent_panel(edge, Design.S4)

	var row := UI.hbox(Design.S4)
	panel.add_child(row)

	# Zone identity
	var text := UI.vbox(Design.S1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_color := Design.TEXT
	if not unlocked:
		name_color = Design.TEXT_MUTED
	text.add_child(UI.label(str(zone["name"]), Design.FS_HEADING, name_color))
	text.add_child(UI.caption(str(zone["subtitle"])))

	var element_line := "%s %s  ·  Boss: %s" % [
		Design.ELEMENT_ICON.get(str(zone["element"]), "◆"),
		str(zone["element"]),
		str(zone["boss"]),
	]
	text.add_child(UI.caption(element_line))
	row.add_child(text)

	# Progress
	var status := UI.vbox(Design.S1)
	var status_text := "%d / %d stages" % [cleared, Campaign.STAGES_PER_ZONE]
	var status_color := Design.ACCENT
	if complete:
		status_text = "✓ Cleared"
		status_color = Design.SUCCESS
	elif not unlocked:
		status_text = "🔒 Locked"
		status_color = Design.TEXT_MUTED
	status.add_child(UI.label(status_text, Design.FS_BODY, status_color, HORIZONTAL_ALIGNMENT_RIGHT))

	var floors_line := "Floors %d–%d" % [
		Campaign.floor_for(zone_index, 0),
		Campaign.floor_for(zone_index, Campaign.STAGES_PER_ZONE - 1),
	]
	status.add_child(UI.caption(floors_line))
	row.add_child(status)

	# Enter
	var enter := UI.primary_button("Enter", func():
		GameState.progression.pending_zone = zone_index
		Routes.go(self, Routes.ZONE)
	, Vector2(130, 48))
	enter.disabled = not unlocked
	row.add_child(enter)

	return panel
