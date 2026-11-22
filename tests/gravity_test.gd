extends TestCase
## Gravity field resolution tests (pure logic, no nodes).

const G: float = 9.8


func test_global_only() -> void:
	var g: Vector3 = GravityMath.resolve([], Vector3.DOWN * G, Vector3(3, 4, 5))
	check_vec(g, Vector3(0, -G, 0), "no fields = global gravity")


func test_priority_resolution() -> void:
	var low: GravityFieldData = GravityFieldData.make_box("low", Vector3.ZERO, Vector3(5, 5, 5), Vector3.RIGHT, 1)
	var high: GravityFieldData = GravityFieldData.make_box("high", Vector3.ZERO, Vector3(1, 1, 1), Vector3.BACK, 2)
	var fields: Array = [low, high]
	check_vec(GravityMath.resolve(fields, Vector3.DOWN * G, Vector3.ZERO), Vector3.BACK * G, "higher priority wins inside both")
	check_vec(GravityMath.resolve(fields, Vector3.DOWN * G, Vector3(3, 0, 0)), Vector3.RIGHT * G, "only low field contains point")
	check_vec(GravityMath.resolve(fields, Vector3.DOWN * G, Vector3(30, 0, 0)), Vector3.DOWN * G, "outside all fields = global")


func test_equal_priority_blends() -> void:
	var a: GravityFieldData = GravityFieldData.make_box("a", Vector3.ZERO, Vector3(2, 2, 2), Vector3.RIGHT, 1)
	var b: GravityFieldData = GravityFieldData.make_box("b", Vector3.ZERO, Vector3(2, 2, 2), Vector3.LEFT, 1)
	var c: GravityFieldData = GravityFieldData.make_box("c", Vector3.ZERO, Vector3(2, 2, 2), Vector3.DOWN, 1)
	check_vec(GravityMath.resolve([a, b], Vector3.DOWN * G, Vector3.ZERO), Vector3.ZERO, "opposite equal fields cancel")
	check_vec(GravityMath.resolve([a, c], Vector3.DOWN * G, Vector3.ZERO), (Vector3.RIGHT + Vector3.DOWN) * G * 0.5, "equal fields average")


func test_disabled_field_ignored() -> void:
	var a: GravityFieldData = GravityFieldData.make_box("a", Vector3.ZERO, Vector3(2, 2, 2), Vector3.UP, 3)
	a.enabled = false
	check_vec(GravityMath.resolve([a], Vector3.DOWN * G, Vector3.ZERO), Vector3.DOWN * G, "disabled field does nothing")


func test_box_rotation() -> void:
	var a: GravityFieldData = GravityFieldData.make_box("a", Vector3.ZERO, Vector3(4, 0.5, 0.5), Vector3.UP, 1)
	a.basis = Basis(Vector3.BACK, PI * 0.5)   # long axis now points along Y
	check(a.contains(Vector3(0, 3, 0)), "rotated box contains point along its long axis")
	check(not a.contains(Vector3(3, 0, 0)), "rotated box no longer contains old long axis")


func test_sphere_direction() -> void:
	var s: GravityFieldData = GravityFieldData.make_sphere("rock", Vector3(10, 0, 0), 2.0, 8.0, 2)
	s.falloff = false
	var g: Vector3 = GravityMath.resolve([s], Vector3.DOWN * G, Vector3(10, 3, 0))
	check_vec(g, Vector3(0, -G, 0), "above the rock pulls down toward centre")
	var g2: Vector3 = GravityMath.resolve([s], Vector3.DOWN * G, Vector3(13, 0, 0))
	check_vec(g2, Vector3(-G, 0, 0), "beside the rock pulls sideways toward centre")
	var g3: Vector3 = GravityMath.resolve([s], Vector3.DOWN * G, Vector3(10, -3, 0))
	check_vec(g3, Vector3(0, G, 0), "under the rock pulls UP toward centre")
	check_vec(GravityMath.resolve([s], Vector3.DOWN * G, Vector3(30, 0, 0)), Vector3.DOWN * G, "outside influence = global")


