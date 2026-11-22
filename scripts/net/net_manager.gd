extends Node
## NetManager (autoload): hosting, joining, the lobby and game sync.
## -----------------------------------------------------------------------------
## Model: HOST-AUTHORITATIVE listen server. The host (peer 1) runs all physics
## and rules. Clients send input 30x/s and draw what the host sends:
##   - snapshots 20x/s (unreliable): plumber poses, awake props, goo
##   - level state 5x/s: sludge, timer, work orders, object states
##   - reliable events: start level, spawn/despawn, gravity shifts (in
##     GravityManager), ducks, results, toasts...
## Solo is simply a host with no clients (OfflineMultiplayerPeer).
## Every RPC lives on this autoload, so node paths always match.
## Clients are untrusted: everything they send is validated and clamped.
## See docs/NETWORK.md for ports, messages and bandwidth.

signal players_changed
signal connection_changed(state: String, message: String)   ## "connecting" / "connected" / "failed" / "closed"
signal lobby_info_changed
signal upnp_changed

enum Mode { OFFLINE, HOSTING, CONNECTING, CLIENT }

var mode: Mode = Mode.OFFLINE
var players: Dictionary = {}          ## peer_id -> {"name", "look", "ready", "index", "fake"}
var room_name: String = "Space Station"
var port: int = 24777
var lobby_level_id: String = "bathroom"
var host_version: String = ""
var local_ips: Array = []
var room_code: String = ""
var internet_code: String = ""
var upnp_message: String = ""
var bytes_up_per_sec: float = 0.0
var bytes_down_per_sec: float = 0.0
var sim_latency_ms: int = 0           ## debug: fake extra latency on unreliable traffic
var sim_loss: float = 0.0             ## debug: fake packet loss 0..1
var puppet_simple_rig: bool = false   ## clients build puppets with the host's rig type
var host_paused: bool = false

var _transport: TransportENet = TransportENet.new()
var _lan: LanDiscovery
var _upnp: UpnpHelper
var _runner: LevelRunner = null
var _local_input: LocalInput = null
var _input_t: float = 0.0
var _snap_t: float = 0.0
var _snap_seq: int = 0
var _stat_t: float = 0.0
var _ping_t: float = 0.0
var _ping_ms: int = 0
var _pings: Dictionary = {}           ## host: peer -> ms
var _input_counts: Dictionary = {}    ## host: peer -> packets this second (rate limit)
var _connect_timer: float = -1.0
var _snapshots: Array = []            ## client: recent decoded snapshots (oldest first)
var _time_offset: float = 0.0
var _have_offset: bool = false
var _goo_seen: Dictionary = {}
var _outbox: Array = []               ## [due_msec, Callable] for simulated latency
var _bots: Dictionary = {}            ## fake peer id -> BotBrain
var _next_fake_id: int = 100000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lan = LanDiscovery.new()
	_lan.name = "LanDiscovery"
	add_child(_lan)
	_upnp = UpnpHelper.new()
	_upnp.name = "Upnp"
	add_child(_upnp)
	_upnp.finished.connect(_on_upnp_finished)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	port = Tuning.DEFAULT_PORT
	_reset_players_solo()


# --- Basic queries -------------------------------------------------------------

func mode_name() -> String:
	return ["offline", "hosting", "connecting", "client"][int(mode)]


func is_online() -> bool:
	return mode == Mode.HOSTING or mode == Mode.CLIENT


func is_client() -> bool:
	return mode == Mode.CLIENT


func peer_count() -> int:
	return multiplayer.get_peers().size() if is_online() else 0


func player_count() -> int:
	return players.size()


## Player peer ids sorted by player index (host first).
func get_player_ids() -> Array:
	var ids: Array = players.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((players[a] as Dictionary)["index"]) < int((players[b] as Dictionary)["index"]))
	return ids


func get_ping_ms() -> int:
	return _ping_ms


func get_peer_ping(peer_id: int) -> int:
	return int(_pings.get(peer_id, 0))


func get_player_name(peer_id: int) -> String:
	var p: Dictionary = players.get(peer_id, {})
	return str(p.get("name", "Plumber"))


func get_look(peer_id: int) -> PlumberLook:
	var p: Dictionary = players.get(peer_id, {})
	var b: Variant = p.get("look", PackedByteArray())
	if b is PackedByteArray and (b as PackedByteArray).size() >= 2:
		return PlumberLook.from_bytes(b as PackedByteArray)
	return null


