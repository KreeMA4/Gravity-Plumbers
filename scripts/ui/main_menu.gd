extends Node
## Main menu: Play Solo, Host Game, Join Game, Customize, Settings (+ debug rooms),
## over an animated 3D background (your plumber idling in front of a space window).

const DEBUG_ROOMS: Array = [
	["Gravity Test Room", "gravity_test"],
	["Look Test Room", "look_test"],
	["Ragdoll Playground", "playground"],
	["Plumbing Workshop", "game:workshop"],
	["Physics Soak Test", "soak_test"],
	["Run Tests", "tests"],
]

var _root: Control
var _debug_box: VBoxContainer


func _ready() -> void:
	var backdrop_script: GDScript = load("res://scripts/ui/menu_backdrop.gd") as GDScript
	if backdrop_script != null:
		add_child(backdrop_script.new() as Node)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_root = UITheme.make_screen_root()
	layer.add_child(_root)
	var margin: MarginContainer = UITheme.safe_margin()
	_root.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(560, 0)
	row.add_child(col)
	var t: Label = UITheme.title("GRAVITY\nPLUMBERS")
	col.add_child(t)
	var sub: Label = UITheme.label("Keep the station from flooding!", UITheme.FONT_SIZE_SMALL, UITheme.C_SLUDGE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	_needs(_add_button(col, "Play Solo", UITheme.C_GOOD.darkened(0.3), _on_solo), "game")
	_needs(_add_button(col, "Host Game", UITheme.C_BUTTON, _on_host), "host_join")
	_needs(_add_button(col, "Join Game", UITheme.C_BUTTON, _on_join), "host_join")
	var row2: HBoxContainer = HBoxContainer.new()
	col.add_child(row2)
	var cust: Button = UITheme.big_button("Customize", UITheme.C_PIPE.darkened(0.25))
	cust.custom_minimum_size = Vector2(270, 110)
	cust.pressed.connect(func() -> void: GameState.goto_screen("customize"))
	row2.add_child(cust)
	_needs(cust, "customize")
	var sett: Button = UITheme.big_button("Settings", Color(0.35, 0.35, 0.5))
	sett.custom_minimum_size = Vector2(270, 110)
	sett.pressed.connect(func() -> void: GameState.goto_screen("settings"))
	row2.add_child(sett)
	_needs(sett, "settings")

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	# Right column: debug rooms (collapsed by default) + version.
	var right: VBoxContainer = VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(right)
	var dbg_toggle: Button = UITheme.small_button("Debug rooms")
	dbg_toggle.custom_minimum_size = Vector2(320, 100)
	right.add_child(dbg_toggle)
	_debug_box = VBoxContainer.new()
	_debug_box.visible = false
	right.add_child(_debug_box)
	dbg_toggle.pressed.connect(func() -> void: _debug_box.visible = not _debug_box.visible)
	for entry: Variant in DEBUG_ROOMS:
		var e: Array = entry as Array
		var b: Button = UITheme.small_button(str(e[0]))
		b.custom_minimum_size = Vector2(320, 96)
		var screen_id: String = str(e[1])
		if screen_id.begins_with("game:"):
			var lid: String = screen_id.substr(5)
			b.pressed.connect(func() -> void:
				NetManager.start_solo()
				GameState.start_level(lid))
			_needs(b, "game")
		else:
			b.pressed.connect(func() -> void: GameState.goto_screen(screen_id))
			_needs(b, screen_id)
		_debug_box.add_child(b)
	var dbg_overlay: Button = UITheme.small_button("Debug overlay")
	dbg_overlay.custom_minimum_size = Vector2(320, 96)
	dbg_overlay.pressed.connect(_toggle_overlay)
	_debug_box.add_child(dbg_overlay)
	var ver: Label = UITheme.label("v%s  %s   ducks: %d\n%s" % [Tuning.GAME_VERSION, Tuning.MILESTONE_ID, SaveData.duck_count(), BuildInfo.LABEL], 22)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(ver)

	if GameState.menu_message != "":
		_show_message(GameState.menu_message)
		GameState.menu_message = ""
	AudioManager.play_music("menu")
	Quality.maybe_start_auto_benchmark()


func _add_button(parent: Control, text: String, color: Color, cb: Callable) -> Button:
	var b: Button = UITheme.big_button(text, color)
	b.custom_minimum_size = Vector2(560, 116)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Disable a button whose screen isn't built yet (earlier milestones).
func _needs(b: Button, screen_id: String) -> void:
	if not GameState.screen_available(screen_id):
		b.disabled = true
		b.text += " (soon)"


func _toggle_overlay() -> void:
	var main: Node = get_parent()
	if main != null and main.has_method("get_debug_overlay"):
		var o: Node = main.call("get_debug_overlay") as Node
		if o != null and o.has_method("toggle"):
			o.call("toggle")


func _on_solo() -> void:
	NetManager.maybe_random_look()
	NetManager.start_solo()
	GameState.start_level("hub")


func _on_host() -> void:
	GameState.goto_screen("host_join", {"tab": "host"})


func _on_join() -> void:
	GameState.goto_screen("host_join", {"tab": "join"})


func _show_message(text: String) -> void:
	var dlg: AcceptDialog = AcceptDialog.new()
	dlg.dialog_text = text
	dlg.title = "Heads up!"
	dlg.theme = UITheme.get_theme()
	_root.add_child(dlg)
	dlg.popup_centered(Vector2i(900, 360))
