class_name GMessage # TODO: remove the name
extends Control

@onready var avatar: TextureRect = $Avatar
@onready var author: Label = $VBoxContainer/Author/Name
@onready var label: RichTextLabel = $VBoxContainer/Content
@onready var timeLabel: Label = $VBoxContainer/Author/Time

var _timestamp_unix: int = 0
# FIXME: this should be in a base `Message` class, not the UI one
var _author_id: String
var _pending: bool = false

const BASE_URL: String = "https://cdn.discordapp.com"

var _tokens: Array = []

func set_author(author_name: String, author_id: String, avatar_id: String) -> void:
	self.author.text = author_name
	self._author_id = author_id

	if avatar_id and avatar_id != "":
		avatar.texture = await Discord.get_avatar(author_id, avatar_id, self._on_image_loaded)
	else:
		avatar.texture = null

func get_author() -> String:
	return author.text

func set_pending(pending: bool) -> void:
	_pending = pending
	var alpha: float = 0.6 if pending else 1.0
	self.modulate = Color(1, 1, 1, alpha)

func get_author_id() -> String:
	return self._author_id

func get_unix_timestamp() -> int:
	return _timestamp_unix

func _on_image_loaded(texture: Texture2D) -> void:
	avatar.texture = texture

func set_content(text: String, attachments: Array = [], embeds: Array = []) -> void:
	_tokens = []
	_add_text_and_media(text, attachments, embeds)

func append_content(text: String, attachments: Array = [], embeds: Array = []) -> void:
	if _tokens.size() > 0:
		_tokens.append({"type": "text", "value": "\n"})
	_add_text_and_media(text, attachments, embeds)

func _add_text_and_media(text: String, attachments: Array, embeds: Array) -> void:
	for token: Dictionary in _tokenize_text(text):
		_tokens.append(token)

	for embed: Dictionary in embeds:
		if embed is Dictionary:
			if _tokens.size() > 0:
				_tokens.append({"type": "text", "value": "\n"})
			var embed_title := str(embed.get("title", ""))
			if embed_title != "":
				_tokens.append({"type": "text", "value": embed_title})
			var embed_description := str(embed.get("description", ""))
			if embed_description != "":
				_tokens.append({"type": "text", "value": embed_description})
			var embed_image: Variant = embed.get("image", {})
			if embed_image is Dictionary and embed_image.has("url"):
				var url: String = str(embed_image["url"])
				if _is_image_url(url):
					_tokens.append({"type": "image", "url": url, "texture": null})
			var embed_thumbnail: Variant = embed.get("thumbnail", {})
			if embed_thumbnail is Dictionary and embed_thumbnail.has("url"):
				var url_thumb: String = str(embed_thumbnail["url"])
				if _is_image_url(url_thumb):
					_tokens.append({"type": "image", "url": url_thumb, "texture": null})

	for attachment: Dictionary in attachments:
		if attachment is Dictionary and attachment.has("url"):
			if _tokens.size() > 0:
				_tokens.append({"type": "text", "value": "\n"})
			var url_attachment: String = str(attachment["url"])
			var is_image := false
			if attachment.has("content_type"):
				var ct: String = str(attachment["content_type"]).to_lower()
				is_image = ct.begins_with("image/")
			if not is_image:
				is_image = _is_image_url(url_attachment)
			if is_image:
				_tokens.append({"type": "image", "url": url_attachment, "texture": null})
			else:
				_tokens.append({"type": "text", "value": "[file] " + url_attachment})

	_refresh_label()
	_request_missing_textures()

