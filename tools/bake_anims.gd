extends SceneTree
## Bakes the animation clips the game uses into assets/generated/animations.res.
## Run after changing CharacterLib.CMU_CLIPS or the source animation files:
##   godot --headless --script res://tools/bake_anims.gd


func _initialize() -> void:
	var full := CharacterLib.build_library()
	var out := AnimationLibrary.new()
	for n: String in CharacterLib.USED:
		if full.has_animation(n):
			out.add_animation(n, full.get_animation(n))
		else:
			push_warning("missing clip " + n)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/generated"))
	var err := ResourceSaver.save(out, CharacterLib.BAKED_PATH, ResourceSaver.FLAG_COMPRESS)
	print("baked %d clips -> %s (%s)" % [out.get_animation_list().size(), CharacterLib.BAKED_PATH, error_string(err)])
	quit()
