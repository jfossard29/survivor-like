extends WeaponBase

@export var aura_scene: PackedScene

var aura_instance: Node3D = null

func _ready():
	weapon_id = "aura_weapon"
	weapon_name = "Aura Protectrice"
	base_damage = 5.0
	base_fire_rate = 2.0 
	base_range = 3.0
	
	super._ready()

func initialize(p: CharacterBody3D) -> void:
	super.initialize(p)
	
	spawn_aura()

func setup() -> void:
	pass

func spawn_aura() -> void:
	aura_instance = aura_scene.instantiate()
	player.add_child(aura_instance)
	
	aura_instance.position = Vector3.ZERO
	
	update_aura_stats()

func fire() -> void:
	start_cooldown()

func update_stats() -> void:
	super.update_stats()
	update_aura_stats()

func update_aura_stats() -> void:
	if not aura_instance or not is_instance_valid(aura_instance):
		return

	if "radius" in aura_instance:
		aura_instance.radius = final_range
	
	if "damage" in aura_instance:
		aura_instance.damage = int(final_damage)
	
	var final_tick_rate = base_fire_rate
	if "tick_rate" in aura_instance:
		aura_instance.tick_rate = final_tick_rate

func _exit_tree():
	if aura_instance and is_instance_valid(aura_instance):
		aura_instance.queue_free()
