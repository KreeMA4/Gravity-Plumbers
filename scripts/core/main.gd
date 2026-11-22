extends Node
## Root script of scenes/main.tscn (the only scene the game boots into).
## It creates the debug overlay, then asks GameState to show the main menu.
## Every other screen is built in code and added as a child of this node.

func _ready() -> void:
	var overlay: CanvasLayer = (load("res://scripts/core/debug_overlay.gd") as GDScript).new() as CanvasLayer
	overlay.name = "DebugOverlay"
	add_child(overlay)
	GameState.register_main(self)
	# Command-line flags for desktop testing, e.g.  godot -- --server
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if NetManager.handle_cmdline(args):
		return
	if args.has("--soak"):
		GameState.goto_screen("soak_test")
		return
	GameState.goto_screen("main_menu")


func get_debug_overlay() -> CanvasLayer:
	return get_node_or_null("DebugOverlay") as CanvasLayer
