class_name Routes
extends RefCounted

# =========================================================
# NAVIGATION - one registry of every screen. Replaces 22 hardcoded
# "res://scenes/X.tscn" strings scattered through the codebase.
# =========================================================

const TITLE    := "res://scenes/Title.tscn"
const SLOTS    := "res://scenes/SaveSlots.tscn"
const MAIN     := "res://scenes/Main.tscn"
const LOBBY    := "res://scenes/Lobby.tscn"
const COLLECT  := "res://scenes/CardCollection.tscn"
const PACKS    := "res://scenes/Packs.tscn"
const TEAM     := "res://scenes/TeamBuilder.tscn"
const CHARACTER := "res://scenes/Character.tscn"
const TALENTS  := "res://scenes/Talents.tscn"
const TOWER    := "res://scenes/Tower.tscn"
const CAMPAIGN := "res://scenes/Campaign.tscn"
const ZONE     := "res://scenes/Zone.tscn"
const BATTLE   := "res://scenes/Battle.tscn"
const ARENA    := "res://scenes/Arena.tscn"
const RINGS    := "res://scenes/Rings.tscn"
const GARAGE   := "res://scenes/Garage.tscn"
const SETTINGS := "res://scenes/Settings.tscn"
const CLAN     := "res://scenes/Clan.tscn"


# Where the settings screen's back button should return to. The cog is
# on every screen including the 3D worlds, so "back" has to mean the
# place it was pressed rather than always the main menu.
static var settings_return := ""

# The hub a screen was opened from. The city and the flat menu are both
# hubs, so a screen entered from the city has to come back out into the
# city rather than dumping the player on the menu.
static var hub_return := ""


static func go(node: Node, route: String) -> void:
	node.get_tree().change_scene_to_file(route)


# Opens a destination and records the hub to return to.
static func enter(node: Node, route: String, from_hub: String) -> void:
	hub_return = from_hub
	node.get_tree().change_scene_to_file(route)


# Where a screen's back button should go: the hub it was opened from.
static func back_to_hub() -> String:
	if hub_return != "":
		return hub_return
	return MAIN


# Opens settings and records the way home.
static func open_settings(node: Node, from_route: String) -> void:
	settings_return = from_route
	node.get_tree().change_scene_to_file(SETTINGS)
