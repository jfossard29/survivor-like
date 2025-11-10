extends CanvasLayer

signal amelioration_choisie(name: String)

@export var panel_script_path: String
@onready var container: VBoxContainer = $Conteneur/ChoixConteneur
@onready var modele_carte: CenterContainer = $Common_To_Rare

var pause_menu: CanvasLayer = null
var panel_script: Script = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	call_deferred("_connect_pause_menu")
	_charger_script_panel()

func _connect_pause_menu() -> void:
	pause_menu = get_tree().root.find_child("PauseMenu", true, false)
	if not pause_menu:
		push_warning("⚠️ PauseMenu non trouvé, la pause ne sera pas synchronisée")

func _charger_script_panel() -> void:
	if panel_script_path != "" and ResourceLoader.exists(panel_script_path):
		panel_script = load(panel_script_path)
	else:
		push_warning("⚠️ Script du panel introuvable ou chemin non défini : %s" % panel_script_path)

# Helper: vérifie si l'objet expose une propriété nommée `prop`
func _has_property(obj: Object, prop: String) -> bool:
	if not obj:
		return false
	for p in obj.get_property_list():
		# chaque item est un Dictionary, avec une clé "name"
		if p.has("name") and String(p["name"]) == prop:
			return true
	return false

func afficher(ameliorations: Array):
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	get_tree().paused = true
	if pause_menu and pause_menu.has_signal("game_paused"):
		pause_menu.game_paused.emit(true)

	# Nettoyage
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

	for amelio in ameliorations:
		var carte = modele_carte.duplicate(DUPLICATE_USE_INSTANTIATION)
		carte.visible = true
		container.add_child(carte)

		var panel: PanelContainer = carte.get_node_or_null("PanelContainer")
		if panel:
			if panel_script:
				panel.set_script(panel_script)
			else:
				# Pas bloquant, mais utile en debug
				push_warning("⚠️ Aucun script chargé pour le panel, impossible d’appliquer certaines valeurs")

			panel.set("titre_valeur", amelio.name)
			panel.set("description_valeur", amelio.description)

			# Rarity
			if _has_property(panel, "rarity"):
				panel.set("rarity", amelio.rarity)
			elif panel.has_method("set_rarity"):
				panel.call("set_rarity", amelio.rarity)

		carte.connect("gui_input", Callable(self, "_on_carte_input").bind(amelio))

func _on_carte_input(event: InputEvent, amelio: Amelioration):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_choix(amelio)

func _on_choix(amelio: Amelioration):
	# Si apply_effect est un Callable, appeler proprement
	if typeof(amelio.apply_effect) == TYPE_CALLABLE:
		amelio.apply_effect.call()
	else:
		# si c'est une méthode sur l'objet amelio
		if amelio.has_method("apply_effect"):
			amelio.call("apply_effect")
		else:
			push_warning("⚠️ apply_effect introuvable pour %s" % str(amelio))

	emit_signal("amelioration_choisie", amelio.name)
	hide()

	get_tree().paused = false
	if pause_menu and pause_menu.has_signal("game_paused"):
		pause_menu.game_paused.emit(false)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
