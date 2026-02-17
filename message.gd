class_name GMessage # TODO: remove the name
extends Control

@onready var avatar: TextureRect = $Avatar
@onready var author: Label = $VBoxContainer/Author/Name
@onready var label: RichTextLabel = $VBoxContainer/Content
@onready var timeLabel: Label = $VBoxContainer/Author/Time

var _timestamp_unix: int = 0
# FIXME: this should be in a base `Message` class, not the UI one
var _author_id: String

const BASE_URL: String = "https://cdn.discordapp.com"

func set_author(author_name: String, author_id: String, avatar_id: String) -> void:
	self.author.text = author_name
	self._author_id = author_id

	Discord.get_avatar(author_id, avatar_id, self._on_image_loaded)

func get_author() -> String:
	return author.text

func get_author_id() -> String:
	return self._author_id

func get_unix_timestamp() -> int:
	return _timestamp_unix

func _on_image_loaded(texture: Texture2D) -> void:
	avatar.texture = texture

func set_content(text: String) -> void:
	label.text = text

func append_content(text: String) -> void:
	label.text += "\n" + text

func set_timestamp(timestamp: int) -> void:
	self._timestamp_unix = timestamp

	var timezone_info: Dictionary = Time.get_time_zone_from_system()
	var utc_offset_minutes: int = timezone_info["bias"]

	var unix_timestamp_local: int = self._timestamp_unix + (utc_offset_minutes * 60)

	var local: Dictionary = Time.get_datetime_dict_from_unix_time(unix_timestamp_local)
	var now: Dictionary = Time.get_datetime_dict_from_system()
	
	var text: String = "%02d:%02d" % [local["hour"], local["minute"]]
	
	if local["day"] != now["day"] or local["month"] != now["month"]:
		text = "%02d-%02d " % [local["month"], local["day"]] + text
	
	if local["year"] != now["year"]:
		text = "%04d-" % local["year"] + text
	
	timeLabel.text = text
