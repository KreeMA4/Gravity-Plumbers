class_name Gait
extends RefCounted
## Procedural walk/run maths for the physics plumber (pure functions, unit
## tested in tests/gait_test.gd). Nothing here moves bodies; Plumber turns the
## results into joint-muscle targets and a pelvis ride height, so the ragdoll
## keeps all of its physics (balance, falls, grabs, any gravity direction).
##
## Why: the old walk only swung each hip back and forth while a hover spring
## held the pelvis at a fixed height. Swinging a straight leg lifts its foot
## off the floor, so at mid-stride BOTH feet were in the air and the body slid
## along - the "floating / skating" look. Now each foot follows a real gait
## cycle: in STANCE it is planted on the ground and slides back under the body
## at exactly the walking speed (so it doesn't skate); in SWING it lifts and
## swings forward. Two-bone IK finds the hip and knee angles that put the foot
## there, and the pelvis rides only as high as the stance leg can reach, which
## gives the natural up-down bob of a walk.

## Below this speed (m/s) the legs settle into a standing pose.
const IDLE_SPEED: float = 0.12
## Walk -> run blend happens between these speeds (m/s).
const RUN_FROM: float = 2.4
const RUN_TO: float = 3.6


## How much of the gait to apply at `speed` (0 = standing still, 1 = full stride).
static func amount(speed: float) -> float:
	return smoothstep(IDLE_SPEED, 0.55, speed)


## 0 = walking, 1 = running.
static func run_blend(speed: float) -> float:
	return smoothstep(RUN_FROM, RUN_TO, speed)


## Share of the cycle a foot spends on the ground. Walking > 0.5 (always one
## foot down), running < 0.5 (a flight phase with both feet up).
static func duty(run: float) -> float:
	return lerpf(0.62, 0.38, run)


## Distance a planted foot travels under the body during one stance (m, for a
## plumber of height scale 1). Longer strides at higher speed, capped by reach.
static func stance_length(speed: float, height_scale: float) -> float:
	return clampf(0.3 + 0.25 * speed, 0.3, 0.62) * height_scale


## Cycles per second so a planted foot moves backward at exactly `speed`
## (no foot sliding): stance takes duty/f seconds and covers stance_length.
static func cadence(speed: float, height_scale: float) -> float:
	var s: float = stance_length(speed, height_scale)
	return speed * duty(run_blend(speed)) / maxf(s, 0.01)


## Swing foot lift (m).
static func lift_height(run: float, height_scale: float) -> float:
	return lerpf(0.08, 0.15, run) * height_scale


## Where one foot is in its cycle. phase in radians (one cycle = TAU).
## Returns Vector2(u, lift): u = +1 front ... -1 back along the walking
## direction (scaled by half the stance length later); lift 0..1.
## Stance: u goes linearly 1 -> -1 at lift 0. Swing: u eases -1 -> 1 with an arc.
static func foot_cycle(phase: float, duty_factor: float) -> Vector2:
	var t: float = fposmod(phase, TAU) / TAU
	var d: float = clampf(duty_factor, 0.1, 0.9)
	if t < d:
		return Vector2(1.0 - 2.0 * (t / d), 0.0)
	var s: float = (t - d) / (1.0 - d)
	var e: float = s * s * (3.0 - 2.0 * s)
	return Vector2(-1.0 + 2.0 * e, sin(PI * s))


static func in_stance(phase: float, duty_factor: float) -> bool:
	return fposmod(phase, TAU) / TAU < clampf(duty_factor, 0.1, 0.9)


## Two-bone leg IK in the leg's side view. Foot target relative to the hip
## joint: `fwd` metres forward, `down` metres below. l1 = thigh, l2 = knee to sole.
## Returns Vector2(hip_flex, knee): hip_flex > 0 swings the thigh forward,
## knee <= 0 bends the shin backward (the plumber's joint conventions).
## Out-of-reach targets give a straight leg pointing at the target.
static func leg_ik(fwd: float, down: float, l1: float, l2: float) -> Vector2:
	var reach: float = l1 + l2
	var dist: float = sqrt(fwd * fwd + down * down)
	var l: float = clampf(dist, absf(l1 - l2) + 0.02 * reach, reach * 0.999)
	var line: float = atan2(fwd, down)
	var cos_a: float = (l1 * l1 + l * l - l2 * l2) / (2.0 * l1 * l)
	var cos_k: float = (l1 * l1 + l2 * l2 - l * l) / (2.0 * l1 * l2)
	var a: float = acos(clampf(cos_a, -1.0, 1.0))
	var interior: float = acos(clampf(cos_k, -1.0, 1.0))
	return Vector2(line + a, -(PI - interior))


## Forward kinematics matching leg_ik (for tests): foot (fwd, down) from the hip.
static func leg_fk(hip_flex: float, knee: float, l1: float, l2: float) -> Vector2:
	var knee_pos: Vector2 = Vector2(sin(hip_flex), cos(hip_flex)) * l1
	var shin: float = hip_flex + knee
	return knee_pos + Vector2(sin(shin), cos(shin)) * l2


## How high the hip may ride so a stance foot `x` metres ahead/behind still
## reaches the floor with a slightly bent knee.
static func hip_height_for(x: float, l1: float, l2: float) -> float:
	var reach: float = (l1 + l2) * 0.96
	return sqrt(maxf(reach * reach - x * x, 0.04))
