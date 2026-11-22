class_name Clog
extends LevelObject
## A big wobbly clog of sludge stuck in a pipe junction. Stab it with the
## Plunger (tap Use) until it POPS, launching goo blobs everywhere.
## Unfinished clogs slowly raise the sludge meter.

var hits_needed: int = 6
var hits: int = 0
var radius: float = 0.5
var goo_pool: GooPool = null
var _blob: MeshInstance3D
var _wobble: float = 0.0


func _init() -> void:
	super._init()
	add_to_group("clogs")


func _ready() -> void:
	hits_needed = Tuning.CLOG_HITS if hits_needed <= 0 else hits_needed
	_blob = MeshInstance3D.new()
	var s: SphereMesh = SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 16
	s.rings = 8
	_blob.mesh = s
	_blob.material_override = Mats.goo()
	add_child(_blob)
	# A solid core so it's something you can bump into.
	var sb: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: SphereShape3D = SphereShape3D.new()
	sh.radius = radius * 0.8
	cs.shape = sh
	sb.add_child(cs)
	add_child(sb)
	_blob.visible = active


func interact_distance(from: Vector3) -> float:
	if not active or done:
		return 999.0
	return maxf(0.0, global_position.distance_to(from) - radius)


func is_open() -> bool:
	return active and not done


func plunge(_p: Plumber) -> void:
	if not is_host() or not is_open():
		return
	hits += 1
	_wobble = 1.0
	AudioManager.play_at("sludge_glug", global_position, 0.0, 0.8 + float(hits) * 0.08)
	if hits >= hits_needed:
		if goo_pool != null:
			goo_pool.burst(global_position, Vector3.UP, 10, 6.0)
		mark_done()


func _on_activated() -> void:
	if _blob != null:
		_blob.visible = true


func _on_done() -> void:
	AudioManager.play_at("sludge_splat", global_position, 3.0)
	FX.splat(get_parent(), global_position, Vector3.UP)
	FX.stars(get_parent(), global_position)
	for c: Node in get_children():
		if c is StaticBody3D:
			c.queue_free()
	if _blob != null:
		_blob.visible = false


func _physics_process(delta: float) -> void:
	_animate(delta)


## Wobble animation (runs on physics ticks so interpolation keeps it smooth).
func _animate(delta: float) -> void:
	if _blob == null or done:
		return
	_wobble = maxf(0.0, _wobble - delta * 2.5)
	var t: float = Time.get_ticks_msec() * 0.001
	var w: float = sin(t * 3.0) * 0.04 + sin(t * 25.0) * 0.2 * _wobble
	var shrink: float = 1.0 - float(hits) / float(maxi(1, hits_needed)) * 0.4
	_blob.scale = Vector3(1.0 + w, 1.0 - w, 1.0 + w) * shrink


func get_net_state() -> Array:
	return [active, done, hits]


func apply_net_state(s: Array) -> void:
	super.apply_net_state(s)
	if s.size() > 2:
		var h: int = clampi(int(s[2]), 0, 99)
		if h > hits:
			_wobble = 1.0
		hits = h
