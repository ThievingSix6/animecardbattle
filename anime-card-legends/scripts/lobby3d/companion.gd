class_name Companion
extends Node3D

# =========================================================
# A spectral projection of the player's best card, drifting a few
# metres behind them in the lobby. Purely cosmetic - a trophy you
# can see, and a reason to care about pulling something rare.
# =========================================================

const FOLLOW_DISTANCE := 3.4
const HOVER_HEIGHT := 1.9
const FOLLOW_SMOOTH := 3.0
const BOB_AMPLITUDE := 0.18
const BOB_SPEED := 1.4
const PANEL_WIDTH := 2.0

var card: CardData

var _panel: MeshInstance3D
var _glow: OmniLight3D
var _plate: Label3D
var _time := 0.0
var _target: Node3D


static func create(source: CardData, target: Node3D) -> Companion:
	var node := Companion.new()
	node.card = source
	node._target = target
	node._build()
	return node


func _build() -> void:
	var accent := Design.rarity_color(card.rarity)
	if Mutations.is_mutated(card.modifier):
		accent = Mutations.color(card.modifier)

	# The card itself, as a translucent floating plane.
	_panel = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(PANEL_WIDTH, PANEL_WIDTH * 1.5)
	_panel.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = CardArt.for_card(card)
	mat.albedo_color = Color(1, 1, 1, 0.62)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.emission_enabled = true
	mat.emission = accent
	mat.emission_energy_multiplier = 0.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_panel.material_override = mat
	add_child(_panel)

	# Rarity-coloured halo behind it.
	var halo := MeshInstance3D.new()
	var halo_quad := QuadMesh.new()
	halo_quad.size = Vector2(PANEL_WIDTH * 1.5, PANEL_WIDTH * 2.0)
	halo.mesh = halo_quad
	halo.position.z = -0.05

	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(accent.r, accent.g, accent.b, 0.16)
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_mat.billboard_keep_scale = true
	halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	halo.material_override = halo_mat
	add_child(halo)

	_glow = OmniLight3D.new()
	_glow.light_color = accent
	_glow.light_energy = 1.4
	_glow.omni_range = 8.0
	add_child(_glow)

	_plate = Label3D.new()
	_plate.text = _title()
	_plate.font_size = 64
	_plate.pixel_size = 0.004
	_plate.position.y = PANEL_WIDTH * 0.85
	_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plate.modulate = accent
	_plate.outline_size = 20
	_plate.outline_modulate = Design.BG
	_plate.no_depth_test = true
	add_child(_plate)


func _title() -> String:
	var prefix := ""
	if Mutations.is_mutated(card.modifier):
		prefix = Mutations.display_name(card.modifier) + " "
	return prefix + card.card_name


func _process(delta: float) -> void:
	if _target == null:
		return

	_time += delta

	# Trail behind whichever way the player is facing.
	var facing := _target.global_transform.basis.z
	var behind := _target.global_position + facing.normalized() * FOLLOW_DISTANCE
	behind.y = HOVER_HEIGHT + sin(_time * BOB_SPEED) * BOB_AMPLITUDE

	global_position = global_position.lerp(behind, clamp(FOLLOW_SMOOTH * delta, 0.0, 1.0))

	if _glow:
		_glow.light_energy = 1.2 + sin(_time * 2.0) * 0.3
