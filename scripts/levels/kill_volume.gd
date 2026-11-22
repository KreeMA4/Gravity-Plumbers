class_name KillVolume
extends Area3D
## Fall in here and you get flushed (plumbers) or reset (props, goo).

var half: Vector3 = Vector3(10, 1, 10)


func _ready() -> void:
	collision_layer = Layers.TRIGGERS
	collision_mask = Layers.PLUMBERS | Layers.PROPS | Layers.GOO
	var cs: CollisionShape3D = CollisionShape3D.new()
	var b: BoxShape3D = BoxShape3D.new()
	b.size = half * 2.0
	cs.shape = b
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	var p: Variant = body.get_meta("plumber", null)
	if p is Plumber:
		(p as Plumber).flush.call_deferred()
		return
	for c: Node in body.get_children():
		if c is GravityBody:
			if body.is_in_group("goo"):
				var pool: Node = body.get_parent()
				if pool is GooPool:
					(pool as GooPool).release.call_deferred(body as RigidBody3D)
			else:
				(c as GravityBody).reset_to_home.call_deferred()
			return
