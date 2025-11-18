extends Node

var player: CharacterBody3D
var active_weapons: Dictionary = {}  # weapon_id -> WeaponBase
var is_active: bool = false  # Flag pour savoir si le manager est actif

@onready var flingue_scene : PackedScene = preload("res://scenes/arme/ProjectileBase.tscn")
@onready var firewall_scene : PackedScene = preload("res://scenes/arme/aura_weapon.tscn")
@onready var ver_scene : PackedScene = preload("res://scenes/arme/projectile_rebond.tscn")

enum WeaponType { Flingue, Firewall, Ver }

func _ready():
	is_active = true

func initialize(p_player: CharacterBody3D) -> void:
	player = p_player
	is_active = true
	print("✅ WeaponManager initialisé pour ", player.name)

func get_weapon(weapon_id: String) -> WeaponBase:
	if not is_active or not active_weapons.has(weapon_id):
		return null
	return active_weapons[weapon_id]

func has_weapon(weapon_id: String) -> bool:
	return is_active and active_weapons.has(weapon_id)

func get_all_weapons() -> Array:
	if not is_active:
		return []
	return active_weapons.values()

func get_weapon_count() -> int:
	if not is_active:
		return 0
	return active_weapons.size()

func remove_weapon(weapon_id: String) -> void:
	if not active_weapons.has(weapon_id):
		return
	
	var weapon = active_weapons[weapon_id]
	if is_instance_valid(weapon):
		weapon.queue_free()
	active_weapons.erase(weapon_id)
	print("🗑️ Arme retirée: ", weapon_id)

func reset() -> void:
	# Désactiver immédiatement le manager
	is_active = false
	
	# Désactiver toutes les armes AVANT de les détruire
	for weapon in active_weapons.values():
		if is_instance_valid(weapon):
			weapon.set_process(false)
			weapon.set_physics_process(false)
	
	# Attendre un frame pour que les processus en cours se terminent
	await get_tree().process_frame
	
	# Maintenant on peut détruire les armes
	for weapon_id in active_weapons.keys():
		var weapon = active_weapons[weapon_id]
		if is_instance_valid(weapon):
			weapon.queue_free()
	
	active_weapons.clear()
	player = null
	print("🧹 WeaponManager reset complet")

func _create_flingue_weapon() -> void:
	# Créer le node de l'arme
	var flingue_weapon = Node.new()
	flingue_weapon.name = "flingue"
	
	# Charger et attacher le script
	var script = load("res://script/arme/armeDebut.gd")
	flingue_weapon.set_script(script)
	
	# ⚠️ IMPORTANT: Configurer l'arme AVANT de l'ajouter à la scène
	flingue_weapon.weapon_id = "flingue"
	flingue_weapon.weapon_name = "Flingue à énergie"
	flingue_weapon.projectile_scene = flingue_scene
	flingue_weapon.base_damage = 10.0
	flingue_weapon.base_fire_rate = 1.0
	flingue_weapon.base_range = 30.0

	# Ajouter au WeaponManager (ceci déclenche _ready())
	add_child(flingue_weapon)
	
	# Enregistrer dans le WeaponManager
	active_weapons["flingue"] = flingue_weapon
	
	# Initialiser APRÈS l'ajout à la scène
	flingue_weapon.initialize(player)

func _create_firewall_weapon() -> void:
	var firewall_weapon = Node.new()
	firewall_weapon.name = "firewall"
	
	var script = load("res://script/arme/armeAura.gd")
	firewall_weapon.set_script(script)
	add_child(firewall_weapon)
	
	firewall_weapon.weapon_id = "firewall"
	firewall_weapon.weapon_name = "Firewall"
	firewall_weapon.aura_scene = firewall_scene
	firewall_weapon.base_damage = 5.0
	firewall_weapon.base_fire_rate = 2.0
	firewall_weapon.base_range = 2.5
	
	active_weapons["firewall"] = firewall_weapon
	firewall_weapon.initialize(player)

func _create_ver_weapon() -> void:
	# Créer le node de l'arme
	var ver_weapon = Node.new()
	ver_weapon.name = "ver"
	
	# Charger et attacher le script
	var script = load("res://script/arme/armeRebond.gd")
	ver_weapon.set_script(script)
	
	# ⚠️ IMPORTANT: Configurer l'arme AVANT de l'ajouter à la scène
	ver_weapon.weapon_id = "ver"
	ver_weapon.weapon_name = "Ver"
	ver_weapon.projectile_scene = ver_scene
	ver_weapon.base_damage = 8.0
	ver_weapon.base_fire_rate = 0.8
	ver_weapon.base_range = 30.0

	add_child(ver_weapon)
	
	# Enregistrer dans le WeaponManager
	active_weapons["ver"] = ver_weapon
	
	# Initialiser APRÈS l'ajout à la scène
	ver_weapon.initialize(player)

func _create_first_weapon(armeJoueur : WeaponType) -> void:
	match armeJoueur:
		WeaponType.Flingue:
			_create_flingue_weapon()
		WeaponType.Firewall:
			_create_firewall_weapon()
		WeaponType.Ver:
			_create_ver_weapon()
		_:
			_create_flingue_weapon()
