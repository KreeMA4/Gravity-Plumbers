class_name GravityMath
extends RefCounted
## Pure gravity maths shared by GravityManager and the tests.

## The 6 axis directions global gravity can point along (index = network id).
const AXES: Array = [
	Vector3(0, -1, 0), Vector3(0, 1, 0),
	Vector3(1, 0, 0), Vector3(-1, 0, 0),
	Vector3(0, 0, 1), Vector3(0, 0, -1),
]


## Combine the global gravity with a list of GravityFieldData at point p.
## Rules: the global field counts as priority 0. The highest priority among
## fields containing p wins; equal priorities are averaged ("blend").
## PUSH fields are added on top afterwards.
static func resolve(fields: Array, global_g: Vector3, p: Vector3) -> Vector3:
	var best: int = 0
	var sum: Vector3 = global_g
	var count: int = 1
	var extra: Vector3 = Vector3.ZERO
	for item: Variant in fields:
		var f: GravityFieldData = item as GravityFieldData
		if f == null or not f.contains(p):
			continue
		if f.kind == GravityFieldData.Kind.PUSH:
			extra += f.accel_at(p)
			continue
		if f.priority > best:
			best = f.priority
			sum = f.accel_at(p)
			count = 1
		elif f.priority == best:
			sum += f.accel_at(p)
			count += 1
	return sum / float(count) + extra


## Strongest air drag of any field containing p (zero-G zones use this).
static func resolve_drag(fields: Array, p: Vector3) -> float:
	var d: float = 0.0
	for item: Variant in fields:
		var f: GravityFieldData = item as GravityFieldData
		if f != null and f.drag > d and f.contains(p):
			d = f.drag
	return d


## Rotate unit vector `from` toward `to` by fraction t (0..1) along the
## shortest arc. Works for 180-degree flips by picking a stable perpendicular axis.
static func rotate_dir(from: Vector3, to: Vector3, t: float) -> Vector3:
	var a: Vector3 = from.normalized()
	var b: Vector3 = to.normalized()
	var angle: float = a.angle_to(b)
	if angle < 0.0001:
		return b
	var axis: Vector3 = a.cross(b)
	if axis.length_squared() < 0.000001:
		axis = perpendicular(a)
	return a.rotated(axis.normalized(), angle * clampf(t, 0.0, 1.0))


## Any unit vector perpendicular to v (deterministic, so all peers agree).
static func perpendicular(v: Vector3) -> Vector3:
	var other: Vector3 = Vector3(1, 0, 0) if absf(v.x) < 0.9 else Vector3(0, 0, 1)
	return v.cross(other).normalized()


## The axis direction (from AXES) closest to `v`. Used by the G-Wrench.
static func nearest_axis_index(v: Vector3) -> int:
	var best_i: int = 0
	var best_dot: float = -2.0
	for i: int in AXES.size():
		var d: float = (AXES[i] as Vector3).dot(v)
		if d > best_dot:
			best_dot = d
			best_i = i
	return best_i


## Smooth 0..1 easing used for gravity transitions.
static func ease_shift(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## A rotation (Quaternion) that turns unit vector a onto unit vector b.
static func quat_between(a: Vector3, b: Vector3) -> Quaternion:
	var an: Vector3 = a.normalized()
	var bn: Vector3 = b.normalized()
	var d: float = an.dot(bn)
	if d > 0.99999:
		return Quaternion.IDENTITY
	if d < -0.99999:
		return Quaternion(perpendicular(an), PI)
	var axis: Vector3 = an.cross(bn).normalized()
	return Quaternion(axis, acos(clampf(d, -1.0, 1.0)))
