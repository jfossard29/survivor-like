extends Node

@export var difficulty_ramp_per_minute: float = 0.1
@export var enemy_update_rate: float = 0.1

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

var enemy_tick_timer: float = 0.0
var registered_enemies: Array = []
var player_reference: CharacterBody3D = null

# Optimisation : nettoyer moins souvent
var cleanup_timer: float = 0.0
const CLEANUP_INTERVAL: float = 2.0

func _process(delta: float) -> void:
	elapsed_time += delta
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

func _cleanup_invalid_enemies() -> void:
	# Nettoyage optimisé en une seule passe
	var i = registered_enemies.size() - 1
	while i >= 0:
		if not is_instance_valid(registered_enemies[i]):
			registered_enemies.remove_at(i)
		i -= 1

func _update_enemies_tick() -> void:
	if not player_reference or not is_instance_valid(player_reference):
		return
	
	var player_pos = player_reference.global_position
	
	# Pas de filter() ici, juste une boucle directe
	for enemy in registered_enemies:
		if not is_instance_valid(enemy) or enemy.has_attacked:
			continue
			
		var direction = (player_pos - enemy.global_position)
		direction.y = 0
		enemy.cached_direction = direction.normalized()

func register_enemy(enemy: Node) -> void:
	if not registered_enemies.has(enemy):
		registered_enemies.append(enemy)

func unregister_enemy(enemy: Node) -> void:
	var idx = registered_enemies.find(enemy)
	if idx != -1:
		registered_enemies.remove_at(idx)

func set_player(player: CharacterBody3D) -> void:
	player_reference = player

func _set_difficulty(value: float) -> void:
	if is_equal_approx(difficulty_factor, value):
		return
	difficulty_factor = value
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
