extends CanvasLayer

signal amelioration_choisie(name: String)

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/Label
@onready var container: VBoxContainer = $Panel/ChoixContainer

var pause_menu: CanvasLayer = null

func _ready():
	# ✅ Ce CanvasLayer doit continuer à fonctionner pendant la pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	hide()
	
	# Récupérer la référence au menu pause
	call_deferred("_connect_pause_menu")

func _connect_pause_menu() -> void:
	pause_menu = get_tree().root.find_child("PauseMenu", true, false)
	if not pause_menu:
		push_warning("⚠️ PauseMenu non trouvé, la pause ne sera pas synchronisée")

func afficher(ameliorations: Array[Amelioration]):
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# ✅ Mettre en pause via le système centralisé
	get_tree().paused = true
	
	# ✅ Notifier le système de pause (pour la musique, etc.)
	if pause_menu and pause_menu.has_signal("game_paused"):
		pause_menu.game_paused.emit(true)
	
	label.text = "Choisissez une amélioration :"
	
	# Nettoyer les anciens boutons
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	
	# Créer les nouveaux boutons
	for amelio in ameliorations:
		var bouton = Button.new()
		bouton.text = amelio.name + "\n" + amelio.description
		bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bouton.connect("pressed", Callable(self, "_on_choix").bind(amelio))
		container.add_child(bouton)

func _on_choix(amelio: Amelioration):
	amelio.apply_effect.call()
	emit_signal("amelioration_choisie", amelio.name)
	hide()
	
	# ✅ Reprendre via le système centralisé
	get_tree().paused = false
	
	# ✅ Notifier le système de pause
	if pause_menu and pause_menu.has_signal("game_paused"):
		pause_menu.game_paused.emit(false)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
