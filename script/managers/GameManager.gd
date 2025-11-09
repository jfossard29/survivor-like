extends Node

@export var difficulty_ramp_per_minute: float = 0.1
@export var enemy_update_rate: float = 0.1
@export var game_duration: float = 600.0  # 10 minutes
@export var boss_spawn_interval: float = 60.0  # Temps entre chaque boss

var elapsed_time: float = 0.0
var difficulty_factor: float = 1.0
var xp_multiplier: float = 1.0
var pickup_scale_multiplier: float = 1.0
var enemy_health_multiplier: float = 1.0
var enemy_damage_multiplier: float = 1.0
var enemy_speed_multiplier: float = 1.0

var registered_pylons: Array = []
var charged_pylons_count: int = 0

signal pylon_charged(pylon: Node3D)
signal all_pylons_charged()
signal multipliers_changed()
signal boss_spawn_requested()
signal game_over()
signal game_won()
signal timer_updated(remaining_time: float, elapsed_time: float)

var enemy_tick_timer: float = 0.0
var registered_enemies: Array = []
var player_reference: CharacterBody3D = null  # Référence au CharacterBody3D du joueur

# Optimisation : nettoyer moins souvent
var cleanup_timer: float = 0.0
const CLEANUP_INTERVAL: float = 2.0

# Gestion de la pause
var is_paused: bool = false

# Gestion des boss
var next_boss_time: float = 0.0
var game_active: bool = true

func _ready() -> void:
	# Initialiser le temps du premier boss
	next_boss_time = boss_spawn_interval
	
	# Connecter au signal de pause si un menu pause existe
	call_deferred("_connect_pause_menu")

func _connect_pause_menu() -> void:
	var pause_menu = get_tree().root.find_child("PauseMenu", true, false)
	if pause_menu and pause_menu.has_signal("game_paused"):
		pause_menu.game_paused.connect(_on_game_paused)

func _on_game_paused(paused: bool) -> void:
	is_paused = paused
	if is_paused:
		print("GameManager: Jeu en pause")
	else:
		print("GameManager: Jeu repris")

func _process(delta: float) -> void:
	# Ne rien faire si le jeu est en pause ou terminé
	if is_paused or not game_active:
		return
	
	elapsed_time += delta
	
	# Mettre à jour le timer UI
	_update_timer_display()
	
	# Vérifier la fin de partie
	if elapsed_time >= game_duration:
		_end_game(true)  # Victoire
		return
	
	# Vérifier le spawn des boss
	if elapsed_time >= next_boss_time:
		print("⏰ Temps écoulé: ", elapsed_time, " / Next boss time: ", next_boss_time)
		_spawn_boss()
		next_boss_time += boss_spawn_interval
		print("⏰ Prochain boss à: ", next_boss_time)
	
	# Augmenter la difficulté
	_set_difficulty(1.0 + difficulty_ramp_per_minute * (elapsed_time / 60.0))
	
	# Nettoyage des ennemis invalides seulement toutes les 2 secondes
	cleanup_timer += delta
	if cleanup_timer >= CLEANUP_INTERVAL:
		cleanup_timer = 0.0
		_cleanup_invalid_enemies()
	
	enemy_tick_timer += delta
	if enemy_tick_timer >= enemy_update_rate:
		enemy_tick_timer = 0.0
		_update_enemies_tick()

func _update_timer_display() -> void:
	var remaining_time = game_duration - elapsed_time
	timer_updated.emit(remaining_time, elapsed_time)

func _spawn_boss() -> void:
	print("🔥 Boss spawn à ", elapsed_time, " secondes!")
	print("📡 Émission du signal boss_spawn_requested...")
	boss_spawn_requested.emit()
	print("📡 Signal émis!")

func _end_game(won: bool) -> void:
	game_active = false
	
	if won:
		print("🎉 Victoire! Partie terminée après ", elapsed_time, " secondes")
		game_won.emit()
	else:
		print("💀 Game Over!")
		game_over.emit()

