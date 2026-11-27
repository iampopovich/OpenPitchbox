class_name SimBall
extends RefCounted
## Ball physics: gravity, drag, rolling friction, boards, posts, crossbar and nets.

var pos := Vector3(0, C.BALL_R, 0)
var vel := Vector3.ZERO
var owner: int = -1          # index of the player in possession, -1 = loose
var last_touch: int = -1
var in_goal: int = 0         # 0 = no, +1 = ball inside the +x goal, -1 = inside the -x goal
var spin: float = 0.0        # visual only
var in_box := false          # entered a goal through the mouth (only then can it be a goal)


func reset(at: Vector2) -> void:
	pos = Vector3(at.x, C.BALL_R, at.y)
	vel = Vector3.ZERO
	owner = -1
	in_goal = 0
	in_box = false


func on_ground() -> bool:
	return pos.y <= C.BALL_R + 0.02 and absf(vel.y) < 0.6


func ground_speed() -> float:
	return Vector2(vel.x, vel.z).length()


## Advances the ball by dt. Returns a list of collision event names.
## Fast balls are integrated in sub-steps of at most MAX_STEP metres so they can never
## tunnel through a post or the end board next to the goal.
const MAX_STEP := 0.1


func step(dt: float) -> Array:
	var ev: Array = []
	if owner >= 0:
		return ev
	var sp := vel.length()
	if sp > C.BALL_MAX_SPEED:
		vel = vel / sp * C.BALL_MAX_SPEED
		sp = C.BALL_MAX_SPEED
	var n := maxi(1, ceili(sp * dt / MAX_STEP))
	var h := dt / n
	for i in n:
		_sub_step(h, ev)
		if in_goal != 0:
			break
	return ev


func _sub_step(dt: float, ev: Array) -> void:
	vel.y -= C.GRAVITY * dt
	vel *= 1.0 - C.BALL_AIR_DRAG * dt
	pos += vel * dt
	# floor
	if pos.y < C.BALL_R:
		pos.y = C.BALL_R
		if vel.y < -1.5:
			vel.y = -vel.y * C.BALL_FLOOR_REST
			vel.x *= 0.92
			vel.z *= 0.92
			if not ev.has("bounce"):
				ev.append("bounce")
		else:
			vel.y = 0.0
	if pos.y <= C.BALL_R + 0.001 and vel.y == 0.0:
		var hv := Vector2(vel.x, vel.z)
		var s := hv.length()
		if s > 0.0:
			var ns := maxf(0.0, s - C.BALL_ROLL_DECEL * dt)
			hv = hv / s * ns
			vel.x = hv.x
			vel.z = hv.y
	spin += ground_speed() * dt / C.BALL_R
	_collide_arena(ev)


func _reflect(n: Vector3, rest: float) -> void:
	var vn := vel.dot(n)
	if vn < 0.0:
		vel -= n * vn * (1.0 + rest)
		# tangential damping
		vel *= 0.96


