class_name Url

static var REGEX: RegEx = RegEx.create_from_string("https?://[^\\s<>]+|www\\.[^\\s<>]+")

## Returns the extension of the url
static func get_extension(url: String) -> String:
	var ext: String = url.get_extension()
	var query: int = ext.find("?")
	
	if query:
		ext = ext.substr(0, query)
	
	return ext.to_lower()

static func is_image(url: String) -> bool:
	var ext: String = Url.get_extension(url)
	
	for image: String in Util.IMAGES:
		if ext == image:
			return true
	
	return false
