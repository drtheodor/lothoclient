class_name UiMessageReplyingTo
extends Container

func set_message(message: Message) -> void:
	$RichTextLabel.from_tokens(message.tokens, 0, 24)
	$Author.text = "@" + message.author_name
	$Rounder/Avatar.texture = await Discord.get_avatar(message.author_id, message.author_avatar)
