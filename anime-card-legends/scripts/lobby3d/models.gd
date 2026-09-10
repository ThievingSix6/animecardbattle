class_name Models
extends RefCounted

# =========================================================
# IMPORTED 3D MODELS.
#
# Drop files in and they are used; drop nothing in and the procedural
# geometry the game already builds stays exactly as it is. Nothing here
# needs a scene file, an inspector or a node path.
#
# WHERE THINGS GO
#   res://art/models/player.glb          the player character
#   res://art/models/zones/<id>.glb      one landmark per campaign zone
#
# Zone ids are the ones in scripts/core/campaign.gd:
#   proving, hollow, emberfall, duskmire, choir, heart
#
# SCALE DOES NOT MATTER. Every model is measured after loading and
# rescaled to the height the game wants, so a model exported in
# centimetres, metres or Blender units all land the same size. The
# model is also re-seated so its feet sit on y = 0 whether it was
# modelled around its origin or above it.
# =========================================================

const FOLDER := "res://art/models/"
const ZONE_FOLDER := FOLDER + "zones/"

# .glb is the format to prefer - one self-contained file, textures
# included, no missing-texture surprises.
const EXTENSIONS: Array[String] = ["glb", "gltf", "tscn", "scn", "escn", "dae", "obj", "fbx", "blend"]

static var _cache: Dictionary = {}


# --- Lookup -------------------------------------------------------------

# Finds <base>.<any supported extension>, or null.
static func _find(base_path: String) -> Resource:
	if _cache.has(base_path):
		return _cache[base_path]

	var found: Resource = null
	for ext in EXTENSIONS:
		var path := base_path + "." + ext
		if ResourceLoader.exists(path):
			found = load(path)
			if found != null:
				break

	_cache[base_path] = found
	return found


static func zone_resource(zone_id: String) -> Resource:
	return _find(ZONE_FOLDER + zone_id)


static func player_resource() -> Resource:
	return _find(FOLDER + "player")


static func has_zone(zone_id: String) -> bool:
	return zone_resource(zone_id) != null


static func has_player() -> bool:
	return player_resource() != null


# Which zone ids currently have a model on disk, for the asset report.
static func missing_zone_models() -> Array[String]:
	var missing: Array[String] = []
	for zone in Campaign.ZONES:
		var id := str(zone["id"])
		if not has_zone(id):
			missing.append(id)
	return missing


# --- Instancing ----------------------------------------------------------

# Turns whatever was loaded into a Node3D. A .glb or .tscn arrives as a
# PackedScene; a bare .obj arrives as a Mesh and gets wrapped.
static func spawn(resource: Resource) -> Node3D:
	if resource == null:
		return null

	if resource is PackedScene:
		var scene: PackedScene = resource
		var node := scene.instantiate()
		if node is Node3D:
			return node
		node.queue_free()
		return null

	if resource is Mesh:
		var holder := MeshInstance3D.new()
		holder.mesh = resource
		return holder

	return null


static func spawn_zone(zone_id: String) -> Node3D:
	return spawn(zone_resource(zone_id))


static func spawn_player() -> Node3D:
	return spawn(player_resource())


# --- Measuring and fitting -----------------------------------------------

# The bounding box of everything drawable under `root`, in root space.
static func combined_aabb(root: Node) -> AABB:
	return _collect(root, root)


static func _collect(node: Node, root: Node) -> AABB:
	var box := AABB()
	var started := false

	if node is VisualInstance3D:
		var vis: VisualInstance3D = node
		var local := vis.get_aabb()
		var relative := _relative_transform(vis, root)
		box = relative * local
		started = true

	for child in node.get_children():
		var child_box := _collect(child, root)
		if child_box.size == Vector3.ZERO:
			continue
		if started:
			box = box.merge(child_box)
		else:
			box = child_box
			started = true

	return box


# Transform of `node` expressed in `root`'s space, walking up the chain
# rather than relying on global transforms (the model is measured before
# it enters the tree).
static func _relative_transform(node: Node3D, root: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			var as_3d: Node3D = current
			result = as_3d.transform * result
		current = current.get_parent()
	return result


# Rescales the model so it stands `target_height` metres tall, and drops
# it so its lowest point rests on y = 0. Returns the scale applied.
static func fit_height(node: Node3D, target_height: float) -> float:
	var box := _collect(node, node)
	if box.size.y <= 0.0001:
		return 1.0

	var factor := target_height / box.size.y
	node.scale = Vector3(factor, factor, factor)
	node.position.y -= box.position.y * factor
	return factor


# The footprint of a fitted model, for building a collision box that
# matches whatever was imported.
static func fitted_size(node: Node3D) -> Vector3:
	var box := _collect(node, node)
	return box.size * node.scale


# --- Animation -----------------------------------------------------------

static func find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := find_animation_player(child)
		if found != null:
			return found
	return null


# Matches an animation by keyword rather than exact name, so the clip
# can be called "Idle", "idle_loop", "Armature|Idle" or "CharacterIdle"
# and still be found.
static func animation_named(player: AnimationPlayer, keywords: Array[String]) -> String:
	if player == null:
		return ""
	var names := player.get_animation_list()
	for keyword in keywords:
		for entry in names:
			if str(entry).to_lower().contains(keyword):
				return str(entry)
	return ""
