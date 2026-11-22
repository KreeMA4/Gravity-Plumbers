extends Node
## NetManager (autoload) - M0 version: offline only.
## The full host/join implementation arrives in milestone M7.
## Solo play already uses Godot's default OfflineMultiplayerPeer, which makes
## this machine the "server" (peer 1), so the host-authoritative code path is
## the same for solo and online.

var bytes_up_per_sec: float = 0.0
var bytes_down_per_sec: float = 0.0


func mode_name() -> String:
	return "offline"


func peer_count() -> int:
	return 0


func get_ping_ms() -> int:
	return 0


## Handles desktop test flags. Returns true if it took over the boot flow.
func handle_cmdline(_args: PackedStringArray) -> bool:
	return false


## Solo play: make sure we are an offline "host" (peer 1, no clients).
func start_solo() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