func get_player_index(peer_id: int) -> int:
	return int((players.get(peer_id, {}) as Dictionary).get("index", 0))


func is_fake(peer_id: int) -> bool:
	return bool((players.get(peer_id, {}) as Dictionary).get("fake", false))


func _my_name() -> String:
	return str(SaveData.data.get("player_name", "Plumber")).substr(0, 16)


func _my_look() -> PackedByteArray:
	var b: PackedByteArray = SaveData.get_look_bytes()
	if b.size() < 2:
		b = PlumberLook.default_for(0).to_bytes()
	return b


## Settings > "Random on join": a fresh random outfit every match.
func maybe_random_look() -> void:
	if not SaveData.setting_b("random_on_join"):
		return
	var b: PackedByteArray = SaveData.get_look_bytes()
	var look: PlumberLook = PlumberLook.from_bytes(b) if b.size() >= 2 else PlumberLook.default_for(0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	look.randomize_look(rng, [], SaveData.duck_count())
	SaveData.set_look_bytes(look.to_bytes())
	SaveData.save()


func _reset_players_solo() -> void:
	players.clear()
	players[1] = {"name": _my_name(), "look": _my_look(), "ready": true, "index": 0, "fake": false}
	_bots.clear()


# --- Solo / leave -------------------------------------------------------------

func start_solo() -> void:
	_close_network()
	mode = Mode.OFFLINE
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_reset_players_solo()
	players_changed.emit()


func leave_session() -> void:
	if mode == Mode.HOSTING:
		_upnp.cleanup()
	start_solo()


func _close_network() -> void:
	_lan.stop()
	_transport.close()
	_snapshots.clear()
	_have_offset = false
	_connect_timer = -1.0
	_outbox.clear()
	host_paused = false
	room_code = ""
	internet_code = ""
	upnp_message = ""


## Refresh my name/look in the player list (after customising).
func update_my_info() -> void:
	var me: int = multiplayer.get_unique_id()
	if players.has(me):
		(players[me] as Dictionary)["name"] = _my_name()
		(players[me] as Dictionary)["look"] = _my_look()
	if mode == Mode.CLIENT:
		_rpc_set_look.rpc_id(1, _my_look(), _my_name())
	elif mode == Mode.HOSTING:
		_broadcast_players()
	players_changed.emit()


# --- Hosting -------------------------------------------------------------------

func host_game(new_room_name: String, new_port: int) -> Error:
	_close_network()
	maybe_random_look()
	port = clampi(new_port, 1024, 65535)
	var err: Error = _transport.create_server(port, maxi(1, Tuning.MAX_PLAYERS - 1))
	if err != OK:
		GameLog.warn("Could not host on port %d (error %d)" % [port, err])
		return err
	multiplayer.multiplayer_peer = _transport.get_peer()
	mode = Mode.HOSTING
	room_name = new_room_name.strip_edges().substr(0, 24)
	if room_name == "":
		room_name = _my_name() + "'s Station"
	_reset_players_solo()
	local_ips = NetUtil.local_ipv4_candidates()
	room_code = RoomCode.encode(NetUtil.best_local_ip(), port)
	_lan.start_beacon(_beacon_info())
	upnp_message = "Trying internet play (UPnP)..."
	_upnp.start(port)
	GameLog.info("Hosting '%s' on port %d, IPs %s, code %s" % [room_name, port, str(local_ips), room_code])
	players_changed.emit()
	return OK


func _beacon_info() -> Dictionary:
	return {"game": "gravity_plumbers", "n": room_name, "l": str(LevelCatalog.info(lobby_level_id).get("name", lobby_level_id)),
		"c": players.size(), "m": Tuning.MAX_PLAYERS, "v": Tuning.GAME_VERSION, "p": port}


func _on_upnp_finished(ok: bool, ext_ip: String, msg: String) -> void:
	upnp_message = msg
	if ok:
		internet_code = RoomCode.encode(ext_ip, port)
	upnp_changed.emit()


func set_lobby_level(level_id: String) -> void:
	lobby_level_id = level_id
	if mode == Mode.HOSTING:
		_lan.beacon = _beacon_info()
		_rpc_lobby_info.rpc(room_name, lobby_level_id, GameState.difficulty)
	lobby_info_changed.emit()


func set_difficulty(d: int) -> void:
	GameState.difficulty = clampi(d, 0, 2)
	if mode == Mode.HOSTING:
		_rpc_lobby_info.rpc(room_name, lobby_level_id, GameState.difficulty)
	lobby_info_changed.emit()


func all_ready() -> bool:
	for k: Variant in players.keys():
		if int(k) != 1 and not bool((players[k] as Dictionary)["ready"]):
			return false
	return true


func kick(peer_id: int) -> void:
	if mode != Mode.HOSTING or peer_id == 1:
		return
	if is_fake(peer_id):
		_remove_player(peer_id)
		return
	_rpc_kicked.rpc_id(peer_id, "The host removed you from the room.")
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if _transport.peer != null:
			_transport.peer.disconnect_peer(peer_id))


