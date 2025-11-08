extends MeshInstance3D

## Script qui fait pulser un mesh selon un fichier JSON de beats
## Compatible avec ShaderMaterial et StandardMaterial3D
## Se synchronise automatiquement avec MusicManager

@export_file("*.json") var beats_file_path: String = "res://beats.json"
@export var pulse_scale: float = 1.5  # Taille max lors du pulse
@export var pulse_speed: float = 8.0  # Vitesse du pulse
@export var emission_strength: float = 3.0  # Intensité de la lueur (pour StandardMaterial3D)

var all_beats_data: Dictionary = {}  # Format: {"song_name.ogg": {"intervals": [...], "first_beat_offset": ...}}
var current_beats: Array[float] = []
var current_beat_index: int = 0
var is_pulsing: bool = false
var current_scale: float = 1.0
var base_scale: Vector3
var music_manager: Node = null
var material: Material
var is_shader_material: bool = false

# Pour le format intervalles
var next_beat_time: float = 0.0
var first_beat_offset: float = 0.0
var current_song_name: String = ""

# Gestion de la pause
var game_manager: Node = null
var is_paused: bool = false

func _ready():
	# Sauvegarder l'échelle de base
	base_scale = scale
	
	# Détecter le type de matériau
	if mesh and mesh.surface_get_material(0):
		material = mesh.surface_get_material(0)
		
		if material is ShaderMaterial:
			is_shader_material = true
			print("✅ ShaderMaterial détecté - Le pulse utilisera uniquement le scale")
		elif material is StandardMaterial3D:
			is_shader_material = false
			material = material.duplicate()
			var std_mat = material as StandardMaterial3D
			std_mat.emission_enabled = true
			std_mat.emission = Color(1.0, 0.8, 0.2)  # Orange/jaune
			std_mat.emission_energy_multiplier = 0.0
			
			if mesh:
				mesh.surface_set_material(0, material)
			print("✅ StandardMaterial3D détecté - Le pulse utilisera scale + emission")
	else:
		# Créer un matériau standard par défaut
		is_shader_material = false
		material = StandardMaterial3D.new()
		var std_mat = material as StandardMaterial3D
		std_mat.albedo_color = Color.WHITE
		std_mat.emission_enabled = true
		std_mat.emission = Color(1.0, 0.8, 0.2)
		std_mat.emission_energy_multiplier = 0.0
		
		if mesh:
			mesh.surface_set_material(0, material)
		print("✅ StandardMaterial3D créé par défaut")
	
	# Charger tous les beats depuis le JSON
	_load_all_beats()
	
	# Trouver le MusicManager (autoload)
	music_manager = get_node_or_null("/root/MusicManager")
	
	if not music_manager:
		push_error("MusicManager non trouvé ! Le script ne pourra pas se synchroniser.")
	else:
		print("✅ MusicManager trouvé")
	
	# Trouver le GameManager pour vérifier la pause
	game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		push_warning("GameManager non trouvé, l'animation ne réagira pas à la pause")

