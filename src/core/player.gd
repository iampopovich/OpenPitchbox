class_name SimPlayer
extends RefCounted
## One footballer on the pitch: kinematics, state machine, buffered input.

var index: int = 0            # global index in MatchSim.players
var team: int = 0             # 0 or 1
var slot: int = 0             # 0 = keeper, 1..5 formation slot
var role: String = "MID"
var data: PlayerData

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var facing := Vector2.RIGHT
var state: int = C.ST_RUN
var state_t: float = 0.0       # time left in the current timed state
var anim: int = 0              # sub-animation id (aerial kind, celebration kind, dive side)
var touch_cd: float = 0.0      # cannot touch the ball while > 0 (just kicked it)
var human: int = -1            # human controller id, -1 = AI
var slide_done: bool = false    # slide already hit something
var steal_guard: float = 0.0    # fresh owner cannot be robbed while > 0
var active: bool = true        # false = not on the pitch (practice mode)

# Buffered action (press before the ball arrives = first-time action)
var buf_action: int = C.ACT_NONE
var buf_t: float = 0.0
var buf_dir := Vector2.ZERO

# Shot charge (human hold)
var charge_t: float = -1.0

# AI memory
var think_t: float = 0.0
var ai_target := Vector2.ZERO
var ai_intent: int = 0

# Keeper
var gk_hold_t: float = 0.0
var gk_tried_shot: int = -1


func max_speed() -> float:
	return C.BASE_SPEED + float(data.stat("spd")) * C.SPEED_PER_STAT


func is_gk() -> bool:
	return slot == 0


func can_act() -> bool:
	return active and (state == C.ST_RUN or state == C.ST_HOLD)


func can_touch() -> bool:
	return active and touch_cd <= 0.0 and (state == C.ST_RUN or state == C.ST_HOLD or state == C.ST_SLIDE or state == C.ST_DIVE)


func set_state(s: int, t: float, sub: int = 0) -> void:
	state = s
	state_t = t
	anim = sub


func knock_down() -> void:
	set_state(C.ST_DOWN, C.DOWN_TIME)
	vel *= 0.3
	buf_action = C.ACT_NONE
	charge_t = -1.0


func buffer(action: int, dir: Vector2) -> void:
	buf_action = action
	buf_t = C.BUFFER_TIME
	buf_dir = dir


func steer(desired: Vector2, dt: float, speed_mul: float = 1.0) -> void:
	## Accelerates toward desired velocity (desired is a velocity, not a direction).
	var maxv := max_speed() * speed_mul
	if desired.length() > maxv:
		desired = desired.normalized() * maxv
	var dv := desired - vel
	var step := C.PLAYER_ACCEL * dt
	if dv.length() > step:
		dv = dv.normalized() * step
	vel += dv


func update_facing(dt: float) -> void:
	if vel.length() > 0.4:
		var target := vel.normalized()
		var a := facing.angle_to(target)
		var turn := 14.0 * dt
		facing = facing.rotated(clampf(a, -turn, turn)).normalized()
