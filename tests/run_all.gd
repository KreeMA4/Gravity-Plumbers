extends SceneTree
## Headless test entry point:
##   godot --headless --import            (once, builds the class cache)
##   godot --headless -s res://tests/run_all.gd
## Exit code 0 = all tests passed.

func _initialize() -> void:
	var result: Dictionary = TestRunner.run_all()
	for line: String in result["lines"]:
		print(line)
	quit(0 if int(result["failed"]) == 0 else 1)
