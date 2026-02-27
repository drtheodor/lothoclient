extends Window

signal on_reply

func _on_reply_button_pressed() -> void:
	on_reply.emit()
