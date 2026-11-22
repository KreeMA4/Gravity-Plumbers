class_name TransportENet
extends RefCounted
## NetTransport implementation using Godot's ENetMultiplayerPeer (UDP).
## Gameplay code never touches ENet directly, so a relay or WebRTC
## transport could be dropped in later with the same three functions.

var peer: ENetMultiplayerPeer = null


func create_server(port: int, max_clients: int) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, max_clients)
	if err != OK:
		peer = null
	return err


func create_client(address: String, port: int) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		peer = null
	return err


func get_peer() -> MultiplayerPeer:
	return peer


## Bytes sent / received since the last call (ENet statistics).
func pop_traffic() -> Vector2:
	if peer == null or peer.host == null:
		return Vector2.ZERO
	var sent: float = peer.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
	var recv: float = peer.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	return Vector2(sent, recv)


func close() -> void:
	if peer != null:
		peer.close()
	peer = null
