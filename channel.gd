extends Control

const BASE_URL: String = "https://discord.com/api/v9"

# TODO: move all requests to `Discord`
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var vbox_container: VBoxContainer = %MessageList
@onready var scroll_container: ScrollContainer = $MarginContainer/HBoxContainer/Main/ScrollContainer
@onready var message_input: CodeEdit = %NewMessageInput
@onready var channel_label: Label = $MarginContainer/HBoxContainer/Main/TopPanel/ChannelLabel
@onready var user_pref: Label = $MarginContainer/HBoxContainer/Sidebar/UserPref/Sort/Name
@onready var user_pref_avatar: TextureRect = $MarginContainer/HBoxContainer/Sidebar/UserPref/Sort/Avatar

const MessageScene: PackedScene = preload("res://message.tscn")

var previous_scroll_max: int = 0
var _fetch_queued: bool = false

# FIXME: this sucks
var _request_mode: String = ""
var _pending_user_id: String = ""
var _first_load: bool = true

func _ready() -> void:
	if OS.get_environment("THEME") == "transparent":
		self.get_tree().get_root().transparent_bg = true
		
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		self.add_theme_stylebox_override("panel", style)
	
	http_request.request_completed.connect(_on_request_completed)

	# Monitor scroll changes
	scroll_container.get_v_scroll_bar().changed.connect(_on_scrollbar_changed)

	# TODO: move api calls to `Discord`
	_fetch_channel_name()
	_fetch_messages()
	#_start_polling()

func _fetch_messages() -> void:
	# Avoid overlapping requests; queue if busy
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_fetch_queued = true
		return

	_fetch_queued = false
	_request_mode = "messages"

	var url: String = "%s/channels/%s/messages" % [BASE_URL, Discord.channel]
	var error: Error = http_request.request(url, ["Authorization: " + Discord.token])

	if error != OK:
		print("Error making HTTP request: ", error)
		add_error_message("Failed to load messages")

func _fetch_channel_name() -> void:
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_fetch_queued = true
		return

	_request_mode = "channel"
	var url: String = "%s/channels/%s" % [BASE_URL, Discord.channel]
	var error: Error = http_request.request(url, ["Authorization: " + Discord.token])
	if error != OK:
		print("Error fetching channel: ", error)

func _fetch_user_name(user_id: String) -> void:
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_fetch_queued = true
		return

	_request_mode = "user"
	_pending_user_id = user_id
	var url: String = "%s/users/%s" % [BASE_URL, user_id]
	var error: Error = http_request.request(url, ["Authorization: " + Discord.token])
	if error != OK:
		print("Error fetching user: ", error)

func _set_channel_label_from_channel_data(data: Dictionary) -> bool:
	if data.has("name") and data["name"] != "":
		channel_label.text = "#%s" % data["name"]
		return true

	if data.has("recipients") and data["recipients"] is Array and data["recipients"].size() > 0:
		var recipient: Variant = data["recipients"][0]
		if recipient is Dictionary:
			var username: String = recipient.get("global_name", "") if recipient.get("global_name", "") != "" else recipient.get("username", "")
			if username != "":
				channel_label.text = "@%s" % username
				return true

	var user_id: String = ""
	if data.has("user_id"):
		user_id = str(data["user_id"])
	elif data.has("recipient_id"):
		user_id = str(data["recipient_id"])

	if user_id != "":
		_fetch_user_name(user_id)
		return false

	return false

# FIXME: this sucks
func _start_polling() -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = false
	timer.autostart = true
	timer.timeout.connect(_fetch_messages)
	add_child(timer)

func _add_pending_message(text: String) -> void:
	var pending: UiMessage = MessageScene.instantiate()
	vbox_container.add_child(pending)
	
	var message: Message = Message.new(
		"You", "local", "", int(Time.get_unix_time_from_system()), [
		Message.TextToken.new(text)
	])
	
	pending.set_pending(true)
	pending.set_message(message)
	
	await get_tree().process_frame
	scroll_to_bottom()

