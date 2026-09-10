class_name Portal
extends Node3D

# =========================================================
# TELEPORTER PORTAL.
#
# One of these stands in the city and in every campaign zone. Walking
# onto its pad and pressing ENTER opens the travel menu, so the run is
# never a one-way trip - you can drop back to the city for a summon or
# jump ahead to a zone you have already opened.
#
# Uses res://art/models/props/portal.glb when it exists. With no model
# it builds a ring of its own, so the mechanic works before the art
# lands.
# =========================================================

const RADIUS := 4.5
const MODEL_HEIGHT := 5.2

var tint := Color("#5ad1ff")

var _pad: MeshInstance3D
var _pad_material: StandardMaterial3D
var _spin: Node3D
var _swirl_material: StandardMaterial3D


static func create(accent: Color = Color("#5ad1ff")) -> Portal:
	var portal := Portal.new()
	portal.tint = accent
	return portal


func _ready() -> void:
	if not _build_model():
		_build_fallback_ring()

	_build_pad()
	_build_light()
	_build_plate()


func interaction_radius() -> float:
	return RADIUS


# --- Body ---------------------------------------------------------------

func _build_model() -> bool:
	var model := Models.spawn_prop("portal")
	if model == null:
		return false

	_spin = Node3D.new()
	add_child(_spin)
	_spin.add_child(model)
	Models.fit_height(model, MODEL_HEIGHT)
	return true


# A ring on a plinth, with a swirling disc in the middle. Deliberately
# simple - it is a placeholder for a real portal model.
func _build_fallback_ring() -> void:
	_spin = Node3D.new()
	add_child(_spin)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.7
	torus.outer_radius = 2.1
	ring.mesh = torus
	ring.position.y = 2.6
	ring.rotation.x = PI * 0.5

	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = tint
	ring_material.emission_enabled = true
	ring_material.emission = tint
	ring_material.emission_energy_multiplier = 1.8
	ring.material_override = ring_material
	_spin.add_child(ring)

	var swirl := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.7
	disc.bottom_radius = 1.7
	disc.height = 0.06
	disc.radial_segments = 32
	swirl.mesh = disc
	swirl.position.y = 2.6
	swirl.rotation.x = PI * 0.5

	_swirl_material = StandardMaterial3D.new()
	_swirl_material.albedo_color = Color(tint.r, tint.g, tint.b, 0.55)
	_swirl_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_swirl_material.emission_enabled = true
	_swirl_material.emission = tint
	_swirl_material.emission_energy_multiplier = 2.4
	_swirl_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	swirl.material_override = _swirl_material
	_spin.add_child(swirl)

	var plinth := MeshInstance3D.new()
	var base := CylinderMesh.new()
	base.top_radius = 2.4
	base.bottom_radius = 2.8
	base.height = 0.5
	base.radial_segments = 24
	plinth.mesh = base
	plinth.position.y = 0.25

	var plinth_material := StandardMaterial3D.new()
	plinth_material.albedo_color = Color("#161a26")
	plinth_material.roughness = 0.6
	plinth.material_override = plinth_material
	add_child(plinth)


func _build_pad() -> void:
	_pad = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.08
	disc.radial_segments = 32
	_pad.mesh = disc
	_pad.position.y = 0.05

	_pad_material = StandardMaterial3D.new()
	_pad_material.albedo_color = Color(tint.r, tint.g, tint.b, 0.22)
	_pad_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pad_material.emission_enabled = true
	_pad_material.emission = tint
	_pad_material.emission_energy_multiplier = 0.4
	_pad.material_override = _pad_material
	add_child(_pad)


func _build_light() -> void:
	var lamp := OmniLight3D.new()
	lamp.position.y = 2.8
	lamp.light_color = tint
	lamp.light_energy = 3.0
	lamp.omni_range = 20.0
	add_child(lamp)


func _build_plate() -> void:
	var plate := Label3D.new()
	plate.text = "◈  PORTAL"
	plate.font_size = 84
	plate.pixel_size = 0.006
	plate.position.y = MODEL_HEIGHT + 1.6
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.modulate = Color.WHITE
	plate.outline_size = 22
	plate.outline_modulate = Color("#0b0d14")
	plate.no_depth_test = true
	add_child(plate)


func _process(delta: float) -> void:
	if _spin != null:
		_spin.rotation.y += delta * 0.6


# Brightens as the player steps on, so the pad reads as live.
func set_active(active: bool) -> void:
	if _pad_material == null:
		return
	var alpha := 0.22
	var energy := 0.4
	if active:
		alpha = 0.55
		energy = 1.6
	_pad_material.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	_pad_material.emission_energy_multiplier = energy
