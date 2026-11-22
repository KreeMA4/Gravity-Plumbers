extends SceneTree
## Headless test entry point:
##   godot --headless --import            (once, builds the class cache)
##   godot --headless -s res://tests/run_all.gd
## Exit code 0 = all tests passed.
## Tests run on the first frame so autoloads are already in the tree.

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var result: Dictionary = TestRunner.run_all()
	for line: String in result["lines"]:
		print(line)
	quit(0 if int(result["failed"]) == 0 else 1)
	return false
