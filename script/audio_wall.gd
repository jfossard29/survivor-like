extends Node3D

# Paramètres visuels
@export var map_size: float = 100.0
@export var bar_count: int = 128  # Nombre de barres par côté
@export var bar_width: float = 1.5
@export var bar_depth: float = 0.5
@export var max_bar_height: float = 25.0
@export var min_bar_height: float = 1.0
@export var border_offset: float = 5.0  # Distance depuis le bord de la map

# Paramètres audio
@export_group("Audio")
@export var audio_bus: String = "Music"
@export_range(0.05, 0.5, 0.05) var smoothing: float = 0.2  # Plus c'est bas, plus c'est réactif
@export_range(0.5, 10.0, 0.5) var intensity: float = 2.0  # Multiplicateur de hauteur global
@export_range(200.0, 1000.0, 50.0) var min_frequency: float = 300.0  # Fréquence minimale (ignore sub-bass)
@export_range(0.1, 5.0, 0.1) var low_boost: float = 1.0  # Boost pour basses-moyennes (centre)
@export_range(0.1, 5.0, 0.1) var mid_boost: float = 2.0  # Boost pour médiums-aigus (bords)

# Couleurs - Nuance unique
@export_group("Couleurs")
@export var base_color: Color = Color(0.51, 0.3, 1.0, 1.0)  # Couleur de base
@export var use_gradient: bool = false  # Si true, utilise un dégradé
@export var gradient_intensity: float = 0.5  # Variation de teinte (0-1)
@export_range(0.0, 1.0) var transparency: float = 0.1  # 0 = invisible, 1 = opaque

# Effet émissif
@export_group("Émission")
@export var emission_energy: float = 2.0
@export var emission_based_on_intensity: bool = true  # L'émission suit l'audio

var bars: Array = []
var spectrum: AudioEffectSpectrumAnalyzerInstance
var smoothed_magnitudes: Array = []

func _ready() -> void:
	_setup_spectrum_analyzer()
	_create_collision_walls()
	_generate_border()

func _setup_spectrum_analyzer() -> void:
	# Trouver ou créer l'effet spectrum analyzer
	var bus_idx = AudioServer.get_bus_index(audio_bus)
	
	var found = false
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var effect = AudioServer.get_bus_effect(bus_idx, i)
		if effect is AudioEffectSpectrumAnalyzer:
			spectrum = AudioServer.get_bus_effect_instance(bus_idx, i)
			found = true
			break
	
	if not found:
		# Créer l'effet si il n'existe pas
		var effect = AudioEffectSpectrumAnalyzer.new()
		effect.buffer_length = 2.0  # Meilleure résolution
		AudioServer.add_bus_effect(bus_idx, effect)
		spectrum = AudioServer.get_bus_effect_instance(bus_idx, AudioServer.get_bus_effect_count(bus_idx) - 1)
	
	# Initialiser le tableau de lissage
	smoothed_magnitudes.resize(bar_count * 4)
	for i in range(smoothed_magnitudes.size()):
		smoothed_magnitudes[i] = 0.0

func _create_collision_walls() -> void:
	var half_size = map_size * 0.5 + border_offset
	var wall_height = max_bar_height
	var wall_thickness = 1.0
	
	# 4 murs invisibles avec collision
	var walls = [
		{"pos": Vector3(0, wall_height * 0.5, -half_size), "size": Vector3(map_size + border_offset * 2, wall_height, wall_thickness)},  # Nord
		{"pos": Vector3(half_size, wall_height * 0.5, 0), "size": Vector3(wall_thickness, wall_height, map_size + border_offset * 2)},   # Est
		{"pos": Vector3(0, wall_height * 0.5, half_size), "size": Vector3(map_size + border_offset * 2, wall_height, wall_thickness)},   # Sud
		{"pos": Vector3(-half_size, wall_height * 0.5, 0), "size": Vector3(wall_thickness, wall_height, map_size + border_offset * 2)}   # Ouest
	]
	
	for wall_data in walls:
		var wall_body = StaticBody3D.new()
		wall_body.name = "CollisionWall"
		wall_body.collision_layer = 1
		wall_body.collision_mask = 0
		wall_body.position = wall_data.pos
		
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = wall_data.size
		collision.shape = shape
		
		wall_body.add_child(collision)
		add_child(wall_body)

