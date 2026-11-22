extends TestCase
## Work-order state machine + sludge meter.


func _defs() -> Array:
	return [
		{"id": "a", "type": "leak", "targets": ["leak1", "leak2"]},
		{"id": "b", "type": "valve", "targets": ["valve1"], "after": ["a"]},
		{"id": "c", "type": "clog", "targets": ["clog1"]},
	]


func test_initial_states() -> void:
	var m: WorkOrderManager = WorkOrderManager.new()
	m.load_orders(_defs())
	check_eq(int(m.get_order("a").status), int(WorkOrder.Status.ACTIVE), "a active")
	check_eq(int(m.get_order("b").status), int(WorkOrder.Status.LOCKED), "b locked until a")
	check_eq(int(m.get_order("c").status), int(WorkOrder.Status.ACTIVE), "c parallel")


func test_ordered_completion() -> void:
	var m: WorkOrderManager = WorkOrderManager.new()
	m.load_orders(_defs())
	m.target_done("leak1")
	check_eq(int(m.get_order("a").status), int(WorkOrder.Status.ACTIVE), "half done")
	check_near(m.get_order("a").progress(), 0.5, "progress 50%")
	m.target_done("leak2")
	check_eq(int(m.get_order("a").status), int(WorkOrder.Status.DONE), "a done")
	check_eq(int(m.get_order("b").status), int(WorkOrder.Status.ACTIVE), "b unlocked")
	check(not m.all_done(), "not all done yet")
	m.target_done("valve1")
	m.target_done("clog1")
	check(m.all_done(), "all done")


func test_early_targets_count_later() -> void:
	var m: WorkOrderManager = WorkOrderManager.new()
	m.load_orders(_defs())
	m.target_done("valve1")   # b is still locked
	check_eq(int(m.get_order("b").status), int(WorkOrder.Status.LOCKED), "still locked")
	m.target_done("leak1")
	m.target_done("leak2")
	check_eq(int(m.get_order("b").status), int(WorkOrder.Status.DONE), "early valve counted when b opened")


func test_signals_fire_once() -> void:
	var m: WorkOrderManager = WorkOrderManager.new()
	var count: Array = [0]
	m.all_completed.connect(func() -> void: count[0] = int(count[0]) + 1)
	m.load_orders([{"id": "x", "targets": ["t"]}])
	m.target_done("t")
	m.target_done("t")
	check_eq(int(count[0]), 1, "all_completed once")


func test_state_roundtrip() -> void:
	var m: WorkOrderManager = WorkOrderManager.new()
	m.load_orders(_defs())
	m.target_done("leak1")
	var m2: WorkOrderManager = WorkOrderManager.new()
	m2.load_orders(_defs())
	m2.apply_state(m.get_state())
	check_near(m2.get_order("a").progress(), 0.5, "client sees progress")


func test_sludge() -> void:
	var s: SludgeMeter = SludgeMeter.new()
	s.tick(10.0, 2, 1, 1.0, 1.0, 0.5)
	check_near(s.value, 25.0, "2 leaks + 1 clog for 10 s")
	s.reward(10.0)
	check_near(s.value, 15.0, "reward lowers sludge")
	s.add(200.0)
	check(s.is_flooded(), "floods at 100")
	var solo: SludgeMeter = SludgeMeter.new()
	solo.can_flood = false
	solo.add(500.0)
	check(not solo.is_flooded(), "solo never hard-fails")
	check_eq(SludgeMeter.stars_for(100.0, 300.0, 10.0), 3, "fast clean = 3 stars")
	check_eq(SludgeMeter.stars_for(1000.0, 300.0, 90.0), 1, "slow messy = 1 star")
