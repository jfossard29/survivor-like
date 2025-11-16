# game_manager.gd - Autoload principal
extends Node

# Références aux autres gestionnaires
var difficulty_manager: Node
var enemy_manager: Node
var pylon_manager: Node
var timer_manager: Node

# État du jeu
var game_active: bool = false
var is_paused: bool = false

# Référence au joueur
var player_reference: CharacterBody3D = null

# Signaux centraux
signal game_over()
signal game_won()
signal game_paused(paused: bool)

func _ready() -> void:
	# Créer et initialiser les sous-gestionnaires
	difficulty_manager = preload("res://script/managers/difficultyManager.gd").new()
	add_child(difficulty_manager)
	
	enemy_manager = preload("res://script/managers/enemyManager.gd").new()
	add_child(enemy_manager)
	
	pylon_manager = preload("res://script/managers/pylonManager.gd").new()
	add_child(pylon_manager)
	
	timer_manager = preload("res://script/managers/timerManager.gd").new()
	add_child(timer_manager)
	
	# Connecter les signaux
	_setup_signals()
	
	# Connecter au menu pause
	call_deferred("_connect_pause_menu")

func _setup_signals() -> void:
	timer_manager.game_time_ended.connect(_on_game_time_ended)
	timer_manager.boss_spawn_requested.connect(_on_boss_spawn_requested)
	pylon_manager.all_pylons_charged.connect(_on_all_pylons_charged)

func _connect_pause_menu() -> void:
	var pause_menu = get_tree().root.find_child("PauseMenu", true, false)
	if pause_menu and pause_menu.has_signal("game_paused"):
		pause_menu.game_paused.connect(_on_game_paused)

func _on_game_paused(paused: bool) -> void:
	is_paused = paused
	game_paused.emit(paused)
	print("GameManager: Jeu ", "en pause" if paused else "repris")

func _process(delta: float) -> void:
	if is_paused or not game_active:
		return
	
	# Déléguer aux gestionnaires
	difficulty_manager.update(delta)
	enemy_manager.update(delta, player_reference)
	timer_manager.update(delta)

func set_game_active(state: bool) -> void:
	game_active = state
	if state:
		timer_manager.start()
	else:
		timer_manager.stop()

func set_player(player: CharacterBody3D) -> void:
	player_reference = player
	print("✅ Joueur enregistré: ", player.name)

func get_player() -> CharacterBody3D:
	return player_reference

func player_died() -> void:
	_end_game(false)

func _on_game_time_ended() -> void:
	_end_game(true)

func _on_boss_spawn_requested() -> void:
	print("🔥 Boss spawn demandé!")
	# Propager le signal aux systèmes concernés

func _on_all_pylons_charged() -> void:
	print("🎉 Tous les pylônes chargés!")
	# Déclencher la victoire ou un événement spécial

func _end_game(won: bool) -> void:
	game_active = false
	
	if won:
		print("🎉 Victoire!")
		game_won.emit()
	else:
		print("💀 Game Over!")
		game_over.emit()

func get_difficulty_manager() -> Node:
	return difficulty_manager

func get_enemy_manager() -> Node:
	return enemy_manager

func get_pylon_manager() -> Node:
	return pylon_manager

func get_timer_manager() -> Node:
	return timer_manager

func reset() -> void:
	difficulty_manager.reset()
	enemy_manager.reset()
	pylon_manager.reset()
	timer_manager.reset()
	WeaponManager.reset()
	game_active = false
	player_reference = null