func _generate_border() -> void:
	var half_size = map_size * 0.5 + border_offset
	
	# 4 côtés de la bordure
	var sides = [
		{"start": Vector3(-half_size, 0, -half_size), "end": Vector3(half_size, 0, -half_size), "rotation": 0},      # Nord
		{"start": Vector3(half_size, 0, -half_size), "end": Vector3(half_size, 0, half_size), "rotation": 90},       # Est
		{"start": Vector3(half_size, 0, half_size), "end": Vector3(-half_size, 0, half_size), "rotation": 180},      # Sud
		{"start": Vector3(-half_size, 0, half_size), "end": Vector3(-half_size, 0, -half_size), "rotation": 270}     # Ouest
	]
	
	for side in sides:
		_create_side_bars(side.start, side.end, side.rotation)

func _create_side_bars(start: Vector3, end: Vector3, rotation_y: float) -> void:
	var direction = (end - start).normalized()
	var side_length = start.distance_to(end)
	var spacing = side_length / bar_count
	
	for i in range(bar_count):
		var bar_container = Node3D.new()
		bar_container.name = "BarContainer_" + str(bars.size())
		
		var t = float(i) / float(bar_count)
		var pos = start.lerp(end, t)
		bar_container.position = pos
		bar_container.rotation_degrees.y = rotation_y
		
		# Créer la barre visuelle
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Bar"
		
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(bar_width, min_bar_height, bar_depth)
		mesh_instance.mesh = box_mesh
		
		# Material avec émission et transparence
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission_energy_multiplier = emission_energy
		
		# Activer la transparence
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # Effet néon/additif
		material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible des deux côtés
		
		mesh_instance.material_override = material
		
		bar_container.add_child(mesh_instance)
		add_child(bar_container)
		
		bars.append({
			"container": bar_container,
			"mesh": mesh_instance,
			"material": material,
			"index": i,
			"side_index": bars.size()
		})

func _process(_delta: float) -> void:
	if spectrum == null or bars.is_empty():
		return
	
	# 🎵 Élargir la plage pour ignorer les très basses fréquences
	var freq_max = 20000.0  # Hz
	
	for i in range(bars.size()):
		var bar = bars[i]
		
		# Position de la barre sur son côté (0 = début, 1 = fin)
		var side_position = float(bar.side_index % bar_count) / float(bar_count)
		
		# Créer une distribution en V : 0 au centre, 1 aux extrémités
		var mirror_t = abs(side_position * 2.0 - 1.0)
		
		# Mapper la position miroir à une fréquence
		# Centre = fréquences moyennes-basses, bords = hautes fréquences
		var freq = lerp(min_frequency, freq_max, mirror_t * mirror_t)  # Échelle logarithmique
		
		# Obtenir la magnitude MOYENNE des deux canaux (stéréo)
		var magnitude_left = spectrum.get_magnitude_for_frequency_range(freq, freq + 100.0, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
		var magnitude_right = magnitude_left  # Par défaut, même valeur
		
		# Si stéréo, combiner les deux canaux
		var magnitude = (magnitude_left.length() + magnitude_right.length()) * 0.5
		
		# 🎛️ Appliquer les boost selon la position (simplifié)
		var frequency_boost: float = lerp(low_boost, mid_boost, mirror_t)
		
		magnitude *= frequency_boost
		
		# Lisser la magnitude
		smoothed_magnitudes[bar.side_index] = lerp(
			smoothed_magnitudes[bar.side_index],
			magnitude,
			smoothing
		)
		
		# Calculer la hauteur de la barre
		var normalized_magnitude = clamp(smoothed_magnitudes[bar.side_index] * intensity * 100.0, 0.0, 1.0)
		var target_height = lerp(min_bar_height, max_bar_height, normalized_magnitude)
		
		# Mettre à jour le mesh
		var box_mesh = bar.mesh.mesh as BoxMesh
		box_mesh.size.y = target_height
		bar.container.position.y = target_height * 0.5
		
		# Calculer la couleur finale
		var final_color: Color
		final_color = base_color.lerp(Color.WHITE, mirror_t * gradient_intensity * 0.3)
		final_color.a = transparency
		bar.material.albedo_color = final_color
		if emission_based_on_intensity:
			bar.material.emission = final_color * normalized_magnitude
		else:
			bar.material.emission = final_color
