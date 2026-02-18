# TODO: stop using HTTPRequestNode and make this a normal object
extends Node

var _cache: Dictionary[String, ImageTexture] = {}
var _pending: Dictionary[String, CacheRequest] = {}

class CacheRequest:
	signal done(texture: ImageTexture)

# Disk cache directory
const CACHE_DIR: String = "user://cache/"

func _ready() -> void:
	# Create cache directory if it doesn't exist
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)

func get_or_request(url: String) -> ImageTexture:
	var result: ImageTexture = _cache.get(url)

	if result:
		return result
		#callback.call(result)
	else:
		# Check disk cache
		var cached_path: String = _get_cached_path(url)

		if FileAccess.file_exists(cached_path):
			var image: Image = Image.load_from_file(cached_path)
			if image:
				var texture: ImageTexture = ImageTexture.create_from_image(image)
				_cache[url] = texture
				return texture
		
		return await request_image(url)

func request_image(url: String) -> Signal:
	if _pending.has(url):
		return _pending[url].done

	# Start new download
	var result: CacheRequest = CacheRequest.new()
	_pending[url] = result
	await _download_image(url)

	return result.done

func _download_image(url: String) -> void:
	print("Downloading " + url)
	var http_request: HTTPRequest = HTTPRequest.new()
	add_child(http_request)

	var error: Error = http_request.request(url)

	if error != OK:
		print("Failed to start request for: ", url)
		http_request.queue_free()
		_cleanup_pending(url, null)

	var http_result: Array = await http_request.request_completed
	#.connect(
	#	func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	#		_on_image_downloaded(url, result, response_code, headers, body, http_request)
	#)
	var result: int = http_result[0]
	var response_code: int = http_result[1]
	var body: PackedByteArray = http_result[3]
	
	_on_image_downloaded(url, result, response_code, body, http_request)


func _on_image_downloaded(url: String, result: int, response_code: int,
						 body: PackedByteArray, http_request: HTTPRequest) -> void:
	http_request.queue_free()

	var texture: ImageTexture = null

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var cache_path: String = _get_cached_path(url)
		_save_to_disk_cache(url, body)

		var image: Image = Image.new()
		var error: Error = image.load(cache_path)

		if error == OK:
			texture = ImageTexture.create_from_image(image)
			_cache[url] = texture
		else:
			print("Failed to parse image from: ", url)

	# Notify all callbacks
	_cleanup_pending(url, texture)

func _cleanup_pending(url: String, texture: Texture2D) -> void:
	var req: CacheRequest = _pending[url]

	if req:
		req.done.emit(texture)

	_pending.erase(url)

func _get_cached_path(url: String) -> String:
	# Create a hash of the URL for filename
	var url_hash: String = str(url.md5_text())
	var ext: String = _guess_extension(url)
	return CACHE_DIR + url_hash + ext

func _save_to_disk_cache(url: String, data: PackedByteArray) -> void:
	var cache_path: String = _get_cached_path(url)
	var file: FileAccess = FileAccess.open(cache_path, FileAccess.WRITE)

	if file:
		file.store_buffer(data)
		file.close()

# FIXME: this sucks
func _guess_extension(url: String) -> String:
	var clean: String = url
	var query_index: int = clean.find("?")
	if query_index != -1:
		clean = clean.substr(0, query_index)
	var fragment_index: int = clean.find("#")
	if fragment_index != -1:
		clean = clean.substr(0, fragment_index)
	var dot_index: int = clean.rfind(".")
	if dot_index == -1 or dot_index < clean.rfind("/"):
		return ".img"
	var ext: String = clean.substr(dot_index).to_lower()
	if ext == "" or ext.length() > 8:
		return ".img"
	return ext

func clear_memory_cache() -> void:
	_cache.clear()

func clear_disk_cache() -> void:
	var dir: DirAccess = DirAccess.open(CACHE_DIR)

	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()

		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)

			file_name = dir.get_next()
