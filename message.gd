class_name GMessage # TODO: remove the name
extends BoxContainer

@onready var avatar: TextureRect = $Avatar
@onready var terminator: Label = $TerminatorLabel
@onready var author: Label = $VBoxContainer/Author
@onready var label: Label = $VBoxContainer/Content
@onready var timeLabel: Label = $VBoxContainer/Author/TimeLabel
@onready var spacer: Label = $VBoxContainer/GroupSpacer
@onready var content_spacer: Label = $VBoxContainer/ContentSpacer

var _timestamp_iso: String = ""
var _timestamp_unix: int = 0

const BASE_URL: String = "https://cdn.discordapp.com"

func set_author(author_name: String, author_id: String, avatar_id: String) -> void:
	author.text = author_name

	Discord.get_avatar(author_id, avatar_id, self._on_image_loaded)

func get_author() -> String:
	return author.text

func get_unix_timestamp() -> int:
	return _timestamp_unix

func _on_image_loaded(texture: Texture2D) -> void:
	avatar.texture = texture

func set_content(text: String) -> void:
	var grouped: bool = self._should_group_with_previous()
	avatar.visible = not grouped
	terminator.visible = grouped
	spacer.visible = not grouped
	content_spacer.visible = not grouped
	author.visible = not grouped
	timeLabel.visible = not grouped
	label.text = text

func _should_group_with_previous() -> bool:
	var parent: Node = get_parent()
	
	if not parent:
		return false
		
	var index: int = self.get_index(false)
	
	if index <= 0:
		return false
		
	var prev_message: GMessage = parent.get_child(index - 1)
	
	if not prev_message.has_method("get_author") or not prev_message.has_method("get_unix_timestamp"):
		return false
		
	var same_author: bool = prev_message.get_author() == get_author()
	var time_delta: int = abs(prev_message.get_unix_timestamp() - _timestamp_unix)
	return same_author and time_delta <= 600

func set_timestamp(timestamp: String) -> void:
	_timestamp_iso = timestamp
	var dict: Dictionary[String, int] = Time.get_datetime_dict_from_datetime_string(timestamp, false)
	_timestamp_unix = Time.get_unix_time_from_datetime_dict(dict)
	var formatted_time: String = self._get_local_discord_time(timestamp)
	timeLabel.text = formatted_time

# Doesn't fucking work on Linux at least, or at all for whatever reason. I just set it to use UTC for now because fucking hell I'm getting pissed OFF
func _get_local_discord_time(iso_timestamp: String) -> String:
	var dict: Dictionary[String, int] = Time.get_datetime_dict_from_datetime_string(iso_timestamp, false)
	return "%02d:%02d UTC" % [dict.hour, dict.minute]
