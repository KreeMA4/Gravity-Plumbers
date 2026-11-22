class_name PipePort
extends LevelObject
## The gap where a loose PipeSegment belongs. Shows a see-through ghost of
## the missing pipe. When the matching piece is within Tuning.PIPE_SNAP_RADIUS
## and its axis is within Tuning.PIPE_SNAP_ANGLE of the gap's axis, it snaps in.

var piece_id: String = ""
var axis: Vector3 = Vector3.UP
var length: float = 1.2
var _ghost: MeshInstance3D
var _piece: PipeSegment = null


func _init() -> void:
	super._init()
	add_to_group("pipe_ports")


func _ready() -> void:
	_ghost = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.2
	cm.height = length
	_ghost.mesh = cm
	_ghost.material_override = Mats.glow(Color(0.3, 1.0, 1.0, 0.25))
	_ghost.basis = PipeBuilder.basis_along(axis)
	add_child(_ghost)


func _find_piece() -> PipeSegment:
	if _piece != null and is_instance_valid(_piece):
		return _piece
	for n: Node in get_tree().get_nodes_in_group("pipe_pieces"):
		var ps: PipeSegment = n as PipeSegment
		if ps != null and ps.piece_id == piece_id:
			_piece = ps
			return ps
	return null


func _physics_process(_dt: float) -> void:
	if done or not active:
		return
	_ghost.visible = true
	if not is_host():
		return
	var ps: PipeSegment = _find_piece()
	if ps == null or ps.is_locked:
		return
	var d: float = ps.global_position.distance_to(global_position)
	if d > Tuning.PIPE_SNAP_RADIUS:
		return
	var piece_axis: Vector3 = ps.global_basis.y.normalized()
	var ang: float = piece_axis.angle_to(axis.normalized())
	ang = minf(ang, PI - ang)   # a pipe fits either way round
	if ang > Tuning.PIPE_SNAP_ANGLE:
		return
	ps.lock_into(Transform3D(PipeBuilder.basis_along(axis), global_position))
	mark_done()


func _on_done() -> void:
	if _ghost != null:
		_ghost.visible = false
	AudioManager.play_at("pipe_snap", global_position, 2.0)
	FX.stars(get_parent(), global_position)
	# Clients: lock the piece locally too.
	var ps: PipeSegment = _find_piece()
	if ps != null and not ps.is_locked:
		ps.lock_into(Transform3D(PipeBuilder.basis_along(axis), global_position))
