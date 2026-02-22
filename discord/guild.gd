class_name Guild

var guild_id: String
var guild_name: String
var guild_icon: String
var channels: Array[Channel.GuildChannel] = []

func _init(_guild_id: String, _guild_name: String, _guild_icon: String, _channels: Array[Channel.GuildChannel]) -> void:
	self.guild_id = _guild_id
	self.guild_name = _guild_name
	self.guild_icon = _guild_icon
	self.channels = _channels

# TODO: improve typing
static func from_json(data: Dictionary) -> Guild:
	var id: String = data["id"]
	var props: Variant = data["properties"]
	
	var name: Variant = props["name"]
	
	var icon: Variant = props["icon"]
	icon = icon if icon else ""
	
	var channels: Array[Channel.GuildChannel] = []
	
	for raw_channel: Variant in data["channels"]:
		channels.append(Channel.GuildChannel.from_json(raw_channel))
	
	return Guild.new(id, name, icon, channels)
	
	
