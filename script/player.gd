extends CharacterBody3D

@export var projectile_scene: PackedScene
@export var base_projectile_speed: float = 20.0
@export var max_health: float = 100.0
@export var base_damage: int = 10
@export var base_speed: float = 5.0
@export var base_fire_interval: float = 1.0
@export var fire_range: float = 30.0
@export var turn_speed: float = 0.8
@export var camera: Camera3D
@export var xp_to_next_level: float = 100.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var mouse_sensitivity: float = 0.002
@export var pivot_camera: Node3D
@export var jump_speed: float = 5.0

@onready var health_bar: ProgressBar = $"../CanvasLayer/Panel/PV/ProgressBar"
@onready var experience_bar: ProgressBar = $"../CanvasLayer/Panel/Experience/ProgressBar"
@onready var recolte: Area3D = $Recolte
@onready var popup_multi: CanvasLayer = $"../Amelioration"
@onready var amelioration_manager: Node = $"../AmeliorationManager"

var camera_pitch: float = 0.0
var current_health: float = 100.0
var current_experience: float = 0.0
var level: int = 1
var experience_to_next_level: float = 100.0

var can_fire: bool = true
var fire_timer: float = 0.0
var damage: int
var move_speed: float
var fire_interval: float
var projectile_speed: float
var ameliorations_en_attente: Array[Amelioration] = []
var base_radius: float = 1.0
var radius_multiplier: float = 1.0

# Tweens séparés pour éviter les conflits
var health_tween: Tween = null
var xp_tween: Tween = null

func _ready():
	add_to_group("player")
	update_stats()
	update_health_display()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if recolte:
		recolte.connect("area_entered", Callable(self, "_on_harvest_zone_entered"))
	
	# Enregistrer le joueur dans le GameManager
	if GameManager:
		GameManager.set_player(self)

func update_stats():
	damage = base_damage + (level - 1) * 2
	move_speed = base_speed + (level - 1) * 0.3
	fire_interval = base_fire_interval * pow(0.95, level - 1)
	projectile_speed = base_projectile_speed + (level - 1) * 1.5
	
	if Engine.has_singleton("GameManager"):
		recolte.set_pickup_radius_multiplier(GameManager.pickup_scale_multiplier)

func level_up():
	# Animation simplifiée
	var stylebox = experience_bar.get("theme_override_styles/fill") as StyleBoxFlat
	if stylebox:
		var flash = create_tween()
		flash.set_loops(2)
		flash.tween_property(stylebox, "bg_color", Color(0.6, 0.8, 1), 0.1)
		flash.tween_property(stylebox, "bg_color", Color(0.2, 0.4, 1), 0.1)
	
	level += 1
	xp_to_next_level *= 1.25
	move_speed += 0.2
	fire_interval = max(0.3, fire_interval - 0.05)
	
	var choix = amelioration_manager.get_ameliorations_random(self)
	popup_multi.afficher(choix)

func _physics_process(delta: float) -> void:
	var start = Time.get_ticks_usec()
	
	# Gestion du timer de tir
	if not can_fire:
		fire_timer -= delta
		if fire_timer <= 0:
			can_fire = true
	
	var fire_time = Time.get_ticks_usec()
	
	# Tir automatique
	if can_fire:
		fire_projectile()
	
	var projectile_time = Time.get_ticks_usec()
	
	# Appliquer la gravité
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	get_input(delta)
	
	var input_time = Time.get_ticks_usec()
	
	move_and_slide()
	
	var total_time = Time.get_ticks_usec() - start
	
	# Logger si c'est lent (plus de 5ms)
	if total_time > 5000:
		print("⚠️ FRAME LENTE:")
		print("  Fire check: %.2f ms" % ((fire_time - start) / 1000.0))
		print("  Projectile: %.2f ms" % ((projectile_time - fire_time) / 1000.0))
		print("  Input: %.2f ms" % ((input_time - projectile_time) / 1000.0))
		print("  Move: %.2f ms" % ((Time.get_ticks_usec() - input_time) / 1000.0))
		print("  TOTAL: %.2f ms" % (total_time / 1000.0))

