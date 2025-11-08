extends Node
class_name WeaponBase

# Identifiant unique de l'arme
@export var weapon_id: String = "weapon"
@export var weapon_name: String = "Arme"

# Stats de base (définies dans chaque arme)
@export var base_damage: float = 10.0
@export var base_fire_rate: float = 1.0  # Attaques par seconde
@export var base_range: float = 30.0

# Multiplicateurs d'amélioration (modifiés par les upgrades)
var damage_flat_bonus: float = 0.0  # Bonus plat de dégâts
var damage_multiplier: float = 1.0  # Multiplicateur de dégâts (%)
var fire_rate_multiplier: float = 1.0  # Multiplicateur de cadence
var range_multiplier: float = 1.0  # Multiplicateur de portée
var bounce_count: int = 1
# Stats finales calculées
var final_damage: float
var final_fire_interval: float
var final_range: float

# Gestion du tir
var can_fire: bool = true
var fire_timer: float = 0.0

# Référence au joueur
var player: CharacterBody3D

func _ready():
	update_stats()

func initialize(p_player: CharacterBody3D) -> void:
	player = p_player
	update_stats()

func update_stats() -> void:
	# Calcul des stats finales
	final_damage = (base_damage + damage_flat_bonus) * damage_multiplier
	final_fire_interval = (1.0 / base_fire_rate) / fire_rate_multiplier
	final_range = base_range * range_multiplier
	
	print("📊 ", weapon_name, " stats: DMG=", final_damage, " Rate=", 1.0/final_fire_interval, "/s Range=", final_range)

func _process(delta: float) -> void:
	if not can_fire:
		fire_timer -= delta
		if fire_timer <= 0:
			can_fire = true
	
	if can_fire:
		fire()

# À override dans chaque arme
func fire() -> void:
	pass

func start_cooldown() -> void:
	can_fire = false
	fire_timer = final_fire_interval

# Méthodes d'amélioration
func add_flat_damage(amount: float) -> void:
	damage_flat_bonus += amount
	update_stats()

func add_damage_multiplier(percent: float) -> void:
	damage_multiplier += percent / 100.0
	update_stats()

func add_fire_rate(percent: float) -> void:
	fire_rate_multiplier += percent / 100.0
	update_stats()

func add_range(percent: float) -> void:
	range_multiplier += percent / 100.0
	update_stats()
	
func add_bounce_count(number: int) -> void:
	bounce_count += number
