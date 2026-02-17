class_name Discord

const BASE_URL: String = "https://cdn.discordapp.com"

static var image_cache: Variant = preload("res://discord/image_cache.gd").new()

static func get_avatar(user_id: String, avatar_id: String, callback: Callable) -> void:
	var url: String = "%s/avatars/%s/%s.webp?size=64" % [BASE_URL, user_id, avatar_id]
	image_cache.get_or_request(url, callback)

static var token: String:
	get:
		return OS.get_environment("TOKEN")

static var channel: String:
	get:
		return OS.get_environment("CHANNEL")
