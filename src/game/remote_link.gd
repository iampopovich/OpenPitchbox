class_name RemoteLink
extends Node
## Phones as controllers over the local network (UDP, port 47800).
## Host (the game showing the match): answers discovery and maps up to 4 phones to
## devices "remote0".."remote3" in VirtualPads.
## Client (a phone in controller mode): finds a host by broadcast and streams its pad.
## Packet: "OPBX" | u32 client id | i8 move x | i8 move y | u8 buttons.

const PORT := 47800
const MAGIC := "OPBX"
const BUTTONS := ["pass", "shoot", "lob", "aerial", "switch", "pause"]

var is_host := true
var udp := PacketPeerUDP.new()
var clients := {}          # client id -> device name
var client_id := 0
var host_ip := ""
var host_name := ""
var _search_t := 0.0
var _send_t := 0.0


func start_host() -> bool:
	is_host = true
	return udp.bind(PORT) == OK


func start_client() -> void:
	is_host = false
	client_id = randi()
	udp.set_broadcast_enabled(true)
	udp.bind(0)


func stop() -> void:
	udp.close()
	for d in clients.values():
		VirtualPads.release_all(d)
	clients.clear()


func _exit_tree() -> void:
	stop()


func _process(dt: float) -> void:
	if not udp.is_bound():
		return
	if is_host:
		_host_poll()
	else:
		_client_tick(dt)


func _host_poll() -> void:
	while udp.get_available_packet_count() > 0:
		var pkt := udp.get_packet()
		var ip := udp.get_packet_ip()
		var port := udp.get_packet_port()
		if pkt.size() < 4 or pkt.slice(0, 4).get_string_from_ascii() != MAGIC:
			continue
		if pkt.size() == 5 and pkt[4] == 63:          # "OPBX?" discovery
			udp.set_dest_address(ip, port)
			udp.put_packet((MAGIC + "!" + OS.get_name() + " · " + ProjectSettings.get_setting("application/config/name")).to_ascii_buffer())
			continue
		if pkt.size() < 11:
			continue
		var cid := pkt.decode_u32(4)
		if not clients.has(cid):
			if clients.size() >= 4:
				continue
			var used: Array = clients.values()
			for i in 4:
				if not used.has("remote%d" % i):
					clients[cid] = "remote%d" % i
					break
		var dev: String = clients[cid]
		var mv := Vector2(pkt.decode_s8(8), pkt.decode_s8(9)) / 127.0
		VirtualPads.set_move(dev, mv)
		var bits := pkt[10]
		for i in BUTTONS.size():
			VirtualPads.set_button(dev, BUTTONS[i], (bits >> i) & 1 == 1)
		VirtualPads.remote_seen[dev] = Time.get_ticks_msec()


func _client_tick(dt: float) -> void:
	while udp.get_available_packet_count() > 0:
		var pkt := udp.get_packet()
		var s := pkt.get_string_from_ascii()
		if s.begins_with(MAGIC + "!"):
			host_ip = udp.get_packet_ip()
			host_name = s.substr(5)
	if host_ip == "":
		_search_t -= dt
		if _search_t <= 0.0:
			_search_t = 1.0
			udp.set_dest_address("255.255.255.255", PORT)
			udp.put_packet((MAGIC + "?").to_ascii_buffer())
		return
	_send_t -= dt
	if _send_t > 0.0:
		return
	_send_t = 1.0 / 60.0
	var pad := VirtualPads.get_pad("remote")
	var buf := PackedByteArray()
	buf.append_array(MAGIC.to_ascii_buffer())
	buf.resize(11)
	buf.encode_u32(4, client_id)
	var mv: Vector2 = pad["move"]
	buf.encode_s8(8, int(clampf(mv.x, -1, 1) * 127))
	buf.encode_s8(9, int(clampf(mv.y, -1, 1) * 127))
	var bits := 0
	for i in BUTTONS.size():
		if pad.get(BUTTONS[i], false):
			bits |= 1 << i
	buf[10] = bits
	udp.set_dest_address(host_ip, PORT)
	udp.put_packet(buf)