func _collide_arena(ev: Array) -> void:
	var r := C.BALL_R
	var ax := absf(pos.x)
	var sx := signf(pos.x) if pos.x != 0.0 else 1.0
	# --- goal frame and nets ---
	var mouth := absf(pos.z) < C.GOAL_HW - r * 0.5 and pos.y < C.GOAL_H - r * 0.5
	if ax < C.HX - r:
		in_box = false
	elif mouth:
		in_box = true
	if ax > C.HX - r and in_box:
		# inside or entering the goal box
		if ax > C.HX + C.GOAL_DEPTH - r:
			pos.x = sx * (C.HX + C.GOAL_DEPTH - r)
			_reflect(Vector3(-sx, 0, 0), C.BALL_NET_REST)
			ev.append("net")
		# sloping back net: from the roof edge (NET_TOP_DEPTH, GOAL_H) down to (GOAL_DEPTH, 0)
		var run := C.GOAL_DEPTH - C.NET_TOP_DEPTH
		var a := absf(pos.x) - C.HX - C.NET_TOP_DEPTH
		if a > -r:
			var n2 := Vector2(C.GOAL_H, run).normalized()   # outward normal in (depth, height)
			var dist := (a * C.GOAL_H + pos.y * run - C.GOAL_H * run) / Vector2(C.GOAL_H, run).length()
			if dist > -r:
				var push := dist + r
				pos.x -= sx * n2.x * push
				pos.y -= n2.y * push
				_reflect(Vector3(-sx * n2.x, -n2.y, 0), C.BALL_NET_REST)
				pos.y = maxf(pos.y, r)
				ev.append("net")
		if ax > C.HX:
			if absf(pos.z) > C.GOAL_HW - r:
				var sz := signf(pos.z)
				pos.z = sz * (C.GOAL_HW - r)
				_reflect(Vector3(0, 0, -sz), C.BALL_NET_REST)
				ev.append("net")
			if pos.y > C.GOAL_H - r:
				pos.y = C.GOAL_H - r
				_reflect(Vector3(0, -1, 0), C.BALL_NET_REST)
				ev.append("net")
		if absf(pos.x) > C.HX + r:
			in_goal = int(sx)
	elif ax > C.HX - r:
		# end board around the goal (also catches a ball that never entered the mouth)
		pos.x = sx * (C.HX - r)
		_reflect(Vector3(-sx, 0, 0), C.BALL_WALL_REST)
		ev.append("wall")
	# posts (vertical cylinders at the mouth edges)
	if pos.y < C.GOAL_H + r:
		for pz: float in [-C.GOAL_HW, C.GOAL_HW]:
			var d := Vector2(pos.x - sx * C.HX, pos.z - pz)
			var mind := r + C.POST_R
			if d.length_squared() < mind * mind and d.length_squared() > 0.000001:
				var dl := d.length()
				var n2 := d / dl
				pos.x = sx * C.HX + n2.x * mind
				pos.z = pz + n2.y * mind
				_reflect(Vector3(n2.x, 0, n2.y), C.BALL_WALL_REST)
				ev.append("post")
	# crossbar (horizontal cylinder along z)
	if absf(pos.z) < C.GOAL_HW + r:
		var d2 := Vector2(pos.x - sx * C.HX, pos.y - C.GOAL_H)
		var mind2 := r + C.POST_R
		if d2.length_squared() < mind2 * mind2 and d2.length_squared() > 0.000001:
			var dl2 := d2.length()
			var n3 := d2 / dl2
			pos.x = sx * C.HX + n3.x * mind2
			pos.y = C.GOAL_H + n3.y * mind2
			_reflect(Vector3(n3.x, n3.y, 0), C.BALL_WALL_REST)
			ev.append("post")
	# --- side boards ---
	if absf(pos.z) > C.HZ - r:
		var sz2 := signf(pos.z)
		pos.z = sz2 * (C.HZ - r)
		_reflect(Vector3(0, 0, -sz2), C.BALL_WALL_REST)
		ev.append("wall")
	# --- rounded corners ---
	var cx := C.HX - C.CORNER_R
	var cz := C.HZ - C.CORNER_R
	if absf(pos.x) > cx and absf(pos.z) > cz and absf(pos.x) <= C.HX:
		var c := Vector2(signf(pos.x) * cx, signf(pos.z) * cz)
		var d3 := Vector2(pos.x, pos.z) - c
		var lim := C.CORNER_R - r
		if d3.length() > lim:
			var n4 := d3.normalized()
			pos.x = c.x + n4.x * lim
			pos.z = c.y + n4.y * lim
			_reflect(Vector3(-n4.x, 0, -n4.y), C.BALL_WALL_REST)
			ev.append("wall")


## Predicted ground-plane positions for the next n samples of step dt (ignores boards).
func predict(n: int, dt: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var p := pos
	var v := vel
	for i in n:
		v.y -= C.GRAVITY * dt
		v *= 1.0 - C.BALL_AIR_DRAG * dt
		p += v * dt
		if p.y < C.BALL_R:
			p.y = C.BALL_R
			if v.y < -1.5:
				v.y = -v.y * C.BALL_FLOOR_REST
			else:
				v.y = 0.0
		if p.y <= C.BALL_R + 0.001 and v.y == 0.0:
			var h := Vector2(v.x, v.z)
			var s := h.length()
			if s > 0.0:
				var ns := maxf(0.0, s - C.BALL_ROLL_DECEL * dt)
				h = h / s * ns
				v.x = h.x
				v.z = h.y
		# clamp into the arena so targets stay reachable
		p.x = clampf(p.x, -C.HX + 0.3, C.HX - 0.3)
		p.z = clampf(p.z, -C.HZ + 0.3, C.HZ - 0.3)
		out.append(p)
	return out
