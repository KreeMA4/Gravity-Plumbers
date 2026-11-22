class_name Interaction
extends RefCounted
## Contextual interaction for one plumber: what the Interact button would do
## right now ("PICK UP Plunger", "FLIP Switch", "DROP Pipe").
##
## Picking things up is ALWAYS a deliberate button press. Walking near an item,
## touching it, or holding Grab never picks it up. (Grab L / Grab R are the
## physics hands: they cling to surfaces, crates and teammates, but skip
## anything in the "pickups" group.)
##
## Items join the group "pickups" and may implement:
##   can_pick_up() -> bool        (false while held / locked / respawning)
##   get_interact_name() -> String
## Interactables (switches, hub stations) are the existing "interactables" group
## with interact(plumber) and get_use_label().
##
## The same query runs on the host (to act on the button) and on each device
## (to show the prompt), so it only uses state every peer has.

enum Kind { NONE, PICKUP, DROP, USE_OBJECT }

## Items this close horizontally count in any direction (you're standing on them).
## Measured flat, because distances are taken from the pelvis, ~0.9 m above the floor.
const CLOSE_RANGE: float = 0.45
## Interactables keep their old, generous "anywhere around you" rule.
const OBJECT_RANGE: float = 1.8

var kind: int = Kind.NONE
var node: Node3D = null
var verb: String = ""
var item_name: String = ""


func is_none() -> bool:
	return kind == Kind.NONE


## Text for the Interact button ("PICK UP", "DROP", "FLIP").
func button_text() -> String:
	return verb


## Full prompt, e.g. "PICK UP  Plunger".
func prompt_text() -> String:
	if item_name == "":
		return verb
	return "%s  %s" % [verb, item_name]


func same_as(other: Interaction) -> bool:
	return other != null and other.kind == kind and other.node == node


## Score a candidate at `target` for a plumber at `from` looking along `look`
## (both already flattened onto the walking plane). Higher is better; < 0 means
## "not a candidate". Prefers what you're facing, then what's closest.
static func score_candidate(from: Vector3, look: Vector3, target: Vector3, up: Vector3,
		max_range: float, min_dot: float) -> float:
	var to: Vector3 = target - from
	var d: float = to.length()
	if d > max_range:
		return -1.0
	var flat: Vector3 = to - up * to.dot(up)
	var dot: float = 1.0
	if flat.length() > 0.05 and look.length() > 0.001:
		dot = look.normalized().dot(flat.normalized())
	if dot < min_dot and flat.length() > CLOSE_RANGE:
		return -1.0
	return clampf(dot, 0.0, 1.0) * 0.65 + (1.0 - d / maxf(max_range, 0.01)) * 0.35


## Is this pickup in someone's hand right now? Works on host and clients:
## a plumber whose right hand is full and whose palm is at the item holds it.
static func is_held(item: Node3D, tree: SceneTree) -> bool:
	if tree == null:
		return false
	for n: Node in tree.get_nodes_in_group("plumbers"):
		var p: Plumber = n as Plumber
		if p == null or not p.is_hand_full():
			continue
		if p.held_item() == item:
			return true
		if p.get_hand_position("r").distance_to(item.global_position) < 0.7:
			return true
	return false


static func find(p: Plumber, aim: Vector3) -> Interaction:
	var res: Interaction = Interaction.new()
	if p == null or not is_instance_valid(p) or not is_instance_valid(p.pelvis):
		return res
	if p.state != Plumber.State.ACTIVE:
		return res
	var tree: SceneTree = p.get_tree()
	var up: Vector3 = p.local_up
	var look: Vector3 = aim - up * aim.dot(up)
	if look.length_squared() < 0.0025:
		look = p.facing
	look = look.normalized()
	var from: Vector3 = p.get_center()
	var best_score: float = -1.0
	# 1) Switches, stations... (unchanged rule: anything within reach).
	for n: Node in tree.get_nodes_in_group("interactables"):
		var n3: Node3D = n as Node3D
		if n3 == null or not n3.is_inside_tree() or not n3.has_method("interact"):
			continue
		var s: float = score_candidate(from, look, n3.global_position, up, OBJECT_RANGE, -1.0)
		if s < 0.0:
			continue
		s += 0.15   # a switch right next to you beats a tool on the floor
		if s > best_score:
			best_score = s
			res.kind = Kind.USE_OBJECT
			res.node = n3
			res.verb = str(n3.call("get_use_label")) if n3.has_method("get_use_label") else "USE"
			res.item_name = str(n3.call("get_interact_name")) if n3.has_method("get_interact_name") else ""
	# 2) Items to pick up (only with a free right hand).
	if not p.is_hand_full():
		for n: Node in tree.get_nodes_in_group("pickups"):
			var it: Node3D = n as Node3D
			if it == null or not it.is_inside_tree() or not it.is_visible_in_tree():
				continue
			if it.has_method("can_pick_up") and not bool(it.call("can_pick_up")):
				continue
			var s2: float = score_candidate(from, look, it.global_position, up, Tuning.PICKUP_RANGE, Tuning.PICKUP_MIN_DOT)
			if s2 < 0.0 or s2 <= best_score:
				continue
			if is_held(it, tree) or not _line_of_sight(p, from, it):
				continue
			best_score = s2
			res.kind = Kind.PICKUP
			res.node = it
			res.verb = "PICK UP"
			res.item_name = str(it.call("get_interact_name")) if it.has_method("get_interact_name") else "Item"
	# 3) Nothing better to do but your hand is full: offer to put it down.
	if res.kind == Kind.NONE and p.is_hand_full():
		var held: Node3D = p.held_item()
		res.kind = Kind.DROP
		res.node = held
		res.verb = "DROP"
		res.item_name = str(held.call("get_interact_name")) if held != null and held.has_method("get_interact_name") else ""
	return res


## Don't offer things on the other side of a wall.
static func _line_of_sight(p: Plumber, from: Vector3, item: Node3D) -> bool:
	# Items are on the PROPS layer, so a WORLD-only ray never hits the item itself.
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, item.global_position, Layers.WORLD, p._exclude)
	var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty()
