class_name UiMessage
extends Control

const MessageReplyingTo: PackedScene = preload("res://message_replying_to.tscn")
const MessageContent: PackedScene = preload("res://message_content.tscn")

const MAX_IMAGE_WIDTH: int = 580
const EMOJI_SIZE: int = 24

var label: UiTokenizedLabel

var messages: Array[Message] = []

signal mouse_entered_msg(msg_label: Control, message: Message)

func add_message(message: Message) -> void:
	if not self.label:
		self._set_author(message.author_name, message.author_id, message.author_avatar)
		self._set_timestamp(message.timestamp)
	
	self.messages.append(message)
	
	var new_label: Control = MessageContent.instantiate()
	
	new_label.mouse_entered.connect(
		func () -> void:
			self.mouse_entered_msg.emit(new_label, message)
	)
	
	new_label.meta_clicked.connect(func (meta: Variant) -> void: OS.shell_open(str(meta)))
	
	self.label = new_label
	%ContentBase.add_child(self.label)
	
	if message.referenced:
		var header: UiMessageReplyingTo = MessageReplyingTo.instantiate()
		header.set_message(message.referenced)
		
		self.add_child(header)
		self.move_child(header, 0)
	
	self.label.from_tokens(message.tokens, MAX_IMAGE_WIDTH, EMOJI_SIZE)

func _set_author(author_name: String, author_id: String, avatar_id: String) -> void:
	%Name.text = author_name

	if author_id and avatar_id:
		%Avatar.texture = await Discord.get_avatar(author_id, avatar_id)
	else:
		%Avatar.texture = null

func _set_timestamp(timestamp: int) -> void:
	var timezone_info: Dictionary = Time.get_time_zone_from_system()
	var utc_offset_minutes: int = timezone_info["bias"]

	var unix_timestamp_local: int = timestamp + (utc_offset_minutes * 60)

	var local: Dictionary = Time.get_datetime_dict_from_unix_time(unix_timestamp_local)
	var now: Dictionary = Time.get_datetime_dict_from_system()

	var text: String = "%02d:%02d" % [local["hour"], local["minute"]]
	
	if now["day"] - 1 == local["day"] and local["month"] == now["month"] and local["year"] == now["year"]:
		text = "Yesterday, %s" % text
	elif local["day"] != now["day"] or local["month"] != now["month"] or local["year"] != now["year"]:
		text = "%02d/%02d/%04d, %s" % [local["day"], local["month"], local["year"], text]
	
	%Time.text = text

func set_pending() -> void:
	self.modulate = Color(1, 1, 1, 0.6)
