class_name LanDiscovery
extends Node
## LAN room browsing with UDP broadcast on Tuning.DISCOVERY_PORT.
## Host: sends a small JSON beacon every second.
## Joiner: listens and keeps a list of rooms seen in the last few seconds.
## Android can refuse sockets (no Wi-Fi, permissions): every failure is
## reported as a message instead of crashing.

signal rooms_changed

var hosting: bool = false
var listening: bool = false
var beacon: Dictionary = {}           ## host: what we advertise
var rooms: Dictionary = {}            ## joiner: "ip:port" -> {info..., "ip", "seen"}
var error_text: String = ""

var _udp: PacketPeerUDP = null
var _t: float = 0.0


func start_beacon(info: Dictionary) -> void:
	stop()
	beacon = info
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	hosting = true
	error_text = ""


func start_listening() -> bool:
	stop()
	_udp = PacketPeerUDP.new()
	var err: Error = _udp.bind(Tuning.DISCOVERY_PORT, "*")
	if err != OK:
		error_text = "Can't look for LAN games on this network (error %d). Use a room code instead." % err
		_udp = null
		return false
	listening = true
	error_text = ""
	return true


func stop() -> void:
	if _udp != null:
		_udp.close()
	_udp = null
	hosting = false
	listening = false
	rooms.clear()


func _process(delta: float) -> void:
	if _udp == null:
		return
	_t -= delta
	if hosting and _t <= 0.0:
		_t = 1.0
		var pkt: PackedByteArray = JSON.stringify(beacon).to_utf8_buffer()
		for addr: Variant in NetUtil.broadcast_addresses():
			_udp.set_dest_address(str(addr), Tuning.DISCOVERY_PORT)
			_udp.put_packet(pkt)
	if listening:
		var changed: bool = false
		while _udp.get_available_packet_count() > 0:
			var data: PackedByteArray = _udp.get_packet()
			var ip: String = _udp.get_packet_ip()
			if data.size() > 512:
				continue
			var parsed: Variant = JSON.parse_string(data.get_string_from_utf8())
			if not (parsed is Dictionary):
				continue
			var info: Dictionary = parsed as Dictionary
			if str(info.get("game", "")) != "gravity_plumbers":
				continue
			var port: int = clampi(int(info.get("p", Tuning.DEFAULT_PORT)), 1, 65535)
			var key: String = "%s:%d" % [ip, port]
			info["ip"] = ip
			info["seen"] = Time.get_ticks_msec()
			if not rooms.has(key):
				changed = true
			rooms[key] = info
		var now: int = Time.get_ticks_msec()
		for k: Variant in rooms.keys():
			if now - int((rooms[k] as Dictionary)["seen"]) > 4000:
				rooms.erase(k)
				changed = true
		if changed:
			rooms_changed.emit()


func _exit_tree() -> void:
	stop()