# TODO: this should be handled inside `Discord`
func _on_request_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		print("HTTP request failed: ", result)
		add_error_message("Failed to load messages")
		return

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(body.get_string_from_utf8())

	if parse_result != OK:
		print("JSON parse error: ", parse_result)
		add_error_message("Failed to parse messages")
		_request_mode = ""
		return

	var data: Variant = json.data

	if _request_mode == "channel":
		if data is Dictionary:
			var dict: Dictionary = data
			var handled: bool = _set_channel_label_from_channel_data(dict)
			if not handled:
				return
		_request_mode = ""
		if _fetch_queued:
			_fetch_messages()
		return

	if _request_mode == "user":
		if data is Dictionary:
			var channel_name: String = data.get("global_name", "") if data.get("global_name", "") != "" else data.get("username", _pending_user_id)
			channel_label.text = "@%s" % channel_name
		_pending_user_id = ""
		_request_mode = ""
		if _fetch_queued:
			_fetch_messages()
		return

	if data is Array:
		var messages: Array[Variant] = data
		_on_message(messages)
	else:
		print("Response is not an array")
		add_error_message("Invalid response format")
		_request_mode = ""
		return

	_request_mode = ""
	if _fetch_queued:
		_fetch_messages()

func _on_message(messages: Array[Variant]) -> void:
	messages.reverse()
	var should_scroll: bool = _first_load or _is_near_bottom()

	# Clear existing messages
	for child: Node in vbox_container.get_children():
		child.queue_free()

	var last_message: UiMessage = null

	# Add messages in chronological order (oldest first at top, newest at bottom)
	for message_data: Dictionary in messages:
		#print(message_data)
			var message: Message = Message.from_json(message_data)
			
			if last_message and _should_group(last_message.message, message):
				last_message.append_message(message)
			else:
				last_message = MessageScene.instantiate()
				vbox_container.add_child(last_message)
				
				last_message.set_message(message)
				
				user_pref.text = message.author_name
				
				if message.author_avatar:
					user_pref_avatar.texture = await Discord.get_avatar(message.author_id, message.author_avatar)
				else:
					user_pref_avatar.texture = null
				

	# Wait for layout to update, then optionally scroll to bottom
	await get_tree().process_frame
	await get_tree().process_frame
	if should_scroll:
		scroll_to_bottom()
	_first_load = false

func _is_near_bottom() -> bool:
	var vbar: ScrollBar = scroll_container.get_v_scroll_bar()
	if not vbar:
		return true
	return (vbar.max_value - scroll_container.scroll_vertical) < 50

func _should_group(prev_message: Message, new_message: Message) -> bool:
	return abs(prev_message.timestamp - new_message.timestamp) <= 60 * 10 * 1000 and prev_message.author_id == new_message.author_id

func _on_scrollbar_changed() -> void:
	# Auto-scroll to bottom when new content is added if we were at bottom
	var vbar: ScrollBar = scroll_container.get_v_scroll_bar()

	if vbar:
		# Check if scroll max increased (new content)
		if vbar.max_value > previous_scroll_max:
			# If user was near bottom, keep them at bottom
			if abs(scroll_container.scroll_vertical - previous_scroll_max) < 50:
				await get_tree().process_frame
				scroll_container.scroll_vertical = int(vbar.max_value)

		previous_scroll_max = int(vbar.max_value)

func scroll_to_bottom() -> void:
	await get_tree().process_frame
	var vbar: ScrollBar = scroll_container.get_v_scroll_bar()
	if vbar:
		scroll_container.scroll_vertical = int(vbar.max_value)
	else:
		# Calculate manually
		var content: Node = scroll_container.get_child(0)
		if content:
			scroll_container.scroll_vertical = content.size.y - scroll_container.size.y

func add_error_message(text: String) -> void:
	var message_instance: Node = MessageScene.instantiate()
	vbox_container.add_child(message_instance)
	message_instance.set_content(text)
	await get_tree().process_frame
	scroll_to_bottom()

func _on_code_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if event.shift_pressed:
				event.shift_pressed = false
				return

			# Cancel the default behavior
			accept_event()

			if message_input.text.strip_edges().is_empty():
				return

			var text_to_send: String = message_input.text
			message_input.text = ''
			_add_pending_message(text_to_send)
			Discord.send_message(Discord.channel, text_to_send)
			_fetch_messages()
