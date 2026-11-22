class_name GravityHUD
extends Control
## Round gravity indicator: an arrow showing which way gravity pulls at
## `probe` (normally the local player), as seen from the current camera.
## During a shift warning it flashes and shows the countdown and the
## direction gravity is ABOUT to point, so shifts are always telegraphed.

var probe: Vector3 = Vector3.ZERO
var radius: float = 70.0
var boots_charge: float = -1.0     ## 0..1 to draw the boot charge ring, <0 to hide.
var _flash: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0 + 20.0, radius * 2.0 + 20.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_flash += delta
	queue_redraw()


func _project(dir: Vector3) -> Vector3:
	## Returns (screen x, screen y, depth) of a world direction in camera space.
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return Vector3(dir.x, -dir.y, dir.z)
	var local: Vector3 = cam.global_basis.inverse() * dir
	return Vector3(local.x, -local.y, -local.z)


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var warn: bool = GravityManager.phase == GravityManager.Phase.WARNING
	var bg: Color = Color(0.05, 0.06, 0.15, 0.75)
	if warn and fmod(_flash, 0.5) < 0.25:
		bg = Color(0.6, 0.12, 0.1, 0.85)
	draw_circle(c, radius, bg)
	draw_arc(c, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.8), 4.0, true)
	if boots_charge >= 0.0:
		draw_arc(c, radius + 8.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(boots_charge, 0.0, 1.0), 48, UITheme.C_TEAL, 7.0, true)
	var g: Vector3 = GravityManager.get_gravity_at(probe)
	if g.length_squared() < 0.25:
		# Zero-G: draw a little floating "0".
		draw_string(ThemeDB.fallback_font, c + Vector2(-14, 14), "0g", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, UITheme.C_TEAL)
	else:
		_draw_arrow(c, g.normalized(), UITheme.C_ACCENT, 1.0)
	if warn:
		_draw_arrow(c, GravityManager.pending_dir, Color(1, 0.35, 0.3), 0.75)
		var txt: String = str(ceili(GravityManager.warning_left))
		draw_string(ThemeDB.fallback_font, c + Vector2(-radius, -radius - 12), "GRAVITY " + txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.4, 0.3))


func _draw_arrow(c: Vector2, dir: Vector3, col: Color, scale_k: float) -> void:
	var p: Vector3 = _project(dir)
	var flat: Vector2 = Vector2(p.x, p.y)
	var length: float = radius * 0.8 * scale_k
	if flat.length() < 0.2:
		# Pointing straight into / out of the screen: draw a dot or a cross.
		if p.z > 0.0:
			draw_circle(c, 14.0 * scale_k, col)
		else:
			draw_line(c + Vector2(-14, -14), c + Vector2(14, 14), col, 6.0)
			draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), col, 6.0)
		return
	var d: Vector2 = flat.normalized()
	var tip: Vector2 = c + d * length * flat.length()
	var tail: Vector2 = c - d * length * 0.4
	draw_line(tail, tip, col, 10.0 * scale_k, true)
	var side: Vector2 = Vector2(-d.y, d.x)
	var head: PackedVector2Array = PackedVector2Array([tip + d * 12.0, tip - d * 16.0 + side * 16.0, tip - d * 16.0 - side * 16.0])
	draw_colored_polygon(head, col)