func get_input(delta: float) -> void:
	var vy: float = velocity.y
	
	# Déplacement avant/arrière
	var forward_input: float = Input.get_axis("decelerer", "accelerer")
	# Déplacement gauche/droite
	var strafe_input: float = Input.get_axis("gauche", "droite")
	
	# Calcul de la direction avant
	var forward_dir: Vector3 = -transform.basis.z
	forward_dir.y = 0
	forward_dir = forward_dir.normalized()
	
	# Calcul de la direction droite
	var right_dir: Vector3 = transform.basis.x
	right_dir.y = 0
	right_dir = right_dir.normalized()
	
	# Combinaison du mouvement
	var move_dir: Vector3 = forward_dir * forward_input + right_dir * strafe_input
	move_dir = move_dir.normalized() if move_dir.length() > 0 else Vector3.ZERO
	
	# Appliquer la vitesse
	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed
	
	# Saut
	if is_on_floor() and Input.is_action_just_pressed("sauter"):
		velocity.y = jump_speed
	else:
		velocity.y = vy

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# rotation horizontale du joueur (yaw)
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# rotation verticale du pivot de la caméra (pitch)
		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, -1.5, 1.5)
		pivot_camera.rotation.x = camera_pitch

func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)
	
	update_health_display()
	
	# Vérifier si le joueur est mort
	if current_health <= 0:
		die()

func heal(amount: int):
	current_health += amount
	current_health = min(max_health, current_health)
	update_health_display()

func update_health_display():
	if not health_bar:
		return
	
	var ratio = current_health / max_health
	
	# Tuer l'ancien tween proprement
	if health_tween and health_tween.is_valid():
		health_tween.kill()
	
	health_tween = create_tween()
	health_tween.tween_property(health_bar, "value", ratio * health_bar.max_value, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Animation de couleur simplifiée
	var stylebox = health_bar.get("theme_override_styles/fill") as StyleBoxFlat
	if stylebox:
		var color_tween = create_tween()
		color_tween.tween_property(stylebox, "bg_color", Color(1, 0.3, 0.3), 0.1)
		color_tween.tween_property(stylebox, "bg_color", Color(1, 0, 0), 0.3)

func die():
	print("Le joueur est mort !")

func fire_projectile():
	if projectile_scene == null or not can_fire:
		return
	
	var closest_pnj: Node3D = null
	var closest_dist: float = fire_range + 1.0
	
	# Utiliser le cache d'ennemis du GameManager au lieu de get_nodes_in_group
	if GameManager and GameManager.registered_enemies:
		for p in GameManager.registered_enemies:
			if not is_instance_valid(p) or p.has_attacked:
				continue
			var d = global_position.distance_to(p.global_position)
			if d <= fire_range and d < closest_dist:
				closest_dist = d
				closest_pnj = p
	
	# Instance du projectile
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	
	# Position et direction de départ
	var forward_dir: Vector3 = -global_transform.basis.z.normalized()
	var start_pos: Vector3 = global_position + forward_dir * 0.8
	projectile.look_at_from_position(start_pos, start_pos + forward_dir, Vector3.UP)
	
	# On passe les stats du joueur
	projectile.damage = damage
	projectile.speed = projectile_speed
	
	# Ciblage
	if closest_pnj != null:
		projectile.target = closest_pnj
	else:
		projectile.direction = forward_dir
	
	# Gestion de la cadence avec timer au lieu d'await
	can_fire = false
	fire_timer = fire_interval

func _on_harvest_zone_entered(body: Node) -> void:
	if body.is_in_group("experience"):
		body.start_following(self)

func add_experience(amount: float):
	current_experience += amount
	update_experience_bar()
	
	while current_experience >= xp_to_next_level:
		current_experience -= xp_to_next_level
		level_up()

func update_experience_bar():
	if not experience_bar:
		return
	
	var ratio = current_experience / xp_to_next_level
	
	# Tuer l'ancien tween proprement
	if xp_tween and xp_tween.is_valid():
		xp_tween.kill()
	
	xp_tween = create_tween()
	xp_tween.tween_property(experience_bar, "value", ratio * experience_bar.max_value, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Pulse bleu simplifié
	var stylebox = experience_bar.get("theme_override_styles/fill") as StyleBoxFlat
	if stylebox:
		var color_tween = create_tween()
		color_tween.tween_property(stylebox, "bg_color", Color(0.4, 0.6, 1), 0.1)
		color_tween.tween_property(stylebox, "bg_color", Color(0.2, 0.4, 1), 0.3)

func apply_pickup_multiplier(mult: float) -> void:
	if recolte and recolte.has_method("add_pickup_radius_multiplier"):
		recolte.add_pickup_radius_multiplier(mult)
