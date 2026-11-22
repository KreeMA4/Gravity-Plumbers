extends TestCase
## On-screen movement joystick maths.

const R: float = 140.0
const DZ: float = 0.12


func test_eight_directions() -> void:
	var c: Vector2 = Vector2(300, 800)
	# screen offset (y down) -> expected stick (x right, y forward)
	var cases: Array = [
		[Vector2(0, -1), Vector2(0, 1)], [Vector2(0, 1), Vector2(0, -1)],
		[Vector2(1, 0), Vector2(1, 0)], [Vector2(-1, 0), Vector2(-1, 0)],
		[Vector2(1, -1), Vector2(1, 1)], [Vector2(-1, -1), Vector2(-1, 1)],
		[Vector2(1, 1), Vector2(1, -1)], [Vector2(-1, 1), Vector2(-1, -1)],
	]
	for item: Variant in cases:
		var screen_dir: Vector2 = ((item as Array)[0] as Vector2).normalized()
		var want: Vector2 = ((item as Array)[1] as Vector2).normalized()
		var v: Vector2 = JoystickMath.stick_vector(c, c + screen_dir * R, R, DZ)
		check_near(v.length(), 1.0, "full deflection %s has length 1" % str(screen_dir), 0.001)
		check(v.normalized().dot(want) > 0.999, "direction %s -> %s (got %s)" % [str(screen_dir), str(want), str(v)])


func test_deadzone_and_analog() -> void:
	var c: Vector2 = Vector2(300, 800)
	check_eq(JoystickMath.stick_vector(c, c, R, DZ), Vector2.ZERO, "centre is zero")
	check_eq(JoystickMath.stick_vector(c, c + Vector2(R * 0.1, 0), R, DZ), Vector2.ZERO, "inside deadzone is zero")
	var half: float = JoystickMath.stick_vector(c, c + Vector2(R * 0.5, 0), R, DZ).length()
	check_near(half, (0.5 - DZ) / (1.0 - DZ), "half deflection is proportional (smooth analog)", 0.001)
	var quarter: float = JoystickMath.stick_vector(c, c + Vector2(R * 0.25, 0), R, DZ).length()
	check(quarter > 0.0 and quarter < half, "analog increases smoothly")
	var far: Vector2 = JoystickMath.stick_vector(c, c + Vector2(R * 5.0, R * 5.0), R, DZ)
	check(far.length() <= 1.0001, "never longer than 1")


func test_knob_stays_inside_ring() -> void:
	var c: Vector2 = Vector2(300, 800)
	check_vec2(JoystickMath.knob_position(c, c + Vector2(1000, 0), R), c + Vector2(R, 0), "knob clamps to rim")
	check_vec2(JoystickMath.knob_position(c, c + Vector2(30, -20), R), c + Vector2(30, -20), "knob follows finger inside")


func test_base_on_screen_every_resolution() -> void:
	# UI canvas sizes for 16:9, 18:9, 19.5:9 (Galaxy S25 Ultra), 20:9, 21:9 and 4:3 screens,
	# with no notch, a left camera cut-out, and rounded corners / gesture bar.
	var views: Array = [Vector2(1920, 1080), Vector2(2160, 1080), Vector2(2340, 1080), Vector2(2400, 1080),
		Vector2(2520, 1080), Vector2(1920, 1440), Vector2(1280, 720)]
	var pads: Array = [Vector4.ZERO, Vector4(110, 0, 0, 0), Vector4(40, 20, 40, 60)]
	for v: Variant in views:
		var view: Vector2 = v as Vector2
		for p: Variant in pads:
			var pad: Vector4 = p as Vector4
			for lefty: bool in [false, true]:
				var c: Vector2 = JoystickMath.base_center(view, pad, R, lefty)
				var label: String = "%s pad %s lefty %s" % [str(view), str(pad), str(lefty)]
				check(c.x - R >= pad.x - 0.01 or lefty, "left edge inside safe area: " + label)
				check(c.x + R <= view.x - pad.z + 0.01 or not lefty, "right edge inside safe area: " + label)
				check(c.x - R >= 0.0 and c.x + R <= view.x, "fully on screen horizontally: " + label)
				check(c.y - R >= 0.0 and c.y + R <= view.y - pad.w + 0.01, "fully on screen vertically: " + label)
				check((c.x < view.x * 0.5) != lefty, "on the correct side: " + label)
				check(c.y > view.y * 0.5, "in the bottom half: " + label)
				check(JoystickMath.in_activation_zone(c, view, lefty), "its own centre starts it: " + label)


func test_activation_zone_leaves_right_side_free() -> void:
	var view: Vector2 = Vector2(2340, 1080)
	check(not JoystickMath.in_activation_zone(Vector2(1800, 800), view, false), "right side is for look/buttons")
	check(not JoystickMath.in_activation_zone(Vector2(200, 100), view, false), "top-left strip is for HUD")
	check(JoystickMath.in_activation_zone(Vector2(500, 700), view, false), "lower-left starts the joystick")
	check(JoystickMath.in_activation_zone(Vector2(1900, 800), view, true), "mirrored when left-handed")


func check_vec2(a: Vector2, b: Vector2, msg: String) -> void:
	check(a.distance_to(b) <= 0.01, "%s (got %s, expected %s)" % [msg, str(a), str(b)])
