class_name C
extends RefCounted
## Every tuning number of the match engine lives here.
## World axes: x = pitch length (goal to goal), z = width, y = up.
## Ground positions are Vector2(x, z).

const TICK := 1.0 / 60.0

# Arena (inner faces of the boards)
const HX := 24.0             # 48 x 29 m: room for six a side to spread and pass
const HZ := 14.5
const CORNER_R := 3.5
const GOAL_HW := 2.6
const GOAL_H := 2.3
const GOAL_DEPTH := 1.6
const NET_TOP_DEPTH := 0.6     # roof of the net before it slopes down to the ground
const POST_R := 0.08
const BOX_DEPTH := 7.0      # penalty box depth from the goal line
const BOX_HW := 7.5         # penalty box half width

# Ball
const BALL_R := 0.15
const GRAVITY := 13.0
const BALL_AIR_DRAG := 0.10
const BALL_ROLL_DECEL := 4.2
const BALL_FLOOR_REST := 0.55
const BALL_WALL_REST := 0.72
const BALL_NET_REST := 0.15
const BALL_MAX_SPEED := 34.0

# Players
const PLAYER_R := 0.42
const PLAYER_ACCEL := 30.0
const BASE_SPEED := 4.6
const SPEED_PER_STAT := 0.19      # speed 5 -> 5.6 m/s, 10 -> 6.5, 15 -> 7.5, 20 -> 8.4
const ACCEL_PER_STAT := 0.6
const CARRY_SPEED_MUL := 0.84     # running with the ball is clearly slower than the pass
const CONTROL_DIST := 0.72
const CONTROL_MAX_Y := 0.9
const DRIBBLE_OFFSET := 0.58
const TOUCH_COOLDOWN := 0.28
const STEAL_RATE := 2.4           # per second at equal tackle/control
const STEAL_DIST := 0.95
const SLIDE_SPEED := 10.5
const SLIDE_TIME := 0.5
const SLIDE_RECOVER := 0.45
const SLIDE_REACH := 0.75
const DOWN_TIME := 1.3
const BUFFER_TIME := 0.42
const AERIAL_REACH := 1.45
const AERIAL_MIN_Y := 0.45
const AERIAL_MAX_Y := 2.7
const HEADER_MIN_Y := 1.45
const AERIAL_TIME := 0.6

# Kicks
const SHOT_MIN := 19.0
const SHOT_MAX := 30.0
const SHOT_CHARGE_TIME := 0.5
const PASS_MIN := 11.0
const PASS_MAX := 24.0
const LOB_SPEED_H := 13.0
const LOB_ARRIVE_Y := 0.9      # a lob drops to chest height at the receiver
const CHEST_MAX_Y := 1.55      # the intended receiver can control a dropping ball up to here
const KICK_WINDUP := 0.1       # backswing before the foot meets the ball

# Keeper
const GK_LINE_OFFSET := 0.7
const GK_REACH := 0.85
const GK_DIVE_REACH := 1.9
const GK_HOLD_TIME := 0.9
const GK_DIVE_TIME := 0.8

# Match flow
const KICKOFF_DELAY := 1.2
const GOAL_PAUSE := 3.0
const REPLAY_SECONDS := 5.0
const SETPIECE_DELAY := 1.6
const PENALTY_SPOT := 4.2
const WALL_DIST := 4.0

# Player states
enum { ST_RUN, ST_SLIDE, ST_RECOVER, ST_DOWN, ST_AERIAL, ST_DIVE, ST_KICK, ST_CELEBRATE, ST_HOLD }

# Actions (buttons)
enum { ACT_NONE, ACT_PASS, ACT_SHOOT, ACT_LOB, ACT_AERIAL }

# Phases
enum { PH_KICKOFF, PH_PLAY, PH_GOAL, PH_FULLTIME, PH_SETPIECE }

const STAT_KEYS := ["spd", "sht", "pas", "tkl", "kep"]
const STAT_NAMES := {"spd": "Speed", "sht": "Shooting", "pas": "Passing", "tkl": "Tackling", "kep": "Keeping"}
const STAT_MAX := 20
const STAT_MIN := 1


static func stat01(v: int) -> float:
	return clampf((float(v) - 1.0) / 19.0, 0.0, 1.0)


static func v3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


static func flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
