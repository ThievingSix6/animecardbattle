extends Node

# =========================================================
# Installs the application theme at the scene-tree root (autoload).
# =========================================================

func _ready() -> void:
	get_tree().root.theme = ThemeBuilder.build()
