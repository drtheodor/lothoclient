class_name UiMessage
extends Control

@onready var avatar: TextureRect = $Avatar
@onready var author: Label = $VBoxContainer/Author/Name
@onready var label: RichTextLabel = $VBoxContainer/Content
@onready var timeLabel: Label = $VBoxContainer/Author/Time

@export var max_image_width: int = 580
@export var emoji_size: int = 24

var message: Message
var _pending: bool

func _ready() -> void:
	self.label.meta_clicked.connect(func (meta: Variant) -> void: OS.shell_open(str(meta)))

func set_message(_message: Message) -> void:
	self.message = _message
	
	self._set_author(_message.author_name, _message.author_id, _message.author_avatar)
	self._set_timestamp(_message.timestamp)
	self._set_content(_message.tokens)

func append_message(_message: Message) -> void:
	self._append_content([Message.BreakToken.INSTANCE])
	self._append_content(_message.tokens)

func _set_author(author_name: String, author_id: String, avatar_id: String) -> void:
	self.author.text = author_name

	if author_id and avatar_id:
		avatar.texture = await Discord.get_avatar(author_id, avatar_id)
	else:
		avatar.texture = null

func _set_content(tokens: Array[Message.Token]) -> void:
	label.clear()
	self._append_content(tokens)

func _append_content(tokens: Array[Message.Token]) -> void:
	# TODO: coroutine it properly
	for token: Message.Token in tokens:
		if token is Message.AbstractImageToken:
			var image_token: Message.AbstractImageToken = token
			
			if not image_token.texture:
				var ext: String = Url.get_extension(image_token.url)
				image_token.texture = await Discord.image_cache.get_or_request(image_token.url, ext)
	
	for token: Message.Token in tokens:
		match token.type:
			Message.Token.Type.BREAK:
				label.newline()
			
			Message.Token.Type.TEXT:
				var text_token: Message.TextToken = token
				label.append_text(str(text_token.text))
			
			Message.Token.Type.LINK:
				var link_token: Message.LinkToken = token
				
				label.push_color(Color.LIGHT_BLUE)
				label.push_meta(link_token.url)
				label.add_text(link_token.url)
				label.pop()
				label.pop()
			
			Message.Token.Type.IMAGE:
				var image_token: Message.ImageToken = token
				var tex: ImageTexture = image_token.texture
				
				if not tex:
					print("Failed to load image by url", image_token.url)
					continue
				
				var tex_size: Vector2 = tex.get_size()
				var width: int = int(tex_size.x)
				var height: int = int(tex_size.y)
				if width > max_image_width:
					var tex_scale: float = float(max_image_width) / width
					width = max_image_width
					height = int(height * tex_scale)
				
				var texture_rect: TextureRect = TextureRect.new()
			
				texture_rect.texture = tex
				texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
				texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
				texture_rect.custom_minimum_size = Vector2(width, height)
				texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				label.get_parent().add_child(texture_rect)
			
			Message.Token.Type.EMOJI:
				var emoji_token: Message.EmojiToken = token
				var tex: ImageTexture = emoji_token.texture
				var emoji_name: String = emoji_token.emoji_name
				
				label.add_image(tex, emoji_size, emoji_size, Color.WHITE, InlineAlignment.INLINE_ALIGNMENT_CENTER, Util.ZERO_RECT, null, false, emoji_name, false, false, emoji_name)

func _set_timestamp(timestamp: int) -> void:
	var timezone_info: Dictionary = Time.get_time_zone_from_system()
	var utc_offset_minutes: int = timezone_info["bias"]

	var unix_timestamp_local: int = timestamp + (utc_offset_minutes * 60)

	var local: Dictionary = Time.get_datetime_dict_from_unix_time(unix_timestamp_local)
	var now: Dictionary = Time.get_datetime_dict_from_system()

	var text: String = "%02d:%02d" % [local["hour"], local["minute"]]

	if local["day"] != now["day"] or local["month"] != now["month"]:
		text = "%02d-%02d " % [local["month"], local["day"]] + text

	if local["year"] != now["year"]:
		text = "%04d-" % local["year"] + text

	timeLabel.text = text

func set_pending(pending: bool) -> void:
	self._pending = pending
	
	var alpha: float = 0.6 if pending else 1.0
	self.modulate = Color(1, 1, 1, alpha)
