class_name PauseMenu
extends CanvasLayer
## Pause: Resume, Settings, Quit to menu. Solo play actually pauses the game;
## online the game keeps running for everyone else. A host quitting ends the
## session for everyone, so it asks first.

signal closed

var _panel: PanelContainer
var _confirm: PanelContainer
var _runner: Node = null


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root: Control = UITheme.make_screen_root()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var col: VBoxContainer = VBoxContainer.new()
	_panel.add_child(col)
	col.add_child(UITheme.title("PAUSED"))
	var resume: Button = UITheme.big_button("Resume", UITheme.C_GOOD.darkened(0.3))
	resume.pressed.connect(close)
	col.add_child(resume)
	if GameState.screen_available("settings"):
		var sett: Button = UITheme.big_button("Settings")
		sett.pressed.connect(_open_settings)
		col.add_child(sett)
	var quit: Button = UITheme.big_button("Quit to Menu", UITheme.C_DANGER.darkened(0.2))
	quit.pressed.connect(_on_quit)
	col.add_child(quit)
	_confirm = PanelContainer.new()
	_confirm.visible = false
	center.add_child(_confirm)
	var c2: VBoxContainer = VBoxContainer.new()
	_confirm.add_child(c2)
	var msg: Label = UITheme.label("You're the host.\nQuitting ends the game for everyone!", 34)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c2.add_child(msg)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	c2.add_child(row)
	var yes: Button = UITheme.big_button("End Game", UITheme.C_DANGER.darkened(0.2))
	yes.custom_minimum_size = Vector2(300, 110)
	yes.pressed.connect(_quit_now)
	row.add_child(yes)
	var no: Button = UITheme.big_button("Cancel")
	no.custom_minimum_size = Vector2(300, 110)
	no.pressed.connect(func() -> void:
		_confirm.visible = false
		_panel.visible = true)
	row.add_child(no)


func open(runner: Node) -> void:
	_runner = runner
	visible = true
	_panel.visible = true
	_confirm.visible = false
	if not NetManager.is_online():
		get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


func _open_settings() -> void:
	var scr: GDScript = load(str(GameState.SCREENS["settings"])) as GDScript
	var s: Node = scr.new() as Node
	if s.has_method("set_overlay"):
		s.call("set_overlay", true)
	add_child(s)


func _on_quit() -> void:
	if NetManager.is_online() and multiplayer.is_server() and NetManager.peer_count() > 0:
		_panel.visible = false
		_confirm.visible = true
	else:
		_quit_now()


func _quit_now() -> void:
	get_tree().paused = false
	NetManager.leave_session()
	GameState.goto_screen("main_menu")
