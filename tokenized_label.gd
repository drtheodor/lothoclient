class_name UiTokenizedLabel
extends RichTextLabel

const PLACEHOLDER_IMAGE: Texture2D = preload("res://icon.svg")

func from_tokens(tokens: Array[Message.Token], max_image_width: int, emoji_size: int) -> void:
	for token: Message.Token in tokens:
		match token.type:
			Message.Token.Type.TEXT:
				var text_token: Message.TextToken = token
				self.append_text(str(text_token.text))
			
			Message.Token.Type.LINK:
				var link_token: Message.LinkToken = token
				
				self.push_color(Color.LIGHT_BLUE)
				self.push_meta(link_token.url)
				self.add_text(link_token.url)
				self.pop()
				self.pop()
			
			Message.Token.Type.IMAGE:
				if not max_image_width:
					self.append_text("")
					continue
				
				var image_token: Message.ImageToken = token
				self._handle_image(image_token, max_image_width)
			
			Message.Token.Type.EMOJI:
				var emoji_token: Message.EmojiToken = token
				self._handle_emoji(emoji_token, emoji_size)

func _handle_image(token: Message.ImageToken, max_image_width: int) -> void:
	var texture_rect: TextureRect = TextureRect.new()

	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	self.get_parent().add_child(texture_rect)
	
	var ext: String = Url.get_extension(token.url)
	var tex: ImageTexture = await Discord.image_cache.get_or_request(token.url, ext)
	
	var tex_size: Vector2 = tex.get_size()
	var width: int = int(tex_size.x)
	var height: int = int(tex_size.y)
	if width > max_image_width:
		var tex_scale: float = float(max_image_width) / width
		width = max_image_width
		height = int(height * tex_scale)
	
	
	texture_rect.custom_minimum_size = Vector2(width, height)
	texture_rect.texture = tex

func _handle_emoji(token: Message.EmojiToken, emoji_size: int) -> void:
	var emoji_name: String = token.emoji_name
	
	var texture: ImageTexture = Discord.image_cache.get_cached(token.url)
	
	if texture:
		self.add_image(texture, emoji_size, emoji_size, Color.WHITE, 
			InlineAlignment.INLINE_ALIGNMENT_CENTER, Util.ZERO_RECT, 
			null, false, emoji_name, false, false, emoji_name
		)
	else:
		self.add_image(PLACEHOLDER_IMAGE, emoji_size, emoji_size, Color.WHITE, 
			InlineAlignment.INLINE_ALIGNMENT_CENTER, Util.ZERO_RECT, 
			token.emoji_id, false, emoji_name, false, false, emoji_name
		)
		
		var ext: String = Url.get_extension(token.url)
		texture = await Discord.image_cache.get_or_request(token.url, ext)
		
		self.update_image(token.emoji_id, RichTextLabel.UPDATE_TEXTURE, texture)
