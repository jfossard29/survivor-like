extends Area3D

@export var base_radius: float = 1.0
var radius_multiplier: float = 1.0

@onready var zone: CollisionShape3D = $Zone

func _ready() -> void:
	connect("area_entered", Callable(self, "_on_area_entered"))
	# rendre la shape unique pour être sûr que changement de radius ait effet
	if zone and zone.shape:
		zone.shape = zone.shape.duplicate()
	# se connecter seulement si singleton présent
	if Engine.has_singleton("GameManager"):
		GameManager.connect("multipliers_changed", Callable(self, "_on_game_manager_changed"))
	else:
		print("HarvestZone: GameManager singleton absent au ready")
	_update_collision_shape()

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
	if not Engine.has_singleton("GameManager"):
		print("HarvestZone._on_game_manager_changed: pas de singleton")
		return
	var gm_val = GameManager.pickup_scale_multiplier
	print("HarvestZone: reçu multipliers_changed, GameManager.pickup_scale_multiplier =", gm_val)
	radius_multiplier = gm_val
	_update_collision_shape()

func _update_collision_shape() -> void:
	if not zone:
		print("Zone missing")
		return
	if not zone.shape:
		print("Zone.shape missing")
		return
	if zone.shape is SphereShape3D:
		zone.shape.radius = base_radius * radius_multiplier
		print("Nouveau rayon (shape.radius):", zone.shape.radius)
	else:
		print("zone.shape n'est pas une SphereShape3D:", zone.shape)
