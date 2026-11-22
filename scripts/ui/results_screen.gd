extends Node
## Results: stars, time, golden ducks and silly per-player awards, then back
## to the hub (or try again after a flood).

const FAIL_LINES: Array = [
	"The station is now a swimming pool. A gross one.",
	"Sludge: 1, Plumbers: 0. Rematch?",
	"DISPATCH-O-TRON is filing this under 'learning experiences'.",
	"Next time, maybe plug the leaks BEFORE the flood?",
]


func _ready() -> void:
	var r: Dictionary = GameState.last_results
	var won: bool = bool(r.get("won", false))
	var backdrop_script: GDScript = load("res://scripts/ui/menu_backdrop.gd") as GDScript
	add_child(backdrop_script.new() as Node)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var root: Control = UITheme.make_screen_root()
	layer.add_child(root)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	panel.add_child(col)
	col.add_child(UITheme.title("STATION SAVED!" if won else "FLOODED!"))
	var name_l: Label = UITheme.label(str(r.get("name", "")), 34, UITheme.C_TEAL)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_l)
	if won:
		var stars: int = int(r.get("stars", 1))
		var star_row: HBoxContainer = HBoxContainer.new()
		star_row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(star_row)
		for i: int in 3:
			var s: StarIcon = StarIcon.new()
			s.filled = i < stars
			s.delay = 0.3 + 0.35 * float(i)
			s.custom_minimum_size = Vector2(110, 110)
			star_row.add_child(s)
		var t: float = float(r.get("time", 0.0))
		var info: Label = UITheme.label("Time %d:%02d    Sludge %d%%    Ducks found: %d" % [
			floori(t / 60.0), int(t) % 60, int(r.get("sludge", 0.0)), (r.get("ducks", []) as Array).size()], 32)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(info)
	else:
		var fl: Label = UITheme.label(str(FAIL_LINES[randi() % FAIL_LINES.size()]), 32)
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(fl)
	for a: Variant in r.get("awards", []):
		var arr: Array = a as Array
		var al: Label = UITheme.label("%s: %s (%s)" % [str(arr[0]), str(arr[1]), str(arr[2])], 28, UITheme.C_ACCENT)
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(al)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var can_choose: bool = multiplayer.is_server()
	if not won and can_choose:
		var retry: Button = UITheme.big_button("Try Again", UITheme.C_GOOD.darkened(0.3))
		retry.custom_minimum_size = Vector2(340, 116)
		var lid: String = str(r.get("level_id", "hub"))
		retry.pressed.connect(func() -> void: NetManager.host_start_level(lid))
		row.add_child(retry)
	if can_choose and LevelCatalog.exists("hub"):
		var hub: Button = UITheme.big_button("Back to Hub" if not NetManager.is_online() else "Back to Lobby")
		hub.custom_minimum_size = Vector2(340, 116)
		hub.pressed.connect(func() -> void:
			if NetManager.is_online():
				NetManager.goto_lobby()
			else:
				NetManager.host_start_level("hub"))
		row.add_child(hub)
	elif not can_choose:
		row.add_child(UITheme.label("Waiting for the host...", 30))
	var menu: Button = UITheme.big_button("Main Menu", Color(0.35, 0.35, 0.5))
	menu.custom_minimum_size = Vector2(300, 116)
	menu.pressed.connect(func() -> void:
		NetManager.leave_session()
		GameState.goto_screen("main_menu"))
	row.add_child(menu)
	AudioManager.play_music("menu")


## A star that pops in after a delay.
class StarIcon extends Control:
	var filled: bool = true
	var delay: float = 0.3
	var _t: float = 0.0
	var _popped: bool = false

	func _process(delta: float) -> void:
		_t += delta
		if _t >= delay and not _popped:
			_popped = true
			if filled:
				AudioManager.play_ui("work_done", -4.0, 1.0 + delay * 0.3)
		queue_redraw()

	func _draw() -> void:
		var k: float = clampf((_t - delay) * 5.0, 0.0, 1.0)
		var scale_k: float = k * (1.0 + 0.3 * sin(k * PI))
		var c: Vector2 = size * 0.5
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in 10:
			var r: float = (48.0 if i % 2 == 0 else 20.0) * scale_k
			var a: float = -PI * 0.5 + float(i) * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		if scale_k > 0.01:
			draw_colored_polygon(pts, UITheme.C_ACCENT if filled else Color(0.3, 0.3, 0.4))
