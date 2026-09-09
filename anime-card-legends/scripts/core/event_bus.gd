extends Node

# =========================================================
# EVENT BUS (autoload)
# Systems announce what happened; screens listen. Replaces the old
# pattern of screens polling state in _process() every frame and
# manually rebuilding themselves.
# =========================================================

# Economy / collection
@warning_ignore("unused_signal")
signal currency_changed(gems: int, gold: int)
@warning_ignore("unused_signal")
signal collection_changed
@warning_ignore("unused_signal")
signal team_changed
@warning_ignore("unused_signal")
signal card_acquired(card: CardData, is_new: bool)

# Rolling
@warning_ignore("unused_signal")
signal auto_rolled(cards: Array)
@warning_ignore("unused_signal")
signal bulk_roll_finished(summary: Dictionary)

# Progression
@warning_ignore("unused_signal")
signal talent_upgraded(talent: String, level: int)
@warning_ignore("unused_signal")
signal floor_cleared(floor_number: int, rewards: Dictionary)
@warning_ignore("unused_signal")
signal roll_pack_granted(pack_id: String)

# World
@warning_ignore("unused_signal")
signal weather_started(event: Dictionary)
@warning_ignore("unused_signal")
signal weather_ended
@warning_ignore("unused_signal")
signal weather_tick(seconds_remaining: float)

# UI
@warning_ignore("unused_signal")
signal toast_requested(message: String, kind: String)


func toast(message: String, kind: String = "info") -> void:
	toast_requested.emit(message, kind)
