extends SceneTree
## Debug: triangle budget of the match scene parts.

func _tris(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx != null and idx.size() > 0:
			n += idx.size() / 3
		else:
			n += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _walk(n: Node, out: Dictionary) -> void:
	if n is MultiMeshInstance3D:
		var mm := (n as MultiMeshInstance3D).multimesh
		out["crowd"] = int(out.get("crowd", 0)) + _tris(mm.mesh) * mm.instance_count
		out["crowd_instances"] = int(out.get("crowd_instances", 0)) + mm.instance_count
	elif n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out["arena_meshes"] = int(out.get("arena_meshes", 0)) + _tris((n as MeshInstance3D).mesh)
	for c in n.get_children():
		_walk(c, out)


func _initialize() -> void:
	var pair := TeamFactory.quick_pair(1)
	var a := ArenaView.new()
	root.add_child(a)
	a.build(pair[0], pair[1])
	var out := {}
	_walk(a, out)
	print("arena ", out)
	var inst := CharacterLib.scene().instantiate()
	var o2 := {}
	_walk(inst, o2)
	print("one character ", o2)
	quit()