## Debug: a pretend remote player driven by a bot (its input goes through the
## same encode -> (simulated latency/loss) -> decode path as real clients).
func add_fake_bot() -> void:
	if players.size() >= Tuning.MAX_PLAYERS:
		return
	var id: int = _next_fake_id
	_next_fake_id += 1
	players[id] = {"name": "TestBot %d" % (id - 99999), "look": PlumberLook.default_for(players.size()).to_bytes(),
		"ready": true, "index": _free_index(), "fake": true}
	_broadcast_players()
	if _runner != null and is_instance_valid(_runner):
		_spawn_late(id)


func _free_index() -> int:
	var used: Dictionary = {}
	for k: Variant in players.keys():
		used[int((players[k] as Dictionary)["index"])] = true
	for i: int in 8:
		if not used.has(i):
			return i
	return players.size()


func _broadcast_players() -> void:
	players_changed.emit()
	if mode != Mode.HOSTING:
		return
	_lan.beacon = _beacon_info()
	_rpc_player_list.rpc(_players_to_array())


func _players_to_array() -> Array:
	var arr: Array = []
	for k: Variant in get_player_ids():
		var p: Dictionary = players[k] as Dictionary
		arr.append([int(k), str(p["name"]), p["look"] as PackedByteArray, bool(p["ready"]), int(p["index"]), bool(p.get("fake", false))])
	return arr


