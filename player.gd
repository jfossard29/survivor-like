extends CharacterBody3D

@export var projectile_scene: PackedScene
@export var max_health = 100
@export var fire_interval: float = 1.0
@export var fire_range: float = 30.0  # portée de détection des PNJ
var current_health = 100
var can_fire: bool = true
# Référence au label d'affichage des PV
@onready var health_label: Label = $"../CanvasLayer/Panel/PV/Label"

@export var speed: float = 5.0
@export var turn_speed: float = 0.8
@export var camera: Camera3D
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	
	if can_fire:
		fire_projectile()
		can_fire = false
		await get_tree().create_timer(fire_interval).timeout
		can_fire = true

	get_input(delta)
	move_and_slide()

func get_input(delta: float) -> void:
	var vy: float = velocity.y

	var move_input: float = Input.get_axis("decelerer", "accelerer")
	var turn_input: float = Input.get_axis("droite", "gauche")

	rotate_y(turn_input * turn_speed * delta)

	var forward_dir: Vector3 = -transform.basis.z
	forward_dir.y = 0
	forward_dir = forward_dir.normalized()

	velocity.x = forward_dir.x * move_input * speed
	velocity.z = forward_dir.z * move_input * speed

	velocity.y = vy
	
func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)  # Ne pas descendre en dessous de 0
	
	print("Joueur touché ! PV restants : ", current_health)
	update_health_display()
	
	# Vérifier si le joueur est mort
	if current_health <= 0:
		die()

func heal(amount: int):
	current_health += amount
	current_health = min(max_health, current_health)  # Ne pas dépasser le max
	update_health_display()

func update_health_display():
	if health_label:
		health_label.text = str(current_health)
	else:
		print("ERREUR : Label 'nombre' introuvable dans PV/nombre")

func die():
	print("Le joueur est mort !")
	
func fire_projectile():
	if projectile_scene == null:
		return
	
	var pnjs = get_tree().get_nodes_in_group("pnj")
	var closest_pnj: Node3D = null
	var closest_dist: float = fire_range + 1.0
	
	for p in pnjs:
		var d = global_position.distance_to(p.global_position)
		if d <= fire_range and d < closest_dist:
			closest_dist = d
			closest_pnj = p
	
	var proj = projectile_scene.instantiate()
	proj.global_position = global_position + Vector3(0,1.0,0)
	get_parent().call_deferred("add_child", proj)
	
	if closest_pnj != null:
		proj.target = closest_pnj
	else:
		# Sinon tir droit devant
		var forward_dir: Vector3 = -transform.basis.z
		forward_dir.y = 0
		proj.direction = forward_dir.normalized()
