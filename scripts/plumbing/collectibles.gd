class_name GoldenDuck
extends Area3D
## A hidden golden rubber duck. Touch it to collect it (saved forever);
## collected ducks unlock cosmetics. Already-found ducks show as ghosts.

signal collected(duck_id: String)

var duck_id: String = ""
var _body: Node3D
var _t: float = 0.0
var _taken: bool = false


func _ready() -> void:
	collision_layer = Layers.TRIGGERS
	collision_mask = Layers.PLUMBERS
	var cs: CollisionShape3D = CollisionShape3D.new()
	var s: SphereShape3D = SphereShape3D.new()
	s.radius = 0.5
	cs.shape = s
	add_child(cs)
	_body = Node3D.new()
	add_child(_body)
	var found: bool = SaveData.has_duck(duck_id)
	var col: Color = Color(1.0, 0.85, 0.15) if not found else Color(1.0, 1.0, 1.0, 0.35)
	var mat: Material = Mats.toon_glow(col, 0.35, true) if not found else Mats.glow(col)
	var b: MeshInstance3D = MeshInstance3D.new()
	var bm: SphereMesh = SphereMesh.new()
	bm.radius = 0.2
	bm.height = 0.32
	b.mesh = bm
	b.material_override = mat
	_body.add_child(b)
	var h: MeshInstance3D = MeshInstance3D.new()
	var hm: SphereMesh = SphereMesh.new()
	hm.radius = 0.12
	hm.height = 0.24
	h.mesh = hm
	h.material_override = mat
	h.position = Vector3(0, 0.2, -0.1)
	_body.add_child(h)
	var beak: MeshInstance3D = MeshInstance3D.new()
	var km: BoxMesh = BoxMesh.new()
	km.size = Vector3(0.08, 0.04, 0.1)
	beak.mesh = km
	beak.material_override = Mats.toon(Color(1.0, 0.5, 0.1))
	beak.position = Vector3(0, 0.18, -0.24)
	_body.add_child(beak)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _taken or not multiplayer.is_server():
		return
	if Plumber.of(body) is Plumber:
		_taken = true
		collected.emit(duck_id)


## Called on every peer when the host says the duck was collected.
func show_collected() -> void:
	_taken = true
	AudioManager.play_at("work_done", global_position, 0.0, 1.5)
	FX.confetti(get_parent(), global_position)
	queue_free()


func _physics_process(delta: float) -> void:
	_t += delta
	if _body != null:
		_body.rotation = Vector3(0, _t * 1.5, 0)
		_body.position = Vector3(0, sin(_t * 2.0) * 0.08, 0)
