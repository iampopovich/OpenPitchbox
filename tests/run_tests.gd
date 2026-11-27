extends SceneTree
## Headless test runner: godot --headless --script res://tests/run_tests.gd [-- filter]
## Runs every test_* method of every tests/test_*.gd script.

var failures: Array = []
var current := ""


func _initialize() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var dir := DirAccess.open("res://tests")
	var files: Array = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var total := 0
	var t0 := Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		var inst = script.new()
		inst.set("runner", self)
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			if filter != "" and not (f + ":" + name).contains(filter):
				continue
			current = f + ":" + name
			var before := failures.size()
			var ts := Time.get_ticks_msec()
			inst.call(name)
			total += 1
			var ok := failures.size() == before
			print("%s %s (%d ms)" % ["PASS" if ok else "FAIL", current, Time.get_ticks_msec() - ts])
	print("\n%d tests, %d failures, %.1f s" % [total, failures.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	for fl in failures:
		print("  - " + fl)
	quit(1 if failures.size() > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])
