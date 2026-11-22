class_name LimbController
extends RefCounted
## A "muscle" for one joint: a PD controller that turns the child body
## toward a target rotation relative to its parent (or a world rotation).
##
##   angular accel = Kp * rotation_error - Kd * relative_angular_velocity
##
## We apply it as a change of angular velocity (mass-independent, so light
## and heavy limbs behave the same and nothing explodes), clamp it, and push
## a little of the opposite rotation into the parent so it isn't pure magic.

var child: RigidBody3D
var parent: RigidBody3D
var target: Quaternion = Quaternion.IDENTITY      ## Rotation relative to the parent's rest.
var target_world: Quaternion = Quaternion.IDENTITY
var use_world: bool = false                       ## true = aim at target_world (grabbing arms)
var strength: float = 1.0                         ## Per-joint multiplier (necks are weaker).
var reaction: float = 0.35                        ## Fraction of the push given back to the parent.


func _init(child_body: RigidBody3D, parent_body: RigidBody3D, joint_strength: float = 1.0) -> void:
	child = child_body
	parent = parent_body
	strength = joint_strength


## Rotation error (axis * angle, world space) from current to goal.
static func rotation_error(current: Quaternion, goal: Quaternion) -> Vector3:
	var q: Quaternion = goal * current.inverse()
	if q.w < 0.0:
		q = -q
	var v: Vector3 = Vector3(q.x, q.y, q.z)
	var s: float = v.length()
	if s < 0.00001:
		return Vector3.ZERO
	var angle: float = 2.0 * atan2(s, q.w)
	return v / s * angle


func update(dt: float, stiffness: float) -> void:
	if not is_instance_valid(child) or not is_instance_valid(parent):
		return
	var qc: Quaternion = child.global_basis.get_rotation_quaternion()
	var goal: Quaternion
	if use_world:
		goal = target_world
	else:
		goal = parent.global_basis.get_rotation_quaternion() * target
	var err: Vector3 = rotation_error(qc, goal)
	var rel_w: Vector3 = child.angular_velocity - parent.angular_velocity
	var k: float = stiffness * strength
	var acc: Vector3 = err * (Tuning.JOINT_KP * k) - rel_w * (Tuning.JOINT_KD * sqrt(maxf(k, 0.0)))
	acc = acc.limit_length(Tuning.JOINT_MAX_ANG_ACCEL)
	var dw: Vector3 = acc * dt
	if not dw.is_finite():
		return
	child.angular_velocity += dw
	var ratio: float = reaction * child.mass / maxf(0.1, parent.mass)
	parent.angular_velocity -= dw * ratio
