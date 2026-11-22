class_name Tank
extends LevelObject
## A tank that must be filled with goo: blobs (and goo canisters, worth
## several blobs) that fall into its opening are counted. Usually you need
## to shift gravity so the goo falls in!

var size: Vector3 = Vector3(1.6, 1.6, 1.6)
var up_dir: Vector3 = Vector3.UP      ## the open side
var need: int = 12
var amount: int = 0
var goo_pool: GooPool = null

var _fill: MeshInstance3D
var _label: Label3D
var _area: Area3D


func _init() -> void:
	super._init()
	add_to_group("tanks")


func _ready() -> void:
	var b: Basis = PipeBuilder.basis_along(up_dir)
	var root: Node3D = Node3D.new()
	root.basis = b
	add_child(root)
	# Glass walls (4 sides + bottom) as static colliders.
	var h: Vector3 = size * 0.5
	var t: float = 0.08
	var walls: Array = [
		[Vector3(0, -h.y, 0), Vector3(size.x, t, size.z)],
		[Vector3(-h.x, 0, 0), Vector3(t, size.y, size.z)],
		[Vector3(h.x, 0, 0), Vector3(t, size.y, size.z)],
		[Vector3(0, 0, -h.z), Vector3(size.x, size.y, t)],
		[Vector3(0, 0, h.z), Vector3(size.x, size.y, t)],
	]
	for w: Variant in walls:
		var arr: Array = w as Array
		var sb: StaticBody3D = Geo.static_box(root, arr[0] as Vector3, arr[1] as Vector3, Color(0.6, 0.9, 1.0))
		for c: Node in sb.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).material_override = Mats.glass()
	# Rim in the accent colour so it reads as "put stuff here".
	var rim: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(size.x + 0.2, 0.1, size.z + 0.2)
	rim.mesh = bm
	rim.material_override = Mats.toon_glow(UITheme.C_ACCENT, 0.3, Quality.outlines_on_props)
	rim.position = Vector3(0, h.y, 0)
	root.add_child(rim)
	_fill = MeshInstance3D.new()
	var fm: BoxMesh = BoxMesh.new()
	fm.size = Vector3(size.x - 0.15, 1.0, size.z - 0.15)
	_fill.mesh = fm
	_fill.material_override = Mats.goo()
	root.add_child(_fill)
	_label = Label3D.new()
	_label.font_size = 64
	_label.outline_size = 12
	_label.pixel_size = 0.005
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, h.y + 0.6, 0)
	root.add_child(_label)
	_area = Area3D.new()
	_area.collision_layer = Layers.TRIGGERS
	_area.collision_mask = Layers.GOO | Layers.PROPS
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size * 0.9
	cs.shape = bs
	_area.add_child(cs)
	root.add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	_refresh()


func _on_body_entered(body: Node3D) -> void:
	if not is_host() or not active or done:
		return
	var worth: int = 0
	if body.is_in_group("goo"):
		worth = 1
		if goo_pool != null:
			goo_pool.release(body as RigidBody3D)
	elif body.is_in_group("goo_canister"):
		worth = int(body.get_meta("goo_worth", 4))
		body.call_deferred("queue_free")
	if worth <= 0:
		return
	amount = mini(need, amount + worth)
	AudioManager.play_at("sludge_glug", global_position, -2.0)
	_refresh()
	if amount >= need:
		mark_done()


func _refresh() -> void:
	if _fill == null:
		return
	var f: float = float(amount) / float(maxi(1, need))
	_fill.visible = f > 0.0
	_fill.scale = Vector3(1, maxf(0.01, f * (size.y - 0.15)), 1)
	_fill.position = Vector3(0, -size.y * 0.5 + 0.08 + f * (size.y - 0.15) * 0.5, 0)
	_label.text = "%d / %d" % [amount, need] if not done else "FULL!"
	_label.modulate = UITheme.C_GOOD if done else Color(1, 1, 1)
	_label.visible = active


func _on_activated() -> void:
	_refresh()


func _on_done() -> void:
	FX.confetti(get_parent(), global_position + up_dir * size.y * 0.6)
	_refresh()


func get_net_state() -> Array:
	return [active, done, amount]


func apply_net_state(s: Array) -> void:
	super.apply_net_state(s)
	if s.size() > 2:
		amount = clampi(int(s[2]), 0, need)
	_refresh()
