extends Screen

# =========================================================
# Clan hall: the roster, what the clan's level unlocks, the raid, and
# a live feed of what the other members are doing.
# =========================================================

const FEED_LIMIT := 12
const CHAT_LIMIT := 40

var _feed: VBoxContainer
var _chat_log: VBoxContainer
var _chat_scroll: ScrollContainer
var _chat_input: LineEdit
var _raid_bar: ProgressBar
var _raid_label: Label


func screen_title() -> String: return "Clan"


func build_content() -> void:
	var clan: ClanSystem = GameState.clan

	if not clan.founded:
		_build_recruitment()
		return

	_build_banner(clan)
	_build_raid(clan)
	_build_perks(clan)
	_build_chat()
	_build_roster(clan)
	_build_feed()

	# build_content() runs again on every rebuild, so these have to be
	# connect-once.
	bind(EventBus.clan_activity, _on_activity)
	bind(EventBus.clan_level_changed, _on_level_changed)
	bind(EventBus.chat_message, _on_chat_message)


func _exit_tree() -> void:
	super()
	unbind(EventBus.clan_activity, _on_activity)
	unbind(EventBus.clan_level_changed, _on_level_changed)
	unbind(EventBus.chat_message, _on_chat_message)


# --- Not in a clan yet -------------------------------------------------

