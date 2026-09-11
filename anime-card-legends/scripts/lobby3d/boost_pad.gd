class_name BoostPad
extends Area3D

# =========================================================
# A boost pad, Rocket League's two sizes.
#
#   BIG    100 boost, ten seconds to come back
#   SMALL   12 boost, four seconds
#
# Taking one is what makes the pad worth driving to rather than just
# holding boost down, and respawn times are what make CONTROL of the big
# pads a thing at all - so both are here rather than an infinite tank.
# =========================================================

signal collected(car: CarBody, amount: float)

const BIG_AMOUNT := 100.0
const SMALL_AMOUNT := 12.0
const BIG_RESPAWN := 10.0
const SMALL_RESPAWN := 4.0

const BIG_RADIUS := 1.9
const SMALL_RADIUS := 1.3
# How tall the trigger stands. A car has to touch the pad, not fly over
# it - but a wheel clipping the edge should still count.
const TRIGGER_HEIGHT := 2.6

var big := false

var _amount := SMALL_AMOUNT
var _respawn := SMALL_RESPAWN
var _cooldown := 0.0
var _glow: MeshInstance3D
var _tint := Color("#ffb020")


static func create(at: Vector3, is_big: bool) -> BoostPad:
	var pad := BoostPad.new()
	pad.big = is_big
	pad.position = at
	return pad


func _ready() -> void:
	_amount = BIG_AMOUNT if big else SMALL_AMOUNT
	_respawn = BIG_RESPAWN if big else SMALL_RESPAWN
	_tint = Color("#ffd24a") if big else Color("#ffa63d")

	var radius := BIG_RADIUS if big else SMALL_RADIUS

	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = TRIGGER_HEIGHT
	shape.shape = cylinder
	shape.position.y = TRIGGER_HEIGHT * 0.5
	add_child(shape)

	_glow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius * 0.82
	disc.height = 0.35 if big else 0.22
	disc.radial_segments = 18
	_glow.mesh = disc
	_glow.position.y = disc.height * 0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _tint
	mat.emission_enabled = true
	mat.emission = _tint
	mat.emission_energy_multiplier = RenderMode.emission(1.0)
	_glow.material_override = mat
	add_child(_glow)

	body_entered.connect(_on_entered)


func _on_entered(body: Node) -> void:
	if _cooldown > 0.0 or not (body is CarBody):
		return

	var car: CarBody = body
	if car.boost >= CarBody.BOOST_MAX:
		return

	car.boost = minf(CarBody.BOOST_MAX, car.boost + _amount)
	_cooldown = _respawn
	_glow.visible = false
	var pitch := 1.4 if big else 1.8
	Audio.play_at("coin", 0.45, pitch)
	collected.emit(car, _amount)


func _process(delta: float) -> void:
	if _cooldown <= 0.0:
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_glow.visible = true
