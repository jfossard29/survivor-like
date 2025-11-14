# difficulty_manager.gd
extends Node

@export var difficulty_ramp_per_minute: float = 0.1

var difficulty_factor: float = 1.0
var xp_multiplier: float = 1.0
var pickup_scale_multiplier: float = 1.0
var enemy_health_multiplier: float = 1.0
var enemy_damage_multiplier: float = 1.0
var enemy_speed_multiplier: float = 1.0

signal multipliers_changed()

func update(delta: float) -> void:
	# La difficulté est calculée en fonction du temps écoulé
	var elapsed_time = get_parent().get_timer_manager().get_elapsed_time()
	_set_difficulty(1.0 + difficulty_ramp_per_minute * (elapsed_time / 60.0))

func _set_difficulty(value: float) -> void:
	if is_equal_approx(difficulty_factor, value):
		return
	
	difficulty_factor = value
	
	# Mettre à jour les multiplicateurs basés sur la difficulté
	enemy_health_multiplier = 1.0 + (value - 1.0) * 0.5  # +50% de vie max
	enemy_damage_multiplier = 1.0 + (value - 1.0) * 0.3  # +30% de dégâts max
	enemy_speed_multiplier = 1.0 + (value - 1.0) * 0.2   # +20% de vitesse max
	
	multipliers_changed.emit()

func add_xp_multiplier(factor: float) -> void:
	xp_multiplier *= factor
	multipliers_changed.emit()

func add_pickup_multiplier(factor: float) -> void:
	pickup_scale_multiplier *= factor
	multipliers_changed.emit()

func get_difficulty_factor() -> float:
	return difficulty_factor

func get_xp_multiplier() -> float:
	return xp_multiplier

func get_pickup_multiplier() -> float:
	return pickup_scale_multiplier

func get_enemy_health_multiplier() -> float:
	return enemy_health_multiplier

func get_enemy_damage_multiplier() -> float:
	return enemy_damage_multiplier

func get_enemy_speed_multiplier() -> float:
	return enemy_speed_multiplier
