extends TestCase
## Walk/run maths (scripts/character/gait.gd).

const L1: float = 0.38
const L2: float = 0.38


func test_ik_reaches_the_target() -> void:
	# Forward kinematics of the IK answer must land on the requested foot point.
	for fwd: float in [-0.35, -0.2, 0.0, 0.15, 0.3]:
		for down: float in [0.5, 0.6, 0.7, 0.74]:
			if sqrt(fwd * fwd + down * down) > (L1 + L2) * 0.99:
				continue   # out of reach (covered below)
			var a: Vector2 = Gait.leg_ik(fwd, down, L1, L2)
			var foot: Vector2 = Gait.leg_fk(a.x, a.y, L1, L2)
			check(foot.distance_to(Vector2(fwd, down)) < 0.002, "IK reaches (%.2f, %.2f) (got %s)" % [fwd, down, str(foot)])
			check(a.y <= 0.0001, "knee only bends backward at (%.2f, %.2f)" % [fwd, down])


func test_ik_out_of_reach_is_straight() -> void:
	var a: Vector2 = Gait.leg_ik(0.0, 2.0, L1, L2)
	check(absf(a.y) < 0.1, "a far target gives a (nearly) straight leg")
	check(absf(a.x) < 0.1, "...pointing at it")


func test_stance_and_swing() -> void:
	var duty: float = 0.6
	var start: Vector2 = Gait.foot_cycle(0.0, duty)
	var mid: Vector2 = Gait.foot_cycle(TAU * duty * 0.5, duty)
	var swing: Vector2 = Gait.foot_cycle(TAU * (duty + (1.0 - duty) * 0.5), duty)
	check_near(start.x, 1.0, "stance starts with the foot in front")
	check_near(mid.x, 0.0, "mid-stance: foot under the hip", 0.01)
	check_eq(start.y, 0.0, "planted foot doesn't lift")
	check(swing.y > 0.9, "mid-swing the foot is lifted")
	check(Gait.in_stance(0.1, duty) and not Gait.in_stance(TAU * 0.8, duty), "stance/swing split follows the duty factor")
	# Left and right (half a cycle apart): walking always has a foot down, running has flight.
	var walk_both_up: bool = false
	var run_both_up: bool = false
	for i: int in 200:
		var ph: float = TAU * float(i) / 200.0
		if not Gait.in_stance(ph, Gait.duty(0.0)) and not Gait.in_stance(ph + PI, Gait.duty(0.0)):
			walk_both_up = true
		if not Gait.in_stance(ph, Gait.duty(1.0)) and not Gait.in_stance(ph + PI, Gait.duty(1.0)):
			run_both_up = true
	check(not walk_both_up, "walking: never both feet in the air")
	check(run_both_up, "running: has a flight phase")


func test_planted_foot_moves_at_body_speed() -> void:
	# Stance lasts duty/f seconds and covers stance_length: that's exactly the speed.
	for v: float in [0.5, 1.5, 3.0, 4.5]:
		var f: float = Gait.cadence(v, 1.0)
		var stance_time: float = Gait.duty(Gait.run_blend(v)) / f
		check_near(Gait.stance_length(v, 1.0) / stance_time, v, "foot speed == body speed at %.1f m/s (no skating)" % v, 0.001)
	check_eq(Gait.cadence(0.0, 1.0), 0.0, "no stepping when standing still")
	check(Gait.cadence(4.5, 1.0) > Gait.cadence(1.5, 1.0), "running steps faster than walking")


func test_blends() -> void:
	check_eq(Gait.amount(0.0), 0.0, "standing: no gait")
	check_near(Gait.amount(2.0), 1.0, "walking: full gait")
	check_eq(Gait.run_blend(1.5), 0.0, "1.5 m/s is a walk")
	check_near(Gait.run_blend(4.5), 1.0, "4.5 m/s is a run")


func test_stride_stays_within_reach() -> void:
	for v: float in [0.5, 2.0, 4.5]:
		var half: float = Gait.stance_length(v, 1.0) * 0.5
		var h: float = Gait.hip_height_for(half, L1, L2)
		check(sqrt(half * half + h * h) <= (L1 + L2) * 0.97, "foot at the stride end is reachable at %.1f m/s" % v)
		check(h > 0.55, "hip doesn't sink too low at %.1f m/s (%.2f)" % [v, h])
	check(Gait.hip_height_for(0.3, L1, L2) < Gait.hip_height_for(0.0, L1, L2), "pelvis dips when the feet are spread (walk bob)")
