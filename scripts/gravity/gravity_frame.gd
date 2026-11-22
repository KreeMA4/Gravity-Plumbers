class_name GravityFrame
extends RefCounted
## An orientation frame whose "up" smoothly follows a target up vector.
## Cameras use it so the world visibly rotates during a gravity shift instead
## of snapping. When up changes, the whole frame is rotated by the smallest
## rotation, so "forward" stays as close as possible to where it was.

var basis: Basis = Basis.IDENTITY


## Rotate the frame so its up moves toward target_up. `t` is 0..1 per call.
func follow(target_up: Vector3, t: float) -> void:
	if not target_up.is_finite() or target_up.length_squared() < 0.0001:
		return
	var cur_up: Vector3 = basis.y.normalized()
	var want: Vector3 = target_up.normalized()
	var q: Quaternion = GravityMath.quat_between(cur_up, want)
	var partial: Quaternion = Quaternion.IDENTITY.slerp(q, clampf(t, 0.0, 1.0))
	basis = (Basis(partial) * basis).orthonormalized()


## Snap instantly.
func snap(target_up: Vector3) -> void:
	follow(target_up, 1.0)


## Frame-rate independent smoothing factor for a time constant in seconds.
static func smooth_factor(delta: float, time_constant: float) -> float:
	if time_constant <= 0.0001:
		return 1.0
	return 1.0 - exp(-delta * 3.0 / time_constant)
