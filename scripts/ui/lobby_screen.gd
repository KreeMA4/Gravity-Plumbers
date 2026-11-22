extends Node
## Lobby: room code + IP (with copy button), the player list with ready
## checks and live outfit previews (3D, behind the UI), the host's level and
## difficulty pick, Start (enabled when everyone is ready), kick, and
## one-phone test tools (fake remote bot, simulated latency / packet loss).

var _root: Control
var _players_box: VBoxContainer
var _code_label: Label
var _ip_label: Label
var _net_label: Label
var _start: Button
var _ready_b: Button
var _level_pick: OptionButton
var _level_ids: Array = []
var _info_label: Label
var _diff_buttons: Array = []
var _preview_root: Node3D
var _my_ready: bool = false


func _ready() -> void:
	var backdrop_script: GDScript = load("res://scripts/ui/menu_backdrop.gd") as GDScript
	var backdrop: Node3D = backdrop_script.new() as Node3D
	add_child(backdrop)
	_preview_root = Node3D.new()
	_preview_root.name = "LobbyPreviews"
	_preview_root.position = Vector3(0.3, 0.0, -1.6)
	backdrop.add_child(_preview_root)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_root = UITheme.make_screen_root()
	layer.add_child(_root)
	var margin: MarginContainer = UITheme.safe_margin()
	_root.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	# Left column: room info.
	var left: PanelContainer = PanelContainer.new()
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(left)
	var lc: VBoxContainer = VBoxContainer.new()
	left.add_child(lc)
	var title: Label = UITheme.label(NetManager.room_name, 40, UITheme.C_ACCENT)
	lc.add_child(title)
	_code_label = UITheme.label("", 52)
	lc.add_child(_code_label)
	var copy_b: Button = UITheme.small_button("Copy code")
	copy_b.custom_minimum_size = Vector2(300, 90)
	copy_b.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(NetManager.room_code)
		copy_b.text = "Copied!")
	lc.add_child(copy_b)
	_ip_label = UITheme.label("", 24)
	_ip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ip_label.custom_minimum_size = Vector2(520, 0)
	lc.add_child(_ip_label)
	_net_label = UITheme.label("", 22, Color(0.8, 0.85, 1.0))
	_net_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_net_label.custom_minimum_size = Vector2(520, 0)
	lc.add_child(_net_label)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	# Right column: players + controls.
	var right: PanelContainer = PanelContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(right)
	var rc: VBoxContainer = VBoxContainer.new()
	right.add_child(rc)
	rc.add_child(UITheme.label("Plumbers", 40, UITheme.C_ACCENT))
	_players_box = VBoxContainer.new()
	rc.add_child(_players_box)
	_info_label = UITheme.label("", 28)
	rc.add_child(_info_label)
	var host: bool = multiplayer.is_server()
	if host:
		_level_pick = OptionButton.new()
		_level_pick.custom_minimum_size = Vector2(560, 90)
		_level_pick.add_theme_font_size_override("font_size", 28)
		_level_ids = ["hub"]
		_level_pick.add_item("The Rusty Pipe (hub)")
		for l: Variant in LevelCatalog.story_levels():
			var d: Dictionary = l as Dictionary
			_level_pick.add_item(str(d["name"]))
			_level_ids.append(str(d["id"]))
		_level_pick.selected = maxi(0, _level_ids.find(NetManager.lobby_level_id))
		_level_pick.item_selected.connect(func(i: int) -> void: NetManager.set_lobby_level(str(_level_ids[i])))
		rc.add_child(_level_pick)
		var dr: HBoxContainer = HBoxContainer.new()
		rc.add_child(dr)
		for i: int in 3:
			var b: Button = UITheme.small_button(str((Tuning.DIFFICULTY[i] as Dictionary)["name"]))
			b.custom_minimum_size = Vector2(176, 86)
			b.toggle_mode = true
			b.button_pressed = GameState.difficulty == i
			var idx: int = i
			b.pressed.connect(func() -> void:
				NetManager.set_difficulty(idx)
				for j: int in _diff_buttons.size():
					(_diff_buttons[j] as Button).button_pressed = j == idx)
			dr.add_child(b)
			_diff_buttons.append(b)
		_start = UITheme.big_button("START!", UITheme.C_GOOD.darkened(0.3))
		_start.custom_minimum_size = Vector2(560, 116)
		_start.pressed.connect(func() -> void: NetManager.host_start_level(NetManager.lobby_level_id))
		rc.add_child(_start)
		var dbg: HBoxContainer = HBoxContainer.new()
		rc.add_child(dbg)
		var bot_b: Button = UITheme.small_button("+ Test bot")
		bot_b.custom_minimum_size = Vector2(176, 80)
		bot_b.add_theme_font_size_override("font_size", 24)
		bot_b.pressed.connect(NetManager.add_fake_bot)
		dbg.add_child(bot_b)
		var lag: OptionButton = OptionButton.new()
		lag.add_theme_font_size_override("font_size", 22)
		for t: String in ["Lag 0", "Lag 100ms", "Lag 250ms"]:
			lag.add_item(t)
		lag.item_selected.connect(func(i: int) -> void: NetManager.sim_latency_ms = [0, 100, 250][i])
		dbg.add_child(lag)
		var loss: OptionButton = OptionButton.new()
		loss.add_theme_font_size_override("font_size", 22)
		for t2: String in ["Loss 0%", "Loss 5%", "Loss 15%"]:
			loss.add_item(t2)
		loss.item_selected.connect(func(i: int) -> void: NetManager.sim_loss = [0.0, 0.05, 0.15][i])
		dbg.add_child(loss)
	else:
		_ready_b = UITheme.big_button("I'M READY", UITheme.C_GOOD.darkened(0.3))
		_ready_b.custom_minimum_size = Vector2(560, 116)
		_ready_b.toggle_mode = true
		_ready_b.toggled.connect(func(on: bool) -> void:
			_my_ready = on
			_ready_b.text = "READY!" if on else "I'M READY"
			NetManager.set_ready(on))
		rc.add_child(_ready_b)
	var bottom: HBoxContainer = HBoxContainer.new()
	rc.add_child(bottom)
	if GameState.screen_available("customize"):
		var cust: Button = UITheme.small_button("Customise")
		cust.custom_minimum_size = Vector2(270, 90)
		cust.pressed.connect(_open_customize)
		bottom.add_child(cust)
	var leave: Button = UITheme.small_button("Leave")
	leave.custom_minimum_size = Vector2(270, 90)
	leave.pressed.connect(func() -> void:
		NetManager.leave_session()
		GameState.goto_screen("main_menu"))
	bottom.add_child(leave)
	NetManager.players_changed.connect(_refresh)
	NetManager.lobby_info_changed.connect(_refresh)
	NetManager.upnp_changed.connect(_refresh)
	_refresh()
	AudioManager.play_music("menu")


