extends Node

@export var difficulty_ramp_per_minute: float = 0.1  # combien la difficulté augmente par minute
var elapsed_time: float = 0.0
var difficulty_factor: float = 1.0

# Modificateurs modifiables par amélioration
var xp_multiplier: float = 1.0
var pickup_scale_multiplier: float = 1.0
var enemy_health_multiplier: float = 1.0
var enemy_damage_multiplier: float = 1.0
var enemy_speed_multiplier: float = 1.0

signal multipliers_changed()

func _process(delta: float) -> void:
	elapsed_time += delta
	_set_difficulty(1.0 + difficulty_ramp_per_minute * (elapsed_time / 60.0))

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
