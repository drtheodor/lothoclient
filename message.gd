extends BoxContainer

@onready var avatar = $Avatar
@onready var terminator = $TerminatorLabel
@onready var author = $VBoxContainer/Author
@onready var label = $VBoxContainer/Content
@onready var timeLabel = $VBoxContainer/TimeLabel
@onready var spacer = $VBoxContainer/GroupSpacer
@onready var content_spacer = $VBoxContainer/ContentSpacer

var _timestamp_iso: String = ""
var _timestamp_unix: int = 0

const BASE_URL = "https://cdn.discordapp.com"

func set_author(author_name: String, author_id: String, avatar_id: String) -> void:
	author.text = author_name

	var url = BASE_URL + "/avatars/" + author_id + "/" + avatar_id + ".webp?size=64"
	CacheManager.load_image(url, self._on_image_loaded)

func get_author() -> String:
	return author.text

func get_unix_timestamp() -> int:
	return _timestamp_unix

func _on_image_loaded(texture: Texture2D) -> void:
	avatar.texture = texture

func set_content(text: String) -> void:
	var grouped = _should_group_with_previous()
	avatar.visible = not grouped
	terminator.visible = grouped
	spacer.visible = not grouped
	content_spacer.visible = not grouped
	author.visible = not grouped
	timeLabel.visible = not grouped
	label.text = text

func _should_group_with_previous() -> bool:
	var parent = get_parent()
	if parent == null:
		return false
	var index = self.get_index(false)
	if index <= 0:
		return false
	var prev_message = parent.get_child(index - 1)
	if not prev_message.has_method("get_author") or not prev_message.has_method("get_unix_timestamp"):
		return false
	var same_author = prev_message.get_author() == get_author()
	var time_delta = abs(prev_message.get_unix_timestamp() - _timestamp_unix)
	return same_author and time_delta <= 600

func set_timestamp(timestamp: String) -> void:
	_timestamp_iso = timestamp
	var dict = Time.get_datetime_dict_from_datetime_string(timestamp, false)
	_timestamp_unix = Time.get_unix_time_from_datetime_dict(dict)
	var formatted_time = get_local_discord_time(timestamp)
	timeLabel.text = formatted_time

# Doesn't fucking work on Linux at least, or at all for whatever reason. I just set it to use UTC for now because fucking hell I'm getting pissed OFF
func get_local_discord_time(iso_timestamp: String) -> String:
	var dict = Time.get_datetime_dict_from_datetime_string(iso_timestamp, false)
	return "%02d:%02d UTC" % [dict.hour, dict.minute]
