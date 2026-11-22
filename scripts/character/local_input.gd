class_name LocalInput
extends Node
## Collects THIS device's input (touch controls + keyboard + gamepad) into a
## PlumberInput every physics tick. On the host it drives the local plumber
## directly; on a client NetManager sends it to the host instead.
## Also forwards look drags / right stick to the camera.

var touch: TouchControls = null
var camera: PlumberCamera = null
var plumber: Plumber = null
var frame: PlumberInput = PlumberInput.new()
var blocked: bool = false        ## true while paused or a menu is open


func _physics_process(_dt: float) -> void:
	if blocked:
		frame.move = Vector2.ZERO
		frame.buttons = 0
	else:
		var mv: Vector2 = Vector2.ZERO
		if touch != null:
			mv = touch.joystick
		var kb: Vector2 = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		if kb.length() > mv.length():
			mv = kb
		var bits: int = touch.buttons_held if touch != null else 0
		if Input.is_action_pressed("jump"):
			bits |= PlumberInput.JUMP
		if Input.is_action_pressed("grab_left"):
			bits |= PlumberInput.GRAB_L
		if Input.is_action_pressed("grab_right"):
			bits |= PlumberInput.GRAB_R
		if Input.is_action_pressed("use"):
			bits |= PlumberInput.USE
		if Input.is_action_pressed("boots"):
			bits |= PlumberInput.BOOTS
		if Input.is_action_pressed("flop"):
			bits |= PlumberInput.FLOP
		if Input.is_action_pressed("get_up"):
			bits |= PlumberInput.GET_UP
		if Input.is_action_pressed("emote"):
			bits |= PlumberInput.EMOTE
		if SaveData.setting_b("single_grab") and (bits & (PlumberInput.GRAB_L | PlumberInput.GRAB_R)) != 0:
			bits |= PlumberInput.GRAB_L | PlumberInput.GRAB_R
		frame.move = mv.limit_length(1.0)
		frame.buttons = bits
	if camera != null:
		frame.aim = camera.get_aim()
	if plumber != null and is_instance_valid(plumber) and not plumber.is_puppet:
		plumber.input.copy_from(frame)


func _process(delta: float) -> void:
	if camera == null or blocked:
		if touch != null:
			touch.take_look_delta()
		return
	var d: Vector2 = Vector2.ZERO
	if touch != null:
		d = touch.take_look_delta()
	var stick: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	d += stick * delta * 700.0
	camera.look_delta += d
