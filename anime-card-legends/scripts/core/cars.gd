class_name Cars
extends RefCounted

# =========================================================
# THE GARAGE - every car model on disk, as a pool.
#
# Drop a .glb in res://art/models/props/cars/ and it is a car you can
# pick. No registry to edit, no id to invent: the filename is the name,
# the same way card art and the city's buildings already work.
#
#   art/models/props/cars/octane.glb      ->  "Octane"
#   art/models/props/cars/dominus_gt.glb  ->  "Dominus GT"
#
# The original art/models/props/car.glb still works and appears first,
# so nothing has to be moved for this to land.
#
# WHICH WAY A CAR FACES IS MEASURED, NOT CONFIGURED. A car exported with
# its length along X needs a quarter turn; one exported along Z does not.
# That used to be a hand-set constant tuned for one model, which is no
# use at all once there are four. The model is measured instead: whichever
# horizontal axis is longer is the car's length, and it gets turned to
# lie along -Z. Drop a car in facing any direction and it drives forwards.
# =========================================================

const FOLDER := "cars"
const LEGACY := "car"


# Every car, in a stable order, as model names ready for
# Models.spawn_prop(). The legacy single car leads if it is still there.
static func list() -> Array[String]:
	var found: Array[String] = []
	if Models.has_prop(LEGACY):
		found.append(LEGACY)
	found.append_array(Models.list_props(FOLDER))
	return found


static func count() -> int:
	return list().size()


# A readable name for the picker: "dominus_gt" -> "Dominus GT".
static func display_name(model_name: String) -> String:
	var base := model_name.get_file()
	if base == LEGACY:
		return "Standard"
	return base.replace("_", " ").replace("-", " ").capitalize()


# The model the player has chosen, or the first one available. Falls back
# to "" when there are no car models at all, which the car reads as "use
# the procedural wedge".
static func selected() -> String:
	var pool := list()
	if pool.is_empty():
		return ""

	var wanted := Settings.car_model
	if pool.has(wanted):
		return wanted
	return pool[0]


static func select(model_name: String) -> void:
	Settings.set_car_model(model_name)


# Steps through the pool, wrapping. For the picker's arrows.
static func next(model_name: String, step: int) -> String:
	var pool := list()
	if pool.is_empty():
		return ""
	var at := pool.find(model_name)
	if at < 0:
		at = 0
	return pool[(at + step + pool.size()) % pool.size()]


# --- Orientation --------------------------------------------------------

# The turn that puts a model's LENGTH along -Z, which is the way a car in
# Godot faces. Measured from the model itself rather than set per car.
static func facing_yaw(model: Node3D) -> float:
	if model == null:
		return 0.0
	var box := Models.model_frame(model) * Models.combined_aabb(model)
	# Longer on X than on Z: its length runs sideways, so turn it a
	# quarter.
	if box.size.x > box.size.z:
		return PI * 0.5
	return 0.0


# Spawns the chosen car, turned to face forwards and ready to be fitted.
# Returns null when there is no model on disk.
static func spawn(model_name: String) -> Node3D:
	if model_name == "":
		return null
	var model := Models.spawn_prop(model_name)
	if model == null:
		return null
	Models.spin(model, facing_yaw(model))
	return model
