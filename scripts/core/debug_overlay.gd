extends CanvasLayer
## Debug overlay: FPS, physics bodies, ping, gravity, network traffic, build id.
## Toggle with a three-finger tap, F3, or the "Debug" button in Settings.
## Created once by scenes/main.gd and kept for the whole session.

var _label: Label
var _touches: Dictionary = {}
var _accum: float = 0.0
var _full: bool = false   ## true = full overlay, false = nothing (or just FPS)


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_label.visible = false


func toggle() -> void:
	_full = not _full
	_accum = 1.0


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		toggle()
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_touches[t.index] = true
			if _touches.size() >= 3:
				_touches.clear()
				toggle()
		else:
			_touches.erase(t.index)


func _process(delta: float) -> void:
	# Show a tiny FPS counter even when the overlay is hidden, if enabled in Settings.
	var show_fps: bool = SaveData.setting_b("show_fps")
	_label.visible = _full or show_fps
	if not _label.visible:
		return
	_accum += delta
	if _accum < 0.25:
		return
	_accum = 0.0
	if not _full:
		_label.text = "%d fps" % Engine.get_frames_per_second()
		return
	var g: Vector3 = GravityManager.get_gravity_at(GravityManager.debug_probe)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("FPS %d   physics %.1f ms   process %.1f ms" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	lines.append("Bodies awake %d   draw calls %d   prims %d" % [
		int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
	lines.append("Gravity (%.1f, %.1f, %.1f) |%.1f|" % [g.x, g.y, g.z, g.length()])
	lines.append("Net %s  peers %d  ping %d ms  up %.1f KB/s  down %.1f KB/s" % [
		NetManager.mode_name(), NetManager.peer_count(), NetManager.get_ping_ms(),
		NetManager.bytes_up_per_sec / 1024.0, NetManager.bytes_down_per_sec / 1024.0])
	lines.append("Quality %s  scale %.2f  %s" % [Quality.preset_name, Quality.render_scale,
		RenderingServer.get_video_adapter_name()])
	lines.append("Build %s  %s  %s  Godot %s" % [Tuning.GAME_VERSION, Tuning.MILESTONE_ID, BuildInfo.LABEL,
		Engine.get_version_info().get("string", "?")])
	_label.text = "\n".join(lines)
