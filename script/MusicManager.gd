extends Node
@export var main_tracks: Array[AudioStream] = []
@export_range(-80.0, 0.0, 0.5) var volume_db: float = -6.0 : set = _set_volume

# Paramètres de l'effet de pause
@export_group("Pause Effect")
@export_range(-80.0, 0.0, 0.5) var paused_volume_db: float = -20.0
@export_range(100.0, 20000.0, 100.0) var normal_cutoff: float = 20000.0
@export_range(100.0, 20000.0, 100.0) var paused_cutoff: float = 500.0
@export var transition_speed: float = 5.0

var main_player: AudioStreamPlayer
var current_track_index := 0
var is_paused := false

# Bus et effet
var music_bus_idx: int
var lowpass_effect: AudioEffectLowPassFilter

# Valeurs cibles pour l'interpolation
var target_volume: float
var target_cutoff: float
var current_volume: float
var current_cutoff: float

func _init():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready():
	music_bus_idx = AudioServer.get_bus_index("Music")
	
	# 🔍 DEBUG : Voir combien de filtres existent
	print("Nombre d'effets sur bus Music: ", AudioServer.get_bus_effect_count(music_bus_idx))
	
	# Créer le player audio
	main_player = AudioStreamPlayer.new()
	main_player.bus = "Music"
	main_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(main_player)
	main_player.finished.connect(_on_main_track_finished)
	
	# ✅ Vérifier si un filtre existe déjà
	var filter_found = false
	for i in range(AudioServer.get_bus_effect_count(music_bus_idx)):
		var effect = AudioServer.get_bus_effect(music_bus_idx, i)
		if effect is AudioEffectLowPassFilter:
			lowpass_effect = effect
			filter_found = true
			print("✅ Filtre existant trouvé")
			break
	
	# Créer seulement si aucun filtre n'existe
	if not filter_found:
		lowpass_effect = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(music_bus_idx, lowpass_effect)
		print("🆕 Nouveau filtre créé")
	
	# ✅ FORCER le cutoff à 20000 Hz (pas de filtre)
	lowpass_effect.cutoff_hz = normal_cutoff
	print("🎵 Cutoff réglé à: ", lowpass_effect.cutoff_hz, " Hz")
	
	# Initialiser les valeurs
	current_volume = volume_db
	current_cutoff = normal_cutoff
	target_volume = volume_db
	target_cutoff = normal_cutoff
	
	_set_volume(volume_db)
func _process(delta: float) -> void:
	# Interpoler smoothement le volume et le filtre
	if not is_equal_approx(current_volume, target_volume):
		current_volume = lerp(current_volume, target_volume, transition_speed * delta)
		main_player.volume_db = current_volume
	
	if not is_equal_approx(current_cutoff, target_cutoff):
		current_cutoff = lerp(current_cutoff, target_cutoff, transition_speed * delta)
		lowpass_effect.cutoff_hz = current_cutoff

func start_music():
	if main_tracks.is_empty():
		push_error("Aucune musique principale définie!")
		return
	
	current_track_index = randi() % main_tracks.size()
	print("🎵 Musique démarrée - Track #", current_track_index + 1)
	
	_play_main_track()

func _play_main_track():
	if current_track_index < main_tracks.size():
		main_player.stream = main_tracks[current_track_index]
		main_player.play()

func _on_main_track_finished():
	if is_paused:
		return
	current_track_index = (current_track_index + 1) % main_tracks.size()
	_play_main_track()

func set_game_paused(paused: bool):
	is_paused = paused
	
	if paused:
		target_volume = paused_volume_db
		target_cutoff = paused_cutoff
	else:
		target_volume = volume_db
		target_cutoff = normal_cutoff

func _set_volume(value: float) -> void:
	volume_db = clamp(value, -80.0, 0.0)
	if main_player and not is_paused:
		main_player.volume_db = volume_db
		target_volume = volume_db
		current_volume = volume_db

func set_volume(value: float) -> void:
	_set_volume(value)

func stop_all():
	main_player.stop()
	if lowpass_effect:
		lowpass_effect.cutoff_hz = normal_cutoff
