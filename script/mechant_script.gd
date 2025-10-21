extends CharacterBody3D

@export var speed: float = 5.0
@export var damage: int = 25
@export var max_health: int = 50
@export var experience_scene: PackedScene
@onready var game_manager: Node = GameManager
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var player: Node3D = null
var current_health: int
var has_attacked: bool = false

func _ready() -> void:
	add_to_group("pnj")
	current_health = max_health
	player = get_tree().get_first_node_in_group("player")
	_apply_difficulty_modifiers()

	if player:
		print("✅ Joueur trouvé :", player.name)
	else:
		print("❌ Aucun joueur trouvé dans le groupe 'player' !")

func _apply_difficulty_modifiers():
	if not game_manager:
		return
	# Facteur global venant du temps
	var df = game_manager.difficulty_factor

	# Appliquer multiplicateurs liés au temps + améliorations
	max_health = int(max_health * df * game_manager.enemy_health_multiplier)
	damage = int(damage * df * game_manager.enemy_damage_multiplier)
	speed = speed * df * game_manager.enemy_speed_multiplier
	current_health = max_health

func _physics_process(delta: float) -> void:
	if not player or has_attacked:
		return
	
	# Appliquer la gravité (conserver velocity.y)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	# Déplacement horizontal vers le joueur (sans toucher à velocity.y)
	var direction = (player.global_position - global_position)
	direction.y = 0
	direction = direction.normalized()
	
	# Appliquer seulement le mouvement horizontal
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	move_and_slide()
	
	# Vérification de collision avec le joueur
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("player") and not has_attacked:
			if collider.has_method("take_damage"):
				collider.take_damage(damage)
				print("💥 PNJ touche le joueur !")
			has_attacked = true
			queue_free()
			break
func take_damage(amount: int) -> void:
	current_health -= amount
	print("PNJ touché ! PV restants :", current_health)
	if current_health <= 0:
		die()

func die() -> void:
	print("PNJ mort !")
	if experience_scene:
		var experience = experience_scene.instantiate()
		get_parent().add_child(experience)
		experience.global_position = global_position
	queue_free()
