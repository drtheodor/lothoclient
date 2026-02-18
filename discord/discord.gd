# FIXME: `Discord` shouldn't be *the* global API wrapper thingy
extends Node

const CDN_URL: String = "https://cdn.discordapp.com"
const BASE_URL: String = "https://discord.com/api/v9"

const ImageCache: GDScript = preload("res://discord/image_cache.gd")

@onready var image_cache: ImageCache = ImageCache.new()
@onready var http: HTTPRequest = HTTPRequest.new()

func _dummy_func() -> void: pass

func _ready() -> void:
	add_child(image_cache)
	add_child(http)

func get_avatar(user_id: String, avatar_id: String, callback: Callable) -> ImageTexture:
	var url: String = "%s/avatars/%s/%s.webp?size=64" % [CDN_URL, user_id, avatar_id]
	return await self.image_cache.get_or_request(url, callback)

func send_message(channel_id: String, message: String, callback: Callable = _dummy_func) -> void:
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

func fetch_messages(channel_id: String, callback: Callable = _dummy_func) -> void:
	pass

const DISCORD_EPOCH: int = 1420070400000

# Used in snowflake generation
const WORKER_ID: int = 1
const PROCESS_ID: int = 1

# How many snowflakes were generated
var _snowflakes: int = 0

# https://docs.discord.com/developers/reference#snowflakes
func _generate_snowflake() -> int:
	var cur_time: int = int(Time.get_unix_time_from_system() * 1000)
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
