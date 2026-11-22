class_name InputSetup
extends RefCounted
## Registers every input action in code instead of in project.godot.
## Why: the input-map section of project.godot is long, fiddly text that is
## easy to break by hand. Doing it here is readable and beginner-proof.
## tools/validate_project.py reads the ACTIONS list below to check that every
## action used in code exists.

## action name -> list of default bindings.
## "k:<KEY>" = keyboard key (Godot Key enum name without KEY_),
## "m:<n>"  = mouse button index, "jb:<n>" = gamepad button, "ja:<axis>:<sign>" = gamepad axis.
const ACTIONS: Dictionary = {
	"move_forward": ["k:W", "k:UP", "ja:1:-1"],
	"move_back": ["k:S", "k:DOWN", "ja:1:1"],
	"move_left": ["k:A", "k:LEFT", "ja:0:-1"],
	"move_right": ["k:D", "k:RIGHT", "ja:0:1"],
	"look_left": ["ja:2:-1"],
	"look_right": ["ja:2:1"],
	"look_up": ["ja:3:-1"],
	"look_down": ["ja:3:1"],
	"jump": ["k:SPACE", "jb:0"],
	"grab_left": ["k:Q", "ja:4:1"],
	"grab_right": ["k:E", "ja:5:1"],
	"use": ["k:F", "jb:2"],
	"boots": ["k:G", "jb:3"],
	"flop": ["k:R", "jb:1"],
	"get_up": ["k:T", "jb:9"],
	"emote": ["k:X", "jb:4"],
	"pause": ["k:ESCAPE", "jb:6"],
	"debug_overlay": ["k:F3"],
	"debug_gravity": ["k:F4"],
	"debug_spawn": ["k:F5"],
}


static func register_all() -> void:
	for action_name: String in ACTIONS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.25)
		for spec: String in ACTIONS[action_name]:
			var ev: InputEvent = _make_event(spec)
			if ev != null:
				InputMap.action_add_event(action_name, ev)


static func _make_event(spec: String) -> InputEvent:
	var parts: PackedStringArray = spec.split(":")
	match parts[0]:
		"k":
			var key_ev: InputEventKey = InputEventKey.new()
			key_ev.physical_keycode = _key_from_name(parts[1])
			return key_ev
		"m":
			var mouse_ev: InputEventMouseButton = InputEventMouseButton.new()
			mouse_ev.button_index = parts[1].to_int() as MouseButton
			return mouse_ev
		"jb":
			var jb: InputEventJoypadButton = InputEventJoypadButton.new()
			jb.button_index = parts[1].to_int() as JoyButton
			return jb
		"ja":
			var ja: InputEventJoypadMotion = InputEventJoypadMotion.new()
			ja.axis = parts[1].to_int() as JoyAxis
			ja.axis_value = float(parts[2].to_int())
			return ja
	return null


static func _key_from_name(key_name: String) -> Key:
	match key_name:
		"W": return KEY_W
		"A": return KEY_A
		"S": return KEY_S
		"D": return KEY_D
		"Q": return KEY_Q
		"E": return KEY_E
		"F": return KEY_F
		"G": return KEY_G
		"R": return KEY_R
		"T": return KEY_T
		"X": return KEY_X
		"UP": return KEY_UP
		"DOWN": return KEY_DOWN
		"LEFT": return KEY_LEFT
		"RIGHT": return KEY_RIGHT
		"SPACE": return KEY_SPACE
		"ESCAPE": return KEY_ESCAPE
		"F3": return KEY_F3
		"F4": return KEY_F4
		"F5": return KEY_F5
	return KEY_NONE
