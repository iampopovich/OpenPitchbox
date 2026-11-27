extends RefCounted
## Assets shared by every platform: the baked animation library must match its sources.

var runner


func test_baked_animations_up_to_date() -> void:
	var baked: AnimationLibrary = load(CharacterLib.BAKED_PATH)
	runner.check(baked != null, "assets/generated/animations.res exists (run tools/bake_anims.gd)")
	if baked == null:
		return
	var full := CharacterLib.build_library()
	for n: String in CharacterLib.USED:
		runner.check(baked.has_animation(n), "baked clip %s present" % n)
		if baked.has_animation(n) and full.has_animation(n):
			var a := baked.get_animation(n)
			var b := full.get_animation(n)
			runner.check(absf(a.length - b.length) < 0.001 and a.get_track_count() == b.get_track_count(),
				"baked clip %s matches its source (re-run tools/bake_anims.gd)" % n)
	CharacterLib._library = null
