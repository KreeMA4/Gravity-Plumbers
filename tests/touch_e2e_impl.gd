extends Node
## END-TO-END touch input test: boots the real game, opens a gameplay screen,
## and drives it with the SAME events an Android phone sends
## (InputEventScreenTouch / InputEventScreenDrag through Input.parse_input_event).
## Checks that the joystick is visible and on screen, that dragging it moves the
## plumber in all 8 directions RELATIVE TO THE CAMERA, that it's analog, that it
## doesn't steal camera look / Jump, that multi-touch works, that keyboard input
## still works, and that it stays on screen at several resolutions.
##
## Launched by tests/touch_e2e_test.gd (it is loaded on the first frame so the
## game's autoloads exist when this script compiles).

var failures: PackedStringArray = PackedStringArray()
var checks: int = 0
var touch: TouchControls
var player: LocalPlayer
var plumber: Plumber
var shot_dir: String = ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shot_dir = a.substr(8)
	_run.call_deferred()


func ok(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		failures.append(msg)


func frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


## Canvas (UI) coordinates -> window coordinates, like a real finger on the glass.
func to_window(p: Vector2) -> Vector2:
	return get_tree().root.get_screen_transform() * p


func touch_down(index: int, p: Vector2) -> void:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = index
	e.pressed = true
	e.position = to_window(p)
	Input.parse_input_event(e)


func touch_move(index: int, from: Vector2, to: Vector2) -> void:
	var e: InputEventScreenDrag = InputEventScreenDrag.new()
	e.index = index
	e.position = to_window(to)
	e.relative = to_window(to) - to_window(from)
	Input.parse_input_event(e)


func touch_up(index: int, p: Vector2) -> void:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = index
	e.pressed = false
	e.position = to_window(p)
	Input.parse_input_event(e)


## Slide a finger from a to b in a few steps (like a real thumb).
func drag(index: int, a: Vector2, b: Vector2, steps: int = 5) -> void:
	var prev: Vector2 = a
	for i: int in steps:
		var p: Vector2 = a.lerp(b, float(i + 1) / float(steps))
		touch_move(index, prev, p)
		prev = p
		await get_tree().process_frame


func screenshot(shot_name: String) -> void:
	if shot_dir == "":
		return
	await get_tree().process_frame
	var img: Image = get_tree().root.get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(shot_dir.path_join(shot_name + ".png"))
		print("  shot  " + shot_name + ".png")


func _run() -> void:
	print("TOUCH E2E: booting the game")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await frames(10)
	# Keep the camera still during the test so "relative to the camera" is measurable.
	Tuning.CAMERA_RECENTER_SPEED = 0.0
	NetManager.start_solo()
	GameState.goto_screen("playground")
	await frames(90)
	touch = get_tree().root.find_child("TouchControls", true, false) as TouchControls
	player = get_tree().root.find_child("LocalPlayer", true, false) as LocalPlayer
	for n: Node in get_tree().get_nodes_in_group("plumbers"):
		if (n as Plumber).player_index == 0:
			plumber = n as Plumber
	ok(touch != null, "touch controls exist on the gameplay screen")
	ok(player != null and plumber != null, "local player and plumber exist")
	if touch == null or player == null or plumber == null:
		_finish()
		return
	await _check_visible("default window")
	await screenshot("touch_idle")
	await _check_directions()
	await _check_analog()
	await _check_look_and_buttons()
	await _check_keyboard()
	await _check_resolutions()
	_finish()


func _check_visible(label: String) -> void:
	var view: Rect2 = Rect2(Vector2.ZERO, touch.get_viewport().get_visible_rect().size)
	var c: Vector2 = touch.joystick_home()
	var r: float = touch.joystick_radius()
	ok(touch.is_visible_in_tree() and touch.enabled, "[%s] joystick layer visible and enabled" % label)
	ok(touch.size.distance_to(view.size) < 2.0, "[%s] touch layer covers the whole screen (%s vs %s)" % [label, str(touch.size), str(view.size)])
	ok(r >= 60.0, "[%s] joystick has a usable size (radius %.0f)" % [label, r])
	ok(view.grow(-1.0).encloses(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)), "[%s] joystick fully on screen (centre %s, r %.0f, screen %s)" % [label, str(c), r, str(view.size)])
	ok(c.x < view.size.x * 0.5 and c.y > view.size.y * 0.5, "[%s] joystick is bottom-left" % label)
	for id: Variant in touch.button_ids():
		var bc: Vector2 = touch.button_center(str(id))
		var br: float = touch.button_radius(str(id))
		ok(bc.distance_to(c) > r + br, "[%s] joystick doesn't overlap button %s" % [label, str(id)])


