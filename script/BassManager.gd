extends Node

## Détecteur de batterie (kick, snare) pour le bus Music
## Détecte les pics d'énergie soudains

@export_range(0.5, 3.0, 0.1) var beat_multiplier: float = 1.3  # Pic = 1.3x la moyenne
@export_range(20.0, 300.0, 10.0) var low_freq: float = 60.0
@export_range(300.0, 4000.0, 100.0) var high_freq: float = 2000.0
@export var detection_cooldown: float = 0.08  # ~120 BPM max
@export var debug_mode: bool = true  # Afficher les détections

var music_bus_idx: int
var spectrum: AudioEffectSpectrumAnalyzerInstance
var last_detection_time: float = 0.0
var previous_energy: float = 0.0
var energy_history: Array[float] = []
var history_size: int = 10

func _ready():
	music_bus_idx = AudioServer.get_bus_index("Music")
	
	print("=== DEBUG BUS MUSIC ===")
	print("Nombre d'effets: ", AudioServer.get_bus_effect_count(music_bus_idx))
	
	# Lister tous les effets existants
	for i in AudioServer.get_bus_effect_count(music_bus_idx):
		var effect = AudioServer.get_bus_effect(music_bus_idx, i)
		print("  Effet #%d: %s" % [i, effect.get_class()])
	
	# Vérifier si un SpectrumAnalyzer existe
	var spectrum_idx := -1
	for i in AudioServer.get_bus_effect_count(music_bus_idx):
		var effect = AudioServer.get_bus_effect(music_bus_idx, i)
		if effect is AudioEffectSpectrumAnalyzer:
			spectrum_idx = i
			print("✓ SpectrumAnalyzer trouvé à l'index %d" % i)
			break
	
	if spectrum_idx == -1:
		# Ajouter SpectrumAnalyzer EN PREMIER (index 0)
		var spectrum_effect = AudioEffectSpectrumAnalyzer.new()
		spectrum_effect.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
		spectrum_effect.tap_back_pos = 0.01
		AudioServer.add_bus_effect(music_bus_idx, spectrum_effect, 0)
		spectrum_idx = 0
		print("✓ SpectrumAnalyzer ajouté à l'index 0 (AVANT les autres effets)")
	
	# Récupérer l'instance
	spectrum = AudioServer.get_bus_effect_instance(music_bus_idx, spectrum_idx)
	if spectrum:
		print("✓ Détecteur de batterie initialisé")
		# Attendre 1 seconde puis tester
		await get_tree().create_timer(1.0).timeout
		_test_spectrum()
	else:
		push_error("❌ Impossible de récupérer le SpectrumAnalyzer !")

func _test_spectrum():
	if not spectrum:
		return
	
	var test_magnitude = spectrum.get_magnitude_for_frequency_range(20.0, 20000.0)
	var test_energy = test_magnitude.length()
	print("TEST SPECTRUM - Énergie totale: %.6f" % test_energy)
	
	if test_energy < 0.000001:
		print("⚠️ AUCUN SIGNAL DÉTECTÉ ! La musique joue-t-elle ?")
	else:
		print("✓ Signal détecté, le détecteur devrait fonctionner")

func _get_spectrum_effect_index() -> int:
	for i in AudioServer.get_bus_effect_count(music_bus_idx):
		var effect = AudioServer.get_bus_effect(music_bus_idx, i)
		if effect is AudioEffectSpectrumAnalyzer:
			return i
	return -1

func _process(_delta: float) -> void:
	if not spectrum:
		return
	
	# Calculer l'énergie actuelle
	var current_energy := _get_drum_energy()
	
	# Calculer l'énergie moyenne récente
	energy_history.append(current_energy)
	if energy_history.size() > history_size:
		energy_history.pop_front()
	
	var avg_energy := _get_average_energy()
	
	# Debug: afficher l'énergie toutes les 60 frames
	if debug_mode and Engine.get_frames_drawn() % 60 == 0:
		var ratio = current_energy / avg_energy if avg_energy > 0 else 0
	
	# Détecter un pic (énergie actuelle > X fois la moyenne)
	var current_time := Time.get_ticks_msec() / 1000.0
	
	# Attendre d'avoir assez d'historique
	if energy_history.size() < history_size:
		return
	
	# Le beat est détecté si l'énergie est beat_multiplier fois supérieure à la moyenne
	if avg_energy > 0.001 and current_energy > avg_energy * beat_multiplier:
		if (current_time - last_detection_time) > detection_cooldown:
			var ratio = current_energy / avg_energy
			last_detection_time = current_time
			beat_detected.emit(current_energy)
	
	previous_energy = current_energy

func _get_drum_energy() -> float:
	# Analyser les fréquences de la batterie (kick ~60-100Hz, snare ~200-500Hz)
	var low_magnitude := spectrum.get_magnitude_for_frequency_range(low_freq, 150.0)
	var mid_magnitude := spectrum.get_magnitude_for_frequency_range(150.0, high_freq)
	
	# Combiner les deux zones (kick + snare)
	var total_energy := low_magnitude.length() + mid_magnitude.length() * 0.5
	
	return total_energy

func _get_average_energy() -> float:
	if energy_history.is_empty():
		return 0.0
	
	var sum := 0.0
	for e in energy_history:
		sum += e
	
	return sum / energy_history.size()

# Signal pour réagir aux détections
signal beat_detected(energy: float)
