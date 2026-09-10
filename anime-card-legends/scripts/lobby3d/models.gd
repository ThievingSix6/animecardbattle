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
const PROP_FOLDER := FOLDER + "props/"

# Sidecar emissive maps. A .glb that was exported without its emission
# slot assigned still ships the map as a loose file, so rather than make
# you re-author the material, the loader picks it up from beside the
# model.
const IMAGE_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp", "tga"]
const EMISSIVE_ENERGY := 1.6

# .glb is the format to prefer - one self-contained file, textures
# included, no missing-texture surprises.
const EXTENSIONS: Array[String] = ["glb", "gltf", "tscn", "scn", "escn", "dae", "obj", "fbx", "blend"]

static var _cache: Dictionary = {}
static var _emissive_cache: Dictionary = {}


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


# Shared scenery: building, portal, streetlight, and anything else the
# worlds ask for by name.
static func prop_resource(prop_name: String) -> Resource:
	return _find(PROP_FOLDER + prop_name)


static func has_prop(prop_name: String) -> bool:
	return prop_resource(prop_name) != null


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


# Every spawn goes through here, so a sidecar emissive map is applied
# wherever the model is used without each caller remembering to ask.
static func spawn_zone(zone_id: String) -> Node3D:
	var node := spawn(zone_resource(zone_id))
	apply_emissive(node, ZONE_FOLDER + zone_id)
	return node


static func spawn_player() -> Node3D:
	var node := spawn(player_resource())
	apply_emissive(node, FOLDER + "player")
	return node


static func spawn_prop(prop_name: String) -> Node3D:
	var node := spawn(prop_resource(prop_name))
	apply_emissive(node, PROP_FOLDER + prop_name)
	return node


# --- Emissive sidecars ----------------------------------------------------
#
# Exporters routinely drop the emission slot, so the map arrives as a
# loose texture_emissive.png next to the model instead of inside it.
# Both of these are picked up, in this order:
#
#   art/models/zones/proving_emissive.png
#   art/models/zones/proving/texture_emissive.png
#
# The second form exists because every exporter names the file the same
# thing, so several of them cannot share one folder. Give the model a
# folder of its own named after it and the original filename is fine.

static func emissive_texture(base_path: String) -> Texture2D:
	# Looked up once per model: the city spawns one building forty times
	# and must not stat the filesystem forty times over.
	if _emissive_cache.has(base_path):
		return _emissive_cache[base_path]

	var found := _scan_emissive(base_path)
	_emissive_cache[base_path] = found
	return found


static func _scan_emissive(base_path: String) -> Texture2D:
	for ext in IMAGE_EXTENSIONS:
		var path := base_path + "_emissive." + ext
		if ResourceLoader.exists(path):
			return load(path)

	# A folder named after the model: take any file with "emissive" in it.
	var folder := base_path + "/"
	var dir := DirAccess.open(folder)
	if dir == null:
		return null

	var found: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower := file_name.to_lower()
			if lower.contains("emissive") or lower.contains("emission") or lower.contains("_glow"):
				for ext in IMAGE_EXTENSIONS:
					if lower.ends_with("." + ext):
						found.append(folder + file_name)
						break
		file_name = dir.get_next()
	dir.list_dir_end()

	if found.is_empty():
		return null
	found.sort()
	return load(found[0])


static func has_emissive(base_path: String) -> bool:
	return emissive_texture(base_path) != null


# Lights up every surface of the model with the sidecar map. Materials
# that already carry their own emission are left alone - a correctly
# exported model is never overridden.
static func apply_emissive(root: Node3D, base_path: String, energy: float = EMISSIVE_ENERGY) -> bool:
	if root == null:
		return false

	var texture := emissive_texture(base_path)
	if texture == null:
		return false

	_light_surfaces(root, texture, energy)
	return true


static func _light_surfaces(node: Node, texture: Texture2D, energy: float) -> void:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node
		if mesh_node.mesh != null:
			for i in mesh_node.mesh.get_surface_count():
				_light_surface(mesh_node, i, texture, energy)

	for child in node.get_children():
		_light_surfaces(child, texture, energy)


static func _light_surface(mesh_node: MeshInstance3D, surface: int, texture: Texture2D, energy: float) -> void:
	var source: Material = mesh_node.get_surface_override_material(surface)
	if source == null:
		source = mesh_node.mesh.surface_get_material(surface)
	if source == null or not (source is StandardMaterial3D):
		return

	var base: StandardMaterial3D = source
	if base.emission_enabled and base.emission_texture != null:
		return

	# Duplicated so two instances of one model cannot fight over the
	# same material resource.
	var lit: StandardMaterial3D = base.duplicate()
	lit.emission_enabled = true
	lit.emission_texture = texture
	lit.emission = Color.WHITE
	lit.emission_energy_multiplier = energy
	mesh_node.set_surface_override_material(surface, lit)


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
