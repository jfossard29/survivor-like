extends CanvasLayer

signal amelioration_choisie(name: String)

@export var panel_script_path: String = "res://script/UI/option_levelup.gd"
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

func _has_property(obj: Object, prop: String) -> bool:
	if not obj:
		return false
	for p in obj.get_property_list():
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
		# Duplication COMPLÈTE avec tous les flags
		var carte = modele_carte.duplicate(DUPLICATE_SIGNALS | DUPLICATE_GROUPS | DUPLICATE_SCRIPTS | DUPLICATE_USE_INSTANTIATION)
		carte.visible = true
		
		# Trouver le panel dans la copie
		var panel: PanelContainer = carte.get_node_or_null("PanelContainer")
		if panel:
			# Réappliquer le script pour réinitialiser les @onready
			if panel_script:
				panel.set_script(null)  # Reset d'abord
				panel.set_script(panel_script)
			
			# Attendre que le nœud soit dans l'arbre avant de configurer
			container.add_child(carte)
			
			# Forcer la réinitialisation des @onready
			await get_tree().process_frame
			
			# Maintenant configurer les valeurs
			if panel.has_method("configure"):
				panel.call("configure", amelio.name, amelio.description, amelio.rarity)
			else:
				# Fallback si pas de méthode configure
				panel.set("titre_valeur", amelio.name)
				panel.set("description_valeur", amelio.description)
				
				if _has_property(panel, "rarity"):
					panel.set("rarity", amelio.rarity)
				elif panel.has_method("set_rarity"):
					panel.call("set_rarity", amelio.rarity)
			
			# Connecter l'input sur la carte (pas le panel)
			carte.connect("gui_input", Callable(self, "_on_carte_input").bind(amelio))
		else:
			# Si pas de panel, ajouter quand même
			container.add_child(carte)
			carte.connect("gui_input", Callable(self, "_on_carte_input").bind(amelio))

func _on_carte_input(event: InputEvent, amelio: Amelioration):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_choix(amelio)

func _on_choix(amelio: Amelioration):
	if typeof(amelio.apply_effect) == TYPE_CALLABLE:
		amelio.apply_effect.call()
	else:
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