func _tokenize_text(text: String) -> Array:
	var tokens: Array = []
	var regex := RegEx.new()
	regex.compile("(<(a?):[A-Za-z0-9_]+:[0-9]+>)|((?i)https?://\\S+)")
	var start := 0

	for match in regex.search_all(text):
		var s := match.get_start(0)
		var e := match.get_end(0)
		if s > start:
			tokens.append({"type": "text", "value": text.substr(start, s - start)})
		var full := match.get_string(0)
		if full.begins_with("<"):
			tokens.append({"type": "emoji", "raw": full, "texture": null})
		else:
			var url := full
			var normalized := _normalize_image_url(url)
			if _is_image_url(normalized):
				tokens.append({"type": "image", "url": normalized, "texture": null})
			elif _looks_like_media(normalized):
				tokens.append({"type": "image", "url": normalized, "texture": null})
			else:
				tokens.append({"type": "text", "value": url})
		start = e

	if start < text.length():
		tokens.append({"type": "text", "value": text.substr(start, text.length() - start)})

	return tokens

func _refresh_label() -> void:
	label.bbcode_enabled = false
	label.clear()
	for token: Dictionary in _tokens:
		match token.get("type", ""):
			"text":
				label.append_text(token.get("value", ""))
			"emoji", "image":
				var tex: Texture2D = token.get("texture")
				if tex:
					var size: Vector2 = tex.get_size()
					var width := size.x
					var height := size.y
					if width > 256:
						var scale := 256.0 / width
						width = 256
						height = int(height * scale)
					label.add_image(tex, width, height, Color(1.0, 1.0, 1.0, 1.0), 5, Rect2(0, 0, 0, 0), true)
				else:
					label.append_text(" [image] ")

func _request_missing_textures() -> void:
	for i in range(_tokens.size()):
		var token: Dictionary = _tokens[i]
		if (token.get("type") == "emoji" or token.get("type") == "image") and token.get("texture") == null:
			var url: Variant = token.get("url", "")
			if token.get("type") == "emoji":
				url = _emoji_to_url(token.get("raw", ""))
			if url == "":
				continue
			var index := i
			Discord.image_cache.get_or_request(url, func(tex: Texture2D) -> void:
				if tex:
					_tokens[index]["texture"] = tex
				_refresh_label()
			)

func _emoji_to_url(raw: String) -> String:
	var regex := RegEx.new()
	regex.compile("<(a?):([A-Za-z0-9_]+):([0-9]+)>")
	var match := regex.search(raw)
	if not match:
		return ""
	var animated := match.get_string(1) == "a"
	var id := match.get_string(3)
	return "%s/emojis/%s.%s?size=64&quality=lossless" % [BASE_URL, id, "gif" if animated else "png"]

func _normalize_image_url(url: String) -> String:
	if url.to_lower().ends_with(".gifv"):
		return url.substr(0, url.length() - 1)
	return url

func _strip_url_params(url: String) -> String:
	var clean := url
	var q := clean.find("?")
	if q != -1:
		clean = clean.substr(0, q)
	var h := clean.find("#")
	if h != -1:
		clean = clean.substr(0, h)
	return clean

func _looks_like_media(url: String) -> bool:
	var clean := _strip_url_params(url)
	return clean.find("/emojis/") != -1 or _is_image_url(clean)

func _is_image_url(url: String) -> bool:
	var lower := _strip_url_params(url).to_lower()
	return lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".gif") or lower.ends_with(".webp") or lower.ends_with(".bmp") or lower.ends_with(".avif") or lower.ends_with(".gifv")

func set_timestamp(timestamp: int) -> void:
	self._timestamp_unix = timestamp

	var timezone_info: Dictionary = Time.get_time_zone_from_system()
	var utc_offset_minutes: int = timezone_info["bias"]

	var unix_timestamp_local: int = self._timestamp_unix + (utc_offset_minutes * 60)

	var local: Dictionary = Time.get_datetime_dict_from_unix_time(unix_timestamp_local)
	var now: Dictionary = Time.get_datetime_dict_from_system()

	var text: String = "%02d:%02d" % [local["hour"], local["minute"]]

	if local["day"] != now["day"] or local["month"] != now["month"]:
		text = "%02d-%02d " % [local["month"], local["day"]] + text

	if local["year"] != now["year"]:
		text = "%04d-" % local["year"] + text

	timeLabel.text = text
