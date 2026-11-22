extends Node
## NetManager (autoload) - OFFLINE version (milestones M0-M6).
## The full host/join implementation replaces this file in milestone M7.
## Solo play uses Godot's default OfflineMultiplayerPeer, which makes this
## machine the "server" (peer 1), so the host-authoritative game code is the
## same for solo and online. Events are simply handled locally here.

var bytes_up_per_sec: float = 0.0
var bytes_down_per_sec: float = 0.0
var _runner: LevelRunner = null


func mode_name() -> String:
	return "offline"


func is_online() -> bool:
	return false


func peer_count() -> int:
	return 0


func player_count() -> int:
	return 1


func get_player_ids() -> Array:
	return [multiplayer.get_unique_id()]


func get_ping_ms() -> int:
	return 0


func get_player_name(_peer_id: int) -> String:
	return str(SaveData.data.get("player_name", "Plumber"))


func get_look(_peer_id: int) -> PlumberLook:
	var b: PackedByteArray = SaveData.get_look_bytes()
	if b.size() < 2:
		return null
	return PlumberLook.from_bytes(b)


## Handles desktop test flags. Returns true if it took over the boot flow.
func handle_cmdline(_args: PackedStringArray) -> bool:
	return false


## Solo play: make sure we are an offline "host" (peer 1, no clients).
func start_solo() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func leave_session() -> void:
	start_solo()


func level_started(runner: LevelRunner) -> void:
	_runner = runner


func level_ended(runner: LevelRunner) -> void:
	if _runner == runner:
		_runner = null


func set_local_input(_input: LocalInput) -> void:
	pass


func send_level_state(_state: Dictionary) -> void:
	pass


func broadcast_results(_results: Dictionary) -> void:
	pass


func broadcast_event(event_name: String, args: Array) -> void:
	_handle_event(event_name, args)


func send_event_to(peer_id: int, event_name: String, args: Array) -> void:
	if peer_id == multiplayer.get_unique_id():
		_handle_event(event_name, args)


func host_start_level(level_id: String) -> void:
	GameState.start_level(level_id)


func _handle_event(event_name: String, args: Array) -> void:
	if _runner == null or not is_instance_valid(_runner):
		return
	match event_name:
		"duck":
			if args.size() > 0:
				_runner.apply_duck(str(args[0]))
		"toast":
			if args.size() > 0 and _runner.hud != null:
				_runner.hud.say(str(args[0]), 3.0)
		"open_mirror":
			_runner.open_mirror()
