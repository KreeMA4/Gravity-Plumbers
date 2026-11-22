class_name WorkOrder
extends RefCounted
## One objective ("work order") from DISPATCH-O-TRON. Pure data + state.
## type: leak | pipe | valve | clog | tank | switch
## targets: ids of the level objects that must be done (sealed, turned...)
## after: ids of work orders that must be finished before this one opens.

enum Status { LOCKED, ACTIVE, DONE }

var id: String = ""
var type: String = "leak"
var text: String = ""
var targets: PackedStringArray = PackedStringArray()
var after: PackedStringArray = PackedStringArray()
var reward: float = 8.0
var status: Status = Status.LOCKED
var done_targets: Dictionary = {}


static func from_dict(d: Dictionary) -> WorkOrder:
	var w: WorkOrder = WorkOrder.new()
	w.id = str(d.get("id", ""))
	w.type = str(d.get("type", "leak"))
	w.text = str(d.get("text", "Fix the thing!"))
	w.reward = float(d.get("reward", 8.0))
	for t: Variant in d.get("targets", []):
		w.targets.append(str(t))
	for a: Variant in d.get("after", []):
		w.after.append(str(a))
	return w


func progress() -> float:
	if targets.is_empty():
		return 1.0 if status == Status.DONE else 0.0
	return float(done_targets.size()) / float(targets.size())


func is_complete() -> bool:
	for t: String in targets:
		if not done_targets.has(t):
			return false
	return true
