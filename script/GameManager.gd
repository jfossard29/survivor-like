extends Node

@export var difficulty_ramp_per_minute: float = 0.1
var elapsed_time: float = 0.0
var difficulty_factor: float = 1.0

var xp_multiplier: float = 1.0
var pickup_scale_multiplier: float = 1.0
var enemy_health_multiplier: float = 1.0
var enemy_damage_multiplier: float = 1.0
var enemy_speed_multiplier: float = 1.0

signal multipliers_changed()

@export var enemy_update_rate: float = 0.1
var enemy_tick_timer: float = 0.0
var registered_enemies: Array = []
var player_reference: CharacterBody3D = null

func _process(delta: float) -> void:
	elapsed_time += delta
	_set_difficulty(1.0 + difficulty_ramp_per_minute * (elapsed_time / 60.0))
	
	enemy_tick_timer += delta
	if enemy_tick_timer >= enemy_update_rate:
		enemy_tick_timer = 0.0
		_update_enemies_tick()

func _update_enemies_tick() -> void:
	if not player_reference or not is_instance_valid(player_reference):
		return
	
	registered_enemies = registered_enemies.filter(func(e): return is_instance_valid(e))
	
	var player_pos = player_reference.global_position
	
	for enemy in registered_enemies:
		if not enemy.has_attacked:
			var direction = (player_pos - enemy.global_position)
			direction.y = 0
			enemy.cached_direction = direction.normalized()

func register_enemy(enemy: Node) -> void:
	if not registered_enemies.has(enemy):
		registered_enemies.append(enemy)

func unregister_enemy(enemy: Node) -> void:
	registered_enemies.erase(enemy)

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