func player_died() -> void:
	_end_game(false)

func _cleanup_invalid_enemies() -> void:
	# Nettoyage optimisé en une seule passe
	var i = registered_enemies.size() - 1
	while i >= 0:
		if not is_instance_valid(registered_enemies[i]):
			registered_enemies.remove_at(i)
		i -= 1

func _get_player_position() -> Vector3:
	"""Helper pour obtenir la position du joueur"""
	if not player_reference or not is_instance_valid(player_reference):
		return Vector3.ZERO
	
	# Le player_reference est maintenant toujours le CharacterBody3D
	return player_reference.global_position

func _update_enemies_tick() -> void:
	if not player_reference or not is_instance_valid(player_reference):
		return
	
	# Vérifier que le joueur est dans l'arbre
	if not player_reference.is_inside_tree():
		return
	
	var player_pos = _get_player_position()
	
	for enemy in registered_enemies:
		# Vérifier que l'ennemi est valide ET dans l'arbre
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		
		# Vérifier si l'ennemi a la propriété has_attacked
		if enemy.has_method("get") and enemy.get("has_attacked"):
			continue
		
		# Skip les boss - ils gèrent leur propre mouvement
		if enemy.is_in_group("boss"):
			continue
		
		var direction = (player_pos - enemy.global_position)
		direction.y = 0
		
		# Vérifier si l'ennemi a la propriété cached_direction
		if enemy.has_method("set"):
			enemy.cached_direction = direction.normalized()

func register_enemy(enemy: Node) -> void:
	if not registered_enemies.has(enemy):
		registered_enemies.append(enemy)

func unregister_enemy(enemy: Node) -> void:
	var idx = registered_enemies.find(enemy)
	if idx != -1:
		registered_enemies.remove_at(idx)

func set_player(player: CharacterBody3D) -> void:
	"""Enregistre le CharacterBody3D du joueur"""
	player_reference = player
	print("✅ Joueur enregistré dans GameManager: ", player.name, " (Type: ", player.get_class(), ")")
	print("   Position initiale: ", player.global_position)

func get_player() -> CharacterBody3D:
	"""Retourne le CharacterBody3D du joueur"""
	return player_reference

func _set_difficulty(value: float) -> void:
	if is_equal_approx(difficulty_factor, value):
		return
	difficulty_factor = value
	
	# Mettre à jour les multiplicateurs basés sur la difficulté
	enemy_health_multiplier = 1.0 + (value - 1.0) * 0.5  # +50% de vie max
	enemy_damage_multiplier = 1.0 + (value - 1.0) * 0.3  # +30% de dégâts max
	enemy_speed_multiplier = 1.0 + (value - 1.0) * 0.2   # +20% de vitesse max
	
	emit_signal("multipliers_changed")

func add_xp_multiplier(factor: float) -> void:
	xp_multiplier *= factor
	emit_signal("multipliers_changed")

func add_pickup_multiplier(factor: float) -> void:
	pickup_scale_multiplier *= factor
	emit_signal("multipliers_changed")

func register_pylon(pylon: Node3D) -> void:
	if not registered_pylons.has(pylon):
		registered_pylons.append(pylon)

func unregister_pylon(pylon: Node3D) -> void:
	var idx = registered_pylons.find(pylon)
	if idx != -1:
		registered_pylons.remove_at(idx)

func notify_pylon_charged(pylon: Node3D) -> void:
	charged_pylons_count += 1
	pylon_charged.emit(pylon)
	
	if charged_pylons_count >= registered_pylons.size():
		all_pylons_charged.emit()
		print("🎉 Tous les pylônes sont chargés!")

func get_pylon_progress() -> Dictionary:
	return {
		"total": registered_pylons.size(),
		"charged": charged_pylons_count,
		"progress": float(charged_pylons_count) / max(1, registered_pylons.size())
	}

func get_remaining_time() -> float:
	return max(0.0, game_duration - elapsed_time)

func get_elapsed_time() -> float:
	return elapsed_time