func _load_all_beats():
	if beats_file_path.is_empty():
		push_error("Aucun fichier JSON spécifié !")
		return
	
	var file = FileAccess.open(beats_file_path, FileAccess.READ)
	if not file:
		push_error("Impossible d'ouvrir le fichier: %s" % beats_file_path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("Erreur de parsing JSON: %s" % json.get_error_message())
		return
	
	var data = json.data
	all_beats_data.clear()
	
	# Le JSON doit être un tableau d'objets avec des IDs
	if data is Array:
		for song_data in data:
			if not song_data is Dictionary:
				continue
			
			var song_id = song_data.get("id", "")
			if song_id.is_empty():
				continue
			
			all_beats_data[song_id] = {
				"intervals": song_data.get("intervals", []),
				"first_beat_offset": song_data.get("first_beat_offset", 0.0),
				"bpm": song_data.get("bpm", 0),
				"beat_count": song_data.get("beat_count", 0)
			}
		
		print("✅ %d musiques chargées depuis %s" % [all_beats_data.size(), beats_file_path])
		
		# Charger les beats de la première musique disponible
		if all_beats_data.size() > 0:
			var first_song = all_beats_data.keys()[0]
			_load_beats_for_song(first_song)
	else:
		push_error("Le JSON doit être un tableau d'objets avec des 'id'")

func _load_beats_for_song(song_name: String):
	if not all_beats_data.has(song_name):
		push_warning("Aucun beat trouvé pour: %s" % song_name)
		current_beats.clear()
		return
	
	current_song_name = song_name
	var song_data = all_beats_data[song_name]
	
	current_beats.clear()
	for interval in song_data.get("intervals", []):
		current_beats.append(float(interval))
	
	first_beat_offset = song_data.get("first_beat_offset", 0.0)
	next_beat_time = first_beat_offset
	current_beat_index = 0
	
	print("✅ Beats chargés pour: %s" % song_name)
	print("📊 BPM: %s | Beats: %d | Premier beat: %.3fs" % [
		song_data.get("bpm", "N/A"),
		song_data.get("beat_count", 0),
		first_beat_offset
	])

func _get_current_song_name() -> String:
	if not music_manager or not music_manager.main_player:
		return ""
	
	var stream = music_manager.main_player.stream
	if not stream:
		return ""
	
	# Obtenir le nom du fichier depuis le chemin de ressource
	var resource_path = stream.resource_path
	if resource_path.is_empty():
		return ""
	
	return resource_path.get_file()

func _process(delta: float):
	if not music_manager or not music_manager.main_player or current_beats.is_empty():
		return
	
	# Vérifier l'état de pause
	if game_manager:
		is_paused = game_manager.is_paused
	
	# Vérifier si la musique a changé
	var current_playing_song = _get_current_song_name()
	if not current_playing_song.is_empty() and current_playing_song != current_song_name:
		_load_beats_for_song(current_playing_song)
		reset_playback()
	
	# Obtenir la position de lecture
	if not music_manager.main_player.playing:
		return
	
	var playback_position = music_manager.main_player.get_playback_position()
	
	# Vérifier si on doit déclencher un beat (toujours actif pour garder le rythme)
	if current_beat_index < current_beats.size():
		# Mode intervalles : calculer le prochain beat
		if playback_position >= next_beat_time - 0.02:
			_trigger_pulse()
			current_beat_index += 1
			
			# Calculer le prochain beat
			if current_beat_index < current_beats.size():
				next_beat_time += current_beats[current_beat_index]
	
	# Animer le pulse SEULEMENT si le jeu n'est pas en pause
	if is_pulsing and not is_paused:
		current_scale = lerp(current_scale, 1.0, delta * pulse_speed)
		
		# Animer l'émission uniquement pour StandardMaterial3D
		if not is_shader_material and material is StandardMaterial3D:
			var std_mat = material as StandardMaterial3D
			std_mat.emission_energy_multiplier = lerp(std_mat.emission_energy_multiplier, 0.0, delta * pulse_speed)
		
		if current_scale <= 1.05:
			is_pulsing = false
			current_scale = 1.0
			
			if not is_shader_material and material is StandardMaterial3D:
				var std_mat = material as StandardMaterial3D
				std_mat.emission_energy_multiplier = 0.0
	
	# Appliquer l'échelle seulement si pas en pause
	if not is_paused:
		scale = base_scale * current_scale
	else:
		# Forcer l'échelle de base pendant la pause
		scale = base_scale
		# Reset l'état du pulse si on est en pause
		if is_pulsing:
			current_scale = 1.0
			
			if not is_shader_material and material is StandardMaterial3D:
				var std_mat = material as StandardMaterial3D
				std_mat.emission_energy_multiplier = 0.0

func _trigger_pulse():
	# Ne pas déclencher l'animation visuelle si en pause
	if not is_paused:
		is_pulsing = true
		current_scale = pulse_scale
		
		# Activer l'émission uniquement pour StandardMaterial3D
		if not is_shader_material and material is StandardMaterial3D:
			var std_mat = material as StandardMaterial3D
			std_mat.emission_energy_multiplier = emission_strength
	
	# Toujours envoyer le signal au BassManager (pour garder le rythme)
	if has_node("/root/BassManager") and BassManager.has_signal("beat_detected"):
		BassManager.beat_detected.emit(1.0)

func reset_playback():
	"""Appelle cette fonction quand la musique redémarre"""
	current_beat_index = 0
	is_pulsing = false
	current_scale = 1.0
	scale = base_scale
	
	if not is_shader_material and material is StandardMaterial3D:
		var std_mat = material as StandardMaterial3D
		std_mat.emission_energy_multiplier = 0.0
	
	next_beat_time = first_beat_offset
