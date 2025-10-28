extends WeaponBase

@export var aura_scene: PackedScene

var aura_instance: Node3D = null

func _ready():
	weapon_id = "aura_weapon"
	weapon_name = "Aura Protectrice"
	base_damage = 5.0
	base_fire_rate = 2.0  # 2 ticks de dégâts par seconde
	base_range = 3.0  # Rayon de l'aura
	
	super._ready()

# Override de initialize pour spawn l'aura après l'assignation de aura_scene
func initialize(p: CharacterBody3D) -> void:
	super.initialize(p)
	
	# Spawner l'aura maintenant que tout est prêt
	if not aura_scene:
		push_error("AuraWeapon: aura_scene non assigné")
		return
	
	spawn_aura()

func setup() -> void:
	pass  # Pas besoin de setup ici, on spawn dans initialize

func spawn_aura() -> void:
	if aura_instance != null:
		return  # Déjà instancié
	
	if not aura_scene or not player:
		return
	
	aura_instance = aura_scene.instantiate()
	player.add_child(aura_instance)
	
	# Positionner l'aura au centre du joueur
	aura_instance.position = Vector3.ZERO
	
	# Passer les stats initiales
	update_aura_stats()
	
	print("aura instancié - Rayon: ", final_range, " - Dégâts: ", int(final_damage))

func fire() -> void:
	# Pour l'aura, "fire" signifie appliquer des dégâts
	# Les dégâts sont gérés directement par l'aura via sa collision
	start_cooldown()

func update_stats() -> void:
	super.update_stats()
	update_aura_stats()

func update_aura_stats() -> void:
	if not aura_instance or not is_instance_valid(aura_instance):
		return
	
	# Mettre à jour le rayon
	if "radius" in aura_instance:
		aura_instance.radius = final_range
	
	# Mettre à jour les dégâts
	if "damage" in aura_instance:
		aura_instance.damage = int(final_damage)
	
	# Mettre à jour le fire_rate (fréquence des ticks de dégâts)
	var final_tick_rate = base_fire_rate
	if "tick_rate" in aura_instance:
		aura_instance.tick_rate = final_tick_rate
	
	print("Aura MAJ - Rayon: ", final_range, " - Dégâts: ", int(final_damage), " - Tick rate: ", final_tick_rate)

func _exit_tree():
	# Nettoyer l'aura quand l'arme est détruite
	if aura_instance and is_instance_valid(aura_instance):
		aura_instance.queue_free()
