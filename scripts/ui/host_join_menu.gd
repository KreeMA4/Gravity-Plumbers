extends Node
## Host & Join screen.
## HOST: room name, level, difficulty (+ port under Advanced) -> Start Hosting.
## JOIN (all on one screen): LAN games found nearby (tap to join), a room
## code box (forgiving: dashes, lowercase, O/0 and I/1 mix-ups are fine),
## manual IP + port under Advanced, and hotspot help.

const HOTSPOT_HELP: String = "No Wi-Fi? No problem!\n\n1. On the HOST phone, turn on Mobile Hotspot (Settings > Hotspot).\n2. Friends connect their phones to that hotspot.\n3. Host taps Host Game. Friends tap Join and type the room code.\n\nTip: the host's address on a hotspot is often 192.168.43.1, but the code always has the right one. Mobile data isn't used for playing."

var _tab: String = "join"
var _root: Control
var _host_panel: VBoxContainer
var _join_panel: HBoxContainer
var _rooms_box: VBoxContainer
var _lan_status: Label
var _code_edit: LineEdit
var _ip_edit: LineEdit
var _port_edit: LineEdit
var _host_port_edit: LineEdit
var _room_edit: LineEdit
var _name_edit: LineEdit
var _level_pick: OptionButton
var _advanced: VBoxContainer
var _overlay: PanelContainer
var _overlay_label: Label
var _help: PanelContainer
var _tab_host: Button
var _tab_join: Button
var _diff_buttons: Array = []
var _level_ids: Array = []


func setup(params: Dictionary) -> void:
	_tab = str(params.get("tab", "join"))


func _ready() -> void:
	var backdrop_script: GDScript = load("res://scripts/ui/menu_backdrop.gd") as GDScript
	add_child(backdrop_script.new() as Node)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_root = UITheme.make_screen_root()
	layer.add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0.05, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var margin: MarginContainer = UITheme.safe_margin()
	_root.add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	margin.add_child(col)
	# Top bar
	var top: HBoxContainer = HBoxContainer.new()
	col.add_child(top)
	var back: Button = UITheme.small_button("< Back")
	back.custom_minimum_size = Vector2(220, 96)
	back.pressed.connect(func() -> void:
		NetManager.start_solo()
		GameState.goto_screen("main_menu"))
	top.add_child(back)
	_tab_host = UITheme.small_button("HOST")
	_tab_host.custom_minimum_size = Vector2(260, 96)
	_tab_host.toggle_mode = true
	_tab_host.pressed.connect(func() -> void: _show_tab("host"))
	top.add_child(_tab_host)
	_tab_join = UITheme.small_button("JOIN")
	_tab_join.custom_minimum_size = Vector2(260, 96)
	_tab_join.toggle_mode = true
	_tab_join.pressed.connect(func() -> void: _show_tab("join"))
	top.add_child(_tab_join)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(UITheme.label("Your name:", 30))
	_name_edit = _line_edit(str(SaveData.data.get("player_name", "Plumber")), 16)
	_name_edit.custom_minimum_size = Vector2(340, 90)
	_name_edit.text_changed.connect(func(t: String) -> void:
		SaveData.data["player_name"] = t.strip_edges().substr(0, 16))
	top.add_child(_name_edit)
	_build_host_panel(col)
	_build_join_panel(col)
	_build_overlay()
	NetManager.connection_changed.connect(_on_connection_changed)
	_show_tab(_tab)


## Put a popup panel in the middle of the screen.
func _centered(panel: Control) -> void:
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cc)
	cc.add_child(panel)


func _line_edit(text: String, max_len: int) -> LineEdit:
	var le: LineEdit = LineEdit.new()
	le.text = text
	le.max_length = max_len
	le.custom_minimum_size = Vector2(300, 96)
	le.add_theme_font_size_override("font_size", 36)
	return le