func _on_peer_connected(peer_id: int) -> void:
	if mode == Mode.HOSTING:
		GameLog.info("Peer %d connected, waiting for hello" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if mode == Mode.HOSTING:
		GameLog.info("Peer %d left" % peer_id)
		_remove_player(peer_id)


func _remove_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	var nm: String = get_player_name(peer_id)
	players.erase(peer_id)
	if _bots.has(peer_id):
		var b: Node = _bots[peer_id] as Node
		if is_instance_valid(b):
			b.queue_free()
		_bots.erase(peer_id)
	if _runner != null and is_instance_valid(_runner):
		_runner.despawn_plumber(peer_id)
		if _runner.hud != null:
			_runner.hud.say("%s left the station." % nm, 2.5)
	if mode == Mode.HOSTING:
		_rpc_despawn_player.rpc(peer_id)
	_broadcast_players()


# --- Joining -------------------------------------------------------------------

func join_game(ip: String, join_port: int) -> Error:
	_close_network()
	maybe_random_look()
	var err: Error = _transport.create_client(ip, clampi(join_port, 1, 65535))
	if err != OK:
		connection_changed.emit("failed", "Couldn't start connecting (error %d)." % err)
		return err
	multiplayer.multiplayer_peer = _transport.get_peer()
	mode = Mode.CONNECTING
	_connect_timer = Tuning.CONNECT_TIMEOUT
	SaveData.data["last_ip"] = ip
	SaveData.data["last_port"] = join_port
	connection_changed.emit("connecting", "Connecting to %s:%d..." % [ip, join_port])
	return OK


func cancel_join() -> void:
	start_solo()
	connection_changed.emit("closed", "")


func _on_connected_to_server() -> void:
	_connect_timer = -1.0
	_rpc_hello.rpc_id(1, Tuning.GAME_VERSION, Tuning.PROTOCOL_VERSION, _my_name(), _my_look())


func _on_connection_failed() -> void:
	start_solo()
	connection_changed.emit("failed", "Couldn't reach the host. Same Wi-Fi? Right code?")


func _on_server_disconnected() -> void:
	var was_in_game: bool = mode == Mode.CLIENT
	start_solo()
	if was_in_game:
		GameState.menu_message = "The host left the game."
		GameState.goto_screen("main_menu")
	connection_changed.emit("closed", "Disconnected from host.")


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(version: String, protocol: int, pname: String, look: PackedByteArray) -> void:
	if mode != Mode.HOSTING:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if protocol != Tuning.PROTOCOL_VERSION or version != Tuning.GAME_VERSION:
		_rpc_rejected.rpc_id(sender, "Update needed: the host has version %s, you have %s." % [Tuning.GAME_VERSION, version])
		_drop_later(sender)
		return
	if players.size() >= Tuning.MAX_PLAYERS:
		_rpc_rejected.rpc_id(sender, "That station is full (%d plumbers)." % Tuning.MAX_PLAYERS)
		_drop_later(sender)
		return
	var clean_name: String = pname.strip_edges().substr(0, 16)
	if clean_name == "":
		clean_name = "Plumber"
	var clean_look: PlumberLook = PlumberLook.from_bytes(look.slice(0, 32))
	players[sender] = {"name": clean_name, "look": clean_look.to_bytes(), "ready": false, "index": _free_index(), "fake": false}
	GameLog.info("Player %s joined as peer %d" % [clean_name, sender])
	_rpc_welcome.rpc_id(sender, room_name, lobby_level_id, GameState.difficulty, Tuning.GAME_VERSION)
	_broadcast_players()
	if _runner != null and is_instance_valid(_runner) and not _runner.finished:
		# Mid-level join: send them into the current level and spawn them.
		_rpc_start_level.rpc_id(sender, _runner.level_id, GameState.difficulty, Quality.simple_ragdoll)
		_spawn_late(sender)
		if _runner.hud != null:
			_runner.hud.say("%s beamed aboard!" % clean_name, 2.5)


func _spawn_late(peer_id: int) -> void:
	var idx: int = int((players[peer_id] as Dictionary)["index"])
	_runner.spawn_plumber(peer_id, idx)
	_attach_bot_if_fake(peer_id)
	_rpc_spawn_player.rpc(peer_id, idx)


func _drop_later(peer_id: int) -> void:
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if _transport.peer != null and mode == Mode.HOSTING:
			_transport.peer.disconnect_peer(peer_id))


@rpc("authority", "call_remote", "reliable")
func _rpc_rejected(msg: String) -> void:
	start_solo()
	connection_changed.emit("failed", msg)


@rpc("authority", "call_remote", "reliable")
func _rpc_welcome(host_room: String, level_id: String, difficulty: int, version: String) -> void:
	mode = Mode.CLIENT
	room_name = host_room.substr(0, 24)
	lobby_level_id = level_id
	GameState.difficulty = clampi(difficulty, 0, 2)
	host_version = version
	connection_changed.emit("connected", "Joined %s!" % room_name)
	if GameState.current_screen_id != "game":
		GameState.goto_screen("lobby")


@rpc("authority", "call_remote", "reliable")
func _rpc_lobby_info(host_room: String, level_id: String, difficulty: int) -> void:
	room_name = host_room.substr(0, 24)
	lobby_level_id = level_id
	GameState.difficulty = clampi(difficulty, 0, 2)
	lobby_info_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_player_list(list: Array) -> void:
	players.clear()
	for item: Variant in list:
		if not (item is Array) or (item as Array).size() < 6:
			continue
		var a: Array = item as Array
		var look_b: PackedByteArray = a[2] as PackedByteArray if a[2] is PackedByteArray else PackedByteArray()
		players[int(a[0])] = {"name": str(a[1]).substr(0, 16), "look": PlumberLook.from_bytes(look_b).to_bytes(),
			"ready": bool(a[3]), "index": clampi(int(a[4]), 0, 7), "fake": bool(a[5])}
	players_changed.emit()


