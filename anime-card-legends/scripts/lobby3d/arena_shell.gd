class_name ArenaShell
extends RefCounted

# =========================================================
# THE ARENA SURFACE, as one continuous swept shell.
#
# What this replaces: six box slabs. A floor, four flat walls and a
# ceiling, with hard right-angled joins and nothing in the corners. Two
# things were wrong with that beyond the look of it - the stadium model
# is bigger than the box, so driving out onto the part of the stadium you
# can SEE put the car past the end of the only collision that existed and
# it fell forever; and a box has no wall-to-floor transition, so there is
# nowhere to carry speed through a corner.
#
# HOW THE SHAPE IS MADE. One rounded rectangle, swept up the height of
# the arena and pulled inward near the floor and the ceiling:
#
#   inset(h) = r - sqrt(r^2 - (r - h)^2)     for h < r
#
# which is the quarter circle that turns the floor into the wall. A
# rounded rectangle offset inward by d is just a rounded rectangle with
# a-d, b-d and radius-d, so every ring is the same function with a
# different inset and the whole surface falls out of one loop.
#
# The result is Rocket League's cross-section: flat floor, curved
# transition up into the wall, straight wall, rounded corner, curved
# transition into a flat ceiling.
#
# The SAME triangles become the collision. That is the point - the thing
# you see and the thing you hit cannot drift apart, which is exactly how
# the old arena ended up with a void outside its own walls.
# =========================================================

# Rocket League's field, in uu.
const FIELD_WIDTH_UU := 8192.0
const FIELD_LENGTH_UU := 10240.0
const FIELD_HEIGHT_UU := 2044.0
# The 45-degree corners, as a radius.
const CORNER_RADIUS_UU := 1152.0
# The fillets that turn floor into wall and wall into ceiling.
const FLOOR_FILLET_UU := 256.0
const CEILING_FILLET_UU := 256.0

const GOAL_WIDTH_UU := 1786.0
const GOAL_HEIGHT_UU := 642.775
const GOAL_DEPTH_UU := 880.0

# How finely the shape is cut up. Rings up the height, and segments
# around each corner arc.
const RINGS := 26
const CORNER_SEGMENTS := 10


static func half_width() -> float:
	return FIELD_WIDTH_UU * 0.5 * CarBody.UU


static func half_length() -> float:
	return FIELD_LENGTH_UU * 0.5 * CarBody.UU


static func height() -> float:
	return FIELD_HEIGHT_UU * CarBody.UU


static func goal_half_width() -> float:
	return GOAL_WIDTH_UU * 0.5 * CarBody.UU


static func goal_height() -> float:
	return GOAL_HEIGHT_UU * CarBody.UU


static func goal_depth() -> float:
	return GOAL_DEPTH_UU * CarBody.UU


# --- The cross-section -------------------------------------------------

# One ring of the shell: a rounded rectangle inset by `inset`, as a
# closed loop of points in XZ. Corners are walked as arcs so the loop is
# already smooth - there is no separate corner geometry anywhere.
static func _ring(inset: float) -> PackedVector2Array:
	var a := maxf(half_width() - inset, 0.01)
	var b := maxf(half_length() - inset, 0.01)
	var r := clampf(CORNER_RADIUS_UU * CarBody.UU - inset, 0.01, minf(a, b))

	# The centres of the four corner arcs, anticlockwise from +X +Z.
	var centres: Array[Vector2] = [
		Vector2(a - r, b - r),
		Vector2(-(a - r), b - r),
		Vector2(-(a - r), -(b - r)),
		Vector2(a - r, -(b - r)),
	]
	# Each arc sweeps a quarter turn, starting where the previous
	# straight run ended.
	var starts: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]

	var loop := PackedVector2Array()
	for corner in 4:
		var centre: Vector2 = centres[corner]
		var from: float = starts[corner]
		for step in CORNER_SEGMENTS + 1:
			var angle := from + PI * 0.5 * float(step) / float(CORNER_SEGMENTS)
			loop.append(centre + Vector2(cos(angle), sin(angle)) * r)
	return loop


# How far in the surface is pulled at a given height: the floor fillet
# near the bottom, the ceiling fillet near the top, nothing between.
static func _inset_at(h: float) -> float:
	var top := height()
	var floor_r := FLOOR_FILLET_UU * CarBody.UU
	var ceiling_r := CEILING_FILLET_UU * CarBody.UU

	if h < floor_r:
		return floor_r - sqrt(maxf(floor_r * floor_r - (floor_r - h) * (floor_r - h), 0.0))
	if h > top - ceiling_r:
		var down := ceiling_r - (top - h)
		return ceiling_r - sqrt(maxf(ceiling_r * ceiling_r - down * down, 0.0))
	return 0.0


