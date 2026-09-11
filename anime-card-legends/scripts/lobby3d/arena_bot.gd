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

# --- Teammates ---------------------------------------------------------
#
# In 2v2 both bots on a side would otherwise drive at the ball together,
# arrive together, and leave an empty net behind them. So each bot is
# given a ROLE.
#
# The first man challenges the ball. The second holds back between the
# ball and its own goal and only commits once the ball is on its half -
# which is roughly what "rotating" means, without a rotation system to
# maintain.
const ROLE_FIRST := 0
const ROLE_SECOND := 1

# How far back the second man sits, as a fraction of the half-pitch.
const COVER_DEPTH := 0.55
# It stops covering and joins in once the ball is this far into its own
# half, measured the same way.
const COMMIT_DEPTH := 0.35

var active := false
var role := ROLE_FIRST

var _car: CarBody
var _ball: ArenaBall
var _own_goal_z := 0.0
var _half_length := 0.0
var _flip_timer := 0.0


# `own_goal_z` is the end it defends: negative for the far end, positive
# for the near one, so a bot can be put on either team.
func setup(car: CarBody, ball: ArenaBall, half_length: float, own_goal_z: float = 0.0) -> void:
	_car = car
	_ball = ball
	_half_length = absf(half_length)
	# Defaults to the far end, which is where a 1v1 spawns it.
	_own_goal_z = own_goal_z if not is_zero_approx(own_goal_z) else -_half_length


func _physics_process(delta: float) -> void:
	if _car == null or _ball == null:
		return

	_flip_timer = maxf(0.0, _flip_timer - delta)

	if not active:
		_car.drive_inputs(0.0, 0.0, false, false, false)
		return

	var target := _cover_point() if _covering() else _aim_point()
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


# The second man holds position while the ball is up the other end. Once
# it comes back onto its own half it stops covering and challenges like
# anyone else.
func _covering() -> bool:
	if role != ROLE_SECOND or _ball == null:
		return false
	var toward_own_goal := _ball.global_position.z * signf(_own_goal_z)
	return toward_own_goal < _half_length * COMMIT_DEPTH


# Between the ball and its own goal, shaded to the middle of the pitch,
# which is where a second man is useful.
func _cover_point() -> Vector3:
	var goal := Vector3(0.0, _car.global_position.y, _own_goal_z)
	var ball_at := _ball.global_position
	var at := goal.lerp(Vector3(ball_at.x, goal.y, ball_at.z), 1.0 - COVER_DEPTH)
	at.x *= 0.5
	at.y = _car.global_position.y
	return at


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
