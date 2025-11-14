# timer_manager.gd
extends Node

@export var game_duration: float = 600.0  # 10 minutes
@export var boss_spawn_interval: float = 60.0  # Temps entre chaque boss

var elapsed_time: float = 0.0
var next_boss_time: float = 0.0
var is_running: bool = false

signal timer_updated(remaining_time: float, elapsed_time: float)
signal boss_spawn_requested()
signal game_time_ended()

func _ready() -> void:
	# Initialiser le temps du premier boss
	next_boss_time = boss_spawn_interval

func start() -> void:
	is_running = true
	elapsed_time = 0.0
	next_boss_time = boss_spawn_interval

func stop() -> void:
	is_running = false

func pause() -> void:
	is_running = false

func resume() -> void:
	is_running = true

func update(delta: float) -> void:
	if not is_running:
		return
	
	elapsed_time += delta
	
	# Mettre à jour l'affichage du timer
	_update_timer_display()
	
	# Vérifier la fin de partie
	if elapsed_time >= game_duration:
		game_time_ended.emit()
		stop()
		return
	
	# Vérifier le spawn des boss
	if elapsed_time >= next_boss_time:
		print("⏰ Boss spawn à ", elapsed_time, " secondes")
		boss_spawn_requested.emit()
		next_boss_time += boss_spawn_interval
		print("⏰ Prochain boss à: ", next_boss_time, " secondes")

func _update_timer_display() -> void:
	var remaining_time = game_duration - elapsed_time
	timer_updated.emit(remaining_time, elapsed_time)

func get_remaining_time() -> float:
	return max(0.0, game_duration - elapsed_time)

func get_elapsed_time() -> float:
	return elapsed_time

func get_progress() -> float:
	return elapsed_time / game_duration

func set_game_duration(duration: float) -> void:
	game_duration = duration

func set_boss_interval(interval: float) -> void:
	boss_spawn_interval = interval
