extends Node

# =========================================================
# SCRIPT VALIDATOR - compiles every .gd and loads every .tscn in the
# project, with the autoloads registered.
#
# Run it headless:
#
#   godot --headless --path . tools/Validate.tscn
#
# Exits 0 when everything compiles and non-zero when anything does not,
# so it works as a pre-commit check.
#
# Why a scene and not `--check-only --script`: that flag compiles a file
# in isolation, WITHOUT the project's autoloads, so every script that
# says EventBus or GameState fails with "Identifier not found" whether or
# not there is anything wrong with it. Running as a scene means Godot has
# set the autoloads up exactly as it would in the game.
# =========================================================

const ROOTS: Array[String] = ["res://scripts", "res://scenes"]


func _ready() -> void:
	var files := _walk(ROOTS)
	var failed: Array[String] = []

	for path in files:
		# CACHE_MODE_IGNORE so a script already pulled in by an autoload
		# is recompiled here rather than reported from the cache.
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null:
			failed.append(path)

	print("")
	print("=== validated %d files, %d failed ===" % [files.size(), failed.size()])
	for path in failed:
		print("  FAILED  ", path)

	get_tree().quit(1 if failed.size() > 0 else 0)


func _walk(roots: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for root in roots:
		_scan(root, out)
	out.sort()
	return out


func _scan(folder: String, into: Array[String]) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := folder.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan(path, into)
		elif entry.ends_with(".gd") or entry.ends_with(".tscn"):
			into.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
