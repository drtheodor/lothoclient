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

func get_or_request(url: String, callback: Callable) -> void:
	var result: ImageTexture = _cache[url]
	
	if result != null: callback.call(result)
	else: request_image(url).done.connect(callback)

func request_image(url: String) -> CacheRequest:
	# Check disk cache
	var cached_path: String = _get_cached_path(url)
	
	if FileAccess.file_exists(cached_path):
		var image: Image = Image.load_from_file(cached_path)
		if image:
			var texture: ImageTexture = ImageTexture.create_from_image(image)
			_cache[url] = texture
			return null
	
	if _pending.has(url):
		return _pending[url]
	
	# Start new download
	var result: CacheRequest = CacheRequest.new()
	_pending[url] = result
	_download_image(url)
	
	return result

func _download_image(url: String) -> void:
	print("Downloading " + url)
	var http_request: HTTPRequest = HTTPRequest.new()
	add_child(http_request)
	
	http_request.request_completed.connect(
		func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
			_on_image_downloaded(url, result, response_code, headers, body, http_request)
	)
	
	var error: Error = http_request.request(url)
	
	if error != OK:
		print("Failed to start request for: ", url)
		http_request.queue_free()
		_cleanup_pending(url, null)

func _on_image_downloaded(url: String, result: int, response_code: int, 
						 _headers: PackedStringArray, body: PackedByteArray, 
						 http_request: HTTPRequest) -> void:
	http_request.queue_free()
	
	var texture: ImageTexture = null
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		# Try to create image from body
		var image: Image = Image.new()
		var error: Error = image.load_webp_from_buffer(body)

		if error == OK:
			# Save to disk cache
			_save_to_disk_cache(url, body)
			
			# Create texture
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

func _get_cached_path(url: String) -> String:
	# Create a hash of the URL for filename
	var url_hash: String = str(url.md5_text())
	return CACHE_DIR + url_hash + ".cache"

func _save_to_disk_cache(url: String, data: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(_get_cached_path(url), FileAccess.WRITE)
	
	if file:
		file.store_buffer(data)
		file.close()

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
