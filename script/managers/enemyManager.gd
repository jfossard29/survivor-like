# enemy_manager.gd
extends Node

@export var enemy_update_rate: float = 0.1

var registered_enemies: Array = []
var enemy_tick_timer: float = 0.0
var cleanup_timer: float = 0.0

const CLEANUP_INTERVAL: float = 2.0

func update(delta: float, player_ref: CharacterBody3D) -> void:
	# Nettoyage périodique
	cleanup_timer += delta
	if cleanup_timer >= CLEANUP_INTERVAL:
		cleanup_timer = 0.0
		_cleanup_invalid_enemies()
	
	# Mise à jour des ennemis
	enemy_tick_timer += delta
	if enemy_tick_timer >= enemy_update_rate:
		enemy_tick_timer = 0.0
		_update_enemies_tick(player_ref)

func _cleanup_invalid_enemies() -> void:
	var i = registered_enemies.size() - 1
	while i >= 0:
		if not is_instance_valid(registered_enemies[i]):
			registered_enemies.remove_at(i)
		i -= 1

func _update_enemies_tick(player_ref: CharacterBody3D) -> void:
	if not player_ref or not is_instance_valid(player_ref) or not player_ref.is_inside_tree():
		return
	
	var player_pos = player_ref.global_position
	
	for enemy in registered_enemies:
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		
		# Skip si l'ennemi a déjà attaqué
		if enemy.has_method("get") and enemy.get("has_attacked"):
			continue
		
		# Skip les boss - ils gèrent leur propre mouvement
		if enemy.is_in_group("boss"):
			continue
		
		var direction = (player_pos - enemy.global_position)
		direction.y = 0
		
		# Mettre à jour la direction cachée de l'ennemi
		if enemy.has_method("set"):
			enemy.cached_direction = direction.normalized()

func register_enemy(enemy: Node) -> void:
	if not registered_enemies.has(enemy):
		registered_enemies.append(enemy)

func unregister_enemy(enemy: Node) -> void:
	var idx = registered_enemies.find(enemy)
	if idx != -1:
		registered_enemies.remove_at(idx)

func get_enemy_count() -> int:
	return registered_enemies.size()

func get_valid_enemies() -> Array:
	var valid = []
	for enemy in registered_enemies:
		if is_instance_valid(enemy):
			valid.append(enemy)
	return valid

func reset() -> void:
	registered_enemies.clear()
	enemy_tick_timer = 0.0
	cleanup_timer = 0.0
