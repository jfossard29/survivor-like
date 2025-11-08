@tool
extends Node3D

## Script qui génère un robot humanoïde simple
## Attache ce script à un Node3D - Le robot apparaît dans l'éditeur !

@export var robot_color: Color = Color(0.3, 0.5, 0.8):  # Bleu métallique
	set(value):
		robot_color = value
		if Engine.is_editor_hint():
			_rebuild_robot()

@export var joint_color: Color = Color(0.8, 0.8, 0.8):  # Gris clair
	set(value):
		joint_color = value
		if Engine.is_editor_hint():
			_rebuild_robot()

@export var eye_color: Color = Color(0.0, 1.0, 1.0):    # Cyan lumineux
	set(value):
		eye_color = value
		if Engine.is_editor_hint():
			_rebuild_robot()

@export var rebuild: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_rebuild_robot()

var skeleton: Dictionary = {}

func _ready():
	if not Engine.is_editor_hint():
		_build_robot()

func _rebuild_robot():
	# Nettoyer les enfants existants
	for child in get_children():
		child.queue_free()
	
	await get_tree().process_frame
	_build_robot()

func _build_robot():
	# Matériaux
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = robot_color
	body_mat.metallic = 0.7
	body_mat.roughness = 0.3
	
	var joint_mat = StandardMaterial3D.new()
	joint_mat.albedo_color = joint_color
	joint_mat.metallic = 0.9
	joint_mat.roughness = 0.2
	
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = eye_color
	eye_mat.emission_enabled = true
	eye_mat.emission = eye_color
	eye_mat.emission_energy_multiplier = 2.0
	
	# --- TORSE ---
	var torso = _create_box("Torso", Vector3(0.8, 1.2, 0.4), Vector3(0, 1.0, 0), body_mat)
	skeleton.torso = torso
	
	# --- TÊTE ---
	var head_node = Node3D.new()
	head_node.name = "Head"
	head_node.position = Vector3(0, 0.8, 0)
	torso.add_child(head_node)
	skeleton.head = head_node
	
	# Tête (cube)
	var head = _create_box("HeadMesh", Vector3(0.6, 0.6, 0.6), Vector3.ZERO, body_mat)
	head_node.add_child(head)
	
	# Cou (articulation)
	var neck = _create_sphere("Neck", 0.15, Vector3(0, -0.3, 0), joint_mat)
	head_node.add_child(neck)
	
	# Yeux
	var left_eye = _create_sphere("LeftEye", 0.1, Vector3(-0.15, 0.1, 0.31), eye_mat)
	head_node.add_child(left_eye)
	
	var right_eye = _create_sphere("RightEye", 0.1, Vector3(0.15, 0.1, 0.31), eye_mat)
	head_node.add_child(right_eye)
	
	# Antenne
	var antenna = _create_cylinder("Antenna", 0.03, 0.3, Vector3(0, 0.45, 0), joint_mat)
	head_node.add_child(antenna)
	
	var antenna_tip = _create_sphere("AntennaTip", 0.08, Vector3(0, 0.7, 0), eye_mat)
	head_node.add_child(antenna_tip)
	
	# --- BRAS GAUCHE ---
	var left_shoulder_node = Node3D.new()
	left_shoulder_node.name = "LeftShoulder"
	left_shoulder_node.position = Vector3(-0.5, 0.5, 0)
	torso.add_child(left_shoulder_node)
	skeleton.left_shoulder = left_shoulder_node
	
	var left_shoulder = _create_sphere("LeftShoulderJoint", 0.15, Vector3.ZERO, joint_mat)
	left_shoulder_node.add_child(left_shoulder)
	
	var left_upper_arm = _create_cylinder("LeftUpperArm", 0.12, 0.6, Vector3(0, -0.3, 0), body_mat)
	left_shoulder_node.add_child(left_upper_arm)
	
	# Coude gauche
	var left_elbow_node = Node3D.new()
	left_elbow_node.name = "LeftElbow"
	left_elbow_node.position = Vector3(0, -0.6, 0)
	left_shoulder_node.add_child(left_elbow_node)
	skeleton.left_elbow = left_elbow_node
	
	var left_elbow = _create_sphere("LeftElbowJoint", 0.12, Vector3.ZERO, joint_mat)
	left_elbow_node.add_child(left_elbow)
	
	var left_forearm = _create_cylinder("LeftForearm", 0.1, 0.5, Vector3(0, -0.25, 0), body_mat)
	left_elbow_node.add_child(left_forearm)
	
	# Main gauche
	var left_hand = _create_box("LeftHand", Vector3(0.15, 0.2, 0.15), Vector3(0, -0.6, 0), body_mat)
	left_elbow_node.add_child(left_hand)
	
	# --- BRAS DROIT ---
	var right_shoulder_node = Node3D.new()
	right_shoulder_node.name = "RightShoulder"
	right_shoulder_node.position = Vector3(0.5, 0.5, 0)
	torso.add_child(right_shoulder_node)
	skeleton.right_shoulder = right_shoulder_node
	
	var right_shoulder = _create_sphere("RightShoulderJoint", 0.15, Vector3.ZERO, joint_mat)
	right_shoulder_node.add_child(right_shoulder)
	
	var right_upper_arm = _create_cylinder("RightUpperArm", 0.12, 0.6, Vector3(0, -0.3, 0), body_mat)
	right_shoulder_node.add_child(right_upper_arm)
	
	# Coude droit
	var right_elbow_node = Node3D.new()
	right_elbow_node.name = "RightElbow"
	right_elbow_node.position = Vector3(0, -0.6, 0)
	right_shoulder_node.add_child(right_elbow_node)
	skeleton.right_elbow = right_elbow_node
	
	var right_elbow = _create_sphere("RightElbowJoint", 0.12, Vector3.ZERO, joint_mat)
	right_elbow_node.add_child(right_elbow)
	
	var right_forearm = _create_cylinder("RightForearm", 0.1, 0.5, Vector3(0, -0.25, 0), body_mat)
	right_elbow_node.add_child(right_forearm)
	
	# Main droite
	var right_hand = _create_box("RightHand", Vector3(0.15, 0.2, 0.15), Vector3(0, -0.6, 0), body_mat)
	right_elbow_node.add_child(right_hand)
	
	# --- BASSIN ---
	var pelvis = _create_box("Pelvis", Vector3(0.7, 0.3, 0.35), Vector3(0, -0.8, 0), body_mat)
	torso.add_child(pelvis)
	
	# --- JAMBE GAUCHE ---
	var left_hip_node = Node3D.new()
	left_hip_node.name = "LeftHip"
	left_hip_node.position = Vector3(-0.25, -0.95, 0)
	torso.add_child(left_hip_node)
	skeleton.left_hip = left_hip_node
	
	var left_hip = _create_sphere("LeftHipJoint", 0.15, Vector3.ZERO, joint_mat)
	left_hip_node.add_child(left_hip)
	
	var left_thigh = _create_cylinder("LeftThigh", 0.15, 0.7, Vector3(0, -0.35, 0), body_mat)
	left_hip_node.add_child(left_thigh)
	
	# Genou gauche
	var left_knee_node = Node3D.new()
	left_knee_node.name = "LeftKnee"
	left_knee_node.position = Vector3(0, -0.7, 0)
	left_hip_node.add_child(left_knee_node)
	skeleton.left_knee = left_knee_node
	
	var left_knee = _create_sphere("LeftKneeJoint", 0.13, Vector3.ZERO, joint_mat)
	left_knee_node.add_child(left_knee)
	
	var left_shin = _create_cylinder("LeftShin", 0.12, 0.7, Vector3(0, -0.35, 0), body_mat)
	left_knee_node.add_child(left_shin)
	
	# Pied gauche
	var left_foot = _create_box("LeftFoot", Vector3(0.2, 0.15, 0.4), Vector3(0, -0.775, 0.1), body_mat)
	left_knee_node.add_child(left_foot)
	
	# --- JAMBE DROITE ---
	var right_hip_node = Node3D.new()
	right_hip_node.name = "RightHip"
	right_hip_node.position = Vector3(0.25, -0.95, 0)
	torso.add_child(right_hip_node)
	skeleton.right_hip = right_hip_node
	
	var right_hip = _create_sphere("RightHipJoint", 0.15, Vector3.ZERO, joint_mat)
	right_hip_node.add_child(right_hip)
	
	var right_thigh = _create_cylinder("RightThigh", 0.15, 0.7, Vector3(0, -0.35, 0), body_mat)
	right_hip_node.add_child(right_thigh)
	
	# Genou droit
	var right_knee_node = Node3D.new()
	right_knee_node.name = "RightKnee"
	right_knee_node.position = Vector3(0, -0.7, 0)
	right_hip_node.add_child(right_knee_node)
	skeleton.right_knee = right_knee_node
	
	var right_knee = _create_sphere("RightKneeJoint", 0.13, Vector3.ZERO, joint_mat)
	right_knee_node.add_child(right_knee)
	
	var right_shin = _create_cylinder("RightShin", 0.12, 0.7, Vector3(0, -0.35, 0), body_mat)
	right_knee_node.add_child(right_shin)
	
	# Pied droit
	var right_foot = _create_box("RightFoot", Vector3(0.2, 0.15, 0.4), Vector3(0, -0.775, 0.1), body_mat)
	right_knee_node.add_child(right_foot)
	
	print("🤖 Robot généré ! Hauteur totale: ~2.5m")

