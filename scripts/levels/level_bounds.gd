class_name LevelBounds
extends RefCounted
## The playable volume of the current level: a big sphere. Anything that
## drifts outside is "lost in space" (props reset, plumbers get flushed).
## LevelRunner sets these when a level loads.

static var center: Vector3 = Vector3.ZERO
static var radius: float = 80.0
static var kill_y_planes: Array = []   ## Optional extra kill volumes (Array of AABB).


static func radius_sq() -> float:
	return radius * radius


static func set_bounds(c: Vector3, r: float) -> void:
	center = c
	radius = maxf(5.0, r)