# Heights of the rings, packed towards the two fillets where the shape
# actually curves and spread out up the straight wall between them.
static func _heights() -> PackedFloat32Array:
	var top := height()
	var floor_r := FLOOR_FILLET_UU * CarBody.UU
	var ceiling_r := CEILING_FILLET_UU * CarBody.UU

	var out := PackedFloat32Array()
	var curved := 7
	for i in curved + 1:
		out.append(floor_r * float(i) / float(curved))
	var straight := RINGS - curved * 2
	for i in range(1, straight):
		out.append(floor_r + (top - ceiling_r - floor_r) * float(i) / float(straight))
	for i in curved + 1:
		out.append(top - ceiling_r + ceiling_r * float(i) / float(curved))
	return out


# --- Building ----------------------------------------------------------

# Everything the arena needs, built once:
#   "walls"     the transparent shell - wall and ceiling triangles
#   "floor"     the opaque pitch surface
#   "faces"     every triangle, for the collision trimesh
static func build() -> Dictionary:
	var heights := _heights()
	var rings: Array[PackedVector2Array] = []
	for h in heights:
		rings.append(_ring(_inset_at(h)))

	var walls := PackedVector3Array()
	var faces := PackedVector3Array()

	var mouth_x := goal_half_width()
	var mouth_y := goal_height()
	var back := half_length()

	for level in rings.size() - 1:
		var low: PackedVector2Array = rings[level]
		var high: PackedVector2Array = rings[level + 1]
		var y_low := heights[level]
		var y_high := heights[level + 1]

		for i in low.size():
			var j := (i + 1) % low.size()
			var a := Vector3(low[i].x, y_low, low[i].y)
			var b := Vector3(low[j].x, y_low, low[j].y)
			var c := Vector3(high[j].x, y_high, high[j].y)
			var d := Vector3(high[i].x, y_high, high[i].y)

			# The goal mouths are holes in the shell rather than geometry
			# laid over it: any quad sitting inside one is simply not
			# emitted, so what you see and what you hit agree.
			var mid := (a + b + c + d) * 0.25
			if absf(mid.x) < mouth_x and mid.y < mouth_y and absf(mid.z) > back * 0.92:
				continue

			# Wound so the normals face INTO the arena, which is the side
			# anything is ever looking at them from.
			_quad(walls, a, b, c, d)
			_quad(faces, a, b, c, d)

	var floor_mesh := PackedVector3Array()
	_cap(floor_mesh, rings[0], heights[0], true)
	_cap(faces, rings[0], heights[0], true)

	return {"walls": walls, "floor": floor_mesh, "faces": faces}


# Two triangles, inward-facing.
static func _quad(into: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	into.append(a)
	into.append(c)
	into.append(b)
	into.append(a)
	into.append(d)
	into.append(c)


# Fills a ring with a fan from its centre. The ring is a rounded
# rectangle and so always convex, which is what makes a fan safe.
static func _cap(into: PackedVector3Array, loop: PackedVector2Array, y: float, upward: bool) -> void:
	var centre := Vector3(0.0, y, 0.0)
	for i in loop.size():
		var j := (i + 1) % loop.size()
		var a := Vector3(loop[i].x, y, loop[i].y)
		var b := Vector3(loop[j].x, y, loop[j].y)
		if upward:
			into.append(centre)
			into.append(a)
			into.append(b)
		else:
			into.append(centre)
			into.append(b)
			into.append(a)


# A mesh from a triangle soup, with normals worked out per face.
static func mesh_from(faces: PackedVector3Array, material: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()

	for i in range(0, faces.size(), 3):
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		var n := (b - a).cross(c - a).normalized()
		var corners: Array[Vector3] = [a, b, c]
		for v in corners:
			verts.append(v)
			normals.append(n)
			# Projected from above for the floor and off the height for
			# the walls, which is enough for a grid or a scuff texture.
			uvs.append(Vector2(v.x, v.z) * 0.02 if absf(n.y) > 0.7 else Vector2(v.x + v.z, v.y) * 0.02)

	var surface: Array = []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = verts
	surface[Mesh.ARRAY_NORMAL] = normals
	surface[Mesh.ARRAY_TEX_UV] = uvs

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	if material != null:
		mesh.surface_set_material(0, material)
	return mesh
