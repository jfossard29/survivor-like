extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var has_attacked = false
var cached_direction = Vector3.ZERO

@export var speed: float = 3.0
@export var damage: int = 10
@export var max_health: int = 100
@export var experience_scene: PackedScene
@export var debug : bool
var current_health: int = 10

func _ready():
	add_to_group("enemy")
	GameManager.register_enemy(self)

func _exit_tree():
	GameManager.unregister_enemy(self)

func _physics_process(delta: float) -> void:
	# Si déjà attaqué, ne rien faire
	if has_attacked:
		return
	
	# Gravité uniquement si pas au sol
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	# Mouvement horizontal basé sur la direction cachée
	velocity.x = cached_direction.x * speed
	velocity.z = cached_direction.z * speed
	
	move_and_slide()
	
	# Vérifier collisions (optimisé)
	if get_slide_collision_count() > 0:
		_check_player_collision()

func _check_player_collision() -> void:
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(damage)
			has_attacked = true
			queue_free()
			return  # Sortir immédiatement

func take_damage(amount: int) -> void:
	current_health -= amount
	if debug:
		print("PNJ touché ! PV restants :", current_health)
	
	if current_health <= 0:
		die()

func die() -> void:
	
	# Dropper l'expérience si la scène existe
	if experience_scene:
		var experience = experience_scene.instantiate()
		get_parent().add_child(experience)
		experience.global_position = global_position
	
	queue_free()
