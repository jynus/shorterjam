extends LineEdit

signal submit_cmd(cmd: String)

@export var key_sound : AudioStreamPlayer
@export var intro_sound : AudioStreamPlayer

func _on_text_changed(_new_text: String) -> void:
	key_sound.play()

func _on_text_submitted(new_text: String) -> void:
	intro_sound.play()
	text = ""
	if new_text.strip_edges() != "":
		submit_cmd.emit(new_text.strip_edges().to_lower())
