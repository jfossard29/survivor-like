extends Area3D

@export var base_radius: float = 1.0
var radius_multiplier: float = 1.0

@onready var zone: CollisionShape3D = $Zone

func _ready() -> void:
	connect("area_entered", Callable(self, "_on_area_entered"))
	_update_collision_shape()
	if Engine.has_singleton("GameManager"):
		GameManager.connect("multipliers_changed", Callable(self, "_on_game_manager_changed"))
		_on_game_manager_changed()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("experience"):
		area.start_following(get_parent())

func set_pickup_radius_multiplier(mult: float) -> void:
	radius_multiplier = mult
	_update_collision_shape()

func add_pickup_radius_multiplier(mult: float) -> void:
	radius_multiplier *= mult
	_update_collision_shape()

func _on_game_manager_changed() -> void:
	if Engine.has_singleton("GameManager"):
		radius_multiplier = GameManager.pickup_scale_multiplier
		_update_collision_shape()

func _update_collision_shape() -> void:
	if not zone:
		return
	zone.scale = Vector3.ONE * (base_radius * radius_multiplier)
	if zone.shape and zone.shape is SphereShape3D:
		zone.shape.radius = base_radius * radius_multiplier
