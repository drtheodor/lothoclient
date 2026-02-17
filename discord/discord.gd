# FIXME: `Discord` shouldn't be *the* global API wrapper thingy
extends Node
const BASE_URL: String = "https://cdn.discordapp.com"

const ImageCache: GDScript = preload("res://discord/image_cache.gd")

@onready var image_cache: ImageCache = ImageCache.new()

func _ready() -> void:
	add_child(image_cache)

func get_avatar(user_id: String, avatar_id: String, callback: Callable) -> void:
	var url: String = "%s/avatars/%s/%s.webp?size=64" % [BASE_URL, user_id, avatar_id]
	self.image_cache.get_or_request(url, callback)

var token: String:
	get:
		return OS.get_environment("TOKEN")

var channel: String:
	get:
		return OS.get_environment("CHANNEL")
