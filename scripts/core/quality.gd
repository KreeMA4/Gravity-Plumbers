extends Node
## Quality (autoload)
## -----------------------------------------------------------------------------
## Graphics presets (Low / Medium / High) and the "Auto" benchmark.
## Other scripts ask Quality before creating expensive things, e.g.
## `if Quality.outlines_on_props: ...`.
## We never lower quality silently: on sustained low FPS we emit
## `low_fps_detected` and the HUD asks the player.

signal quality_changed
signal low_fps_detected

const PRESETS: Dictionary = {
	"low": {"render_scale": 0.7, "shadows": false, "blob_shadows": false, "simple_ragdoll": true,
		"outlines_on_props": false, "outlines_on_players": true, "particles": 0.4, "msaa": false},
	"medium": {"render_scale": 0.85, "shadows": false, "blob_shadows": true, "simple_ragdoll": false,
		"outlines_on_props": false, "outlines_on_players": true, "particles": 0.7, "msaa": false},
	"high": {"render_scale": 1.0, "shadows": true, "blob_shadows": true, "simple_ragdoll": false,
		"outlines_on_props": true, "outlines_on_players": true, "particles": 1.0, "msaa": false},
}

var preset_name: String = "medium"
var render_scale: float = 0.85
var shadows: bool = false
var blob_shadows: bool = true
var simple_ragdoll: bool = false
var outlines_on_props: bool = false
var outlines_on_players: bool = true
var particle_scale: float = 0.7

var _bench_active: bool = false
var _bench_time: float = 0.0
var _bench_frames: int = 0
var _low_fps_time: float = 0.0
var _watchdog_enabled: bool = false
var _prompted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var q: String = str(SaveData.get_setting("quality"))
	if q == "auto":
		q = "medium"   # until the benchmark has run once
	apply_preset(q)
	SaveData.settings_changed.connect(_on_settings_changed)


func apply_preset(new_name: String) -> void:
	if not PRESETS.has(new_name):
		new_name = "medium"
	preset_name = new_name
	var p: Dictionary = PRESETS[new_name]
	render_scale = float(p["render_scale"])
	shadows = bool(p["shadows"])
	blob_shadows = bool(p["blob_shadows"])
	simple_ragdoll = bool(p["simple_ragdoll"])
	outlines_on_props = bool(p["outlines_on_props"])
	outlines_on_players = bool(p["outlines_on_players"])
	particle_scale = float(p["particles"])
	# Player overrides from Settings.
	var rs: float = SaveData.setting_f("render_scale")
	if rs > 0.0:
		render_scale = clampf(rs, 0.5, 1.0)
	if not SaveData.setting_b("shadows"):
		shadows = false
	_apply_viewport()
	quality_changed.emit()


func _apply_viewport() -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = render_scale


func _on_settings_changed() -> void:
	var q: String = str(SaveData.get_setting("quality"))
	if q == "auto":
		q = preset_name
	if q != preset_name or not is_equal_approx(SaveData.setting_f("render_scale"), render_scale):
		apply_preset(q)


## Start the short first-launch benchmark (called by the main menu, whose
## 3D background is a representative scene).
func maybe_start_auto_benchmark() -> void:
	if str(SaveData.get_setting("quality")) != "auto":
		return
	if SaveData.setting_b("quality_auto_done"):
		return
	_bench_active = true
	_bench_time = -1.0   # skip the first second (shader compile hitches)
	_bench_frames = 0


## Levels turn on the low-FPS watchdog.
func set_watchdog(enabled: bool) -> void:
	_watchdog_enabled = enabled
	_low_fps_time = 0.0


func _process(delta: float) -> void:
	if _bench_active:
		_bench_time += delta
		if _bench_time > 0.0:
			_bench_frames += 1
		if _bench_time >= 4.0:
			_bench_active = false
			var fps: float = float(_bench_frames) / _bench_time
			var pick: String = "high" if fps >= 55.0 else ("medium" if fps >= 38.0 else "low")
			GameLog.info("Auto quality benchmark: %.1f fps -> %s" % [fps, pick])
			SaveData.set_setting("quality_auto_done", true)
			apply_preset(pick)
			SaveData.save()
	if _watchdog_enabled and not _prompted and preset_name != "low":
		if Engine.get_frames_per_second() < Tuning.LOW_FPS_THRESHOLD:
			_low_fps_time += delta
			if _low_fps_time > Tuning.LOW_FPS_SECONDS:
				_prompted = true
				low_fps_detected.emit()
		else:
			_low_fps_time = maxf(0.0, _low_fps_time - delta)


## The next lower preset name ("low" stays "low").
func lower_preset_name() -> String:
	if preset_name == "high":
		return "medium"
	return "low"
