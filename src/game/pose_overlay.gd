class_name PoseOverlay
extends SkeletonModifier3D
## Adds procedural rotations on top of the playing animation (kick swing, header nod,
## bicycle flip, keeper dive). Rotations are given around model-space axes, so they do
## not depend on how each bone's local axes are oriented in the rig.

var rotations: Array = []   # [[bone_idx, axis (Vector3, model space), angle], ...]
var weight := 0.0


func set_rot(list: Array, w: float) -> void:
	rotations = list
	weight = w


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or weight <= 0.001 or rotations.is_empty():
		return
	for r in rotations:
		var b: int = r[0]
		if b < 0:
			continue
		var axis: Vector3 = r[1]
		var ang: float = r[2] * weight
		var parent := sk.get_bone_parent(b)
		var pg := sk.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
		var q_model := Quaternion(axis.normalized(), ang)
		# rotate in model space: local' = Pg^-1 * R * Pg * local
		var local := sk.get_bone_pose_rotation(b)
		var nq := pg.inverse() * q_model * pg * local
		sk.set_bone_pose_rotation(b, nq.normalized())
