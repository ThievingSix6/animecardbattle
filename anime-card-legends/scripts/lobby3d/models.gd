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
const NPC_FOLDER := FOLDER + "npc/"

# Sidecar emissive maps. A .glb that was exported without its emission
# slot assigned still ships the map as a loose file, so rather than make
# you re-author the material, the loader picks it up from beside the
# model.
const IMAGE_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp", "tga"]

# Kept at 1.0 on purpose. A proper emissive map is already a mask - black
# where the surface does not glow - so multiplying it up only pushes the
# lit parts past what the renderer can show. On GL Compatibility, which
# is what this project uses, anything over 1.0 clips to flat white.
const EMISSIVE_ENERGY := 1.0

# Some exporters emit a placeholder emissive map that is a single flat
# colour - usually pure white, which lights the entire model uniformly
# and hides the artwork underneath. Those are rejected.
const PLACEHOLDER_MEAN := 0.86
const PLACEHOLDER_SPREAD := 0.06

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


# Every model sitting in a props subfolder, so a folder can be a
# pool - drop three mountains in and all three get used.
#
# A name starting with "_" is skipped, so a file can be parked in a pool
# folder without joining the pool. That is the quick way to take one
# model out of the city without moving it: _tower.glb.
static func list_props(subfolder: String) -> Array[String]:
	var folder := PROP_FOLDER + subfolder
	if not folder.ends_with("/"):
		folder += "/"

	var dir := DirAccess.open(folder)
	if dir == null:
		return []

	var found: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and not file_name.begins_with("_"):
			var lower := file_name.to_lower()
			for ext in EXTENSIONS:
				if lower.ends_with("." + ext):
					found.append(subfolder + "/" + file_name.get_basename())
					break
		file_name = dir.get_next()
	dir.list_dir_end()

	found.sort()
	return found


# The people in the city: diablo, the_boy, the_jokester.
static func npc_resource(npc_id: String) -> Resource:
	return _find(NPC_FOLDER + npc_id)


static func has_npc(npc_id: String) -> bool:
	return npc_resource(npc_id) != null


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


static func spawn_npc(npc_id: String) -> Node3D:
	var node := spawn(npc_resource(npc_id))
	apply_emissive(node, NPC_FOLDER + npc_id)
	return node


# The first mesh inside an imported model, AND the transform it sits
# under, for drawing many copies through a single MultiMesh instead of a
# node each.
#
# THE TRANSFORM IS NOT OPTIONAL. This was the whole orientation bug.
#
# Almost every .glb here was authored in a Z-up tool and exported with
# the Y-up conversion as a -90 degrees X rotation on the model's ROOT NODE
# rather than baked into the vertices. Measured for real:
#
#   Bench_02.glb    mesh data 192 x  72 x  55   (Z-up, on its back)
#                   under its root node         1.92 x 0.55 x 0.72  correct
#   stadium.glb     mesh data  45 x 3.8 x 1.8   (Z-up, on its back)
#
# Instancing the model as a node applies that rotation and everything
# looks right. Pulling the bare Mesh out for a MultiMesh dropped it on
# the floor, which is why "most of the models are still sitting on their
# side" - it was never a property of the models, it was this function
# throwing their correction away.
#
# Returns {"mesh": Mesh, "correction": Transform3D}; mesh is null when
# the model has no drawable geometry.
static func first_mesh_info(root: Node) -> Dictionary:
	var node := _first_mesh_node(root)
	if node == null or node.mesh == null:
		return {"mesh": null, "correction": Transform3D.IDENTITY}
	return {"mesh": node.mesh, "correction": model_frame(root) * _relative_transform(node, root)}


# The mesh on its own, for the callers that only need to know whether the
# model has geometry at all.
static func first_mesh(root: Node) -> Mesh:
	var node := _first_mesh_node(root)
	if node == null:
		return null
	return node.mesh


