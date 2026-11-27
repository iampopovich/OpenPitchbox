class_name C
extends RefCounted
## Every tuning number of the match engine lives here.
## World axes: x = pitch length (goal to goal), z = width, y = up.
## Ground positions are Vector2(x, z).

const TICK := 1.0 / 60.0

# Arena (inner faces of the boards)
const HX := 20.0
const HZ := 12.0
const CORNER_R := 3.0
const GOAL_HW := 2.6
const GOAL_H := 2.3
const GOAL_DEPTH := 1.6
const POST_R := 0.08
const BOX_DEPTH := 6.0      # penalty box depth from the goal line
const BOX_HW := 6.5         # penalty box half width

# Ball
const BALL_R := 0.12
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
const BASE_SPEED := 5.4
const SPEED_PER_STAT := 0.11      # stat 20 -> +2.2 m/s
const CARRY_SPEED_MUL := 0.9
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
const DOWN_TIME := 0.75
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
const PASS_MIN := 9.0
const PASS_MAX := 22.0
const LOB_SPEED_H := 13.0

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

# Player states
enum { ST_RUN, ST_SLIDE, ST_RECOVER, ST_DOWN, ST_AERIAL, ST_DIVE, ST_KICK, ST_CELEBRATE, ST_HOLD }

# Actions (buttons)
enum { ACT_NONE, ACT_PASS, ACT_SHOOT, ACT_LOB, ACT_AERIAL }

# Phases
enum { PH_KICKOFF, PH_PLAY, PH_GOAL, PH_FULLTIME }

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
