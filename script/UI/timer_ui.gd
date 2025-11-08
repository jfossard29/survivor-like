extends CanvasLayer

@onready var label: Label = $Label  # Ajustez le chemin si nécessaire

func _ready() -> void:
	# Se connecter au signal du GameManager
	if GameManager:
		GameManager.timer_updated.connect(_on_timer_updated)
	else:
		push_error("GameManager n'est pas accessible!")

func _on_timer_updated(remaining_time: float, elapsed_time: float) -> void:
	if not label:
		return
	
	var minutes = int(remaining_time / 60.0)
	var seconds = int(remaining_time) % 60
	label.text = "%02d:%02d" % [minutes, seconds]
	
	# Optionnel : changer la couleur si le temps est critique
	if remaining_time <= 60.0:  # Moins d'1 minute
		label.modulate = Color.RED
	elif remaining_time <= 120.0:  # Moins de 2 minutes
		label.modulate = Color.ORANGE
	else:
		label.modulate = Color.WHITE
