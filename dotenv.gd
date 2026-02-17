extends Node

func _ready() -> void:
	var load_text_file = func (path) -> String:
		# Open the file in read mode
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if FileAccess.get_open_error() != OK:
			printerr("Could not open file: ", path, " Error code: ", FileAccess.get_open_error())
			return "" # Return an empty string or handle the error appropriately
		
		# Read the entire file as a single string
		return file.get_as_text()
	
	var lines: PackedStringArray = load_text_file.call(".env").split("\n")
	for line in lines:
		if line.is_empty(): continue
		var line2 = line.split("=", true, 1)
		# print("set: %s" % line2) MASSIVE fucking security risk lol
		OS.set_environment(line2[0], line2[1])
var token: String:
	get:
		return OS.get_environment("TOKEN")

var channel: String:
	get:
		return OS.get_environment("CHANNEL")
