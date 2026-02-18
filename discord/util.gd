class_name Util

const ZERO_RECT: Rect2 = Rect2()

static var EMOJI: RegEx = RegEx.create_from_string("<(a?):([A-Za-z0-9_]+):([0-9]+)>")
const IMAGES: Array[String] = [
	"png", "jpg", "jpeg", "webp", "gif"
];

func extract_emoji_url(raw: String) -> String:
	var match: RegExMatch = EMOJI.search(raw)
	
	if not match:
		return "" # TODO: return null instead
	
	var animated: bool = match.get_string(1) == "a"
	var id: String = match.get_string(3)
	
	return "%s/emojis/%s.%s?size=64&quality=lossless" % [Discord.CDN_URL, id, "gif" if animated else "webp"]

#static func _looks_like_media(url: String) -> bool:
#	var clean: String = _strip_url_params(url)
#	return clean.find("/emojis/") != -1 or _is_image_url(clean)
