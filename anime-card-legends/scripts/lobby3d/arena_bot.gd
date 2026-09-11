class_name ArenaBot
extends Node

# =========================================================
# The opponent.
#
# Drives the same CarBody the player does, through the same forces -
# it has no special physics and no speed advantage. All it does is
# decide where to point.
#
# The behaviour is deliberately simple and readable: get on the goal
# side of the ball, then drive through it. That produces something that
# defends by accident, which is most of what a casual opponent needs to
# do, without a state machine to maintain.
# =========================================================

# How far behind the ball it lines up before committing.
const APPROACH_BEHIND := 1.8      # multiples of the ball's radius
const STEER_GAIN := 2.4
const BOOST_ANGLE := 0.4          # radians; only boosts when roughly aimed
const BOOST_DISTANCE := 4.0       # multiples of the car's length
const FLIP_DISTANCE := 1.6
const FLIP_COOLDOWN := 1.2

var active := false

var _car: CarBody
var _ball: ArenaBall
var _own_goal_z := 0.0
var _flip_timer := 0.0


func setup(car: CarBody, ball: ArenaBall, half_length: float) -> void:
	_car = car
	_ball = ball
	# It defends the far end, which is where the arena spawns it.
	_own_goal_z = -half_length


func _physics_process(delta: float) -> void:
	if _car == null or _ball == null:
		return

	_flip_timer = maxf(0.0, _flip_timer - delta)

	if not active:
		_car.drive_inputs(0.0, 0.0, false, false, false)
		return

	var target := _aim_point()
	var to_target := target - _car.global_position
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var distance := flat.length()

	if distance < 0.01:
		_car.drive_inputs(0.0, 0.0, false, false, false)
		return

	var forward := -_car.global_transform.basis.z
	var wanted := flat.normalized()

	# Signed angle to the target, about the world's up.
	var angle := atan2(forward.cross(wanted).y, forward.dot(wanted))

	var throttle := 1.0
	var steer := clampf(angle * STEER_GAIN, -1.0, 1.0)

	# Facing away and close: back up rather than grinding in a circle.
	if absf(angle) > 2.2 and distance < _car.CAR_LENGTH * 2.0:
		throttle = -1.0
		steer = -steer

	var boosting := absf(angle) < BOOST_ANGLE and distance > _car.CAR_LENGTH * BOOST_DISTANCE
	var ball_distance := _car.global_position.distance_to(_ball.global_position)
	var flipping := (_flip_timer <= 0.0
		and ball_distance < _car.CAR_LENGTH * FLIP_DISTANCE
		and absf(angle) < BOOST_ANGLE
		and _car.is_grounded())

	if flipping:
		_flip_timer = FLIP_COOLDOWN

	_car.drive_inputs(throttle, steer, boosting, false, flipping)


# Behind the ball, on the line from the player's goal through it - so
# driving at this point sends the ball the right way.
func _aim_point() -> Vector3:
	var ball_at := _ball.global_position
	var attack_dir := Vector3(0.0, 0.0, -signf(_own_goal_z))
	var behind := -attack_dir * ArenaBall.RADIUS * APPROACH_BEHIND

	# Line the shot up across the pitch as well, not just along it.
	var lateral := clampf(-ball_at.x / maxf(ArenaBall.RADIUS * 12.0, 1.0), -1.0, 1.0)
	behind.x += lateral * ArenaBall.RADIUS * APPROACH_BEHIND * 0.6

	var target := ball_at + behind
	target.y = _car.global_position.y
	return target