func _check_directions() -> void:
	var c: Vector2 = touch.joystick_home()
	var r: float = touch.joystick_radius()
	var dirs: Array = [["forward", Vector2(0, 1)], ["back", Vector2(0, -1)], ["right", Vector2(1, 0)], ["left", Vector2(-1, 0)],
		["forward-right", Vector2(1, 1)], ["forward-left", Vector2(-1, 1)], ["back-right", Vector2(1, -1)], ["back-left", Vector2(-1, -1)]]
	var shot_taken: bool = false
	for item: Variant in dirs:
		var dname: String = str((item as Array)[0])
		var stick: Vector2 = ((item as Array)[1] as Vector2).normalized()   # x right, y forward
		plumber.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 10)))   # open floor, away from crates
		await frames(45)
		var up: Vector3 = plumber.local_up
		var aim: Vector3 = player.camera.get_aim()
		var fwd: Vector3 = (aim - up * aim.dot(up)).normalized()
		var right: Vector3 = fwd.cross(up).normalized()
		var expected: Vector3 = (right * stick.x + fwd * stick.y).normalized()
		var start: Vector3 = plumber.get_center()
		var target: Vector2 = c + Vector2(stick.x, -stick.y) * r   # screen y is down
		touch_down(0, c)
		await get_tree().process_frame
		await drag(0, c, target)
		ok(touch.is_joystick_active(), "[%s] joystick grabbed by the finger" % dname)
		var mv_ok: bool = true
		for i: int in 40:
			await get_tree().physics_frame
			if plumber.input.move.normalized().dot(stick) < 0.98 or plumber.input.move.length() < 0.9:
				mv_ok = false
		ok(mv_ok, "[%s] plumber input = full %s (got %s)" % [dname, str(stick), str(plumber.input.move)])
		if not shot_taken:
			shot_taken = true
			await screenshot("touch_dragging_forward")
		touch_up(0, target)
		await frames(3)
		var moved: Vector3 = plumber.get_center() - start
		moved -= up * moved.dot(up)
		var ang: float = rad_to_deg(moved.angle_to(expected)) if moved.length() > 0.01 else 180.0
		ok(moved.length() > 0.7, "[%s] plumber actually moved (%.2f m)" % [dname, moved.length()])
		ok(ang < 30.0, "[%s] moved the way the stick points, relative to the camera (off by %.0f deg)" % [dname, ang])
		ok(not touch.is_joystick_active() and touch.joystick.length() < 0.001, "[%s] released: stick back to centre" % dname)


func _check_analog() -> void:
	var c: Vector2 = touch.joystick_home()
	var r: float = touch.joystick_radius()
	touch_down(0, c)
	await get_tree().process_frame
	await drag(0, c, c + Vector2(r * 0.5, 0))
	await frames(2)
	var half: float = plumber.input.move.length()
	await drag(0, c + Vector2(r * 0.5, 0), c + Vector2(r, 0))
	await frames(2)
	var full: float = plumber.input.move.length()
	touch_up(0, c + Vector2(r, 0))
	await frames(2)
	ok(half > 0.25 and half < 0.65, "analog: half deflection gives partial speed (%.2f)" % half)
	ok(full > 0.95, "analog: full deflection gives full speed (%.2f)" % full)
	# Starting away from the stick (but in its zone) brings the base under the thumb.
	var view: Vector2 = touch.get_viewport().get_visible_rect().size
	var away: Vector2 = Vector2(view.x * 0.32, view.y * 0.55)
	touch_down(0, away)
	await get_tree().process_frame
	ok(touch.is_joystick_active() and touch.joystick_center().distance_to(away) < 1.0, "touch elsewhere in the left zone re-centres the stick")
	touch_up(0, away)
	await frames(2)
	ok(touch.joystick_center().distance_to(touch.joystick_home()) < 0.5, "stick returns home after release")


