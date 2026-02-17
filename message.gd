extends BoxContainer

@onready var avatar = $Avatar
@onready var author = $VBoxContainer/Author
@onready var label = $VBoxContainer/Content

const BASE_URL = "https://cdn.discordapp.com"

func set_author(author_name: String, author_id: String, avatar_id: String) -> void:
	author.text = author_name
	
	var url = BASE_URL + "/avatars/" + author_id + "/" + avatar_id + ".webp?size=64"
	CacheManager.load_image(url, self._on_image_loaded)
	
func _on_image_loaded(texture: Texture2D) -> void:
	avatar.texture = texture

func set_content(text: String) -> void:
	label.text = text