# Fonctions helper
func _create_box(node_name: String, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = mat
	
	add_child(mesh_instance)
	return mesh_instance

func _create_sphere(node_name: String, radius: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2
	mesh_instance.mesh = sphere_mesh
	mesh_instance.material_override = mat
	
	add_child(mesh_instance)
	return mesh_instance

func _create_cylinder(node_name: String, radius: float, height: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius
	cylinder_mesh.height = height
	mesh_instance.mesh = cylinder_mesh
	mesh_instance.material_override = mat
	
	add_child(mesh_instance)
	return mesh_instance

# Fonction pour animer le robot (exemple)
func animate_wave():
	"""Fait faire un signe de la main au robot"""
	var tween = create_tween()
	tween.tween_property(skeleton.right_shoulder, "rotation_degrees", Vector3(-90, 0, 0), 0.5)
	tween.tween_property(skeleton.right_elbow, "rotation_degrees", Vector3(0, 0, -45), 0.3)
	tween.tween_property(skeleton.right_elbow, "rotation_degrees", Vector3(0, 0, 45), 0.3)
	tween.tween_property(skeleton.right_elbow, "rotation_degrees", Vector3(0, 0, -45), 0.3)
	tween.tween_property(skeleton.right_elbow, "rotation_degrees", Vector3(0, 0, 0), 0.3)
	tween.tween_property(skeleton.right_shoulder, "rotation_degrees", Vector3(0, 0, 0), 0.5)
