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
	else:
		print("HarvestZone: GameManager singleton absent au ready")
	
	_update_collision_shape()
	
	print("✅ Zone Recolte configurée - Layer: ", collision_layer, " Mask: ", collision_mask)

func _on_area_entered(area: Area3D) -> void:
	print("🔍 Recolte détecte Area: ", area.name, " Parent: ", area.get_parent().name if area.get_parent() else "null")
	
	# ✅ L'area détectée est le RecolteDetector de l'orbe (RigidBody3D)
	var orbe = area.get_parent()
	if orbe and orbe.is_in_group("experience"):
		print("✅ Orbe trouvé, démarrage de l'attraction")
		orbe.start_following(get_parent())
	else:
		print("⚠️ Area détectée mais pas un orbe d'XP")

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
