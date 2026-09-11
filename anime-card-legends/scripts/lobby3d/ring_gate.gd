class_name RingGate
extends Area3D

# =========================================================
# ONE RING on the course.
#
# The ring you SEE is a torus. The thing that counts you through it is a
# short cylinder down its axis, radius matched to the hole - so the
# trigger is the hole, and clipping the rim does not count.
#
# Rings are not solid. A torus has no primitive collision shape, and
# faking one out of a ring of boxes gives you an obstacle course of
# invisible corners to catch a wing on. The challenge here is flying the
# LINE, so the rim is something to aim at rather than something to crash
# into.
#
# Each ring knows its own number. They have to be taken in order: flying
# through ring 12 having missed 11 does nothing, which is what stops the
# course being cleared by aiming at the middle of the pile.
# =========================================================

signal passed(index: int)

const RIM_THICKNESS := 0.42
const TRIGGER_DEPTH := 1.6
const SEGMENTS := 28

# Waiting, cleared, and the one you are meant to fly through next.
const COLOR_WAITING := Color("#2f7f95")
const COLOR_NEXT := Color("#35d6ff")
const COLOR_DONE := Color("#3ecf7e")

var index := 0
var radius := 7.0

var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _glow: OmniLight3D
var _cleared := false
var _is_next := false


static func create(at: Vector3, facing: Vector3, ring_radius: float, number: int) -> RingGate:
	var gate := RingGate.new()
	gate.index = number
	gate.radius = ring_radius
	gate.position = at
	# A torus lies in its own XZ plane, so its axis is +Y. Standing that
	# axis along the direction of travel is what makes the ring something
	# you fly THROUGH rather than over.
	gate.basis_from(facing)
	return gate


func basis_from(facing: Vector3) -> void:
	var forward := facing.normalized()
	if forward.length() < 0.01:
		forward = Vector3.FORWARD

	# Any vector not parallel to the axis will do for the second one.
	var reference := Vector3.UP
	if absf(forward.dot(reference)) > 0.98:
		reference = Vector3.RIGHT

	var right := reference.cross(forward).normalized()
	var up := forward.cross(right).normalized()
	transform.basis = Basis(right, forward, up)


func _ready() -> void:
	monitoring = true

	var torus := TorusMesh.new()
	torus.inner_radius = radius - RIM_THICKNESS
	torus.outer_radius = radius
	torus.rings = SEGMENTS
	torus.ring_segments = 10

	_mesh = MeshInstance3D.new()
	_mesh.mesh = torus
	_material = StandardMaterial3D.new()
	_material.emission_enabled = true
	_mesh.material_override = _material
	add_child(_mesh)

	_glow = OmniLight3D.new()
	_glow.omni_range = radius * 2.4
	_glow.light_energy = RenderMode.light(0.8)
	add_child(_glow)

	var shape := CollisionShape3D.new()
	var tube := CylinderShape3D.new()
	# The trigger is the HOLE, not the ring: clipping the rim is a miss.
	tube.radius = maxf(radius - RIM_THICKNESS, 0.5)
	tube.height = TRIGGER_DEPTH
	shape.shape = tube
	add_child(shape)

	_apply_colour()
	body_entered.connect(_on_entered)


func _on_entered(body: Node) -> void:
	if _cleared or not (body is CarBody):
		return
	if not _is_next:
		return
	_cleared = true
	_apply_colour()
	passed.emit(index)


func set_next(value: bool) -> void:
	_is_next = value
	_apply_colour()


func reset() -> void:
	_cleared = false
	_is_next = false
	_apply_colour()


func is_cleared() -> bool:
	return _cleared


func _apply_colour() -> void:
	if _material == null:
		return
	var tint := COLOR_WAITING
	if _cleared:
		tint = COLOR_DONE
	elif _is_next:
		tint = COLOR_NEXT

	_material.albedo_color = tint
	_material.emission = tint
	var burn := 1.0 if _is_next else 0.45
	_material.emission_energy_multiplier = RenderMode.emission(burn)
	if _glow != null:
		_glow.light_color = tint
		_glow.visible = _is_next
