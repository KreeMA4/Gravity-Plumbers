extends TestCase
## Room code encode/decode.


func test_round_trip() -> void:
	for ip: String in ["192.168.1.20", "10.0.0.1", "192.168.43.1", "255.255.255.255", "0.0.0.1", "172.16.5.99"]:
		for port: int in [24777, 1, 65535, 8080]:
			var code: String = RoomCode.encode(ip, port)
			check_eq(code.length(), 11, "code is XXXXX-XXXXX for " + ip)
			var d: Dictionary = RoomCode.decode(code)
			check(bool(d["ok"]), "decodes " + code)
			check_eq(str(d["ip"]), ip, "ip round trip")
			check_eq(int(d["port"]), port, "port round trip")


func test_forgiving_input() -> void:
	var code: String = RoomCode.encode("192.168.1.20", 24777)
	var messy: String = code.to_lower().replace("-", " ")
	var d: Dictionary = RoomCode.decode(messy)
	check(bool(d["ok"]) and str(d["ip"]) == "192.168.1.20", "lowercase with spaces works")
	var no_dash: Dictionary = RoomCode.decode(code.replace("-", ""))
	check(bool(no_dash["ok"]), "no dash works")
	check_eq(RoomCode.normalize("o0-il1"), "00111", "O->0, I/L->1")


func test_invalid() -> void:
	check(not bool(RoomCode.decode("ABC")["ok"]), "too short")
	check(not bool(RoomCode.decode("ABCDE-FGHJKM")["ok"]), "too long")
	check(not bool(RoomCode.decode("ABCDE-FGHJU")["ok"]), "U is not in the alphabet")
	check(not bool(RoomCode.decode("ABCD!-FGHJK")["ok"]), "symbols rejected")
	check_eq(RoomCode.encode("999.1.1.1", 24777), "", "bad IP gives empty code")
	check_eq(RoomCode.encode("1.2.3", 24777), "", "short IP gives empty code")
	check_eq(RoomCode.encode("1.2.3.4", 0), "", "bad port gives empty code")
