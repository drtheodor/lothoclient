# FIXME: `Discord` shouldn't be *the* global API wrapper thingy
extends Node

const WEBSOCKET_URL: String = "wss://gateway.discord.gg/?encoding=json&v=9&compress=zlib-stream"
const CDN_URL: String = "https://cdn.discordapp.com"
const BASE_URL: String = "https://discord.com/api/v9"

const MASQUERADE_OS: String = "Linux"
const MASQUERADE_LOCALE: String = "en-US"

const MASQUERADE_BROWSER: String = "Chrome"
const MASQUERADE_BROWSER_VERSION: String = "144.0.0.0"
const MASQUERADE_BROWSER_AGENT: String = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36"

const MASQUERADE_DISCORD_CHANNEL: String = "stable"
const MASQUERADE_DISCORD_BUILD: int = 498386

const ImageCache: GDScript = preload("res://discord/image_cache.gd")
const Gateway: GDScript = preload("res://discord/gateway.gd")

var _gateway: Gateway = Gateway.new()

var image_cache: ImageCache = ImageCache.new()
signal on_message(message: Message)

var http: HTTPRequest = HTTPRequest.new()

func _ready() -> void:
	add_child(image_cache)
	add_child(http)
	
	self._gateway.on_connected.connect(self._on_gateway_connected)
	self._gateway.on_message.connect(self._on_gateway_message)
	self._gateway.on_close.connect(self._on_gateway_close)
	
	var err: Error = self._gateway.connect_to_url(WEBSOCKET_URL)
	
	if err == OK:
		print("Connecting to Discord Gateway")
	else:
		push_error("Failed to connect to Discord Gateway: ", err)

func _process(_delta: float) -> void:
	self._gateway.poll()

func _on_gateway_connected(socket: WebSocketPeer) -> void:
	print("> Sending test packet.")
			
	socket.send_text(JSON.stringify({
		"op": 2,
		"d": {
			"token": self.token,
			"capabilities": 1734653, # whatever that is
			"properties": {
				"os": MASQUERADE_OS,
				"browser": MASQUERADE_BROWSER,
				"device": "",
				"system_locale": MASQUERADE_LOCALE,
				"has_client_mods": false, # client mods? i hardly know 'er!
				"browser_user_agent": MASQUERADE_BROWSER_AGENT,
				"browser_version": MASQUERADE_BROWSER_VERSION,
				"os_version": "",
				"referrer": "",
				"referring_domain": "",
				"referrer_current": "",
				"referring_domain_current": "",
				"release_channel": MASQUERADE_DISCORD_CHANNEL,
				"client_build_number": MASQUERADE_DISCORD_BUILD,
				"client_event_source": null,
				"client_launch_id": UUID.v4(),
				"is_fast_connect": true
			},
			"client_state": {
				"guild_versions": {}
			}
		}
	}))

func _on_gateway_close(_socket: WebSocketPeer, code: int, reason: String) -> void:
	print("WebSocket closed with code: %d. Clean: %s; %s" % [code, code != -1, reason])
	
func _on_gateway_message(_socket: WebSocketPeer, socket_message: String) -> void:
	var some_json: Variant = JSON.parse_string(socket_message)
						
	if not some_json or some_json is not Dictionary:
		print("Received malformed JSON from gateway", socket_message)
	else:
		var json: Dictionary = some_json
		match json["t"]:
			"MESSAGE_CREATE":
				var some_data: Variant = json["d"]
				
				if not some_data or some_data is not Dictionary:
					print("'MESSAGE_CREATE' event is invalid: ", some_data)
					return
				
				var message_json: Dictionary = some_data
				if message_json["channel_id"] == self.channel:
					self.on_message.emit(Message.from_json(message_json))

func get_avatar(user_id: String, avatar_id: String) -> ImageTexture:
	if not avatar_id: return null
	
	var url: String = "%s/avatars/%s/%s.webp?size=64" % [CDN_URL, user_id, avatar_id]
	return await self.image_cache.get_or_request(url, "webp")

func send_message(channel_id: String, message: String) -> int:
	var s: int = self._generate_snowflake()
	
	var body: Dictionary[String, Variant] = {
		# No clue what that is
		"mobile_network_type": "unknown", 
		"content": message,
		
		# Used to verify message consistency, we don't know the message id when we send it, but we do know the nonce...
		"nonce": str(s), 
		"tts": false,
		"flags": 0
	}
	
	var url: String = "%s/channels/%s/messages" % [BASE_URL, channel_id]
	
	http.request(url, [
		"Authorization: " + self.token, 
		"Content-Type: application/json"
	], HTTPClient.Method.METHOD_POST, JSON.stringify(body))
	
	return s

const DISCORD_EPOCH: int = 1420070400000

# Used in snowflake generation
const WORKER_ID: int = 1
const PROCESS_ID: int = 1

# How many snowflakes were generated
var _snowflakes: int = 0

# https://docs.discord.com/developers/reference#snowflakes
func _generate_snowflake() -> int:
	var cur_time: int = Util.get_time_millis()
	var res: int = int(cur_time - DISCORD_EPOCH) << 22
	
	res += WORKER_ID << 17
	res += PROCESS_ID << 12
	res += _snowflakes
	
	_snowflakes += 1
	return res

var token: String:
	get:
		return OS.get_environment("TOKEN")

var channel: String:
	get:
		return OS.get_environment("CHANNEL")
