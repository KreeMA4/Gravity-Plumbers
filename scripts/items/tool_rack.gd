class_name ToolRack
extends Node3D
## A wall rack that holds tools. Tools remember the rack as "home" and
## return there if lost in space. ToolRack.build() makes one with tools.

const TOOL_SCRIPTS: Dictionary = {
	"plunger": "res://scripts/items/plunger.gd",
	"wrench": "res://scripts/items/pipe_wrench.gd",
	"tape": "res://scripts/items/duct_tape.gd",
	"gwrench": "res://scripts/items/g_wrench.gd",
}

var tools: Array = []


## Build a rack at `xform` (rack faces its local -Z) holding the listed tool ids.
static func build(parent: Node, xform: Transform3D, tool_ids: Array) -> ToolRack:
	var rack: ToolRack = ToolRack.new()
	rack.name = "ToolRack"
	parent.add_child(rack)
	rack.global_transform = xform
	var w: float = maxf(1.2, float(tool_ids.size()) * 0.6)
	Geo.static_box(rack, Vector3(0, 0.9, 0.15), Vector3(w + 0.3, 1.6, 0.15), Color(0.45, 0.48, 0.6))
	Geo.static_box(rack, Vector3(0, 0.45, -0.1), Vector3(w + 0.3, 0.08, 0.45), Color(1.0, 0.82, 0.2))
	var lbl: Label3D = Label3D.new()
	lbl.text = "TOOLS"
	lbl.font_size = 64
	lbl.outline_size = 12
	lbl.position = Vector3(0, 1.85, 0.05)
	lbl.pixel_size = 0.004
	rack.add_child(lbl)
	for i: int in tool_ids.size():
		var path: String = str(TOOL_SCRIPTS.get(str(tool_ids[i]), ""))
		if path == "":
			continue
		var t: ToolBase = (load(path) as GDScript).new() as ToolBase
		var local: Vector3 = Vector3((float(i) - float(tool_ids.size() - 1) * 0.5) * 0.6, 0.62, -0.1)
		t.position = local
		t.rotation = Vector3(-PI * 0.5, 0, 0)
		rack.add_child(t)
		rack.tools.append(t)
	return rack
