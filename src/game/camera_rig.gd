class_name CameraRig
extends Camera3D
## Four fixed camera styles, all following the ball with smoothing.

enum { CAM_BROADCAST, CAM_LOW, CAM_END, CAM_TOP }
const NAMES := ["Broadcast", "Sideline", "End-to-end", "Overhead"]

var mode: int = CAM_BROADCAST
var focus := Vector3.ZERO
var shake := 0.0
var end_dir := 1.0       # for CAM_END: +1 = look toward +x


func _ready() -> void:
	fov = 42.0
	near = 0.3
	far = 300.0


func snap_to(p: Vector3) -> void:
	focus = p
	_apply(0.0)


func follow(target: Vector3, dt: float) -> void:
	var k := 1.0 - exp(-dt * 3.5)
	focus = focus.lerp(target, k)
	shake = maxf(0.0, shake - dt * 2.5)
	_apply(dt)


func _apply(_dt: float) -> void:
	var fx := clampf(focus.x, -C.HX + 5.0, C.HX - 5.0)
	var fz := clampf(focus.z, -C.HZ + 3.0, C.HZ - 3.0)
	var eye: Vector3
	var at: Vector3
	match mode:
		CAM_LOW:
			fov = 44.0
			eye = Vector3(fx * 0.95, 6.5, fz * 0.4 + 15.5)
			at = Vector3(fx * 0.95, 0.8, fz * 0.6)
		CAM_END:
			fov = 50.0
			var ex := clampf(focus.x, -C.HX + 2.0, C.HX - 2.0)
			eye = Vector3(ex - end_dir * 12.0, 9.0, fz * 0.6)
			at = Vector3(ex + end_dir * 5.0, 0.0, fz * 0.8)
		CAM_TOP:
			fov = 44.0
			eye = Vector3(fx * 0.8, 30.0, fz * 0.3 + 5.0)
			at = Vector3(fx * 0.75, 0.0, fz * 0.25)
		_:
			fov = 38.0
			eye = Vector3(fx * 0.9, 12.5, fz * 0.35 + 18.5)
			at = Vector3(fx * 0.9, 0.0, fz * 0.6)
	if shake > 0.0:
		var t := Time.get_ticks_msec() / 1000.0
		eye += Vector3(sin(t * 47.0), cos(t * 39.0), sin(t * 31.0)) * shake * 0.25
	look_at_from_position(eye, at, Vector3.UP)


func screen_to_world(stick: Vector2) -> Vector2:
	## Converts a screen-space stick (x right, y down) into a ground-plane direction.
	var right := global_basis.x
	var fwd := -global_basis.z
	var r2 := Vector2(right.x, right.z).normalized()
	var f2 := Vector2(fwd.x, fwd.z)
	if f2.length() < 0.05:
		f2 = Vector2(global_basis.y.x, global_basis.y.z)
	f2 = f2.normalized()
	return r2 * stick.x - f2 * stick.y
