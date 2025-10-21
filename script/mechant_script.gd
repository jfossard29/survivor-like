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
	if has_attacked:
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	velocity.x = cached_direction.x * speed
	velocity.z = cached_direction.z * speed
	
	move_and_slide()
	
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
