class_name RoomCode
extends RefCounted
## Room codes: the host's IPv4 address (4 bytes) + port (2 bytes) written in
## Crockford base32 as XXXXX-XXXXX. No server needed: the code IS the address.
## decode() is forgiving: lowercase, missing/extra dashes and spaces are fine,
## and the look-alike letters O->0, I/L->1 are fixed automatically.

const ALPHABET: String = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const CODE_LEN: int = 10


## "192.168.1.20", 24777 -> "60R2G-0A5XS" style code. Returns "" for a bad IP.
static func encode(ip: String, port: int) -> String:
	var parts: PackedStringArray = ip.split(".")
	if parts.size() != 4:
		return ""
	var value: int = 0
	for p: String in parts:
		if not p.is_valid_int():
			return ""
		var n: int = p.to_int()
		if n < 0 or n > 255:
			return ""
		value = (value << 8) | n
	if port < 1 or port > 65535:
		return ""
	value = (value << 16) | port      # 48 bits total
	var chars: String = ""
	for i: int in CODE_LEN:
		var shift: int = (CODE_LEN - 1 - i) * 5 - 2   # 50 bits of room, top 2 bits are zero
		var digit: int = (value >> shift) & 31 if shift >= 0 else (value << -shift) & 31
		chars += ALPHABET[digit]
	return chars.substr(0, 5) + "-" + chars.substr(5, 5)


## Clean up what the player typed: uppercase, strip separators, fix O/I/L.
static func normalize(code: String) -> String:
	var out: String = ""
	for c: String in code.to_upper():
		var ch: String = c
		if ch == "-" or ch == " " or ch == "_" or ch == ".":
			continue
		if ch == "O":
			ch = "0"
		elif ch == "I" or ch == "L":
			ch = "1"
		out += ch
	return out


## Returns {"ok": bool, "ip": String, "port": int, "error": String}
static func decode(code: String) -> Dictionary:
	var s: String = normalize(code)
	if s.length() != CODE_LEN:
		return {"ok": false, "error": "A room code has 10 letters/numbers (like ABCDE-12345)."}
	var value: int = 0
	for c: String in s:
		var idx: int = ALPHABET.find(c)
		if idx < 0:
			return {"ok": false, "error": "'%s' isn't used in room codes." % c}
		value = (value << 5) | idx
	value = value >> 2            # remove the 2 padding bits
	var port: int = value & 0xFFFF
	var ip_val: int = (value >> 16) & 0xFFFFFFFF
	if port == 0:
		return {"ok": false, "error": "That code doesn't look right."}
	var ip: String = "%d.%d.%d.%d" % [(ip_val >> 24) & 255, (ip_val >> 16) & 255, (ip_val >> 8) & 255, ip_val & 255]
	return {"ok": true, "ip": ip, "port": port, "error": ""}
