class_name HubStation
extends LevelObject
## Hub furniture you can Use: the level-select CONSOLE (host picks the next
## job) and the MIRROR (change your outfit).

var kind: String = "console"
var normal: Vector3 = Vector3.FORWARD
var runner: LevelRunner = null


func _init() -> void:
	super._init()
	add_to_group("interactables")


func _ready() -> void:
	var b: Basis = LevelSpawner.frame(Vector3.UP, atan2(normal.x, normal.z))
	var root: Node3D = Node3D.new()
	root.basis = b
	add_child(root)
	var lbl: Label3D = Label3D.new()
	lbl.font_size = 56
	lbl.outline_size = 12
	lbl.pixel_size = 0.005
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 2.1, 0)
	add_child(lbl)
	if kind == "mirror":
		lbl.text = "MIRROR\n(customise)"
		var frame_m: MeshInstance3D = MeshInstance3D.new()
		var t: TorusMesh = TorusMesh.new()
		t.inner_radius = 0.6
		t.outer_radius = 0.75
		frame_m.mesh = t
		frame_m.material_override = Mats.toon(UITheme.C_ACCENT, true)
		frame_m.position = Vector3(0, 1.2, 0)
		frame_m.rotation = Vector3(PI * 0.5, 0, 0)
		root.add_child(frame_m)
		var glass: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.62
		cm.bottom_radius = 0.62
		cm.height = 0.02
		glass.mesh = cm
		glass.material_override = Mats.toon_glow(Color(0.7, 0.9, 1.0), 0.5, false)
		glass.position = Vector3(0, 1.2, 0)
		glass.rotation = Vector3(PI * 0.5, 0, 0)
		root.add_child(glass)
	else:
		lbl.text = "JOB CONSOLE\n(host picks level)"
		Geo.static_box(root, Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 0.7), Color(0.3, 0.32, 0.42))
		var screen: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(1.2, 0.7, 0.05)
		screen.mesh = bm
		screen.material_override = Mats.toon_glow(UITheme.C_TEAL, 0.8, false)
		screen.position = Vector3(0, 1.25, 0.1)
		screen.rotation = Vector3(-0.3, 0, 0)
		root.add_child(screen)


func get_use_label() -> String:
	return "LOOK" if kind == "mirror" else "JOBS"


func interact(p: Plumber) -> void:
	if runner != null:
		runner.on_station(kind, p)