func _build_host_panel(parent: Control) -> void:
	_host_panel = VBoxContainer.new()
	_host_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(_host_panel)
	var p: PanelContainer = PanelContainer.new()
	_host_panel.add_child(p)
	var c: VBoxContainer = VBoxContainer.new()
	p.add_child(c)
	c.add_child(UITheme.label("Host a game on this phone", 40, UITheme.C_ACCENT))
	var r1: HBoxContainer = HBoxContainer.new()
	c.add_child(r1)
	r1.add_child(UITheme.label("Room name:", 32))
	_room_edit = _line_edit(str(SaveData.data.get("player_name", "Plumber")) + "'s Station", 24)
	_room_edit.custom_minimum_size = Vector2(600, 96)
	r1.add_child(_room_edit)
	var r2: HBoxContainer = HBoxContainer.new()
	c.add_child(r2)
	r2.add_child(UITheme.label("First job:", 32))
	_level_pick = OptionButton.new()
	_level_pick.custom_minimum_size = Vector2(600, 96)
	_level_pick.add_theme_font_size_override("font_size", 30)
	_level_ids.clear()
	_level_pick.add_item("The Rusty Pipe (hub)")
	_level_ids.append("hub")
	for l: Variant in LevelCatalog.story_levels():
		var d: Dictionary = l as Dictionary
		_level_pick.add_item(str(d["name"]))
		_level_ids.append(str(d["id"]))
	r2.add_child(_level_pick)
	var r3: HBoxContainer = HBoxContainer.new()
	c.add_child(r3)
	r3.add_child(UITheme.label("Difficulty:", 32))
	for i: int in 3:
		var b: Button = UITheme.small_button(str((Tuning.DIFFICULTY[i] as Dictionary)["name"]))
		b.custom_minimum_size = Vector2(220, 96)
		b.toggle_mode = true
		b.button_pressed = GameState.difficulty == i
		var idx: int = i
		b.pressed.connect(func() -> void:
			GameState.difficulty = idx
			for j: int in _diff_buttons.size():
				(_diff_buttons[j] as Button).button_pressed = j == idx)
		r3.add_child(b)
		_diff_buttons.append(b)
	var r4: HBoxContainer = HBoxContainer.new()
	c.add_child(r4)
	r4.add_child(UITheme.label("Port (advanced):", 28))
	_host_port_edit = _line_edit(str(Tuning.DEFAULT_PORT), 5)
	_host_port_edit.custom_minimum_size = Vector2(200, 90)
	r4.add_child(_host_port_edit)
	var go: Button = UITheme.big_button("Start Hosting", UITheme.C_GOOD.darkened(0.3))
	go.pressed.connect(_on_host)
	c.add_child(go)


func _build_join_panel(parent: Control) -> void:
	_join_panel = HBoxContainer.new()
	_join_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(_join_panel)
	# Left: LAN list
	var lp: PanelContainer = PanelContainer.new()
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_panel.add_child(lp)
	var lc: VBoxContainer = VBoxContainer.new()
	lp.add_child(lc)
	lc.add_child(UITheme.label("Games nearby (same Wi-Fi / hotspot)", 32, UITheme.C_ACCENT))
	_lan_status = UITheme.label("Looking...", 26)
	_lan_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lc.add_child(_lan_status)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(600, 300)
	lc.add_child(scroll)
	_rooms_box = VBoxContainer.new()
	_rooms_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rooms_box)
	# Right: code + advanced + help
	var rp: PanelContainer = PanelContainer.new()
	_join_panel.add_child(rp)
	var rc: VBoxContainer = VBoxContainer.new()
	rp.add_child(rc)
	rc.add_child(UITheme.label("Room code", 32, UITheme.C_ACCENT))
	_code_edit = _line_edit("", 13)
	_code_edit.placeholder_text = "ABCDE-12345"
	_code_edit.custom_minimum_size = Vector2(520, 110)
	_code_edit.add_theme_font_size_override("font_size", 48)
	_code_edit.text_changed.connect(_on_code_changed)
	rc.add_child(_code_edit)
	var join_b: Button = UITheme.big_button("Join with code", UITheme.C_GOOD.darkened(0.3))
	join_b.custom_minimum_size = Vector2(520, 110)
	join_b.pressed.connect(_on_join_code)
	rc.add_child(join_b)
	var adv_b: Button = UITheme.small_button("Advanced: IP + port")
	adv_b.custom_minimum_size = Vector2(520, 90)
	rc.add_child(adv_b)
	_advanced = VBoxContainer.new()
	_advanced.visible = false
	rc.add_child(_advanced)
	adv_b.pressed.connect(func() -> void: _advanced.visible = not _advanced.visible)
	var ar: HBoxContainer = HBoxContainer.new()
	_advanced.add_child(ar)
	_ip_edit = _line_edit(str(SaveData.data.get("last_ip", "")), 39)
	_ip_edit.placeholder_text = "192.168.1.20"
	ar.add_child(_ip_edit)
	_port_edit = _line_edit(str(int(SaveData.data.get("last_port", Tuning.DEFAULT_PORT))), 5)
	_port_edit.custom_minimum_size = Vector2(180, 96)
	ar.add_child(_port_edit)
	var ipj: Button = UITheme.small_button("Join IP")
	ipj.custom_minimum_size = Vector2(200, 96)
	ipj.pressed.connect(_on_join_ip)
	ar.add_child(ipj)
	var help_b: Button = UITheme.small_button("No Wi-Fi? Hotspot help")
	help_b.custom_minimum_size = Vector2(520, 90)
	rc.add_child(help_b)
	_help = PanelContainer.new()
	_help.visible = false
	_centered(_help)
	var hc: VBoxContainer = VBoxContainer.new()
	_help.add_child(hc)
	var hl: Label = UITheme.label(HOTSPOT_HELP, 30)
	hl.custom_minimum_size = Vector2(1100, 0)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hc.add_child(hl)
	var hok: Button = UITheme.big_button("Got it")
	hok.pressed.connect(func() -> void: _help.visible = false)
	hc.add_child(hok)
	help_b.pressed.connect(func() -> void: _help.visible = true)


