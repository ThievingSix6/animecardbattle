extends Node

# =========================================================
# ORIENTATION PROOF.
#
#   godot --headless --path . tools/Measure.tscn
#
# For every prop, three boxes are measured:
#
#   mesh      the FIRST mesh's raw AABB, which is all the MultiMesh
#             paths used to draw and in the wrong orientation too
#   fixed     every mesh merged with its transform baked in, which is
#             what they draw now
#   node      the whole model instanced as nodes, which has always been
#             right because Godot applies the hierarchy itself
#
# "fixed" and "node" agreeing is the invariant: it means the MultiMesh
# path and the node path now put a model the same way up. Where "mesh"
# disagrees with them is exactly how wrong it was before.
# =========================================================

const POOLS: Array[String] = ["skyline", "scatter", "trees", "mountains", "buildings"]
const SINGLES: Array[String] = ["stadium", "statue", "car", "portal", "building"]


func _ready() -> void:
	var names: Array[String] = []
	for pool in POOLS:
		names.append_array(Models.list_props(pool))
	names.append_array(SINGLES)

	var wrong := 0
	print("")
	print("%-46s %-22s %-22s %s" % ["model", "mesh (was drawn)", "fixed (drawn now)", "node (ground truth)"])

	for model_name in names:
		var node := Models.spawn_prop(model_name)
		if node == null:
			continue
		add_child(node)

		var first := Models.first_mesh(node)
		if first == null:
			node.queue_free()
			continue
		var raw := first.get_aabb()

		var info := Models.merged_mesh_info(node, Models.PROP_FOLDER + model_name)
		var mesh: Mesh = info["mesh"]
		if mesh == null:
			node.queue_free()
			continue
		var fixed := mesh.get_aabb()
		var whole: AABB = Models.model_frame(node) * Models.combined_aabb(node)

		var agrees := _same_shape(fixed, whole)
		var changed := not _same_shape(raw, fixed)
		var flag := ""
		if not agrees:
			flag = "  <-- MULTIMESH STILL DISAGREES"
			wrong += 1
		elif changed:
			flag = "  (was sideways, now correct)"

		print("%-46s %-22s %-22s %s%s" % [
			model_name.get_file(), _shape(raw), _shape(fixed), _shape(whole), flag])
		node.queue_free()

	print("")
	print("=== %d models disagree ===" % wrong)
	get_tree().quit(1 if wrong > 0 else 0)


# Shape only, not size: a model may legitimately be scaled by its
# correction, and all that matters here is which way up it is.
func _same_shape(a: AABB, b: AABB) -> bool:
	if a.size.y <= 0.0001 or b.size.y <= 0.0001:
		return false
	var one := a.size / a.size.y
	var two := b.size / b.size.y
	return one.distance_to(two) < 0.02


func _shape(box: AABB) -> String:
	return "%.2f x %.2f x %.2f" % [box.size.x, box.size.y, box.size.z]