func _open_customize() -> void:
	var scr: GDScript = load(str(GameState.SCREENS["customize"])) as GDScript
	var c: Node = scr.new() as Node
	if c.has_method("set_overlay"):
		c.call("set_overlay", true)
	add_child(c)
	c.tree_exited.connect(func() -> void:
		if NetManager.is_online():
			NetManager.update_my_info())


func _refresh() -> void:
	if not is_inside_tree():
		return
	var host: bool = multiplayer.is_server()
	_code_label.text = NetManager.room_code if host else ""
	if host:
		var ips: String = ", ".join(PackedStringArray(NetManager.local_ips))
		_ip_label.text = "Local IP: %s  port %d\nFriends on the same Wi-Fi/hotspot see this room in their Join list, or type the code." % [ips, NetManager.port]
		var net_txt: String = NetManager.upnp_message
		if NetManager.internet_code != "":
			net_txt += "\nInternet code: " + NetManager.internet_code
		else:
			net_txt += "\nFor internet play: forward UDP %d on your router, or use a VPN like Tailscale or ZeroTier, or just use a hotspot." % NetManager.port
		_net_label.text = net_txt
	else:
		_ip_label.text = "Connected. Ping %d ms" % NetManager.get_ping_ms()
		_net_label.text = ""
	for c: Node in _players_box.get_children():
		c.queue_free()
	for pid: Variant in NetManager.get_player_ids():
		var p: Dictionary = NetManager.players[pid] as Dictionary
		var r: HBoxContainer = HBoxContainer.new()
		_players_box.add_child(r)
		var is_host_row: bool = int(pid) == 1
		var ready_txt: String = "HOST" if is_host_row else ("READY" if bool(p["ready"]) else "...")
		var nm: Label = UITheme.label("%s  %s" % [str(p["name"]), "(bot)" if bool(p.get("fake", false)) else ""], 32)
		nm.custom_minimum_size = Vector2(300, 0)
		r.add_child(nm)
		var st: Label = UITheme.label(ready_txt, 28, UITheme.C_GOOD if (bool(p["ready"]) or is_host_row) else Color(0.7, 0.7, 0.8))
		st.custom_minimum_size = Vector2(120, 0)
		r.add_child(st)
		if host and not is_host_row:
			r.add_child(UITheme.label("%dms" % NetManager.get_peer_ping(int(pid)), 22))
			var kick: Button = UITheme.small_button("Kick")
			kick.custom_minimum_size = Vector2(120, 76)
			kick.add_theme_font_size_override("font_size", 22)
			var id: int = int(pid)
			kick.pressed.connect(func() -> void: NetManager.kick(id))
			r.add_child(kick)
	var lvl_name: String = str(LevelCatalog.info(NetManager.lobby_level_id).get("name", NetManager.lobby_level_id))
	_info_label.text = "Job: %s\nDifficulty: %s" % [lvl_name, str((Tuning.DIFFICULTY[GameState.difficulty] as Dictionary)["name"])]
	if _start != null:
		_start.disabled = not NetManager.all_ready()
		_start.text = "START!" if NetManager.all_ready() else "Waiting for READY..."
	_refresh_previews()


