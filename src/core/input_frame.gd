class_name InputFrame
extends RefCounted
## One tick of a human controller: stick + buttons (held and just-pressed edges).

var move := Vector2.ZERO        # ground plane direction in world space (x, z), length 0..1
var pass_held := false
var shoot_held := false
var lob_held := false
var aerial_held := false
var switch_held := false
var pass_pressed := false
var shoot_pressed := false
var lob_pressed := false
var aerial_pressed := false
var switch_pressed := false
var shoot_released := false
var any_pressed := false


func clear_edges() -> void:
	pass_pressed = false
	shoot_pressed = false
	lob_pressed = false
	aerial_pressed = false
	switch_pressed = false
	shoot_released = false
	any_pressed = false
