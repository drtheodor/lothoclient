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

static func json_s2i(json: Dictionary, path: String, default: int = -1) -> int:
	var some: Variant = json.get(path, default)
	
	if some is int:
		return some
	
	if some is String:
		var ssome: String = some
		return int(ssome)
	
	return default

static func get_time_millis() -> int:
	return int(Time.get_unix_time_from_system() * 1000)

#static func _looks_like_media(url: String) -> bool:
#	var clean: String = _strip_url_params(url)
#	return clean.find("/emojis/") != -1 or _is_image_url(clean)
