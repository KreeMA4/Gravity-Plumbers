extends Node3D
## Animated 3D background for the main menu: a space window with a slowly
## turning camera. (Milestones M2/M8 add the starfield and your plumber.)

var _cam: Camera3D
var _t: float = 0.0


func _ready() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.05, 0.14)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.8)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.6, 0.0)
	add_child(light)
	var frame: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 2.2
	torus.outer_radius = 2.6
	frame.mesh = torus
	frame.rotation = Vector3(PI * 0.5, 0, 0)
	frame.position = Vector3(2.5, 1.5, -4.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = UITheme.C_PIPE
	frame.material_override = mat
	add_child(frame)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.5, 4)
	add_child(_cam)
	_cam.current = true


func _process(delta: float) -> void:
	_t += delta
	_cam.rotation = Vector3(sin(_t * 0.2) * 0.04, sin(_t * 0.13) * 0.08, 0.0)
