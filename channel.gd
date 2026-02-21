extends Control

const BASE_URL: String = "https://discord.com/api/v9"

@onready var message_list: VBoxContainer = %MessageList
@onready var channel_list: VBoxContainer = %ChannelList
@onready var message_input: CodeEdit = %NewMessageInput

@onready var scroll_container: ScrollContainer = $MarginContainer/HBoxContainer/Main/ScrollContainer
@onready var channel_label: Label = $MarginContainer/HBoxContainer/Main/TopPanel/ChannelLabel
@onready var user_pref: Label = $MarginContainer/HBoxContainer/Sidebar/UserPref/Sort/Name
@onready var user_pref_avatar: TextureRect = $MarginContainer/HBoxContainer/Sidebar/UserPref/Sort/Avatar

const MessageScene: PackedScene = preload("res://message.tscn")
const ChannelItemScene: PackedScene = preload("res://channel_item.tscn")

@onready var channels: PackedStringArray = OS.get_environment("CHANNELS").split(",")

var _busy: bool

func _ready() -> void:
	self._init_channels()
	
	if OS.get_environment("THEME") == "transparent":
		self.get_tree().get_root().transparent_bg = true
		
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		
		self.add_theme_stylebox_override("panel", style)
	
	Discord.on_message.connect(self._on_message)

	self.message_input.grab_focus()

func _init_channels() -> void:
	for child: Node in channel_list.get_children():
		child.queue_free()
	
	for channel_id: String in channels:
		self._init_channel(channel_id)

func _init_channel(channel_id: String) -> void:
	var channel: Channel = await Discord.get_channel(channel_id)
	
	if channel:
		var ui_channel: Node = ChannelItemScene.instantiate()
		channel_list.add_child(ui_channel)
		
		ui_channel.set_channel(channel)
		ui_channel.clicked.connect(_on_channel_change)
	
func _on_channel_change(channel: Channel) -> void:
	if _busy: return
	
	Discord.channel = channel.channel_id
	
	self.channel_label.text = channel.channel_name
	
	# TODO: move api calls to `Discord`
	self._fetch_messages()

func _fetch_messages() -> void:
	self._busy = true
	
	var messages: Array[Message] = await Discord.fetch_messages(Discord.channel)
	messages.reverse()
	
	# Clear existing messages
	for child: Node in message_list.get_children():
		child.queue_free()

	self.last_message = null

	# Add messages in chronological order (oldest first at top, newest at bottom)
	for message: Message in messages:
		self._on_message(message, false)

	self.scroll_to_bottom()
	self._busy = false

func _add_pending_message(text: String, nonce: int) -> void:
	var pending: UiMessage = MessageScene.instantiate()
	message_list.add_child(pending)
	
	var message: Message = Message.new(
		"You", "local", "", int(Time.get_unix_time_from_system()), str(nonce), [
		Message.TextToken.new(text)
	])
	
	pending.set_pending(true)
	pending.set_message(message)
	
	pending_messages[str(nonce)] = pending
	
	if _is_near_bottom():
		scroll_to_bottom()

var last_message: UiMessage
var pending_messages: Dictionary[String, Node] = {}

func _on_message(message: Message, scroll: bool = true) -> void:
	var pending: UiMessage = pending_messages.get(message.nonce)
	
	if pending:
		pending.queue_free()
	
	if self.last_message and _should_group(last_message.message, message):
		self.last_message.append_message(message)
	else:
		self.last_message = MessageScene.instantiate()
		message_list.add_child(self.last_message)
		
		self.last_message.set_message(message)
	
	if scroll and _is_near_bottom():
		self.scroll_to_bottom()

func _is_near_bottom() -> bool:
	var vbar: ScrollBar = scroll_container.get_v_scroll_bar()
	if not vbar:
		return true
	
	return (vbar.max_value - scroll_container.scroll_vertical) < 2000

func _should_group(prev_message: Message, new_message: Message) -> bool:
	return abs(prev_message.timestamp - new_message.timestamp) <= 60 * 10 * 1000 and prev_message.author_id == new_message.author_id

func scroll_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	var vbar: ScrollBar = scroll_container.get_v_scroll_bar()
	
	if vbar:
		scroll_container.scroll_vertical = int(vbar.max_value) + 1
	else:
		# Calculate manually
		var content: Node = scroll_container.get_child(0)
		if content:
			scroll_container.scroll_vertical = content.size.y - scroll_container.size.y

func add_error_message(text: String) -> void:
	self._on_message(Message.new("GDiscord", "0", "https://theo.is-a.dev/favicon.png", Util.get_time_millis(), "", [
		Message.TextToken.new(text)
	]))

func _on_code_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if event.shift_pressed:
				event.shift_pressed = false
				return

			# Cancel the default behavior
			message_input.accept_event()

			if message_input.text.strip_edges().is_empty():
				return

			var text_to_send: String = message_input.text
			message_input.text = ''
			
			var nonce: int = Discord.send_message(Discord.channel, text_to_send)
			_add_pending_message(text_to_send, nonce)
