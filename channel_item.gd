class_name UiChannelItem
extends Button

var _channel: Channel

func _ready() -> void:
	self.pressed.connect(func () -> void: self.clicked.emit(self._channel))

func set_channel(channel: Channel) -> void:
	self._channel = channel
	self.text = "#" + channel.channel_name

signal clicked(channel: Channel)
