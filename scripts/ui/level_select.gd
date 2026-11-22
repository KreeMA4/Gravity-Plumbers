class_name LevelSelect
extends CanvasLayer
## The hub's job console: pick a level and a difficulty (host only).
## Shows your stars and best time for each level.

signal closed

var _difficulty_buttons: Array = []


func _ready() -> void:
	layer = 15
	var root: Control = UITheme.make_screen_root()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	panel.add_child(col)
	col.add_child(UITheme.title("PICK A JOB"))
	var diff_row: HBoxContainer = HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(diff_row)
	for i: int in 3:
		var name_txt: String = str((Tuning.DIFFICULTY[i] as Dictionary)["name"])
		var b: Button = UITheme.small_button(name_txt)
		b.custom_minimum_size = Vector2(230, 96)
		b.toggle_mode = true
		b.button_pressed = GameState.difficulty == i
		var idx: int = i
		b.pressed.connect(func() -> void: _set_difficulty(idx))
		diff_row.add_child(b)
		_difficulty_buttons.append(b)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	col.add_child(grid)
	for l: Variant in LevelCatalog.story_levels():
		var d: Dictionary = l as Dictionary
		var lid: String = str(d["id"])
		var stars: int = SaveData.level_stars(lid)
		var star_txt: String = ""
		for s: int in 3:
			star_txt += "*" if s < stars else "-"
		var b2: Button = UITheme.big_button("%s\n%s" % [str(d["name"]), star_txt], UITheme.C_PIPE.darkened(0.3))
		b2.custom_minimum_size = Vector2(560, 130)
		b2.add_theme_font_size_override("font_size", 30)
		b2.pressed.connect(func() -> void: _start(lid))
		grid.add_child(b2)
	var back: Button = UITheme.big_button("Back")
	back.pressed.connect(_close)
	col.add_child(back)


func _set_difficulty(i: int) -> void:
	GameState.difficulty = i
	for j: int in _difficulty_buttons.size():
		(_difficulty_buttons[j] as Button).button_pressed = j == i


func _start(level_id: String) -> void:
	AudioManager.play_ui("ui_confirm")
	NetManager.host_start_level(level_id)


func _close() -> void:
	closed.emit()
	queue_free()
