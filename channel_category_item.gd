extends FoldableContainer

@onready var vbox: Container = $VBoxContainer 

func set_channel(channel: Channel.GuildChannel) -> void:
	self.title = channel.channel_name

func add_node(node: Node) -> void:
	vbox.add_child(node)
