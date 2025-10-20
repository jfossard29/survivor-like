extends Area3D

@export var base_speed: float = 5.0
@export var base_valeur: float = 10.0

var target: Node3D = null
var is_following: bool = false
var valeur: float
var speed: float = 5.0
const CONTACT_DISTANCE: float = 0.6  # seuil pour considérer "touché"

func _ready():
	add_to_group("experience")
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))  # <- important
	if GameManager:
		GameManager.connect("multipliers_changed", Callable(self, "_update_from_game_manager"))
	_update_from_game_manager()
	# s'assurer que la vitesse est initialisée
	speed = base_speed

func _update_from_game_manager():
	valeur = base_valeur * (GameManager.xp_multiplier if GameManager else 1.0)

func start_following(player: Node3D):
	target = player
	is_following = true

func _physics_process(delta: float) -> void:
	if is_following and target and is_instance_valid(target):
		var dir_vec = target.global_position - global_position
		var dist = dir_vec.length()
		# fallback distance check pour attribuer XP si collision physique manque
		if dist <= CONTACT_DISTANCE:
			_award_and_free(target)
			return
		var dir = dir_vec.normalized()
		global_position += dir * speed * delta
		look_at(target.global_position, Vector3.UP)

func _on_area_entered(area: Area3D) -> void:
	# reçu de la zone Recolte ; on récupère le parent joueur
	var parent = area.get_parent()
	if parent and parent.is_in_group("player"):
		start_following(parent)

func _on_body_entered(body: Node) -> void:
	# détection physique si l'orbe touche directement le CharacterBody3D
	if body.is_in_group("player"):
		_award_and_free(body)

func _award_and_free(player_node: Node) -> void:
	if player_node and player_node.has_method("add_experience"):
		player_node.add_experience(valeur)
	queue_free()