func set_ready(ready: bool) -> void:
	if mode == Mode.CLIENT:
		_rpc_set_ready.rpc_id(1, ready)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_ready(ready: bool) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if mode == Mode.HOSTING and players.has(sender):
		(players[sender] as Dictionary)["ready"] = ready
		_broadcast_players()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_look(look: PackedByteArray, pname: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if mode == Mode.HOSTING and players.has(sender):
		(players[sender] as Dictionary)["look"] = PlumberLook.from_bytes(look.slice(0, 32)).to_bytes()
		var n: String = pname.strip_edges().substr(0, 16)
		if n != "":
			(players[sender] as Dictionary)["name"] = n
		_broadcast_players()


@rpc("authority", "call_remote", "reliable")
func _rpc_kicked(msg: String) -> void:
	start_solo()
	GameState.menu_message = msg
	GameState.goto_screen("main_menu")


# --- Level flow ----------------------------------------------------------------

func host_start_level(level_id: String) -> void:
	if mode == Mode.HOSTING:
		_rpc_start_level.rpc(level_id, GameState.difficulty, Quality.simple_ragdoll)
		_rpc_start_level(level_id, GameState.difficulty, Quality.simple_ragdoll)
	elif mode == Mode.OFFLINE:
		puppet_simple_rig = Quality.simple_ragdoll
		GameState.start_level(level_id)


@rpc("authority", "call_remote", "reliable")
func _rpc_start_level(level_id: String, difficulty: int, simple_rig: bool) -> void:
	if not LevelCatalog.exists(level_id):
		return
	GameState.difficulty = clampi(difficulty, 0, 2)
	puppet_simple_rig = simple_rig
	_snapshots.clear()
	_have_offset = false
	GameState.start_level(level_id)


## Results screen "Back to Lobby" (host).
func goto_lobby() -> void:
	if mode == Mode.HOSTING:
		_rpc_goto_lobby.rpc()
	GameState.goto_screen("lobby")


@rpc("authority", "call_remote", "reliable")
func _rpc_goto_lobby() -> void:
	GameState.goto_screen("lobby")


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_player(peer_id: int, index: int) -> void:
	if _runner != null and is_instance_valid(_runner):
		_runner.spawn_plumber(peer_id, clampi(index, 0, 7))


@rpc("authority", "call_remote", "reliable")
func _rpc_despawn_player(peer_id: int) -> void:
	if _runner != null and is_instance_valid(_runner):
		_runner.despawn_plumber(peer_id)


func level_started(runner: LevelRunner) -> void:
	_runner = runner
	if mode == Mode.HOSTING:
		for k: Variant in players.keys():
			_attach_bot_if_fake(int(k))
	elif mode == Mode.OFFLINE:
		for k2: Variant in players.keys():
			_attach_bot_if_fake(int(k2))
	if mode == Mode.CLIENT:
		# Clients never simulate props: they're moved by snapshots.
		for rb: Variant in runner.dyn_props:
			var body: RigidBody3D = rb as RigidBody3D
			if is_instance_valid(body):
				body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
				body.freeze = true
		_rpc_request_sync.rpc_id(1)


func level_ended(runner: LevelRunner) -> void:
	if _runner == runner:
		_runner = null
	_bots.clear()


func _attach_bot_if_fake(peer_id: int) -> void:
	if not is_fake(peer_id) or _runner == null or _bots.has(peer_id):
		return
	var p: Plumber = _runner.plumbers.get(peer_id) as Plumber
	if p == null:
		return
	var bot: BotBrain = BotBrain.new()
	bot.name = "FakeRemote_%d" % peer_id
	bot.route_input = func(bytes: PackedByteArray) -> void: _send_sim(func() -> void: _apply_input(peer_id, bytes))
	bot.plumber = p
	_runner.add_child(bot)
	_bots[peer_id] = bot


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_sync() -> void:
	if mode != Mode.HOSTING or _runner == null or not is_instance_valid(_runner):
		return
	var sender: int = multiplayer.get_remote_sender_id()
	_rpc_gravity_sync.rpc_id(sender, GravityManager.get_state())
	_rpc_level_state_reliable.rpc_id(sender, _runner.get_level_state())
	for d: Variant in _runner.ducks_found:
		_rpc_event_remote.rpc_id(sender, "duck", [str(d)])


@rpc("authority", "call_remote", "reliable")
func _rpc_gravity_sync(state: Dictionary) -> void:
	GravityManager.apply_state(state)


func set_local_input(input: LocalInput) -> void:
	_local_input = input


func send_level_state(state: Dictionary, reliable: bool = false) -> void:
	if mode != Mode.HOSTING or peer_count() == 0:
		return
	if reliable:
		_rpc_level_state_reliable.rpc(state)
	else:
		_rpc_level_state.rpc(state)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _rpc_level_state(state: Dictionary) -> void:
	if _runner != null and is_instance_valid(_runner):
		_runner.apply_level_state(state)


@rpc("authority", "call_remote", "reliable")
func _rpc_level_state_reliable(state: Dictionary) -> void:
	_rpc_level_state(state)


func broadcast_results(results: Dictionary) -> void:
	if mode == Mode.HOSTING:
		_rpc_results.rpc(results)


@rpc("authority", "call_remote", "reliable")
func _rpc_results(results: Dictionary) -> void:
	GameState.last_results = results
	GameState.goto_screen("results")


## Reliable game event to everyone (handled locally too).
func broadcast_event(event_name: String, args: Array) -> void:
	_handle_event(event_name, args)
	if mode == Mode.HOSTING and peer_count() > 0:
		_rpc_event_remote.rpc(event_name, args)


func send_event_to(peer_id: int, event_name: String, args: Array) -> void:
	if peer_id == multiplayer.get_unique_id():
		_handle_event(event_name, args)
	elif mode == Mode.HOSTING and not is_fake(peer_id):
		_rpc_event_remote.rpc_id(peer_id, event_name, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_event_remote(event_name: String, args: Array) -> void:
	_handle_event(event_name, args)


func _handle_event(event_name: String, args: Array) -> void:
	if event_name == "host_paused":
		host_paused = args.size() > 0 and bool(args[0])
	if _runner == null or not is_instance_valid(_runner):
		return
	match event_name:
		"duck":
			if args.size() > 0:
				_runner.apply_duck(str(args[0]).substr(0, 32))
		"toast":
			if args.size() > 0 and _runner.hud != null:
				_runner.hud.say(str(args[0]).substr(0, 120), 3.0)
		"open_mirror":
			_runner.open_mirror()
		"flushed":
			if args.size() > 0 and mode == Mode.CLIENT:
				var p: Plumber = _runner.plumbers.get(int(args[0])) as Plumber
				if p != null:
					FX.flush_swirl(_runner, p.get_center())
		"host_paused":
			if _runner.hud != null and mode == Mode.CLIENT:
				_runner.hud.say("The host paused the app..." if host_paused else "The host is back!", 3.0)


# --- Input (client -> host) ----------------------------------------------------

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_input(bytes: PackedByteArray) -> void:
	if mode != Mode.HOSTING:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not players.has(sender):
		return
	var n: int = int(_input_counts.get(sender, 0)) + 1
	_input_counts[sender] = n
	if n > 70:
		return   # rate limit: ignore floods
	_apply_input(sender, bytes)


func _apply_input(peer_id: int, bytes: PackedByteArray) -> void:
	if _runner == null or not is_instance_valid(_runner) or bytes.size() != 8:
		return
	var p: Plumber = _runner.plumbers.get(peer_id) as Plumber
	if p == null or p.is_puppet:
		return
	p.input.copy_from(PlumberInput.from_bytes(bytes))


# --- Snapshots (host -> clients) -------------------------------------------------

func _build_snapshot() -> PackedByteArray:
	var plumber_states: Array = []
	for v: Variant in _runner.plumbers.values():
		var p: Plumber = v as Plumber
		if not is_instance_valid(p):
			continue
		var parts: Array = []
		for rb: RigidBody3D in p.body_list:
			parts.append([rb.global_position, rb.global_basis.get_rotation_quaternion()])
		var flags: int = 0
		if p.boots_on:
			flags |= SnapshotSync.F_BOOTS_ON
		if p.boots_active:
			flags |= SnapshotSync.F_BOOTS_ACTIVE
		if p.celebrate_time > 0.0:
			flags |= SnapshotSync.F_CELEBRATE
		if p.emote_time > 0.0:
			flags |= SnapshotSync.F_EMOTE | ((p.emote_id & 7) << 4)
		plumber_states.append({"index": p.player_index, "state": int(p.state), "flags": flags,
			"up": p.local_up, "vel": p.get_velocity(), "parts": parts})
	# Props: awake/moving ones first (they matter most), sleeping ones rarely.
	var moving: Array = []
	var resting: Array = []
	for i: int in _runner.dyn_props.size():
		var rb2: RigidBody3D = _runner.dyn_props[i] as RigidBody3D
		if not is_instance_valid(rb2):
			continue
		var entry: Array = [i + 1, rb2.global_position, rb2.global_basis.get_rotation_quaternion()]
		if rb2.sleeping or (rb2.freeze and rb2.freeze_mode == RigidBody3D.FREEZE_MODE_STATIC):
			if (_snap_seq + i) % 20 == 0:
				resting.append(entry)
		else:
			moving.append(entry)
	moving.append_array(resting)
	var goo: Array = _runner.goo_pool.get_active() if _runner.goo_pool != null else []
	return SnapshotSync.encode(_snap_seq, _now(), plumber_states, moving, goo, LevelBounds.center, Tuning.SNAPSHOT_BYTE_BUDGET)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _rpc_snapshot(bytes: PackedByteArray) -> void:
	if mode != Mode.CLIENT:
		return
	var d: Dictionary = SnapshotSync.decode(bytes, LevelBounds.center)
	if d.is_empty():
		return
	var t: float = float(d["time"])
	var off: float = _now() - t
	if not _have_offset:
		_time_offset = off
		_have_offset = true
	else:
		# Smooth, but jump quickly if packets start arriving earlier than expected.
		_time_offset = minf(off, lerpf(_time_offset, off, 0.05))
	if _snapshots.size() > 0 and float((_snapshots[_snapshots.size() - 1] as Dictionary)["time"]) >= t:
		return   # out of order / duplicate
	_snapshots.append(d)
	while _snapshots.size() > 10:
		_snapshots.pop_front()


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## Client: move puppets to the interpolated pose ~100 ms in the past.
func _apply_snapshots() -> void:
	if _snapshots.is_empty() or _runner == null or not is_instance_valid(_runner):
		return
	var render_t: float = _now() - _time_offset - Tuning.INTERP_DELAY
	var a: Dictionary = _snapshots[0] as Dictionary
	var b: Dictionary = a
	for i: int in _snapshots.size():
		var s: Dictionary = _snapshots[i] as Dictionary
		if float(s["time"]) <= render_t:
			a = s
			b = _snapshots[mini(i + 1, _snapshots.size() - 1)] as Dictionary
	var ta: float = float(a["time"])
	var tb: float = float(b["time"])
	var t: float = 0.0 if tb <= ta else clampf((render_t - ta) / (tb - ta), 0.0, 1.0)
	var extrap: float = clampf(render_t - tb, 0.0, Tuning.EXTRAPOLATE_MAX) if a == b else 0.0
	var by_index: Dictionary = {}
	for v: Variant in _runner.plumbers.values():
		by_index[(v as Plumber).player_index] = v
	var a_pl: Dictionary = {}
	for pa: Variant in a["plumbers"]:
		a_pl[int((pa as Dictionary)["index"])] = pa
	for pb: Variant in b["plumbers"]:
		var pdb: Dictionary = pb as Dictionary
		var idx: int = int(pdb["index"])
		var p: Plumber = by_index.get(idx) as Plumber
		if p == null or not is_instance_valid(p):
			continue
		var parts: Array = pdb["parts"]
		if a_pl.has(idx):
			parts = SnapshotSync.lerp_parts((a_pl[idx] as Dictionary)["parts"] as Array, parts, t)
		var vel: Vector3 = pdb.get("vel", Vector3.ZERO) as Vector3
		var shift: Vector3 = vel * extrap
		for j: int in mini(parts.size(), p.body_list.size()):
			var part: Array = parts[j] as Array
			p.body_list[j].global_transform = Transform3D(Basis(part[1] as Quaternion), (part[0] as Vector3) + shift)
		p.apply_puppet_state(int(pdb["state"]), int(pdb["flags"]), pdb.get("up", Vector3.UP) as Vector3, vel)
	# Props.
	var a_props: Dictionary = {}
	for pr: Variant in a["props"]:
		a_props[int((pr as Array)[0])] = pr
	for pr2: Variant in b["props"]:
		var arr: Array = pr2 as Array
		var id: int = int(arr[0])
		if id < 1 or id > _runner.dyn_props.size():
			continue
		var body: RigidBody3D = _runner.dyn_props[id - 1] as RigidBody3D
		if not is_instance_valid(body):
			continue
		var pos: Vector3 = arr[1] as Vector3
		var q: Quaternion = arr[2] as Quaternion
		if a_props.has(id):
			var aa: Array = a_props[id] as Array
			pos = (aa[1] as Vector3).lerp(pos, t)
			q = (aa[2] as Quaternion).slerp(q, t)
		body.global_transform = Transform3D(Basis(q), pos)
	# Goo.
	if _runner.goo_pool != null:
		var seen: Dictionary = {}
		for g: Variant in b["goo"]:
			var ga: Array = g as Array
			seen[int(ga[0])] = true
			_runner.goo_pool.client_show(int(ga[0]), ga[1] as Vector3)
		_runner.goo_pool.client_hide_except(seen)


# --- Tick ----------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if mode == Mode.CONNECTING and _connect_timer >= 0.0:
		_connect_timer -= dt
		if _connect_timer < 0.0:
			start_solo()
			connection_changed.emit("failed", "Timed out. Check the code, and that you're on the same Wi-Fi or hotspot.")
	if mode == Mode.CLIENT:
		_apply_snapshots()
		_input_t -= dt
		if _input_t <= 0.0 and _local_input != null and is_instance_valid(_local_input) and _runner != null:
			_input_t = 1.0 / Tuning.INPUT_SEND_RATE
			var bytes: PackedByteArray = _local_input.frame.to_bytes()
			_send_sim(func() -> void:
				if mode == Mode.CLIENT:
					_rpc_input.rpc_id(1, bytes))
	elif mode == Mode.HOSTING and _runner != null and is_instance_valid(_runner) and peer_count() > 0:
		_snap_t -= dt
		if _snap_t <= 0.0:
			_snap_t = 1.0 / Tuning.SNAPSHOT_RATE
			_snap_seq += 1
			var snap: PackedByteArray = _build_snapshot()
			_send_sim(func() -> void:
				if mode == Mode.HOSTING:
					_rpc_snapshot.rpc(snap))


func _process(delta: float) -> void:
	# Simulated latency / loss outbox.
	if not _outbox.is_empty():
		var now: int = Time.get_ticks_msec()
		while not _outbox.is_empty() and int((_outbox[0] as Array)[0]) <= now:
			var item: Array = _outbox.pop_front()
			(item[1] as Callable).call()
	_stat_t -= delta
	if _stat_t <= 0.0:
		_stat_t = 1.0
		var tr: Vector2 = _transport.pop_traffic()
		bytes_up_per_sec = tr.x
		bytes_down_per_sec = tr.y
		_input_counts.clear()
	_ping_t -= delta
	if _ping_t <= 0.0 and is_online():
		_ping_t = 1.0
		if mode == Mode.CLIENT:
			_rpc_ping.rpc_id(1, _now())
		elif mode == Mode.HOSTING:
			for pid: int in multiplayer.get_peers():
				_rpc_ping.rpc_id(pid, _now())


## Send now, or later / never when simulating a bad network (debug).
func _send_sim(cb: Callable) -> void:
	if sim_loss > 0.0 and randf() < sim_loss:
		return
	if sim_latency_ms <= 0:
		cb.call()
		return
	_outbox.append([Time.get_ticks_msec() + sim_latency_ms, cb])


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_ping(t: float) -> void:
	_rpc_pong.rpc_id(multiplayer.get_remote_sender_id(), t)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_pong(t: float) -> void:
	var rtt: int = int((_now() - t) * 1000.0)
	if rtt < 0 or rtt > 10000:
		return
	if mode == Mode.CLIENT:
		_ping_ms = rtt
	else:
		_pings[multiplayer.get_remote_sender_id()] = rtt
		_ping_ms = rtt


# --- Desktop test flags --------------------------------------------------------

## godot -- --server            host immediately and open the lobby
## godot -- --client=1.2.3.4    join that host (port from --port=, default 24777)
func handle_cmdline(args: PackedStringArray) -> bool:
	var p: int = Tuning.DEFAULT_PORT
	for a: String in args:
		if a.begins_with("--port="):
			p = a.substr(7).to_int()
	for a2: String in args:
		if a2 == "--server":
			if host_game(_my_name() + "'s Station", p) == OK:
				GameState.goto_screen("lobby")
				return true
		elif a2.begins_with("--client="):
			join_game(a2.substr(9), p)
			GameState.goto_screen("host_join", {"tab": "join"})
			return true
	return false
