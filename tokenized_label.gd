class_name UiTokenizedLabel
extends RichTextLabel

func from_tokens(tokens: Array[Message.Token], max_image_width: int, emoji_size: int) -> void:
	# TODO: coroutine it properly
	for token: Message.Token in tokens:
		if token is Message.AbstractImageToken:
			var image_token: Message.AbstractImageToken = token
			
			if not image_token.texture:
				var ext: String = Url.get_extension(image_token.url)
				# FIXME: temp await fix since there's no Promise.all :(
				image_token.texture = await Discord.image_cache.get_or_request(image_token.url, ext)
	
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
				texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
				texture_rect.custom_minimum_size = Vector2(width, height)
				texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				self.get_parent().add_child(texture_rect)
			
			Message.Token.Type.EMOJI:
				var emoji_token: Message.EmojiToken = token
				var tex: ImageTexture = emoji_token.texture
				var emoji_name: String = emoji_token.emoji_name
				
				self.add_image(tex, emoji_size, emoji_size, Color.WHITE, InlineAlignment.INLINE_ALIGNMENT_CENTER, Util.ZERO_RECT, null, false, emoji_name, false, false, emoji_name)
