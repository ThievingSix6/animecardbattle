extends Screen

# =========================================================
# Paperdoll. Equipment slots on the left, craftable recipes on the
# right, live totals underneath.
# =========================================================

var _slots_column: VBoxContainer
var _recipe_column: VBoxContainer
var _totals: Label


func screen_title() -> String: return "Character"
# This screen scrolls its own list region, so the base page scroll
# would just nest one scroll inside another.
func scrolls_content() -> bool: return false



func build_content() -> void:
	var columns := UI.hbox(Design.S5)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(columns)

	# --- Equipped ---
	var left := UI.vbox(Design.S3)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	left.add_child(UI.section("Equipped"))

	_slots_column = UI.vbox(Design.S2)
	left.add_child(_slots_column)

	left.add_child(UI.separator())
	left.add_child(UI.section("Team bonus"))
	_totals = UI.body("")
	left.add_child(_totals)
	left.add_child(UI.caption("Bonuses apply to every card in your team during battle."))

	# --- Crafting ---
	var right := UI.vbox(Design.S3)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(UI.section("Forge"))
	right.add_child(UI.caption("Crafting consumes spare duplicate cards. Your team is never touched."))

	var scroll := UI.scroll()
	_recipe_column = UI.vbox(Design.S2)
	_recipe_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_recipe_column)
	right.add_child(scroll)

	EventBus.collection_changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	super()
	unbind(EventBus.collection_changed, _refresh)


func _refresh() -> void:
	_refresh_slots()
	_refresh_recipes()
	_refresh_totals()


# --- Equipped slots -------------------------------------------------

func _refresh_slots() -> void:
	clear(_slots_column)
	for slot in EquipmentSystem.SLOTS:
		_slots_column.add_child(_build_slot(slot))


func _build_slot(slot: String) -> PanelContainer:
	var item_id := GameState.equipment.item_in(slot)
	var filled := item_id != ""

	var accent := Design.HAIRLINE
	if filled:
		accent = Design.ACCENT

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		ThemeBuilder.bordered_style(Design.SURFACE, accent, 1, Design.R_MD))

	var row := UI.hbox(Design.S3)
	panel.add_child(row)

	var info := UI.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.caption(slot))

	if filled:
		var recipe := EquipmentSystem.recipe(item_id)
		info.add_child(UI.label(str(recipe.get("name", item_id)), Design.FS_BODY, Design.TEXT))
		info.add_child(UI.label(EquipmentSystem.bonus_text(item_id), Design.FS_MICRO, Design.SUCCESS))
		row.add_child(info)
		row.add_child(UI.button("Remove", func(): _unequip(slot), Vector2(96, 40)))
	else:
		info.add_child(UI.label("— empty —", Design.FS_BODY, Design.TEXT_MUTED))
		row.add_child(info)

	return panel


func _unequip(slot: String) -> void:
	GameState.unequip_slot(slot)
	_refresh()


# --- Forge ----------------------------------------------------------

func _refresh_recipes() -> void:
	clear(_recipe_column)
	for recipe in EquipmentSystem.RECIPES:
		_recipe_column.add_child(_build_recipe(recipe))


func _build_recipe(recipe: Dictionary) -> PanelContainer:
	var item_id: String = recipe["id"]
	var rarity: String = recipe["rarity"]
	var cost: int = recipe["cost"]

	var have: int = GameState.equipment.craftable_material(GameState.collection, rarity)
	var can_make: bool = have >= cost
	var owned_count: int = GameState.equipment.count(item_id)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		ThemeBuilder.bordered_style(Design.SURFACE, Design.rarity_color(rarity), 1, Design.R_MD))

	var body := UI.vbox(Design.S2)
	panel.add_child(body)

	var header := UI.hbox(Design.S2)
	header.add_child(UI.label(str(recipe["name"]), Design.FS_BODY, Design.TEXT))
	header.add_child(UI.pill(str(recipe["slot"]), Design.TEXT_DIM))
	header.add_child(UI.spacer())
	if owned_count > 0:
		header.add_child(UI.pill("owned x" + str(owned_count), Design.SUCCESS))
	body.add_child(header)

	body.add_child(UI.label(EquipmentSystem.bonus_text(item_id), Design.FS_SMALL, Design.SUCCESS))

	var cost_color := Design.DANGER
	if can_make:
		cost_color = Design.TEXT_DIM
	body.add_child(UI.label(
		"Cost: %d spare %s+ cards   (you have %s)" % [cost, rarity, Fmt.commas(have)],
		Design.FS_MICRO, cost_color))

	var actions := UI.hbox(Design.S2)

	var craft_button := UI.button("Craft", func(): _craft(item_id), Vector2(100, 38))
	craft_button.disabled = not can_make
	actions.add_child(craft_button)

	if owned_count > 0 and not GameState.equipment.is_equipped(item_id):
		actions.add_child(UI.primary_button("Equip", func(): _equip(item_id), Vector2(100, 38)))
	elif GameState.equipment.is_equipped(item_id):
		actions.add_child(UI.pill("Equipped", Design.ACCENT))

	body.add_child(actions)
	return panel


func _craft(item_id: String) -> void:
	if GameState.craft_item(item_id):
		_refresh()


func _equip(item_id: String) -> void:
	GameState.equip_item(item_id)
	_refresh()


# --- Totals ---------------------------------------------------------

func _refresh_totals() -> void:
	var totals := GameState.equipment.total_bonuses()
	var parts: Array[String] = []
	for stat in EquipmentSystem.STATS:
		var value: float = totals[stat]
		if value > 0.0:
			parts.append("+%d%% %s" % [int(round(value * 100.0)), stat.to_upper()])

	if parts.is_empty():
		_totals.text = "No bonuses yet — craft and equip something."
		_totals.add_theme_color_override("font_color", Design.TEXT_MUTED)
	else:
		_totals.text = "   ".join(parts)
		_totals.add_theme_color_override("font_color", Design.SUCCESS)