func _build_recruitment() -> void:
	var panel := UI.accent_panel(Design.ACCENT, Design.S5)
	var body := UI.vbox(Design.S4)
	panel.add_child(body)

	body.add_child(UI.label("You are not in a clan", Design.FS_TITLE, Design.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UI.caption(
		"Clans pool their members' progress. The clan levels as everyone "
		+ "contributes, and every level unlocks a perk that applies to your "
		+ "own pulls and rewards."))

	var suggestion := Usernames.clan_name()
	body.add_child(UI.label("Suggested name: " + suggestion, Design.FS_BODY, Design.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))

	var actions := UI.hbox(Design.S3)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(UI.primary_button("Found " + suggestion, func(): _found(suggestion), Vector2(240, 48)))
	actions.add_child(UI.button("Suggest another", _rebuild, Vector2(170, 48)))
	body.add_child(actions)

	content.add_child(panel)


func _found(chosen: String) -> void:
	GameState.clan.found(chosen)
	GameState.save_now()
	Audio.play("levelup")
	show_toast("Founded %s. Members are joining." % chosen, "success")
	_rebuild()


# --- Banner --------------------------------------------------------------

func _build_banner(clan: ClanSystem) -> void:
	var panel := UI.accent_panel(Design.ACCENT, Design.S4)
	var row := UI.hbox(Design.S4)
	panel.add_child(row)

	var identity := UI.vbox(Design.S1)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UI.label("[%s]  %s" % [clan.clan_tag, clan.clan_name], Design.FS_TITLE, Design.ACCENT))
	identity.add_child(UI.caption("%d members  ·  %s total power  ·  %s contributed this week" % [
		clan.member_count(), Fmt.compact(clan.total_power()), Fmt.compact(clan.weekly_total())]))
	row.add_child(identity)

	var level_box := UI.vbox(Design.S1)
	level_box.add_child(UI.label("Level %d" % clan.level, Design.FS_HEADING, Design.TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	if clan.level < ClanSystem.MAX_LEVEL:
		level_box.add_child(UI.caption("%s / %s XP" % [Fmt.compact(clan.xp), Fmt.compact(clan.xp_to_next())]))
	else:
		level_box.add_child(UI.caption("Maximum level"))
	row.add_child(level_box)

	content.add_child(panel)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clan.level_progress()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	content.add_child(bar)


# --- Raid ------------------------------------------------------------------

func _build_raid(clan: ClanSystem) -> void:
	content.add_child(UI.section("Clan raid"))

	var panel := UI.panel(Design.SURFACE, Design.S4)
	var body := UI.vbox(Design.S3)
	panel.add_child(body)

	if not clan.raid_active:
		body.add_child(UI.caption(
			"No raid running. Start one and the whole clan chips away at the "
			+ "boss — your own damage counts toward your share of the reward."))
		body.add_child(UI.primary_button("Start a raid", _start_raid, Vector2(200, 48)))
		content.add_child(panel)
		return

	_raid_label = UI.label("", Design.FS_HEADING, Design.DANGER)
	body.add_child(_raid_label)

	_raid_bar = ProgressBar.new()
	_raid_bar.min_value = 0.0
	_raid_bar.max_value = 1.0
	_raid_bar.show_percentage = false
	_raid_bar.custom_minimum_size = Vector2(0, 18)
	body.add_child(_raid_bar)

	body.add_child(UI.caption(
		"Your damage: %s  (%s of the boss)" % [
			Fmt.compact(clan.raid_player_damage),
			Fmt.percent(clan.raid_player_share(), 1)]))

	body.add_child(UI.primary_button("Fight the boss", _fight_raid, Vector2(200, 48)))

	_refresh_raid()
	content.add_child(panel)


func _refresh_raid() -> void:
	var clan: ClanSystem = GameState.clan
	if is_instance_valid(_raid_bar):
		_raid_bar.value = clan.raid_progress()
	if is_instance_valid(_raid_label):
		_raid_label.text = "%s   %s / %s HP" % [
			clan.raid_boss, Fmt.compact(clan.raid_hp), Fmt.compact(clan.raid_max_hp)]


func _start_raid() -> void:
	GameState.clan.start_raid()
	GameState.save_now()
	Audio.play("summon")
	show_toast("Raid started: " + GameState.clan.raid_boss, "success")
	_rebuild()


func _fight_raid() -> void:
	GameState.progression.queue_raid()
	Routes.go(self, Routes.BATTLE)


# --- Perks -------------------------------------------------------------------

func _build_perks(clan: ClanSystem) -> void:
	content.add_child(UI.section("Clan perks"))

	var panel := UI.panel(Design.SURFACE, Design.S4)
	var body := UI.vbox(Design.S2)
	panel.add_child(body)

	var unlocked := clan.unlocked_perks()
	if unlocked.is_empty():
		body.add_child(UI.caption("No perks yet — the clan unlocks its first at level 2."))
	else:
		for perk in unlocked:
			var row := UI.hbox(Design.S3)
			row.add_child(UI.label("✓", Design.FS_BODY, Design.SUCCESS))
			row.add_child(UI.label(str(perk["label"]), Design.FS_BODY))
			body.add_child(row)

	var upcoming := clan.next_perk()
	if not upcoming.is_empty():
		var row := UI.hbox(Design.S3)
		row.add_child(UI.label("🔒", Design.FS_BODY, Design.TEXT_MUTED))
		row.add_child(UI.label("Level %d — %s" % [int(upcoming["level"]), str(upcoming["label"])],
			Design.FS_BODY, Design.TEXT_MUTED))
		body.add_child(row)

	content.add_child(panel)


# --- Roster --------------------------------------------------------------------

func _build_roster(clan: ClanSystem) -> void:
	content.add_child(UI.section("Roster — this week's contribution"))

	# Rendered straight into the page. The screen itself scrolls, so a
	# scroll container here would swallow the wheel and strand everything
	# below it.
	var list := UI.vbox(Design.S1)
	var rows := clan.leaderboard(_player_power())
	for i in rows.size():
		list.add_child(_member_row(i + 1, rows[i]))

	content.add_child(list)


func _member_row(position: int, member: Dictionary) -> Control:
	var is_player := bool(member.get("is_player", false))

	var bg := Design.SURFACE
	if is_player:
		bg = Design.ACCENT_SOFT
	var panel := UI.panel(bg, Design.S3)

	var row := UI.hbox(Design.S3)
	panel.add_child(row)

	var place_color := Design.TEXT_MUTED
	if position <= 3:
		place_color = Design.ACCENT
	var place := UI.label("#%d" % position, Design.FS_SMALL, place_color)
	place.custom_minimum_size = Vector2(38, 0)
	row.add_child(place)

	var name_color := Design.TEXT
	if is_player:
		name_color = Design.ACCENT
	var identity := UI.vbox(0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UI.label(str(member["username"]), Design.FS_BODY, name_color))
	identity.add_child(UI.caption("%s  ·  %s power" % [
		str(member["rank"]), Fmt.compact(int(member["power"]))]))
	row.add_child(identity)

	var contribution := UI.vbox(0)
	contribution.add_child(UI.label(Fmt.compact(int(member["weekly"])),
		Design.FS_BODY, Design.SUCCESS, HORIZONTAL_ALIGNMENT_RIGHT))
	contribution.add_child(UI.caption("%s all-time" % Fmt.compact(int(member["total"]))))
	row.add_child(contribution)

	return panel


# A rough rating for the player, so their place on the board means
# something: total attack across the fielded team.
func _player_power() -> int:
	var total := 0
	for card in GameState.get_battle_team():
		total += card.attack + card.defense + int(card.health / 4.0)
	return total


# --- Chat ----------------------------------------------------------------

func _build_chat() -> void:
	content.add_child(UI.section("Clan chat"))

	var panel := UI.panel(Design.SURFACE, Design.S3)
	var body := UI.vbox(Design.S3)
	panel.add_child(body)

	# The one nested scroll on this screen, and a deliberate one: the log
	# is a fixed-height window onto a long history. Everything else on the
	# page rides the screen's own scroll.
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_chat_scroll.custom_minimum_size = Vector2(0, 220)
	_chat_log = UI.vbox(Design.S1)
	_chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.add_child(_chat_log)
	body.add_child(_chat_scroll)

	for entry in GameState.chat.history:
		_append_message(str(entry["author"]), str(entry["text"]), bool(entry["player"]))

	if GameState.chat.history.is_empty():
		_chat_log.add_child(UI.caption("Say something — the clan is listening."))

	var row := UI.hbox(Design.S2)

	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Message the clan..."
	_chat_input.max_length = 140
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.text_submitted.connect(_on_chat_submitted)
	row.add_child(_chat_input)

	row.add_child(UI.primary_button("Send", _send_chat, Vector2(96, 40)))
	body.add_child(row)

	content.add_child(panel)


func _on_chat_submitted(_text: String) -> void:
	_send_chat()


func _send_chat() -> void:
	if _chat_input == null:
		return
	var text := _chat_input.text.strip_edges()
	if text == "":
		return
	_chat_input.text = ""
	GameState.send_chat(text)
	Audio.play("click")


func _on_chat_message(author: String, text: String, from_player: bool) -> void:
	_append_message(author, text, from_player)


func _append_message(author: String, text: String, from_player: bool) -> void:
	# A rebuild frees the old log, and a chat line can land in the gap
	# before the new one exists.
	if not is_instance_valid(_chat_log):
		return

	# Clear the placeholder once a real line arrives.
	if _chat_log.get_child_count() == 1:
		var only := _chat_log.get_child(0)
		if only is Label and (only as Label).text.begins_with("Say something"):
			only.queue_free()

	var name_color := Design.INFO
	if from_player:
		name_color = Design.ACCENT

	var row := UI.hbox(Design.S2)
	var who := UI.label(author, Design.FS_SMALL, name_color)
	who.custom_minimum_size = Vector2(120, 0)
	row.add_child(who)

	var said := UI.label(text, Design.FS_SMALL, Design.TEXT)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(said)

	_chat_log.add_child(row)

	while _chat_log.get_child_count() > CHAT_LIMIT:
		_chat_log.get_child(0).queue_free()

	# Wait a frame so the container has resized before scrolling.
	call_deferred("_scroll_chat_to_end")


func _scroll_chat_to_end() -> void:
	if not is_instance_valid(_chat_scroll):
		return
	await get_tree().process_frame
	if not is_instance_valid(_chat_scroll):
		return
	var bar := _chat_scroll.get_v_scroll_bar()
	if bar:
		_chat_scroll.scroll_vertical = int(bar.max_value)


# --- Activity feed ----------------------------------------------------------------

func _build_feed() -> void:
	content.add_child(UI.section("Clan activity"))

	var panel := UI.panel(Design.SURFACE, Design.S3)
	_feed = UI.vbox(Design.S1)
	panel.add_child(_feed)
	_feed.add_child(UI.caption("Waiting for the clan to do something..."))

	content.add_child(panel)


func _on_activity(text: String) -> void:
	if not is_instance_valid(_feed):
		return

	# Drop the placeholder the first time something real arrives.
	if _feed.get_child_count() == 1 and _feed.get_child(0) is Label:
		var first: Label = _feed.get_child(0)
		if first.text.begins_with("Waiting"):
			first.queue_free()

	_feed.add_child(UI.caption(text))
	_feed.move_child(_feed.get_child(_feed.get_child_count() - 1), 0)

	while _feed.get_child_count() > FEED_LIMIT:
		_feed.get_child(_feed.get_child_count() - 1).queue_free()

	_refresh_raid()


func _on_level_changed(_level: int) -> void:
	_rebuild()


func _rebuild() -> void:
	for child in content.get_children():
		child.queue_free()
	call_deferred("build_content")