## Little 3D plumbers in the backdrop so everyone sees each other's outfits.
func _refresh_previews() -> void:
	for c: Node in _preview_root.get_children():
		c.queue_free()
	var i: int = 0
	for pid: Variant in NetManager.get_player_ids():
		var look: PlumberLook = NetManager.get_look(int(pid))
		if look == null:
			look = PlumberLook.default_for(i)
		var pv: Node3D = PlumberMeshBuilder.build_preview(look)
		pv.position = Vector3(-1.2 + float(i) * 0.9, 0.0, 0.0)
		pv.rotation = Vector3(0, -0.3 + 0.15 * float(i), 0)
		pv.scale = Vector3.ONE * 0.9
		_preview_root.add_child(pv)
		var tag: Label3D = Label3D.new()
		tag.text = str((NetManager.players[pid] as Dictionary)["name"])
		tag.font_size = 48
		tag.outline_size = 12
		tag.pixel_size = 0.004
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0, 2.0, 0)
		pv.add_child(tag)
		i += 1


func _process(_delta: float) -> void:
	if not multiplayer.is_server() and NetManager.mode == NetManager.Mode.OFFLINE:
		GameState.goto_screen("main_menu")


func _exit_tree() -> void:
	if NetManager.players_changed.is_connected(_refresh):
		NetManager.players_changed.disconnect(_refresh)
	if NetManager.lobby_info_changed.is_connected(_refresh):
		NetManager.lobby_info_changed.disconnect(_refresh)
	if NetManager.upnp_changed.is_connected(_refresh):
		NetManager.upnp_changed.disconnect(_refresh)