func _check_look_and_buttons() -> void:
	var view: Vector2 = touch.get_viewport().get_visible_rect().size
	var c: Vector2 = touch.joystick_home()
	# Camera look: drag on an empty part of the right side.
	var look_at: Vector2 = Vector2(view.x * 0.62, view.y * 0.3)
	var yaw0: float = player.camera.yaw
	touch_down(2, look_at)
	await get_tree().process_frame
	await drag(2, look_at, look_at + Vector2(-220, 0))
	await frames(3)
	touch_up(2, look_at + Vector2(-220, 0))
	await frames(2)
	ok(absf(player.camera.yaw - yaw0) > 0.3, "right-side drag turns the camera (yaw changed %.2f)" % absf(player.camera.yaw - yaw0))
	ok(not touch.is_joystick_active() and touch.joystick.length() < 0.001, "camera drag doesn't touch the joystick")
	# Jump button alone.
	var jb: Vector2 = touch.button_center("jump")
	touch_down(3, jb)
	await frames(2)
	ok((touch.buttons_held & PlumberInput.JUMP) != 0 and not touch.is_joystick_active(), "Jump button works and doesn't start the joystick")
	touch_up(3, jb)
	await frames(2)
	# Multi-touch: move + grab + jump at the same time.
	touch_down(0, c)
	await get_tree().process_frame
	await drag(0, c, c + Vector2(0, -touch.joystick_radius()))
	touch_down(4, touch.button_center("grab_r"))
	touch_down(5, jb)
	await frames(3)
	var bits: int = plumber.input.buttons
	ok(plumber.input.move.y > 0.9 and (bits & PlumberInput.JUMP) != 0 and (bits & PlumberInput.GRAB_R) != 0,
		"multi-touch: moving while holding Grab and Jump (move %s, buttons %d)" % [str(plumber.input.move), bits])
	touch_up(4, touch.button_center("grab_r"))
	touch_up(5, jb)
	touch_up(0, c + Vector2(0, -touch.joystick_radius()))
	await frames(3)
	ok(touch.buttons_held == 0 and not touch.is_joystick_active(), "all fingers released cleanly")


func _check_keyboard() -> void:
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await frames(3)
	var mv: Vector2 = plumber.input.move
	Input.action_release("move_forward")
	Input.action_release("move_right")
	await frames(3)
	ok(mv.x > 0.5 and mv.y > 0.5, "keyboard WASD still drives the plumber (%s)" % str(mv))
	ok(plumber.input.move.length() < 0.01, "keyboard release stops")


func _check_resolutions() -> void:
	var win: Window = get_tree().root
	var sizes: Array = [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(1680, 720), Vector2i(1440, 720), Vector2i(960, 720), Vector2i(2340, 1080)]
	for s: Variant in sizes:
		var size_i: Vector2i = s as Vector2i
		win.size = size_i
		await frames(6)
		await _check_visible("window %dx%d" % [size_i.x, size_i.y])
	win.size = Vector2i(1560, 720)
	await frames(6)
	await screenshot("touch_19_5x9")


func _finish() -> void:
	print("TOUCH E2E: %d checks, %d failed" % [checks, failures.size()])
	if failures.is_empty():
		print("TOUCH E2E PASSED")
	else:
		print("TOUCH E2E FAILED")
	GameState.quit_game(0 if failures.is_empty() else 1)
