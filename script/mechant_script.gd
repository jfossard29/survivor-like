extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var can_attack = false
var cached_direction = Vector3.ZERO

@export var speed: float = 3.0
@export var damage: int = 10
@export var max_health: int = 100
@export var experience_scene: PackedScene
@export var debug: bool = false
@export var attack_interval: float = 2.0

var current_health: int
var attack_timer: float = 0.0

func _ready():
	add_to_group("enemy")
	GameManager.register_enemy(self)
	current_health = max_health
	attack_timer = attack_interval

func _exit_tree():
	GameManager.unregister_enemy(self)

func _physics_process(delta: float) -> void:
	
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	velocity.x = cached_direction.x * speed
	velocity.z = cached_direction.z * speed
	
	move_and_slide()
	
	if get_slide_collision_count() > 0:
		_check_player_collision()

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
