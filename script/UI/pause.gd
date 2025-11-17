extends CanvasLayer

signal game_paused(is_paused: bool)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()

func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	visible = get_tree().paused
	MusicManager.set_game_paused(get_tree().paused)
	
	if get_tree().paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	game_paused.emit(get_tree().paused)

# ✅ Nouvelle méthode pour forcer le dépausage
func force_unpause() -> void:
	get_tree().paused = false
	visible = false
	MusicManager.set_game_paused(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	game_paused.emit(false)

# ✅ Nettoyer avant de détruire la scène
func _exit_tree() -> void:
	force_unpause()
