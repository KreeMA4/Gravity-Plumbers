class_name DebugRoomUI
extends CanvasLayer
## A column of big buttons on the right edge for debug/test rooms, plus a
## Back button and an optional info label. Usage:
##   var ui := DebugRoomUI.new(); add_child(ui)
##   ui.add_button("Cycle gravity", GravityManager.cycle_debug)

var root: Control
var column: VBoxContainer
var info: Label
var bottom: HBoxContainer


func _init() -> void:
	layer = 10
	root = UITheme.make_screen_root()
	add_child(root)
	var margin: MarginContainer = UITheme.safe_margin()
	root.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	info = UITheme.label("", 26)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(info)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(spacer)
	bottom = HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(bottom)
	column = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(column)
	var back: Button = UITheme.small_button("< Back")
	back.custom_minimum_size = Vector2(300, 96)
	back.pressed.connect(func() -> void: GameState.goto_screen("main_menu"))
	column.add_child(back)


func add_button(text: String, cb: Callable) -> Button:
	var b: Button = UITheme.small_button(text)
	b.custom_minimum_size = Vector2(300, 96)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(cb)
	column.add_child(b)
	return b
