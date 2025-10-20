extends Node3D

@export var create_on_ready: bool = true
@export var collision_body_name: String = "MergedStaticBody"
@export var collision_shape_name: String = "MergedCollision"
@export var remove_child_collisions: bool = true    # supprime les CollisionShape3D enfants pour éviter doublons
@export var debug_show_mesh: bool = false           # crée un MeshInstance3D visuel pour debug (false par défaut)

func _ready():
	if create_on_ready:
		_create_merged_collision()

# Collecte récursive des MeshInstance3D sous ce node
func _collect_mesh_instances(node: Node) -> Array:
	var out := []
	for c in node.get_children():
		if c is MeshInstance3D:
			out.append(c)
		elif c.get_child_count() > 0:
			out += _collect_mesh_instances(c)
	return out

func _create_merged_collision():
	# Supprime ancien StaticBody/Collision s'il existe
	if has_node(collision_body_name):
		get_node(collision_body_name).queue_free()

	# Optionnel : supprimer les CollisionShape3D enfants pour éviter collisions doublées
	if remove_child_collisions:
		var child_collision_nodes := []
		for mi in _collect_mesh_instances(self):
			for c in mi.get_children():
				if c is CollisionShape3D or c is CollisionObject3D:
					child_collision_nodes.append(c)
		for cnode in child_collision_nodes:
			cnode.queue_free()

	# Tableau de triangles (3 sommets consécutifs par triangle)
	var total_tris := PackedVector3Array()

	var mesh_nodes = _collect_mesh_instances(self)
	if mesh_nodes.size() == 0:
		push_warning("Aucun MeshInstance3D trouvé sous ce Node pour créer la collision.")
		return

	for child in mesh_nodes:
		var mesh : Mesh = child.mesh
		if mesh == null:
			continue
		var surf_count = mesh.get_surface_count()
		for s in range(surf_count):
			var arrays = mesh.surface_get_arrays(s)
			if arrays.size() == 0:
				continue
			# Récupère vertices et indices (si présents)
			var verts : PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if verts == null or verts.size() == 0:
				continue
			var indices : PackedInt32Array = PackedInt32Array()
			if arrays.size() > Mesh.ARRAY_INDEX and typeof(arrays[Mesh.ARRAY_INDEX]) == TYPE_ARRAY:
				indices = arrays[Mesh.ARRAY_INDEX]

			# Transform: convertir chaque vertex du local du child vers l'espace local de ce Node (parent)
			# Utilise (global -> to_local) pour garantir cohérence même si les nodes sont imbriqués
			if indices != null and indices.size() > 0:
				for idx in range(0, indices.size(), 3):
					if idx + 2 >= indices.size():
						break
					var i0 = indices[idx]
					var i1 = indices[idx + 1]
					var i2 = indices[idx + 2]
					# Transforme le vertex en global puis en local du parent (this)
					var v0 = to_local(child.global_transform * verts[i0])
					var v1 = to_local(child.global_transform * verts[i1])
					var v2 = to_local(child.global_transform * verts[i2])
					total_tris.append(v0)
					total_tris.append(v1)
					total_tris.append(v2)
			else:
				for vi in range(0, verts.size(), 3):
					if vi + 2 >= verts.size():
						break
					var vv0 = to_local(child.global_transform * verts[vi])
					var vv1 = to_local(child.global_transform * verts[vi + 1])
					var vv2 = to_local(child.global_transform * verts[vi + 2])
					total_tris.append(vv0)
					total_tris.append(vv1)
					total_tris.append(vv2)

	# Vérification
	if total_tris.size() == 0:
		push_warning("Aucun triangle trouvé pour générer la collision fusionnée.")
		return

	# Crée la ConcavePolygonShape3D (trimesh). Bon uniquement pour StaticBody3D.
	var concave = ConcavePolygonShape3D.new()
	concave.data = total_tris

	# Crée StaticBody3D + CollisionShape3D
	# Après la collecte des surfaces (remplace la création ConcavePolygonShape3D par ceci)

	# Crée StaticBody3D unique
	var body = StaticBody3D.new()
	body.name = collision_body_name
	body.collision_layer = 2
	body.collision_mask = 3
	body.transform = Transform3D.IDENTITY
	add_child(body)

	# Pour chaque MeshInstance3D, crée une ou plusieurs ConvexPolygonShape3D à partir de ses surfaces
	for child in mesh_nodes:
		var mesh : Mesh = child.mesh
		if mesh == null:
			continue
		var surf_count = mesh.get_surface_count()
		for s in range(surf_count):
			var arrays = mesh.surface_get_arrays(s)
			if arrays.size() == 0:
				continue
			var verts : PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if verts == null or verts.size() == 0:
				continue

			# Collecte vertices transformés en espace local du parent
			var pts := PackedVector3Array()
			for v in verts:
				pts.append(to_local(child.global_transform * v))

			# Si trop peu de points pour former une convex shape, skip
			if pts.size() < 4:
				continue

			# Crée la ConvexPolygonShape3D
			var convex = ConvexPolygonShape3D.new()
			convex.points = pts

			var colshape = CollisionShape3D.new()
			colshape.shape = convex
			body.add_child(colshape)

	# Option debug : afficher le mesh combiné pour inspection visuelle (facultatif)
	if debug_show_mesh:
		var debug_mesh = ArrayMesh.new()
		var arrays_out := []
		arrays_out.resize(Mesh.ARRAY_MAX)
		# Si tu veux garder l'ancien total_tris pour debug, l'utiliser ; sinon reconstruis un PackedVector3Array de triangles
		arrays_out[Mesh.ARRAY_VERTEX] = total_tris if total_tris.size() > 0 else PackedVector3Array()
		debug_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_out)
		var mi = MeshInstance3D.new()
		mi.mesh = debug_mesh
		mi.name = "MergedDebugMesh"
		mi.visible = true
		add_child(mi)

	print("Collision convexe générée pour", mesh_nodes.size(), "mesh nodes.")
