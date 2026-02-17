extends Node

# In-memory cache
var _texture_cache = {}
# Track ongoing requests to avoid duplicates
var _pending_requests = {}
# Disk cache directory
const CACHE_DIR = "user://image_cache/"

func _ready():
	# Create cache directory if it doesn't exist
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)

func load_image(url: String, callback: Callable) -> void:
	# Check memory cache first
	if _texture_cache.has(url):
		callback.call(_texture_cache[url])
		return
	
	# Check disk cache
	#var cached_path = _get_cached_path(url)
	#if FileAccess.file_exists(cached_path):
	#	var image = Image.load_from_file(cached_path)
	#	if image:
	#		var texture = ImageTexture.create_from_image(image)
	#		_texture_cache[url] = texture
	#		callback.call(texture)
	#		return
	
	# If already downloading, add callback to pending list
	if _pending_requests.has(url):
		_pending_requests[url].append(callback)
		return
	
	# Start new download
	_pending_requests[url] = [callback]
	_download_image(url)

func _download_image(url: String) -> void:
	print("Downloading " + url)
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	http_request.request_completed.connect(
		func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
			_on_image_downloaded(url, result, response_code, headers, body, http_request)
	)
	
	var error = http_request.request(url)
	if error != OK:
		print("Failed to start request for: ", url)
		http_request.queue_free()
		_cleanup_pending(url, null)

func _on_image_downloaded(url: String, result: int, response_code: int, 
						 headers: PackedStringArray, body: PackedByteArray, 
						 http_request: HTTPRequest) -> void:
	http_request.queue_free()
	
	var texture = null
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		# Try to create image from body
		var image = Image.new()
		var error = image.load_webp_from_buffer(body)

		if error == OK:
			# Save to disk cache
			#_save_to_disk_cache(url, body)
			
			# Create texture
			texture = ImageTexture.create_from_image(image)
			_texture_cache[url] = texture
		else:
			print("Failed to parse image from: ", url)
	
	# Notify all callbacks
	_cleanup_pending(url, texture)

func _cleanup_pending(url: String, texture: Texture2D) -> void:
	if _pending_requests.has(url):
		for callback in _pending_requests[url]:
			callback.call(texture)
		_pending_requests.erase(url)

func _get_cached_path(url: String) -> String:
	# Create a hash of the URL for filename
	var url_hash = str(url.md5_text())
	return CACHE_DIR + url_hash + ".cache"

func _save_to_disk_cache(url: String, data: PackedByteArray) -> void:
	var file = FileAccess.open(_get_cached_path(url), FileAccess.WRITE)
	if file:
		file.store_buffer(data)
		file.close()

func clear_memory_cache() -> void:
	_texture_cache.clear()

func clear_disk_cache() -> void:
	var dir = DirAccess.open(CACHE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
