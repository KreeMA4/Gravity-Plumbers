class_name LevelObject
extends Node3D
## Base for gameplay objects placed by levels (leaks, valves, clogs, tanks,
## pipe ports, switches...). Gives them an id, an active/done state, a
## `completed` signal the LevelRunner listens to, and tiny network state.
## Only the host changes gameplay state; clients receive it via apply_net_state().

signal completed(obj_id: String)

var obj_id: String = ""
var active: bool = true      ## dormant objects do nothing until their work order opens
var done: bool = false


func _init() -> void:
	add_to_group("level_objects")


func is_host() -> bool:
	return multiplayer.is_server()


func activate() -> void:
	active = true
	_on_activated()


func _on_activated() -> void:
	pass


func mark_done() -> void:
	if done:
		return
	done = true
	_on_done()
	completed.emit(obj_id)


func _on_done() -> void:
	pass


## Distance used by tools to decide what they're pointing at.
func interact_distance(from: Vector3) -> float:
	if not active or done:
		return 999.0
	return global_position.distance_to(from)


## Compact network state. Subclasses add their own values after these two.
func get_net_state() -> Array:
	return [active, done]


func apply_net_state(s: Array) -> void:
	if s.size() < 2:
		return
	var was_active: bool = active
	active = bool(s[0])
	if active and not was_active:
		_on_activated()
	if bool(s[1]) and not done:
		done = true
		_on_done()
