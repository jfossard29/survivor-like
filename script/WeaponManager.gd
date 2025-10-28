extends Node

var player: CharacterBody3D
var active_weapons: Dictionary = {}  # weapon_id -> WeaponBase

func _ready():
	pass

func initialize(p_player: CharacterBody3D) -> void:
	player = p_player
	print("✅ WeaponManager initialisé pour ", player.name)

func get_weapon(weapon_id: String) -> WeaponBase:
	if active_weapons.has(weapon_id):
		return active_weapons[weapon_id]
	return null

func has_weapon(weapon_id: String) -> bool:
	return active_weapons.has(weapon_id)

func get_all_weapons() -> Array:
	return active_weapons.values()

func get_weapon_count() -> int:
	return active_weapons.size()

func remove_weapon(weapon_id: String) -> void:
	if not active_weapons.has(weapon_id):
		return
	
	var weapon = active_weapons[weapon_id]
	weapon.queue_free()
	active_weapons.erase(weapon_id)
	print("🗑️ Arme retirée: ", weapon_id)
