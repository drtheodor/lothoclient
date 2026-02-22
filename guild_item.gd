class_name UiGuildItem
extends Button

signal clicked(guild: Guild)

var _guild: Guild

func _ready() -> void:
	self.pressed.connect(func () -> void: self.clicked.emit(self._guild))

func set_guild(guild: Guild) -> void:
	self._guild = guild
	
	self.tooltip_text = guild.guild_name
	self.icon = await Discord.get_guild_icon(guild.guild_id, guild.guild_icon)
