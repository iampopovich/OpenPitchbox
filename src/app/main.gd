extends Node
## Entry point. OP_AUTOPLAY=1 starts a CPU vs CPU match (used for screenshots).


func _ready() -> void:
	if OS.get_environment("OP_AUTOPLAY") != "":
		var pair := TeamFactory.quick_pair(int(OS.get_environment("OP_SEED")) if OS.get_environment("OP_SEED") != "" else 3)
		var cam := int(OS.get_environment("OP_CAMERA")) if OS.get_environment("OP_CAMERA") != "" else 0
		Game.play_match({"teams": pair, "humans": [], "length": 120.0, "camera": cam, "seed": 5}, func(_r): get_tree().quit())
		return
	Game.show_menu()
