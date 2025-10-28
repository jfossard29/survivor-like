extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var can_attack = false
var cached_direction = Vector3.ZERO

@export var speed: float = 3.0
@export var climb_speed: float = 2.0
@export var damage: int = 10
@export var max_health: int = 100
@export var experience_scene: PackedScene
@export var debug: bool = false
@export var attack_interval: float = 2.0
@export var stuck_speed_threshold: float = 0.1  # Pourcentage de la vitesse normale (0.5 = 50%)

var current_health: int
var attack_timer: float = 0.0
var is_climbing: bool = false
var last_position: Vector3

func _ready():
	add_to_group("enemy")
	GameManager.register_enemy(self)
	current_health = max_health
	attack_timer = attack_interval
	last_position = global_position

func _exit_tree():
	GameManager.unregister_enemy(self)

func _physics_process(delta: float) -> void:
	
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
	
	# Calculer la vitesse horizontale actuelle
	var horizontal_velocity = Vector2(velocity.x, velocity.z).length()
	var expected_speed = speed * cached_direction.length()
	
	# Vérifier si on est bloqué par le joueur
	var blocked_by_player = _is_blocked_by_player()
	
	# Si on avance moins vite que prévu ET qu'on n'est pas bloqué par le joueur, grimper
	if expected_speed > 0 and horizontal_velocity < expected_speed * stuck_speed_threshold and not blocked_by_player:
		is_climbing = true
		if debug and not is_climbing:
			print("🧗 Commence à grimper - Vitesse: ", horizontal_velocity, " / Attendue: ", expected_speed)
	else:
		if is_climbing and debug:
			print("✅ Décoincé - Vitesse normale retrouvée")
		is_climbing = false
	
	if is_climbing:
		_handle_climbing(delta)
	else:
		_handle_normal_movement(delta)
	
	last_position = global_position
	move_and_slide()
	
	if get_slide_collision_count() > 0:
		_check_player_collision()

func _handle_normal_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	velocity.x = cached_direction.x * speed
	velocity.z = cached_direction.z * speed

func _handle_climbing(delta: float) -> void:
	# Monter verticalement
	velocity.y = climb_speed
	# Continuer à essayer d'avancer
	velocity.x = cached_direction.x * speed
	velocity.z = cached_direction.z * speed

func _is_blocked_by_player() -> bool:
	# Vérifier les collisions actuelles
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if not collider:
			continue
		
		var is_player = collider.is_in_group("player")
		var parent_is_player = collider.get_parent() and collider.get_parent().is_in_group("player")
		
		if is_player or parent_is_player:
			return true
	
	return false

func _check_player_collision() -> void:
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if not collider:
			continue
		
		var is_player = collider.is_in_group("player")
		var parent_is_player = collider.get_parent() and collider.get_parent().is_in_group("player")
		
		if is_player or parent_is_player:
			if not can_attack:
				continue
			
			var target = null
			
			if collider.has_method("take_damage"):
				target = collider
			elif collider.get_parent() and collider.get_parent().has_method("take_damage"):
				target = collider.get_parent()
			
			if target:
				target.take_damage(damage)
				if debug:
					print("💥 Ennemi a touché le joueur! Dégâts: ", damage)
				
				can_attack = false
				attack_timer = attack_interval
				return

func take_damage(amount: int) -> void:
	current_health -= amount
	if debug:
		print("🎯 PNJ touché ! PV restants :", current_health, "/", max_health)
	
	if current_health <= 0:
		die()

func die() -> void:
	if debug:
		print("💀 PNJ vaincu!")
	
	if experience_scene:
		var experience = experience_scene.instantiate()
		get_parent().add_child(experience)
		experience.global_position = global_position
	
	queue_free()
