class_name GravityFieldData
extends RefCounted
## Pure data + maths for ONE gravity field (no nodes, so it is unit-testable).
## A GravityField node owns one of these and keeps its position up to date.
##
## Kinds:
##   BOX     - a box region with its own fixed "down" (e.g. a sideways corridor)
##   SPHERE  - pulls toward a centre point (walk around a planetoid)
##   ZERO_G  - no gravity inside, plus light air drag so you can still steer
##   PUSH    - a vent burst; ADDS to whatever gravity is already there

enum Kind { BOX, SPHERE, ZERO_G, PUSH }

var id: String = ""
var kind: Kind = Kind.BOX
var priority: int = 1          ## Highest priority containing a point wins; equal ones blend.
var enabled: bool = true
var direction: Vector3 = Vector3.DOWN   ## World-space "down" for BOX and PUSH.
var strength: float = 9.8      ## m/s^2
var center: Vector3 = Vector3.ZERO      ## World-space centre (all kinds).
var basis: Basis = Basis.IDENTITY       ## Box orientation.
var half_extents: Vector3 = Vector3(2, 2, 2)  ## Box half size (BOX, ZERO_G, PUSH).
var radius: float = 6.0        ## SPHERE: influence radius.
var surface_radius: float = 2.0 ## SPHERE: rock surface; full strength at/below this.
var falloff: bool = true       ## SPHERE: weaker gravity further from the surface.
var spherical_region: bool = false  ## ZERO_G/PUSH may use a sphere region of `radius` instead of a box.
var drag: float = 0.0          ## Extra air drag inside (used by ZERO_G).


## Is the world-space point inside this field's region?
func contains(p: Vector3) -> bool:
	if not enabled:
		return false
	if kind == Kind.SPHERE or spherical_region:
		return p.distance_squared_to(center) <= radius * radius
	var local: Vector3 = basis.inverse() * (p - center)
	return absf(local.x) <= half_extents.x and absf(local.y) <= half_extents.y and absf(local.z) <= half_extents.z


## Gravity acceleration this field gives at point p (assumes contains(p)).
func accel_at(p: Vector3) -> Vector3:
	match kind:
		Kind.BOX, Kind.PUSH:
			return direction.normalized() * strength
		Kind.ZERO_G:
			return Vector3.ZERO
		Kind.SPHERE:
			var to_center: Vector3 = center - p
			var dist: float = to_center.length()
			if dist < 0.001:
				return Vector3.ZERO
			var s: float = strength
			if falloff and dist > surface_radius:
				# Smoothly fades from full strength at the surface to 25% at the edge.
				var t: float = clampf((dist - surface_radius) / maxf(0.001, radius - surface_radius), 0.0, 1.0)
				s = strength * lerpf(1.0, 0.25, t)
			return to_center / dist * s
	return Vector3.ZERO


static func make_box(field_id: String, c: Vector3, half: Vector3, down: Vector3, prio: int = 1, g: float = 9.8) -> GravityFieldData:
	var f: GravityFieldData = GravityFieldData.new()
	f.id = field_id
	f.kind = Kind.BOX
	f.center = c
	f.half_extents = half
	f.direction = down.normalized()
	f.priority = prio
	f.strength = g
	return f


static func make_sphere(field_id: String, c: Vector3, surface_r: float, influence_r: float, prio: int = 2, g: float = 9.8) -> GravityFieldData:
	var f: GravityFieldData = GravityFieldData.new()
	f.id = field_id
	f.kind = Kind.SPHERE
	f.center = c
	f.surface_radius = surface_r
	f.radius = influence_r
	f.priority = prio
	f.strength = g
	return f


static func make_zero_g(field_id: String, c: Vector3, half: Vector3, prio: int = 3, air_drag: float = 0.6) -> GravityFieldData:
	var f: GravityFieldData = GravityFieldData.new()
	f.id = field_id
	f.kind = Kind.ZERO_G
	f.center = c
	f.half_extents = half
	f.priority = prio
	f.drag = air_drag
	return f


static func make_push(field_id: String, c: Vector3, half: Vector3, push_dir: Vector3, g: float) -> GravityFieldData:
	var f: GravityFieldData = GravityFieldData.new()
	f.id = field_id
	f.kind = Kind.PUSH
	f.center = c
	f.half_extents = half
	f.direction = push_dir.normalized()
	f.strength = g
	f.priority = 0
	f.enabled = false   # vents start off and are pulsed
	return f