# The material a MultiMesh should draw that mesh with, emissive sidecar
# included - a MultiMeshInstance3D has one material for every copy.
static func first_material(root: Node, base_path: String) -> Material:
	var node := _first_mesh_node(root)
	if node == null:
		return null

	var source: Material = node.get_surface_override_material(0)
	if source == null and node.mesh != null and node.mesh.get_surface_count() > 0:
		source = node.mesh.surface_get_material(0)
	if source == null or not (source is BaseMaterial3D):
		return source

	var texture := emissive_texture(base_path)
	if texture == null:
		return source

	var base: BaseMaterial3D = source
	if base.emission_enabled and base.emission_texture != null:
		return base

	var lit: BaseMaterial3D = base.duplicate()
	_light_material(lit, texture, EMISSIVE_ENERGY)
	return lit


static func _first_mesh_node(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for child in root.get_children():
		var found := _first_mesh_node(child)
		if found != null:
			return found
	return null


# The MultiMesh version of fit_box: the horizontal and vertical scales
# a mesh needs to stand `height` tall on a `width` footprint, plus how
# far to lift it so its base sits on the ground.
#
# Takes the dictionary from first_mesh_info(), not a bare Mesh, so the
# model's own root correction is measured in and carried through to
# box_transform().
static func mesh_fit_box(info: Dictionary, model_name: String = "") -> Dictionary:
	var correction := _correction(info, model_name)
	var box: AABB = correction * _mesh_aabb(info)

	var widest := maxf(box.size.x, box.size.z)
	if box.size.y <= 0.0001 or widest <= 0.0001:
		return {"per_width": 1.0, "per_height": 1.0, "base": 0.0, "correction": correction}

	return {
		"per_width": 1.0 / widest,
		"per_height": 1.0 / box.size.y,
		"base": -box.position.y / box.size.y,
		"correction": correction,
	}


# Where one copy of a mesh_fit_box() model goes: yawed by `spin`, stood
# on `at`, scaled to its own footprint and height, with the model's root
# correction innermost so the geometry is the right way up.
static func box_transform(fit: Dictionary, at: Vector3, spin: float,
		width: float, height: float) -> Transform3D:
	var per_width := float(fit["per_width"])
	var per_height := float(fit["per_height"])
	var sized := Basis.IDENTITY.scaled(
		Vector3(per_width * width, per_height * height, per_width * width))
	var lift := Vector3(0.0, float(fit["base"]) * height, 0.0)
	var correction: Transform3D = fit["correction"]
	return Transform3D(Basis(Vector3.UP, spin), at) * Transform3D(sized, lift) * correction


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
			return _accept(load(path))

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
	return _accept(load(found[0]))


# Rejects a flat placeholder map. Sampled on a coarse grid - this runs
# once per model and only needs to tell "one solid colour" from "an
# actual mask".
static func _accept(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null

	var image := texture.get_image()
	if image == null:
		return texture
	if image.is_compressed():
		# decompress() fails on formats without a CPU decoder; if it
		# cannot be read, trust the file.
		if image.decompress() != OK:
			return texture

	var width := image.get_width()
	var height := image.get_height()
	if width < 2 or height < 2:
		return texture

	var steps := 16
	var total := 0.0
	var lowest := 1.0
	var highest := 0.0

	for ix in steps:
		for iy in steps:
			var x := int(float(ix) / float(steps) * float(width))
			var y := int(float(iy) / float(steps) * float(height))
			var pixel := image.get_pixel(x, y)
			var luminance := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			total += luminance
			lowest = minf(lowest, luminance)
			highest = maxf(highest, luminance)

	var mean := total / float(steps * steps)
	var spread := highest - lowest

	# Bright and flat: a placeholder, not a mask.
	if mean >= PLACEHOLDER_MEAN and spread <= PLACEHOLDER_SPREAD:
		push_warning("[Models] ignoring a flat emissive map at "
			+ texture.resource_path + " - it would light the whole model.")
		return null

	return texture


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
	# BaseMaterial3D, not StandardMaterial3D: glTF imports can arrive as
	# ORMMaterial3D, which is a sibling class, not a subclass, so the
	# narrower check silently skipped those models entirely.
	if source == null or not (source is BaseMaterial3D):
		return

	var base: BaseMaterial3D = source
	if base.emission_enabled and base.emission_texture != null:
		return

	# Duplicated so two instances of one model cannot fight over the
	# same material resource.
	var lit: BaseMaterial3D = base.duplicate()
	_light_material(lit, texture, energy)
	mesh_node.set_surface_override_material(surface, lit)


# The one that mattered: emission_operator.
#
# Godot's default is EMISSION_OP_ADD, and ADD means the emission COLOUR
# is added to the texture rather than tinting it:
#
#     EMISSION = (emission + emission_tex) * energy
#
# So a white emission colour over a black mask lights the entire model
# flat white, which is exactly what these models were doing - the maps
# themselves are proper masks, brightest pixel 148/255 and means near
# zero, so they could never have produced that on their own.
#
# MULTIPLY makes the colour a tint over the mask, which is what a
# sidecar emissive map is for:
#
#     EMISSION = (emission * emission_tex) * energy
static func _light_material(material: BaseMaterial3D, texture: Texture2D, energy: float) -> void:
	material.emission_enabled = true
	material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	material.emission_texture = texture
	material.emission = Color.WHITE
	material.emission_energy_multiplier = RenderMode.emission(energy)


# --- Orientation -----------------------------------------------------------
#
# There used to be a bounding-box guess here: "a model whose Z extent is
# bigger than its Y extent is lying on its back, stand it up". It was
# wrong, and it was wrong in both directions at once.
#
# Measured across all 43 models in this project, NOT ONE of them is
# actually Z-up once its own node transform is applied. Every single one
# already carries the Y-up conversion on its glTF root node. The guess
# was a coin flip on top of geometry that was already correct: it stood
# the signs and the trees up (right, by luck, because the MultiMesh path
# had separately discarded their correction) and it tipped the bench, the
# booths, the restaurant, the mountains and the stadium over (wrong).
#
# The correction is a fact recorded in the file. It does not need to be
# guessed - it needs to not be thrown away, which is what
# first_mesh_info() now fixes.
#
# What survives is the manual override, for a model that genuinely lacks
# the conversion node:
#
#     Japanese_Sign_01_zup.glb   rotate a quarter turn back upright
#     Terrain_Patch_yup.glb      leave exactly as exported
#
# Neither is needed by anything currently in art/models/.

const ZUP_ROTATION := Vector3(-PI * 0.5, 0.0, 0.0)


# The filename override, or Vector3.ZERO for "the file already knows".
static func override_rotation(model_name: String) -> Vector3:
	var lower := model_name.get_file().to_lower()
	if lower.ends_with("_zup"):
		return ZUP_ROTATION
	return Vector3.ZERO


# A model's full correction: what its own node hierarchy says, plus the
# filename override when one is present.
static func _correction(info: Dictionary, model_name: String) -> Transform3D:
	var correction: Transform3D = info.get("correction", Transform3D.IDENTITY)
	if model_name.get_file().to_lower().ends_with("_yup"):
		correction = Transform3D.IDENTITY
	var extra := override_rotation(model_name)
	if extra != Vector3.ZERO:
		correction = Transform3D(Basis.from_euler(extra), Vector3.ZERO) * correction
	return correction


static func _mesh_aabb(info: Dictionary) -> AABB:
	var mesh: Mesh = info.get("mesh")
	if mesh == null:
		return AABB()
	return mesh.get_aabb()


# A box after a transform: the eight corners moved, then re-bounded.
static func rotated_aabb(box: AABB, rotation: Vector3) -> AABB:
	if rotation == Vector3.ZERO:
		return box
	return Transform3D(Basis.from_euler(rotation), Vector3.ZERO) * box


# Everything a MultiMesh needs to stand one mesh at a given height
# WITHOUT distorting it: one uniform scale, how far to lift it so its
# base rests on the ground, and the model's own correction.
#
# Uniform is the whole point. Scaling a bench's width and height
# independently to hit a target height is what turned the props into
# tall thin slabs.
static func mesh_fit_upright(info: Dictionary, model_name: String, target_height: float) -> Dictionary:
	var correction := _correction(info, model_name)
	var box: AABB = correction * _mesh_aabb(info)

	var scale := 1.0
	if box.size.y > 0.0001:
		scale = target_height / box.size.y

	return {
		"scale": scale,
		"base": -box.position.y * scale,
		"size": box.size * scale,
		"correction": correction,
	}


# Where one copy of a mesh_fit_upright() model goes.
static func upright_transform(fit: Dictionary, at: Vector3, spin: float) -> Transform3D:
	var scale := float(fit["scale"])
	var sized := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
	var lift := Vector3(0.0, float(fit["base"]), 0.0)
	var correction: Transform3D = fit["correction"]
	return Transform3D(Basis(Vector3.UP, spin), at) * Transform3D(sized, lift) * correction


# --- Measuring and fitting -----------------------------------------------
#
# EVERY FIT COMPOSES WITH THE MODEL'S OWN TRANSFORM. It never assigns
# over it.
#
# Godot imports a .glb whose scene has a single root node - which is all
# 34 of the models here - by promoting that node to the scene root. The
# Y-up conversion, and often a x100 unit conversion with it, lives ON
# THAT NODE. So the node handed back by spawn_prop() arrives with a
# meaningful transform already, and the old `node.scale = ...` /
# `node.rotation = ...` in these functions wiped it out. That is the
# other half of why the models lay on their sides.
#
# The original transform is remembered the first time a model is fitted,
# so fitting twice cannot compound.

const FRAME_META := "acl_model_frame"


# The transform a model came out of its file with.
static func model_frame(node: Node) -> Transform3D:
	if not (node is Node3D):
		return Transform3D.IDENTITY
	var as_3d: Node3D = node
	if as_3d.has_meta(FRAME_META):
		return as_3d.get_meta(FRAME_META)
	as_3d.set_meta(FRAME_META, as_3d.transform)
	return as_3d.transform


# Turns a model to face a different way WITHOUT throwing its import
# transform away. `node.rotation.y = yaw` rebuilds the whole basis from
# euler angles and loses the model's Y-up correction with it; this puts
# the yaw outside whatever the model already carries.
static func spin(node: Node3D, yaw: float) -> void:
	if node == null or is_zero_approx(yaw):
		return
	node.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO) * node.transform


# The same, for a model that also needs nosing up or rolling over.
static func tilt(node: Node3D, pitch: float, roll: float) -> void:
	if node == null or (is_zero_approx(pitch) and is_zero_approx(roll)):
		return
	var turn := Basis(Vector3.RIGHT, pitch) * Basis(Vector3.FORWARD, roll)
	node.transform = Transform3D(turn, Vector3.ZERO) * node.transform


# The bounding box of everything drawable under `root`, in root space.
static func combined_aabb(root: Node) -> AABB:
	return _collect(root, root)


# The same box in the model's PARENT space: the geometry with the import
# transform applied, which is what every fit below actually measures.
static func _seated_aabb(node: Node3D, frame: Transform3D) -> AABB:
	return frame * _collect(node, node)


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
# it enters the tree). Excludes root's own transform, which is exactly
# what model_frame() supplies separately.
static func _relative_transform(node: Node3D, root: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			var as_3d: Node3D = current
			result = as_3d.transform * result
		current = current.get_parent()
	return result


# Applies a scale and a lift on top of the model's import transform.
static func _seat(node: Node3D, frame: Transform3D, scale: Vector3, lift: float) -> void:
	node.transform = Transform3D(Basis.IDENTITY.scaled(scale), Vector3(0.0, lift, 0.0)) * frame


# Rescales the model so it stands `target_height` metres tall, and drops
# it so its lowest point rests on y = 0. Returns the scale applied.
static func fit_height(node: Node3D, target_height: float) -> float:
	var frame := model_frame(node)
	var box := _seated_aabb(node, frame)
	if box.size.y <= 0.0001:
		return 1.0

	var factor := target_height / box.size.y
	_seat(node, frame, Vector3(factor, factor, factor), -box.position.y * factor)
	return factor


# Fits a model to a target footprint AND a target height independently.
#
# fit_height() scales uniformly, which ties a building's width to how
# tall it is: ask for a 50 m tower and you get a 50 m-wide block that
# swallows its own street. This keeps the footprint to the lot and lets
# the height run free, which is what makes a tower a tower.
static func fit_box(node: Node3D, target_width: float, target_height: float) -> void:
	var frame := model_frame(node)
	var box := _seated_aabb(node, frame)
	if box.size.y <= 0.0001:
		return

	var widest := maxf(box.size.x, box.size.z)
	var horizontal := 1.0
	if widest > 0.0001:
		horizontal = target_width / widest
	var vertical := target_height / box.size.y

	_seat(node, frame, Vector3(horizontal, vertical, horizontal), -box.position.y * vertical)


# Scales a model uniformly so its longest horizontal axis measures
# `target_length`, then seats it on the ground. For anything that must
# not be stretched - a vehicle, a character, a prop with proportions
# that matter.
static func fit_length(node: Node3D, target_length: float) -> float:
	var frame := model_frame(node)
	var box := _seated_aabb(node, frame)
	var longest := maxf(box.size.x, box.size.z)
	if longest <= 0.0001:
		return 1.0

	var factor := target_length / longest
	_seat(node, frame, Vector3(factor, factor, factor), -box.position.y * factor)
	return factor


# Fits an instanced model to a height WITHOUT distorting it. For props,
# statues, anything whose proportions are part of the model rather than
# something to be dictated.
#
# No guessing here. The import transform is already in `frame`, so this
# path is upright by construction; only the filename override can add a
# rotation on top.
static func fit_upright(node: Node3D, model_name: String, target_height: float) -> void:
	var frame := model_frame(node)
	var extra := override_rotation(model_name)
	if model_name.get_file().to_lower().ends_with("_yup"):
		frame = Transform3D.IDENTITY
	if extra != Vector3.ZERO:
		frame = Transform3D(Basis.from_euler(extra), Vector3.ZERO) * frame

	var box := _seated_aabb(node, frame)
	if box.size.y <= 0.0001:
		node.transform = frame
		return

	var factor := target_height / box.size.y
	_seat(node, frame, Vector3(factor, factor, factor), -box.position.y * factor)


# The footprint of a fitted model, for building a collision box that
# matches whatever was imported.
static func fitted_size(node: Node3D) -> Vector3:
	return (node.transform * _collect(node, node)).size


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


# The keyword lists, in one place, so the loader and the asset report
# can never disagree about what should have bound.
#
# Order matters: the first keyword that matches anything wins. The
# vaguer entries sit at the end as last resorts - a character with no
# idle clip at all standing in a dance loop still reads better than one
# frozen on frame zero.
const IDLE_WORDS: Array[String] = [
	"idle", "stand", "breath", "wait", "greet", "talk", "pose", "dance",
]
const RUN_WORDS: Array[String] = [
	"run", "walk", "jog", "sprint", "stride", "move",
]
const JUMP_WORDS: Array[String] = [
	"jump", "leap", "fall", "air",
]
const TALK_WORDS: Array[String] = [
	"talk", "speak", "greet", "chat", "sit", "converse",
]
const DEFEAT_WORDS: Array[String] = [
	"defeat", "death", "die", "dead", "lose", "loss", "kneel", "down",
	"ko", "hurt", "collapse",
]


# Every clip an actor uses, resolved together so the fallbacks can see
# each other: an actor with no idle borrows its talk clip, and one with
# no talk borrows its idle.
#
# Also makes the continuous clips loop. glTF has no concept of a looping
# animation, so every clip arrives as LOOP_NONE and plays exactly once -
# which is why the walk stopped dead a second in while the player kept
# moving. Idle, run and talk are set to loop; jump and defeat are
# one-shots and stay that way.
static func animation_set(player: AnimationPlayer) -> Dictionary:
	var out := {
		"idle": animation_named(player, IDLE_WORDS),
		"run": animation_named(player, RUN_WORDS),
		"jump": animation_named(player, JUMP_WORDS),
		"talk": animation_named(player, TALK_WORDS),
		"defeat": animation_named(player, DEFEAT_WORDS),
	}

	if str(out["idle"]) == "":
		out["idle"] = out["talk"]
	if str(out["talk"]) == "":
		out["talk"] = out["idle"]

	var looping: Array[String] = ["idle", "run", "talk"]
	for key in looping:
		set_looping(player, str(out[key]), true)

	return out


static func set_looping(player: AnimationPlayer, anim_name: String, looping: bool) -> void:
	if player == null or anim_name == "":
		return
	if not player.has_animation(anim_name):
		return

	var animation := player.get_animation(anim_name)
	if animation == null:
		return

	if looping:
		animation.loop_mode = Animation.LOOP_LINEAR
	else:
		animation.loop_mode = Animation.LOOP_NONE
