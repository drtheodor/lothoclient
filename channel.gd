extends Control

const BASE_URL: String = "https://discord.com/api/v9"

# TODO: move all requests to `Discord`
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var vbox_container: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var scroll_container: ScrollContainer = $ScrollContainer

const MessageScene: PackedScene = preload("res://message.tscn")
var previous_scroll_max: int = 0

func _ready() -> void:
	http_request.request_completed.connect(_on_request_completed)
	
	# Configure for bottom-anchored behavior
	vbox_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Monitor scroll changes
	scroll_container.get_v_scroll_bar().changed.connect(_on_scrollbar_changed)
	
	# TODO: move api calls to `Discord`
	var url: String = "%s/channels/%s/messages" % [BASE_URL, Discord.channel]
	var error: Error = http_request.request(url, ["Authorization: " + Discord.token])
	
	if error != OK:
		print("Error making HTTP request: ", error)
		add_error_message("Failed to load messages")

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
		return
		
	var data: Variant = json.data
	
	# print(data) # print data for decoding purposes
	
	if data is Array:
		var messages: Array[Dictionary] = data
		_on_message(messages)
	else:
		print("Response is not an array")
		add_error_message("Invalid response format")
		return

func _on_message(messages: Array[Dictionary]) -> void:
	messages.reverse()
	
	# Clear existing messages
	for child: Node in vbox_container.get_children():
		child.queue_free()
	
	# Add messages in chronological order (oldest first at top, newest at bottom)
	for message_data: Dictionary[String, Variant] in messages:
		#print(message_data)
		if message_data is Dictionary and "content" in message_data:
			var content: String = message_data["content"]
			var author: Dictionary[String, Variant] = message_data["author"]
			#var mentions = message_data["mentions"]
			#var mention_roles = message_data["mention_roles"]
			#var attachments = message_data["attachments"]
			#var embeds = message_data["embeds"]
			var timestamp: int = message_data["timestamp"]
			#var edited_timestamp: int = message_data["edited_timestamp"]
			var author_name: String = author["global_name"]
			var author_avatar: String = author["avatar"]
			var author_id: String = author["id"]
			
			var message_instance: Node = MessageScene.instantiate()
			
			vbox_container.add_child(message_instance)
			message_instance.set_timestamp(str(timestamp))
			message_instance.set_author(author_name, author_id, author_avatar)
			message_instance.set_content(str(content))
	
	# Wait for layout to update, then scroll to bottom
	await get_tree().process_frame
	await get_tree().process_frame
	scroll_to_bottom()

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
