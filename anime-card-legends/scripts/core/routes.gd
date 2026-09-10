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
const SETTINGS := "res://scenes/Settings.tscn"
const CLAN     := "res://scenes/Clan.tscn"


# Where the settings screen's back button should return to. The cog is
# on every screen including the 3D worlds, so "back" has to mean the
# place it was pressed rather than always the main menu.
static var settings_return := ""


static func go(node: Node, route: String) -> void:
	node.get_tree().change_scene_to_file(route)


# Opens settings and records the way home.
static func open_settings(node: Node, from_route: String) -> void:
	settings_return = from_route
	node.get_tree().change_scene_to_file(SETTINGS)