func _build_overlay() -> void:
	_overlay = PanelContainer.new()
	_overlay.visible = false
	_centered(_overlay)
	var c: VBoxContainer = VBoxContainer.new()
	_overlay.add_child(c)
	_overlay_label = UITheme.label("Connecting...", 40)
	_overlay_label.custom_minimum_size = Vector2(900, 0)
	_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(_overlay_label)
	var cancel: Button = UITheme.big_button("Cancel", UITheme.C_DANGER.darkened(0.2))
	cancel.pressed.connect(func() -> void:
		NetManager.cancel_join()
		_overlay.visible = false
		_start_lan())
	c.add_child(cancel)


func _show_overlay(text: String, show_cancel: bool) -> void:
	_overlay_label.text = text
	_overlay.visible = true
	(_overlay.get_child(0).get_child(1) as Button).text = "Cancel" if show_cancel else "OK"


func _show_tab(tab: String) -> void:
	_tab = tab
	_tab_host.button_pressed = tab == "host"
	_tab_join.button_pressed = tab == "join"
	_host_panel.visible = tab == "host"
	_join_panel.visible = tab == "join"
	if tab == "join":
		_start_lan()


func _start_lan() -> void:
	var lan: LanDiscovery = NetManager.get_node("LanDiscovery") as LanDiscovery
	if lan == null:
		return
	if not lan.rooms_changed.is_connected(_refresh_rooms):
		lan.rooms_changed.connect(_refresh_rooms)
	if lan.start_listening():
		_lan_status.text = "Looking for games... (they appear here automatically)"
	else:
		_lan_status.text = lan.error_text
	_refresh_rooms()


func _refresh_rooms() -> void:
	for c: Node in _rooms_box.get_children():
		c.queue_free()
	var lan: LanDiscovery = NetManager.get_node("LanDiscovery") as LanDiscovery
	if lan == null:
		return
	for k: Variant in lan.rooms.keys():
		var info: Dictionary = lan.rooms[k] as Dictionary
		var txt: String = "%s  -  %s  (%d/%d)" % [str(info.get("n", "?")).substr(0, 24), str(info.get("l", "")).substr(0, 30),
			int(info.get("c", 1)), int(info.get("m", 4))]
		if str(info.get("v", "")) != Tuning.GAME_VERSION:
			txt += "  [needs v%s]" % str(info.get("v", "?")).substr(0, 10)
		var b: Button = UITheme.big_button(txt, UITheme.C_TEAL.darkened(0.3))
		b.custom_minimum_size = Vector2(600, 100)
		b.add_theme_font_size_override("font_size", 28)
		var ip: String = str(info["ip"])
		var p: int = int(info.get("p", Tuning.DEFAULT_PORT))
		b.pressed.connect(func() -> void: _join(ip, p))
		_rooms_box.add_child(b)


func _on_code_changed(t: String) -> void:
	var up: String = t.to_upper()
	if up != t:
		var caret: int = _code_edit.caret_column
		_code_edit.text = up
		_code_edit.caret_column = caret


func _on_join_code() -> void:
	var d: Dictionary = RoomCode.decode(_code_edit.text)
	if not bool(d["ok"]):
		_show_overlay(str(d["error"]), false)
		return
	_join(str(d["ip"]), int(d["port"]))


func _on_join_ip() -> void:
	var ip: String = _ip_edit.text.strip_edges()
	if ip.split(".").size() != 4:
		_show_overlay("That doesn't look like an IP address (e.g. 192.168.1.20).", false)
		return
	_join(ip, clampi(_port_edit.text.to_int(), 1, 65535))


func _join(ip: String, p: int) -> void:
	SaveData.save()
	var lan: LanDiscovery = NetManager.get_node("LanDiscovery") as LanDiscovery
	if lan != null:
		lan.stop()
	if NetManager.join_game(ip, p) == OK:
		_show_overlay("Connecting to %s:%d..." % [ip, p], true)


func _on_connection_changed(state: String, message: String) -> void:
	if not is_inside_tree():
		return
	match state:
		"failed":
			_show_overlay(message, false)
		"connected":
			_overlay.visible = false
		"connecting":
			_show_overlay(message, true)


func _on_host() -> void:
	SaveData.save()
	var p: int = clampi(_host_port_edit.text.to_int(), 1024, 65535)
	var err: Error = NetManager.host_game(_room_edit.text, p)
	if err != OK:
		_show_overlay("Couldn't host on port %d (error %d). Is another game already hosting? Try another port." % [p, err], false)
		return
	NetManager.set_lobby_level(str(_level_ids[clampi(_level_pick.selected, 0, _level_ids.size() - 1)]))
	GameState.goto_screen("lobby")


func _exit_tree() -> void:
	if NetManager.connection_changed.is_connected(_on_connection_changed):
		NetManager.connection_changed.disconnect(_on_connection_changed)
	var lan: LanDiscovery = NetManager.get_node_or_null("LanDiscovery") as LanDiscovery
	if lan != null:
		if lan.rooms_changed.is_connected(_refresh_rooms):
			lan.rooms_changed.disconnect(_refresh_rooms)
		if lan.listening:
			lan.stop()
