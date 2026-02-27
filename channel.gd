extends Control

@onready var message_list: VBoxContainer = %MessageList
@onready var channel_list: VBoxContainer = %ChannelList
@onready var message_input: CodeEdit = %NewMessageInput
@onready var guild_list: Container = %GuildList

@onready var scroll_container: ScrollContainer = $MarginContainer/HBoxContainer/Main/ScrollContainer
@onready var channel_label: Label = $MarginContainer/HBoxContainer/Main/TopPanel/ChannelLabel
@onready var user_pref: Label = $MarginContainer/HBoxContainer/Sidebar/UserPref/Sort/Name
@onready var user_pref_avatar: TextureRect = $MarginContainer/HBoxContainer/Sidebar/UserPref/Sort/Rounder/Avatar
@onready var context: Window = $Context

const MessageScene: PackedScene = preload("res://message.tscn")
const ChannelItemScene: PackedScene = preload("res://channel_item.tscn")
const ChannelCategoryItemScene: PackedScene = preload("res://channel_category_item.tscn")
const GuildItemScene: PackedScene = preload("res://guild_item.tscn")

var _busy: bool

func _ready() -> void:
	if OS.get_environment("THEME") == "transparent":
		self.get_tree().get_root().transparent_bg = true
		
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		
		self.add_theme_stylebox_override("panel", style)
	
	Discord.on_ready.connect(self._on_discord_ready)
	Discord.on_message.connect(self._on_message)

	self.message_input.editable = false

func _init_guild_channels(channels: Array[Channel.GuildChannel]) -> void:
	for child: Node in channel_list.get_children():
		child.queue_free()
	
	var last_category: FoldableContainer
	for channel: Channel.GuildChannel in channels:
		var ui_channel: Node
		if channel.channel_type == Channel.Type.CATEGORY:
			ui_channel = ChannelCategoryItemScene.instantiate()
			last_category = ui_channel
		else:
			ui_channel = ChannelItemScene.instantiate()
			ui_channel.clicked.connect(_on_channel_change)
		
		if ui_channel != last_category:
			last_category.add_node(ui_channel)
		else:
			channel_list.add_child(ui_channel)
		
		ui_channel.set_channel(channel)

func _on_channel_change(channel: Channel) -> void:
	if _busy: return
	
	self.message_input.editable = true
	
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
	
	var message: Message = Message.with_user(
		Discord.user, int(Time.get_unix_time_from_system()), 
		str(nonce), [Message.TextToken.new(text)]
	)
	
	pending.set_pending(true)
	pending.add_message(message)
	
	pending_messages[str(nonce)] = pending
	
	if _is_near_bottom():
		scroll_to_bottom()

func _on_discord_ready() -> void:
	self.user_pref.text = Discord.user.global_name
	self.user_pref_avatar.texture = await Discord.get_avatar(Discord.user.user_id, Discord.user.avatar_id)

	for guild: Guild in Discord.guild_cache.values():
		var guild_item: UiGuildItem = GuildItemScene.instantiate()
		guild_item.clicked.connect(self._on_guild_change)
		
		self.guild_list.add_child(guild_item)
		
		guild_item.set_guild(guild)

func _on_guild_change(guild: Guild) -> void:
	self._init_guild_channels(guild.channels)

var last_message: UiMessage
var pending_messages: Dictionary[String, Node] = {}

func _on_message(message: Message, scroll: bool = true) -> void:
	var pending: UiMessage = pending_messages.get(message.nonce)
	
	if pending:
		pending.queue_free()
	
	if not self.last_message or not self._should_group(last_message.messages[-1], message):
		var new_message: UiMessage = MessageScene.instantiate()
		
		new_message.mouse_entered.connect(
			func() -> void:
				self._on_message_hover(new_message)
		)
		
		self.last_message = new_message
		message_list.add_child(self.last_message)
	
	# FIXME: temp await fix since there's no Promise.all :(
	await self.last_message.add_message(message)
	
	if scroll and _is_near_bottom():
		self.scroll_to_bottom()

func _on_message_hover(message: UiMessage) -> void:
	var message_position: Vector2 = message.get_screen_position()
	message_position.x += message.size[0]
	message_position.x -= context.size[0]
	context.visible = true
	context.position = message_position

func _is_near_bottom() -> bool:
	var vbar: ScrollBar = scroll_container.get_v_scroll_bar()
	if not vbar:
		return true
	
	return (vbar.max_value - scroll_container.scroll_vertical) < 2000

func _should_group(prev_message: Message, new_message: Message) -> bool:
	# TODO: figure out why the fuck its being funny about timestamps
	return abs(prev_message.timestamp - new_message.timestamp) <= 6 * 1000 and prev_message.author_id == new_message.author_id

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
	self._on_message(Message.new("GDiscord", "643945264868098049", "c6a249645d46209f337279cd2ca998c7", Util.get_time_millis(), "", [
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
