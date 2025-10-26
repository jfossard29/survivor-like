extends RigidBody3D

@export var base_speed: float = 8.0
@export var base_valeur: float = 10.0
@export var attraction_force: float = 15.0  # Force d'attraction vers le joueur
@export var max_follow_speed: float = 12.0  # Vitesse max pendant l'attraction
@onready var recolte_area: Area3D = $RecolteDetector
var target: Node3D = null
var is_following: bool = false
var valeur: float
const CONTACT_DISTANCE: float = 1.0  # Seuil pour considérer "touché"

func _ready():
	add_to_group("experience")
	
	# Connecter les signaux
	recolte_area.area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	if GameManager:
		GameManager.multipliers_changed.connect(_update_from_game_manager)
	
	_update_from_game_manager()

func _update_from_game_manager():
	valeur = base_valeur * (GameManager.xp_multiplier if GameManager else 1.0)

func start_following(player: Node3D):
	target = player
	is_following = true
	# Réduire l'effet de la gravité pendant l'attraction
	gravity_scale = 0.3

func _physics_process(delta: float) -> void:
	if is_following and target and is_instance_valid(target):
		var dir_vec = target.global_position - global_position
		var dist = dir_vec.length()
		
		# Vérifier si on est assez proche pour être collecté
		if dist <= CONTACT_DISTANCE:
			_award_and_free(target)
			return
		
		# Appliquer une force d'attraction vers le joueur
		var dir = dir_vec.normalized()
		var force = dir * attraction_force
		apply_central_force(force)
		
		# Limiter la vitesse horizontale
		var horizontal_vel = Vector3(linear_velocity.x, 0, linear_velocity.z)
		if horizontal_vel.length() > max_follow_speed:
			var clamped = horizontal_vel.normalized() * max_follow_speed
			linear_velocity.x = clamped.x
			linear_velocity.z = clamped.z

func _on_area_entered(area: Area3D) -> void:
	# Détection de la zone Recolte du joueur
	var parent = area.get_parent()
	if parent and parent.is_in_group("player"):
		start_following(parent)

func _on_body_entered(body: Node) -> void:
	# Détection physique directe avec le joueur
	if body.is_in_group("player"):
		_award_and_free(body)

func _award_and_free(player_node: Node) -> void:
	if player_node and player_node.has_method("add_experience"):
		player_node.add_experience(valeur)
	queue_free()
