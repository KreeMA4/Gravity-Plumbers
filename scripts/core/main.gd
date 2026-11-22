extends Node
## Root script of scenes/main.tscn (the only scene the game boots into).
## It creates the debug overlay, then asks GameState to show the main menu.
## Every other screen is built in code and added as a child of this node.
##
## Command-line flags (after "--"), used for desktop testing and by CI smoke tests:
##   --server / --client=IP / --port=N   networking (see NetManager)
##   --soak                              run the physics soak test
##   --screen=<id>                       boot straight into a screen (e.g. look_test)
##   --level=<id>                        boot straight into a level, solo (e.g. bathroom)
##   --ci-screenshot=<path.png>          save a screenshot after --ci-frames=N frames (default 240)

var _shot_path: String = ""
var _shot_frames: int = 240


func _ready() -> void:
	var overlay: CanvasLayer = (load("res://scripts/core/debug_overlay.gd") as GDScript).new() as CanvasLayer
	overlay.name = "DebugOverlay"
	add_child(overlay)
	GameState.register_main(self)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for a: String in args:
		if a.begins_with("--ci-screenshot="):
			_shot_path = a.substr(16)
		elif a.begins_with("--ci-frames="):
			_shot_frames = maxi(1, a.substr(12).to_int())
	if NetManager.handle_cmdline(args):
		return
	if args.has("--soak"):
		GameState.goto_screen("soak_test")
		return
	for a2: String in args:
		if a2.begins_with("--screen="):
			GameState.goto_screen(a2.substr(9))
			return
		if a2.begins_with("--level="):
			NetManager.start_solo()
			GameState.start_level(a2.substr(8))
			return
	GameState.goto_screen("main_menu")


func _process(_delta: float) -> void:
	if _shot_path == "":
		return
	_shot_frames -= 1
	if _shot_frames > 0:
		return
	var img: Image = get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		var err: Error = img.save_png(_shot_path)
		GameLog.info("CI screenshot saved to %s (%s)" % [_shot_path, error_string(err)])
	else:
		GameLog.warn("CI screenshot: no image (headless renderer?)")
	_shot_path = ""


func get_debug_overlay() -> CanvasLayer:
	return get_node_or_null("DebugOverlay") as CanvasLayer
