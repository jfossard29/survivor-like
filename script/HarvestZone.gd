extends Area3D

@export var base_radius: float = 1.0

var radius_multiplier: float = 1.0

@onready var zone: CollisionShape3D = $Zone

func _ready() -> void:
	
	connect("area_entered", Callable(self, "_on_area_entered"))
	
	# Rendre la shape unique
	if zone and zone.shape:
		zone.shape = zone.shape.duplicate()
	
	# Se connecter au GameManager
	if Engine.has_singleton("GameManager"):
		GameManager.connect("multipliers_changed", Callable(self, "_on_game_manager_changed"))
	
	_update_collision_shape()

func _on_area_entered(area: Area3D) -> void:
	var orbe = area.get_parent()
	if orbe and orbe.is_in_group("experience"):
		orbe.start_following(get_parent())

func set_pickup_radius_multiplier(mult: float) -> void:
	radius_multiplier = mult
	_update_collision_shape()

func add_pickup_radius_multiplier(mult: float) -> void:
	radius_multiplier *= mult
	_update_collision_shape()

func _on_game_manager_changed() -> void:
	if not Engine.has_singleton("GameManager"):
		return
	var gm_val = GameManager.pickup_scale_multiplier
	radius_multiplier = gm_val
	_update_collision_shape()

func _update_collision_shape() -> void:
	if not zone:
		return
	if not zone.shape:
		return
	if zone.shape is SphereShape3D:
		zone.shape.radius = base_radius * radius_multiplier
