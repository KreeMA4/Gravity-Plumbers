class_name NetUtil
extends RefCounted
## Finding this device's local IP addresses (Wi-Fi / hotspot first).

static func is_private_ipv4(ip: String) -> bool:
	var p: PackedStringArray = ip.split(".")
	if p.size() != 4:
		return false
	var a: int = p[0].to_int()
	var b: int = p[1].to_int()
	if a == 10:
		return true
	if a == 192 and b == 168:
		return true
	if a == 172 and b >= 16 and b <= 31:
		return true
	if a == 100 and b >= 64 and b <= 127:
		return true   # carrier-grade NAT / Tailscale range
	return false


## Private IPv4 addresses, best guess first (Wi-Fi / hotspot interfaces preferred).
static func local_ipv4_candidates() -> Array:
	var scored: Array = []
	for iface: Dictionary in IP.get_local_interfaces():
		var nm: String = str(iface.get("name", "")).to_lower()
		for addr: Variant in iface.get("addresses", []):
			var ip: String = str(addr)
			if not is_private_ipv4(ip):
				continue
			var score: int = 0
			if nm.begins_with("wlan") or nm.begins_with("wl") or nm.begins_with("en") or nm.begins_with("eth"):
				score += 10
			if nm.begins_with("ap") or nm.begins_with("swlan") or nm.contains("softap") or ip.begins_with("192.168.43."):
				score += 12   # Android hotspot
			if nm.begins_with("rmnet") or nm.begins_with("ccmni") or nm.begins_with("tun") or nm.begins_with("docker"):
				score -= 20   # mobile data / VPN / containers
			if ip.begins_with("192.168."):
				score += 2
			scored.append([score, ip])
	if scored.is_empty():
		for addr2: String in IP.get_local_addresses():
			if is_private_ipv4(addr2):
				scored.append([0, addr2])
	scored.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) > int(y[0]))
	var out: Array = []
	for s: Variant in scored:
		var ip2: String = str((s as Array)[1])
		if not out.has(ip2):
			out.append(ip2)
	return out


static func best_local_ip() -> String:
	var c: Array = local_ipv4_candidates()
	return str(c[0]) if c.size() > 0 else "127.0.0.1"


## x.y.z.255 for each candidate, plus the global broadcast address.
static func broadcast_addresses() -> Array:
	var out: Array = ["255.255.255.255"]
	for ip: Variant in local_ipv4_candidates():
		var p: PackedStringArray = str(ip).split(".")
		var b: String = "%s.%s.%s.255" % [p[0], p[1], p[2]]
		if not out.has(b):
			out.append(b)
	return out
