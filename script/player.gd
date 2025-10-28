extends CharacterBody3D

@export var base_projectile_scene: PackedScene  # Arme de base
@export var aura_scene: PackedScene  # Champs de force
@export var max_health: float = 100.0
@export var base_speed: float = 5.0
@export var gravity_force: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var mouse_sensitivity: float = 0.002
@export var jump_speed: float = 5.0
@export var xp_to_next_level: float = 100.0

@onready var pivot_camera: Node3D = $CameraPivot
@onready var health_bar: ProgressBar = $CanvasLayer/Panel/PV/ProgressBar
@onready var experience_bar: ProgressBar = $CanvasLayer/Panel/Experience/ProgressBar
@onready var recolte: Area3D = $Recolte
@onready var popup_multi: CanvasLayer = $Amelioration
@onready var amelioration_manager: Node = $AmeliorationManager

var camera_pitch: float = 0.0
var current_health: float = 100.0
var current_experience: float = 0.0
var level: int = 1
var experience_to_next_level: float = 100.0

var move_speed: float
var ameliorations_en_attente: Array[Amelioration] = []
var base_radius: float = 1.0
var radius_multiplier: float = 1.0

# Tweens séparés
var health_tween: Tween = null
var xp_tween: Tween = null

func _ready():
	add_to_group("player")
	print("✅ Joueur (CharacterBody3D racine) ajouté au groupe 'player'")
	
	update_stats()
	update_health_display()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if not pivot_camera:
		push_error("CameraPivot non trouvé!")
	
	if not recolte:
		push_error("❌ Zone Recolte non trouvée!")
	
	# Enregistrer le joueur dans le GameManager
	if GameManager:
		GameManager.set_player(self)
		print("✅ Joueur enregistré dans GameManager")
	
	# Initialiser le WeaponManager
	if WeaponManager:
		WeaponManager.initialize(self)
		_setup_weapons()
	else:
		push_error("❌ WeaponManager non trouvé!")

func _setup_weapons() -> void:
	_create_basic_weapon()

func update_stats():
	move_speed = base_speed + (level - 1) * 0.3
	
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
	
	var choix = amelioration_manager.get_ameliorations_random(self)
	popup_multi.afficher(choix)

func _physics_process(delta: float) -> void:
	# Appliquer la gravité
	if not is_on_floor():
		velocity.y -= gravity_force * delta
	
	get_input(delta)
	move_and_slide()

func get_input(delta: float) -> void:
	var vy: float = velocity.y
	
	var forward_input: float = Input.get_axis("decelerer", "accelerer")
	var strafe_input: float = Input.get_axis("gauche", "droite")
	
	var forward_dir: Vector3 = -transform.basis.z
	forward_dir.y = 0
	forward_dir = forward_dir.normalized()
	
	var right_dir: Vector3 = transform.basis.x
	right_dir.y = 0
	right_dir = right_dir.normalized()
	
	var move_dir: Vector3 = forward_dir * forward_input + right_dir * strafe_input
	move_dir = move_dir.normalized() if move_dir.length() > 0 else Vector3.ZERO
	
	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed
	
	if is_on_floor() and Input.is_action_just_pressed("sauter"):
		velocity.y = jump_speed
	else:
		velocity.y = vy

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		if pivot_camera:
			camera_pitch -= event.relative.y * mouse_sensitivity
			camera_pitch = clamp(camera_pitch, -1.5, 1.5)
			pivot_camera.rotation.x = camera_pitch
	

	if event.is_action_pressed("ui_page_down"):
		if not WeaponManager.has_weapon("aura"):
			_create_aura_weapon()
			print("🔓 Ricochet débloqué via debug")
		else:
			print("⚠️ Ricochet déjà débloqué")


func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)
	update_health_display()
	
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
	
	if health_tween and health_tween.is_valid():
		health_tween.kill()
	
	health_tween = create_tween()
	health_tween.tween_property(health_bar, "value", ratio * health_bar.max_value, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	var stylebox = health_bar.get("theme_override_styles/fill") as StyleBoxFlat
	if stylebox:
		var color_tween = create_tween()
		color_tween.tween_property(stylebox, "bg_color", Color(1, 0.3, 0.3), 0.1)
		color_tween.tween_property(stylebox, "bg_color", Color(1, 0, 0), 0.3)

func die():
	print("💀 Le joueur est mort !")
	GameManager.player_died()

func _on_harvest_zone_entered(area: Area3D) -> void:
	var orbe = area.get_parent()
	if orbe and orbe.is_in_group("experience"):
		orbe.start_following(self)

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
	
	if xp_tween and xp_tween.is_valid():
		xp_tween.kill()
	
	xp_tween = create_tween()
	xp_tween.tween_property(experience_bar, "value", ratio * experience_bar.max_value, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	var stylebox = experience_bar.get("theme_override_styles/fill") as StyleBoxFlat
	if stylebox:
		var color_tween = create_tween()
		color_tween.tween_property(stylebox, "bg_color", Color(0.4, 0.6, 1), 0.1)
		color_tween.tween_property(stylebox, "bg_color", Color(0.2, 0.4, 1), 0.3)

func apply_pickup_multiplier(mult: float) -> void:
	if recolte and recolte.has_method("add_pickup_radius_multiplier"):
		recolte.add_pickup_radius_multiplier(mult)

func get_player_position() -> Vector3:
	return global_position
	
func _create_basic_weapon() -> void:
	# Créer le node de l'arme
	var basic_weapon = Node.new()
	basic_weapon.name = "BasicWeapon"
	
	# Charger et attacher le script
	var script = load("res://script/armeDebut.gd")
	basic_weapon.set_script(script)
	
	# ⚠️ IMPORTANT: Configurer l'arme AVANT de l'ajouter à la scène
	basic_weapon.weapon_id = "basic_gun"
	basic_weapon.weapon_name = "Pistolet de Base"
	basic_weapon.projectile_scene = base_projectile_scene  # Utilise l'export var du Player
	basic_weapon.base_damage = 10.0
	basic_weapon.base_fire_rate = 1.0
	basic_weapon.base_range = 30.0

	# Ajouter au WeaponManager (ceci déclenche _ready())
	WeaponManager.add_child(basic_weapon)
	
	# Enregistrer dans le WeaponManager
	WeaponManager.active_weapons["basic_gun"] = basic_weapon
	
	# Initialiser APRÈS l'ajout à la scène
	basic_weapon.initialize(self)
	
	print("✅ Arme de base créée et configurée")

func _create_aura_weapon() -> void:
	var aura_weapon = Node.new()
	aura_weapon.name = "AuraWeapon"
	
	var script = load("res://script/armeAura.gd")
	aura_weapon.set_script(script)
	WeaponManager.add_child(aura_weapon)
	
	aura_weapon.weapon_id = "Aura"
	aura_weapon.weapon_name = "Champs de force"
	aura_weapon.aura_scene = aura_scene
	aura_weapon.base_damage = 5.0
	aura_weapon.base_fire_rate = 2.0
	aura_weapon.base_range = 5.0
	
	WeaponManager.active_weapons["aura"] = aura_weapon
	aura_weapon.initialize(self)
