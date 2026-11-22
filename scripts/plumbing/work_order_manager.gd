class_name WorkOrderManager
extends RefCounted
## The work-order state machine (pure logic, unit tested).
## Orders start LOCKED until every order in their `after` list is DONE, then
## become ACTIVE. Level objects report "target done" (e.g. "leak_2 sealed");
## an ACTIVE order whose targets are all done becomes DONE.
## Targets finished early are remembered and count when the order opens.

signal order_activated(order: WorkOrder)
signal order_completed(order: WorkOrder)
signal all_completed

var orders: Array = []                 ## Array of WorkOrder
var finished_targets: Dictionary = {}  ## target id -> true
var _all_done_sent: bool = false


func load_orders(defs: Array) -> void:
	orders.clear()
	finished_targets.clear()
	_all_done_sent = false
	for d: Variant in defs:
		if d is Dictionary:
			orders.append(WorkOrder.from_dict(d as Dictionary))
	_refresh()


func get_order(order_id: String) -> WorkOrder:
	for o: Variant in orders:
		var w: WorkOrder = o as WorkOrder
		if w.id == order_id:
			return w
	return null


## Which order (if any) owns this target id.
func order_for_target(target_id: String) -> WorkOrder:
	for o: Variant in orders:
		var w: WorkOrder = o as WorkOrder
		if w.targets.has(target_id):
			return w
	return null


func is_target_active(target_id: String) -> bool:
	var w: WorkOrder = order_for_target(target_id)
	return w == null or w.status == WorkOrder.Status.ACTIVE


func target_done(target_id: String) -> void:
	finished_targets[target_id] = true
	_refresh()


func done_count() -> int:
	var n: int = 0
	for o: Variant in orders:
		if (o as WorkOrder).status == WorkOrder.Status.DONE:
			n += 1
	return n


func all_done() -> bool:
	return orders.size() > 0 and done_count() == orders.size()


func _refresh() -> void:
	var changed: bool = true
	while changed:
		changed = false
		for o: Variant in orders:
			var w: WorkOrder = o as WorkOrder
			if w.status == WorkOrder.Status.LOCKED and _prereqs_done(w):
				w.status = WorkOrder.Status.ACTIVE
				changed = true
				order_activated.emit(w)
			if w.status == WorkOrder.Status.ACTIVE:
				for t: String in w.targets:
					if finished_targets.has(t):
						w.done_targets[t] = true
				if w.is_complete():
					w.status = WorkOrder.Status.DONE
					changed = true
					order_completed.emit(w)
	if all_done() and not _all_done_sent:
		_all_done_sent = true
		all_completed.emit()


func _prereqs_done(w: WorkOrder) -> bool:
	for a: String in w.after:
		var p: WorkOrder = get_order(a)
		if p != null and p.status != WorkOrder.Status.DONE:
			return false
	return true


## Compact state for network clients: [[id, status, done_target_count], ...]
func get_state() -> Array:
	var out: Array = []
	for o: Variant in orders:
		var w: WorkOrder = o as WorkOrder
		out.append([w.id, int(w.status), w.done_targets.keys()])
	return out


func apply_state(state: Array) -> void:
	for item: Variant in state:
		if not (item is Array) or (item as Array).size() < 3:
			continue
		var arr: Array = item as Array
		var w: WorkOrder = get_order(str(arr[0]))
		if w == null:
			continue
		w.status = clampi(int(arr[1]), 0, 2) as WorkOrder.Status
		w.done_targets.clear()
		if arr[2] is Array:
			for t: Variant in arr[2]:
				w.done_targets[str(t)] = true
