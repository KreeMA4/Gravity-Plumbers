class_name UpnpHelper
extends Node
## Best-effort internet hosting: asks the router (UPnP) to forward our UDP
## port, in a worker thread so the game never freezes. Most phone hotspots
## and many routers say no; that's fine, we explain the other options.

signal finished(ok: bool, external_ip: String, message: String)

var _thread: Thread = null
var _port: int = 0
var mapped: bool = false


func start(port: int) -> void:
	if _thread != null:
		return
	_port = port
	_thread = Thread.new()
	_thread.start(_worker)


func _worker() -> void:
	var upnp: UPNP = UPNP.new()
	var err: int = upnp.discover(2000, 2, "InternetGatewayDevice")
	if err != UPNP.UPNP_RESULT_SUCCESS:
		_done.call_deferred(false, "", "No UPnP router found (code %d)." % err)
		return
	var gw: UPNPDevice = upnp.get_gateway()
	if gw == null or not gw.is_valid_gateway():
		_done.call_deferred(false, "", "The router doesn't allow automatic port forwarding.")
		return
	var r: int = upnp.add_port_mapping(_port, _port, "Gravity Plumbers", "UDP", 0)
	if r != UPNP.UPNP_RESULT_SUCCESS:
		_done.call_deferred(false, "", "The router refused to open the port (code %d)." % r)
		return
	var ext: String = upnp.query_external_address()
	if ext == "":
		_done.call_deferred(false, "", "Port opened, but the router didn't tell us the public address.")
		return
	_done.call_deferred(true, ext, "Internet play is on (UPnP).")


func _done(ok: bool, ext: String, msg: String) -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	mapped = ok
	finished.emit(ok, ext, msg)


## Remove the port mapping (also in a thread; we don't wait for it).
func cleanup() -> void:
	if not mapped:
		return
	mapped = false
	var port: int = _port
	var t: Thread = Thread.new()
	t.start(func() -> void:
		var upnp: UPNP = UPNP.new()
		if upnp.discover(1000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS:
			upnp.delete_port_mapping(port, "UDP"))
	# Detached helper: wait for it when the node goes away.
	set_meta("cleanup_thread", t)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null
	if has_meta("cleanup_thread"):
		var t: Thread = get_meta("cleanup_thread") as Thread
		if t != null and t.is_started():
			t.wait_to_finish()
