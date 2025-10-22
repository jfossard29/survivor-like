extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var has_attacked = false
var cached_direction = Vector3.ZERO

@export var speed = 5.0
@export var damage = 10

func _ready():
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
