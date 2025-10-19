extends Node3D

@export var pnj_scene: PackedScene
@export var player: CharacterBody3D
@export var spawn_interval: float = 3.0
@export var max_pnjs: int = 10

var current_pnjs: Array = []

func _ready():
	spawn_loop()

func spawn_loop() -> void:
	while true:
		await get_tree().create_timer(spawn_interval).timeout
		cleanup_pnjs()
		if current_pnjs.size() < max_pnjs:
			spawn_pnj()

func cleanup_pnjs():
	current_pnjs = current_pnjs.filter(func(p): return is_instance_valid(p))

func spawn_pnj():
	if not player:
		return

	# Récupère la zone de spawn attachée au joueur
	var spawn_zone = player.get_node_or_null("SpawnZone")
	if not spawn_zone:
		push_warning("⚠️ Le joueur n'a pas de SpawnZone (Area3D).")
		return

	var zone_shape = spawn_zone.get_node("CollisionShape3D").shape as CylinderShape3D
	var radius = zone_shape.radius

	# Essaye plusieurs positions avant d'abandonner
	for i in range(10):
		var angle = randf() * TAU
		var distance = randf_range(0.0, radius)
		var local_pos = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var world_pos = spawn_zone.to_global(local_pos)

		# Vérifie qu'on n'est pas trop proche du joueur
		if world_pos.distance_to(player.global_position) < 3.0:
			continue

		# 🔍 Raycast vers le bas pour trouver le sol
		var space_state = get_world_3d().direct_space_state
		var ray_start = world_pos + Vector3.UP * 20.0
		var ray_end = world_pos + Vector3.DOWN * 50.0

		var result = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray_start, ray_end))

		if result and result.collider and result.collider.is_in_group("terrain"):
			var ground_pos = result.position

			# Instance du PNJ
			var pnj = pnj_scene.instantiate()
			get_tree().current_scene.add_child(pnj)

			# 🔧 Ajuste la position Y pour que le PNJ soit au-dessus du sol
			var collider = pnj.get_node_or_null("CollisionShape3D")
			var y_offset = 0.0
			if collider and collider.shape:
				var pnj_shape = collider.shape  # <- nouveau nom pour éviter le conflit
				if pnj_shape is CapsuleShape3D:
					y_offset = pnj_shape.height / 2 + pnj_shape.radius
				elif pnj_shape is BoxShape3D:
					y_offset = pnj_shape.extents.y

			pnj.global_position = ground_pos + Vector3.UP * (y_offset * 0.0)  # 90% de la hauteur calculée

			# Ajoute le PNJ à la liste pour le suivi
			current_pnjs.append(pnj)
			return  # ✅ Succès → on sort

	# Si on arrive ici, aucun spawn valide trouvé
	print("⚠️ Aucun point de spawn valide trouvé après 10 essais.")
