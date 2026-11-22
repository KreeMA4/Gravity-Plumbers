class_name GreatClog
extends Clog
## THE GREAT CLOG (Reactor finale boss): a huge wobbling ball of sludge in the
## reactor core. It can't be plunged away - it has to be FED goo until it
## bursts. Lure goo blobs into it with gravity shifts, or throw canisters at it
## (worth several blobs). Every so often it BURPS goo back out (and raises the
## sludge meter), so keep the pressure on!

var hp_max: int = 30
var burp_period: float = 22.0
var runner_sludge: Callable = Callable()

var _hp: int = 30
var _area: Area3D
var _label: Label3D
var _burp_t: float = 15.0


func _ready() -> void:
	radius = maxf(radius, 1.6)
	hits_needed = 9999
	super._ready()
	_hp = hp_max
	_area = Area3D.new()
	_area.collision_layer = Layers.TRIGGERS
	_area.collision_mask = Layers.GOO | Layers.PROPS
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: SphereShape3D = SphereShape3D.new()
	sh.radius = radius + 0.25
	cs.shape = sh
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	_label = Label3D.new()
	_label.font_size = 80
	_label.outline_size = 16
	_label.pixel_size = 0.006
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0, radius + 0.9, 0)
	add_child(_label)
	_refresh_label()


func _refresh_label() -> void:
	if _label != null:
		_label.text = "THE GREAT CLOG\n%d / %d goo to burst" % [hp_max - _hp, hp_max]
		_label.visible = active and not done


func _on_body_entered(body: Node3D) -> void:
	if not is_host() or not is_open():
		return
	var dmg: int = 0
	if body.is_in_group("goo"):
		dmg = 1
		if goo_pool != null:
			goo_pool.release(body as RigidBody3D)
	elif body.is_in_group("goo_canister"):
		dmg = int(body.get_meta("goo_worth", 4))
		body.call_deferred("queue_free")
	if dmg > 0:
		_feed(dmg)


func plunge(_p: Plumber) -> void:
	# Plunging only annoys it (one point of "damage" and a big wobble).
	if not is_host() or not is_open():
		return
	_wobble = 1.0
	_feed(1)


func _feed(amount: int) -> void:
	_hp = maxi(0, _hp - amount)
	hits = hp_max - _hp
	_wobble = 1.0
	AudioManager.play_at("sludge_glug", global_position, 2.0, 0.6 + 0.4 * float(hits) / float(hp_max))
	_refresh_label()
	if _hp <= 0:
		if goo_pool != null:
			goo_pool.burst(global_position, Vector3.UP, 20, 9.0)
		FX.confetti(get_parent(), global_position)
		mark_done()


func _physics_process(dt: float) -> void:
	_animate(dt)
	if not is_open() or not is_host():
		return
	_burp_t -= dt
	if _burp_t <= 0.0:
		_burp_t = burp_period * Tuning.diff("storm_interval")
		if goo_pool != null:
			goo_pool.burst(global_position, Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)), 6, 6.0)
		if runner_sludge.is_valid():
			runner_sludge.call(2.0)
		AudioManager.play_at("sludge_splat", global_position, 6.0, 0.5)
		_wobble = 1.0


func _on_activated() -> void:
	super._on_activated()
	_refresh_label()


func get_net_state() -> Array:
	return [active, done, hp_max - _hp]


func apply_net_state(s: Array) -> void:
	super.apply_net_state(s)
	if s.size() > 2:
		_hp = hp_max - clampi(int(s[2]), 0, hp_max)
		_refresh_label()
