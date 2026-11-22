class_name GooCanister
extends RigidBody3D
## A sealed canister full of goo (worth several blobs when dropped in a tank).

var worth: int = 4
var net_id: int = 0


func _init() -> void:
	mass = 5.0
	collision_layer = Layers.PROPS
	collision_mask = Layers.MASK_SOLID
	add_to_group("grabbable")
	add_to_group("props")
	add_to_group("goo_canister")


func _ready() -> void:
	set_meta("goo_worth", worth)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.22
	cm.height = 0.55
	mi.mesh = cm
	mi.material_override = Mats.toon(Color(0.75, 0.78, 0.85), Quality.outlines_on_props)
	add_child(mi)
	var window: MeshInstance3D = MeshInstance3D.new()
	var wm: CylinderMesh = CylinderMesh.new()
	wm.top_radius = 0.23
	wm.bottom_radius = 0.23
	wm.height = 0.3
	window.mesh = wm
	window.material_override = Mats.goo()
	add_child(window)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CylinderShape3D = CylinderShape3D.new()
	sh.radius = 0.22
	sh.height = 0.55
	cs.shape = sh
	add_child(cs)
	add_child(GravityBody.new())
