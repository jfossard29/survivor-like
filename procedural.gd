extends Node3D

@export var plate_length: float = 200.0
@export var plate_width: float = 40.0
@export var plate_thickness: float = 1.0
@export var ramp_count: int = 6
@export var ramp_length: float = 8.0
@export var ramp_height: float = 4.0
@export var ramp_width: float = 10.0
@export var ramp_material: StandardMaterial3D
@export var ramp_vertical_offset: float = 1
var rng := RandomNumberGenerator.new()
@export var ramp_buffer: float = 1.5            # marge minimale entre rampes (en unités X)
@export var double_ramp_chance: float = 0.2     # probabilité qu'une rampe soit "double" (longueur+hauteur x2)


func _ready():
	rng.randomize()
	_clear_children()
	_create_plate()
	_place_ramps_on_plate()

func _clear_children():
	for c in get_children():
		c.queue_free()

func _create_plate():
	# Create mesh
	var mesh = BoxMesh.new()
	mesh.size = Vector3(plate_length, plate_thickness, plate_width)
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = mesh
	if ramp_material:
		mesh_inst.set_surface_override_material(0, ramp_material)

	# Create static body for plate
	var body = StaticBody3D.new()
	# Place so top of plate is at y = 0
	var plate_y = -plate_thickness * 0.5
	body.transform = Transform3D(Basis(), Vector3(plate_length * 0.5, plate_y, 0))
	
	# Collision
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.extents = mesh.size * 0.5
	col.shape = box
	var t = col.transform
	t.origin = Vector3.ZERO
	col.transform = t
	body.add_child(col)

	# Visual as child at local origin
	mesh_inst.transform = Transform3D(Basis(), Vector3.ZERO)
	body.add_child(mesh_inst)

	add_child(body)

func _place_ramps_on_plate():
	# Place ramp_count ramps à des positions non superposées le long de la plate
	var margin = 2.0
	var occupied_intervals := []
	var attempts = 0
	var max_attempts = ramp_count * 8

	while len(occupied_intervals) < ramp_count and attempts < max_attempts:
		attempts += 1
		var max_x_start = plate_length - ramp_length - margin
		if max_x_start <= margin:
			break
		var x_start = rng.randf_range(margin, max_x_start)
		x_start += rng.randf_range(-1.5, 1.5)

		var is_double = rng.randf() < double_ramp_chance
		var length = ramp_length * (2 if is_double else 1)
		var height = ramp_height * (2.0 if is_double else 1.0)

		# Clamp pour que la rampe tienne sur la plate
		if x_start < margin:
			x_start = margin
		if x_start + length + margin > plate_length:
			x_start = plate_length - length - margin

		# Intervalle étendu par le buffer
		var interval_start = x_start - ramp_buffer
		var interval_end = x_start + length + ramp_buffer

		var intersects = false
		for iv in occupied_intervals:
			if not (interval_end <= iv[0] or interval_start >= iv[1]):
				intersects = true
				break
		if intersects:
			continue

		var upwards = rng.randf() < 0.5
		_create_ramp(x_start, length, height, ramp_width, upwards)
		occupied_intervals.append([x_start, x_start + length])
	# fin while

func _create_ramp(x_start: float, length: float, height: float, width: float, upwards: bool):
	# Mesh visuel
	var ramp_mesh_size = Vector3(length, height, width)
	var mesh = BoxMesh.new()
	mesh.size = ramp_mesh_size
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = mesh
	if ramp_material:
		mesh_inst.set_surface_override_material(0, ramp_material)

	# Angle et rotation pour obtenir la pente le long de X
	var angle = atan2(height, length)
	var rot = Basis()
	# Pour incliner la boîte de sorte qu'une extrémité soit à y=0 et l'autre à y=height (up) ou -height (down),
	# on effectue une rotation autour de Z d'un signe adapté
	rot = rot.rotated(Vector3(0, 0, 1), -angle if upwards else angle)

	# Centre en X
	var center_x = x_start + length * 0.5

	# Position verticale : on aligne l'arête qui touche la plate sur y = 0
	# - si upwards : l'arête basse doit être à y = 0 -> centre_y = height * 0.5
	# - si downwards : l'arête haute doit être à y = 0 -> centre_y = -height * 0.5
	var center_y = height * 0.5 if upwards else -height * 0.5

	# On n'applique aucun offset vertical qui pourrait placer la rampe sous la plate
	var body = StaticBody3D.new()
	body.transform = Transform3D(rot, Vector3(center_x, center_y, 0))

	# Collision
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.extents = ramp_mesh_size * 0.5
	col.shape = box
	var t = col.transform
	t.origin = Vector3.ZERO
	col.transform = t
	body.add_child(col)

	# Visuel en enfant local
	mesh_inst.transform = Transform3D(Basis(), Vector3.ZERO)
	body.add_child(mesh_inst)

	add_child(body)
