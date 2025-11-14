# Ajouter ce script sur un nouveau Node "PerformanceMonitor"
# Il va vous dire exactement où est le problème

extends Node

var frame_times = []
var max_samples = 60

func _ready():
	print("=== MONITORING DES PERFORMANCES ===")

func _process(delta):
	frame_times.append(delta * 1000.0)  # Convertir en ms
	if frame_times.size() > max_samples:
		frame_times.pop_front()
	
	# Affichage toutes les 2 secondes
	if Engine.get_frames_drawn() % 120 == 0:
		var avg = 0.0
		for t in frame_times:
			avg += t
		avg /= frame_times.size()
		
		print("\n=== DIAGNOSTIC ===")
		print("FPS moyen: ", 1000.0 / avg)
		print("Frame time moyen: %.2f ms" % avg)
		print("Ennemis actifs: ", GameManager.registered_enemies.size())
		print("Nodes totaux: ", get_tree().get_node_count())
		print("Process time: %.2f ms" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000))
		print("Physics time: %.2f ms" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000))
		print("==================\n")
