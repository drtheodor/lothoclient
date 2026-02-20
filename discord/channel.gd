class_name Channel

var channel_id: String
var channel_name: String

func _init(_channel_id: String, _channel_name: String) -> void:
	self.channel_id = _channel_id
	self.channel_name = _channel_name

static func from_json(data: Dictionary) -> Channel:
	var _channel_name: String
	if data.has("name") and data["name"]:
		_channel_name = data["name"]
	elif data.has("recipients") and data["recipients"] is Array and data["recipients"].size() > 0:
		var recipient: Variant = data["recipients"][0]
		if recipient is Dictionary:
			_channel_name = recipient.get("global_name", "") if recipient.get("global_name", "") != "" else recipient.get("username", "")
			
	var _channel_id: String = data["id"]
	return Channel.new(_channel_id, _channel_name)
