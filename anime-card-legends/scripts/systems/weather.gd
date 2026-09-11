class_name WeatherSystem
extends RefCounted

# =========================================================
# Timed global events that boost luck and skew the pool toward
# one element. Driven by wall-clock time so an event keeps running
# (and correctly expires) across save/load.
# =========================================================

var active: Dictionary = {}
var ends_at: float = 0.0
var next_check_at: float = 0.0

var _last_tick_second := -1


func update() -> void:
	var now := Time.get_unix_time_from_system()

	if not active.is_empty():
		if now >= ends_at:
			stop()
		else:
			var remaining := ends_at - now
			var whole := int(remaining)
			if whole != _last_tick_second:
				_last_tick_second = whole
				EventBus.weather_tick.emit(remaining)
		return

	if next_check_at == 0.0:
		schedule_next()
		return

	if now >= next_check_at:
		if randf() < Config.EVENT_CHANCE:
			start()
		schedule_next()


func schedule_next() -> void:
	next_check_at = Time.get_unix_time_from_system() + randf_range(Config.EVENT_CHECK_MIN, Config.EVENT_CHECK_MAX)


func start(event_id: String = "") -> void:
	var chosen: Dictionary = {}
	if event_id == "":
		chosen = Config.WEATHER_EVENTS[randi() % Config.WEATHER_EVENTS.size()]
	else:
		for e in Config.WEATHER_EVENTS:
			if e["id"] == event_id:
				chosen = e
				break
	if chosen.is_empty():
		return

	active = chosen.duplicate()
	ends_at = Time.get_unix_time_from_system() + Config.EVENT_DURATION
	EventBus.weather_started.emit(active)


func stop() -> void:
	active = {}
	ends_at = 0.0
	EventBus.weather_ended.emit()


func is_active() -> bool:
	return not active.is_empty()


func seconds_remaining() -> float:
	if not is_active():
		return 0.0
	return maxf(0.0, ends_at - Time.get_unix_time_from_system())


func boosted_element() -> String:
	if not is_active():
		return ""
	return str(active.get("element", ""))


func luck_multiplier() -> float:
	if is_active():
		return Config.EVENT_LUCK_MULT
	return 1.0
