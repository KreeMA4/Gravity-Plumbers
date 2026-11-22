extends Node
## Runs the logic tests (tests/test_runner.gd) inside the game and shows the
## results, so tests can be run on the phone without a command line.

func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var root: Control = UITheme.make_screen_root()
	layer.add_child(root)
	var bg: ColorRect = ColorRect.new()
	bg.color = UITheme.C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var margin: MarginContainer = UITheme.safe_margin()
	root.add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	margin.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	col.add_child(top)
	var back: Button = UITheme.small_button("< Back")
	back.custom_minimum_size = Vector2(260, 96)
	back.pressed.connect(func() -> void: GameState.goto_screen("main_menu"))
	top.add_child(back)
	var result: Dictionary = TestRunner.run_all()
	var failed: int = int(result["failed"])
	var head: Label = UITheme.label("Tests: %d passed, %d failed" % [int(result["passed"]), failed], 44,
		UITheme.C_GOOD if failed == 0 else UITheme.C_DANGER)
	top.add_child(head)
	var text: RichTextLabel = RichTextLabel.new()
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 24)
	text.scroll_following = false
	text.text = "\n".join(result["lines"] as PackedStringArray)
	col.add_child(text)
	GameLog.info("In-game tests: %d passed, %d failed" % [int(result["passed"]), failed])
