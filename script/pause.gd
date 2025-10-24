extends CanvasLayer

signal game_paused(is_paused: bool)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()

func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	visible = get_tree().paused
	game_paused.emit(get_tree().paused)
