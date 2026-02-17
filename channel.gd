extends Control

const BASE_URL = "https://discord.com/api/v9"

@onready var http_request = $HTTPRequest
@onready var vbox_container = $ScrollContainer/VBoxContainer
@onready var scroll_container = $ScrollContainer

var MessageScene = preload("res://message.tscn")
var previous_scroll_max = 0

func _ready() -> void:
	http_request.request_completed.connect(_on_request_completed)
	
	# Configure for bottom-anchored behavior
	vbox_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Monitor scroll changes
	scroll_container.get_v_scroll_bar().changed.connect(_on_scrollbar_changed)
	
	var url = BASE_URL + "/channels/" + Env.channel + "/messages"
	var error = http_request.request(url, ["Authorization: " + Env.token])
	
	if error != OK:
		print("Error making HTTP request: ", error)
		add_error_message("Failed to load messages")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		print("HTTP request failed: ", result)
		add_error_message("Failed to load messages")
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		print("JSON parse error: ", parse_result)
		add_error_message("Failed to parse messages")
		return
	
	var data = json.get_data()
	
	if not (data is Array):
		print("Response is not an array")
		add_error_message("Invalid response format")
		return
	
	data.reverse()
	
	# Clear existing messages
	for child in vbox_container.get_children():
		child.queue_free()
	
	# Add messages in chronological order (oldest first at top, newest at bottom)
	for message_data in data:
		#print(message_data)
		if message_data is Dictionary and "content" in message_data:
			var content = message_data["content"]
			var author = message_data["author"]
			var author_name = author["global_name"]
			var author_avatar = author["avatar"]
			var author_id = author["id"]
			var message_instance = MessageScene.instantiate()
			vbox_container.add_child(message_instance)
			message_instance.set_content(str(content))
			message_instance.set_author(author_name, author_id, author_avatar)
	
	# Wait for layout to update, then scroll to bottom
	await get_tree().process_frame
	await get_tree().process_frame
	scroll_to_bottom()

func _on_scrollbar_changed() -> void:
	# Auto-scroll to bottom when new content is added if we were at bottom
	var vbar = scroll_container.get_v_scroll_bar()
	if vbar:
		# Check if scroll max increased (new content)
		if vbar.max_value > previous_scroll_max:
			# If user was near bottom, keep them at bottom
			var was_at_bottom = abs(scroll_container.scroll_vertical - previous_scroll_max) < 50
			if was_at_bottom:
				await get_tree().process_frame
				scroll_container.scroll_vertical = vbar.max_value
		previous_scroll_max = vbar.max_value

func scroll_to_bottom() -> void:
	await get_tree().process_frame
	var vbar = scroll_container.get_v_scroll_bar()
	if vbar:
		scroll_container.scroll_vertical = vbar.max_value
	else:
		# Calculate manually
		var content = scroll_container.get_child(0)
		if content:
			scroll_container.scroll_vertical = content.size.y - scroll_container.size.y

func add_error_message(text: String) -> void:
	var message_instance = MessageScene.instantiate()
	vbox_container.add_child(message_instance)
	message_instance.set_content(text)
	await get_tree().process_frame
	scroll_to_bottom()