func test_sphere_falloff() -> void:
	var s: GravityFieldData = GravityFieldData.make_sphere("rock", Vector3.ZERO, 2.0, 10.0, 2)
	var near: float = s.accel_at(Vector3(0, 2, 0)).length()
	var far: float = s.accel_at(Vector3(0, 9.9, 0)).length()
	check_near(near, G, "full strength at the surface")
	check(far < near * 0.4, "weaker near the edge")


func test_zero_g_zone() -> void:
	var z: GravityFieldData = GravityFieldData.make_zero_g("float", Vector3.ZERO, Vector3(3, 3, 3), 3, 0.6)
	check_vec(GravityMath.resolve([z], Vector3.DOWN * G, Vector3(1, 1, 1)), Vector3.ZERO, "zero inside")
	check_near(GravityMath.resolve_drag([z], Vector3(1, 1, 1)), 0.6, "drag inside")
	check_near(GravityMath.resolve_drag([z], Vector3(10, 1, 1)), 0.0, "no drag outside")


func test_push_is_additive() -> void:
	var p: GravityFieldData = GravityFieldData.make_push("vent", Vector3.ZERO, Vector3(1, 1, 1), Vector3.UP, 20.0)
	check_vec(GravityMath.resolve([p], Vector3.DOWN * G, Vector3.ZERO), Vector3.DOWN * G, "vent starts disabled")
	p.enabled = true
	check_vec(GravityMath.resolve([p], Vector3.DOWN * G, Vector3.ZERO), Vector3(0, 20.0 - G, 0), "vent adds to global")


func test_transition_blending() -> void:
	var from: Vector3 = Vector3.DOWN
	var to: Vector3 = Vector3.RIGHT
	check_vec(GravityMath.rotate_dir(from, to, 0.0), from, "t=0 is start")
	check_vec(GravityMath.rotate_dir(from, to, 1.0), to, "t=1 is end")
	var mid: Vector3 = GravityMath.rotate_dir(from, to, 0.5)
	check_near(mid.length(), 1.0, "stays unit length")
	check_near(mid.angle_to(from), PI * 0.25, "halfway is 45 degrees")
	# 180-degree flip must not produce NaN or zero.
	var flip: Vector3 = GravityMath.rotate_dir(Vector3.DOWN, Vector3.UP, 0.5)
	check(flip.is_finite() and absf(flip.length() - 1.0) < 0.001, "180 flip midpoint is a valid unit vector")
	check_near(flip.angle_to(Vector3.DOWN), PI * 0.5, "180 flip midpoint is perpendicular")
	check_near(GravityMath.ease_shift(0.5), 0.5, "ease midpoint")


func test_nearest_axis() -> void:
	check_eq(GravityMath.nearest_axis_index(Vector3(0.9, -0.2, 0.1)), 2, "+X")
	check_eq(GravityMath.nearest_axis_index(Vector3(0.1, -0.9, 0.3)), 0, "-Y")
	check_eq(GravityMath.nearest_axis_index(Vector3(0.1, 0.1, -0.95)), 5, "-Z")


func test_override_timer() -> void:
	# GravityBody needs a RigidBody3D parent; the timer logic is checked by
	# simulating its _physics_process countdown on a detached instance.
	var rb: RigidBody3D = RigidBody3D.new()
	var gb: GravityBody = GravityBody.new()
	rb.add_child(gb)
	gb.body = rb
	gb.set_override(Vector3.LEFT, 1.0)
	check(gb.has_override(), "override active")
	check_vec(gb.current_gravity(), Vector3.LEFT * 9.8, "override direction used")
	# Count down like the physics tick does.
	for i: int in 70:
		if gb.override_time > 0.0:
			gb.override_time -= 1.0 / 60.0
			if gb.override_time <= 0.0:
				gb.clear_override()
	check(not gb.has_override(), "override expired after its duration")
	rb.free()


func test_quat_between() -> void:
	var q: Quaternion = GravityMath.quat_between(Vector3.UP, Vector3.RIGHT)
	check_vec(q * Vector3.UP, Vector3.RIGHT, "rotates up onto right")
	var q2: Quaternion = GravityMath.quat_between(Vector3.UP, Vector3.DOWN)
	check_vec(q2 * Vector3.UP, Vector3.DOWN, "handles opposite vectors")
