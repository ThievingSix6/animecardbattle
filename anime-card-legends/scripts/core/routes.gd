class_name Routes
extends RefCounted

# =========================================================
# NAVIGATION - one registry of every screen. Replaces 22 hardcoded
# "res://scenes/X.tscn" strings scattered through the codebase.
# =========================================================

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


static func go(node: Node, route: String) -> void:
	node.get_tree().change_scene_to_file(route)
