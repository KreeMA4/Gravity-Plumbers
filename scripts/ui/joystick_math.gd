class_name JoystickMath
extends RefCounted
## Pure maths for the on-screen movement joystick (no nodes, unit tested in
## tests/joystick_test.gd). All positions are in UI canvas pixels.

## Gap kept between the joystick and the screen edge / safe area, as a fraction of the radius.
const EDGE_MARGIN_K: float = 0.35
const EDGE_MARGIN_PX: float = 36.0
## Touches that start this far from the base (in radii) re-centre the base under the thumb.
const FLOAT_START_K: float = 1.6


## Where the joystick base sits: bottom-left (bottom-right when left-handed),
## inside the safe area (notches, rounded corners), never off-screen.
## pad = safe-area insets (left, top, right, bottom).
static func base_center(view: Vector2, pad: Vector4, radius: float, lefty: bool) -> Vector2:
	var m: float = radius * (1.0 + EDGE_MARGIN_K) + EDGE_MARGIN_PX
	var c: Vector2 = Vector2(pad.x + m, view.y - pad.w - m)
	if lefty:
		c.x = view.x - pad.z - m
	return clamp_center(c, view, radius)


## Keep a joystick of `radius` fully on screen.
static func clamp_center(c: Vector2, view: Vector2, radius: float) -> Vector2:
	var edge: float = radius + 8.0
	return Vector2(clampf(c.x, edge, maxf(edge, view.x - edge)), clampf(c.y, edge, maxf(edge, view.y - edge)))


## Analog stick value for a finger at `finger`: x = right, y = FORWARD (screen up),
## length 0..1. Inside the deadzone it is zero; outside it ramps smoothly from 0.
static func stick_vector(center: Vector2, finger: Vector2, radius: float, deadzone: float) -> Vector2:
	var v: Vector2 = (finger - center) / maxf(radius, 1.0)
	var l: float = v.length()
	var dz: float = clampf(deadzone, 0.0, 0.9)
	if l <= dz or l < 0.0001:
		return Vector2.ZERO
	var mag: float = clampf((l - dz) / (1.0 - dz), 0.0, 1.0)
	var out: Vector2 = v / l * mag
	return Vector2(out.x, -out.y)


## Where to draw the thumb: under the finger, but never outside the base ring.
static func knob_position(center: Vector2, finger: Vector2, radius: float) -> Vector2:
	return center + (finger - center).limit_length(radius)


## Can a touch at p start the joystick? Lower-left region (lower-right if left-handed);
## the right side stays free for camera look and buttons.
static func in_activation_zone(p: Vector2, view: Vector2, lefty: bool) -> bool:
	var in_x: bool = (p.x > view.x * 0.55) if lefty else (p.x < view.x * 0.45)
	return in_x and p.y > view.y * 0.22
