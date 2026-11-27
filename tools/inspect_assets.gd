extends SceneTree
## Debug: prints the character node tree, bones and the animation list.


func _initialize() -> void:
	var ch: PackedScene = load("res://assets/third_party/quaternius/character/Superhero_Male_FullBody.gltf")
	var n := ch.instantiate()
	_dump(n, 0)
	var sk := _find(n, "Skeleton3D") as Skeleton3D
	if sk:
		var names: Array = []
		for i in sk.get_bone_count():
			names.append(sk.get_bone_name(i))
		print("bones: ", names.size(), " ", names)
		var aabb := AABB()
		for mi in _all(n, "MeshInstance3D"):
			aabb = aabb.merge((mi as MeshInstance3D).get_aabb())
		print("mesh aabb ", aabb)
	var an: PackedScene = load("res://assets/third_party/quaternius/anim/UAL2_Standard.glb")
	var a := an.instantiate()
	var ap := _find(a, "AnimationPlayer") as AnimationPlayer
	if ap:
		var lst := ap.get_animation_list()
		for nm in lst:
			print("anim ", nm, " ", snappedf(ap.get_animation(nm).length, 0.01))
	var sk2 := _find(a, "Skeleton3D") as Skeleton3D
	if sk2:
		print("anim skeleton bones ", sk2.get_bone_count(), " first ", sk2.get_bone_name(0), " path ", a.get_path_to(sk2))
	quit()


func _dump(n: Node, d: int) -> void:
	if d > 4:
		return
	print("  ".repeat(d), n.name, " <", n.get_class(), ">")
	for c in n.get_children():
		_dump(c, d + 1)


func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null


func _all(n: Node, cls: String) -> Array:
	var out: Array = []
	if n.get_class() == cls:
		out.append(n)
	for c in n.get_children():
		out += _all(c, cls)
	return out
