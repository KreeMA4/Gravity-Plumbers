extends SceneTree
## END-TO-END gameplay test launcher (the test itself is tests/gameplay_e2e_impl.gd).
## The implementation is loaded on the first frame, because scripts run with -s are
## compiled before the game's autoloads (Tuning, GameState...) are registered.
##
## Run (needs a real window so touch coordinates and layout are real):
##   xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tests/gameplay_e2e_test.gd
## Prints "GAMEPLAY E2E PASSED" and exits 0 on success.

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var impl: Node = (load("res://tests/gameplay_e2e_impl.gd") as GDScript).new() as Node
		impl.name = "GameplayE2E"
		root.add_child(impl)
	return false
