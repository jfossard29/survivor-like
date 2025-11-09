extends PanelContainer

# Références aux enfants
@onready var hbox: HBoxContainer = $Contenu
@onready var child_panel: PanelContainer = $Contenu/PanelImage

# Paramètres du décalage du PanelContainer parent (self)
@export_group("Parent Movement")
@export var horizontal_offset: float = 10.0  # Décalage à droite en pixels
@export var animation_duration: float = 0.3

# Paramètres de l'animation du PanelContainer enfant
@export_group("Child Panel Effect")
@export var child_rotation: float = 5.0
@export var child_scale: float = 1.1
@export var animate_child: bool = true  # Activer/désactiver l'animation de l'enfant

# Paramètres de rareté
@export_group("Rarity")
@export_enum("common", "uncommon", "rare", "legendary", "unique") var rarity: String = "common"
@export var shadow_pulse_intensity: float = 0.3  # Intensité de la pulsation (0-1)
@export var shadow_pulse_speed: float = 2.0  # Vitesse de la pulsation

var is_hovered: bool = false
var original_position: Vector2
var position_initialized: bool = false
var pulse_time: float = 0.0

func _ready():
	# Connecter les signaux de hover
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	
	# Configurer le pivot de l'enfant pour la rotation
	if child_panel:
		call_deferred("_setup_child_pivot")
	
	# Appliquer la couleur de rareté
	call_deferred("_apply_rarity_style")

func _setup_child_pivot():
	if child_panel:
		child_panel.pivot_offset = child_panel.size / 2

func _process(delta):
	# Sauvegarder la position après le premier frame (quand le layout est stabilisé)
	if not position_initialized:
		original_position = position
		position_initialized = true
	
	# Animation de pulsation des ombres
	pulse_time += delta * shadow_pulse_speed
	_update_shadow_pulse()

func _apply_rarity_style():
	var color = _get_rarity_color(rarity)
	
	# Appliquer la couleur de bordure au parent
	var parent_stylebox = get_theme_stylebox("panel").duplicate()
	if parent_stylebox is StyleBoxFlat:
		parent_stylebox.border_color = color
	add_theme_stylebox_override("panel", parent_stylebox)
	
	# Appliquer la couleur de bordure à l'enfant
	if child_panel:
		var child_stylebox = child_panel.get_theme_stylebox("panel").duplicate()
		if child_stylebox is StyleBoxFlat:
			child_stylebox.border_color = color
		child_panel.add_theme_stylebox_override("panel", child_stylebox)

func _update_shadow_pulse():
	var pulse_factor = (sin(pulse_time) * 0.5 + 0.5) * shadow_pulse_intensity
	var color = _get_rarity_color(rarity)
	
	# Mettre à jour l'ombre du parent
	var parent_stylebox = get_theme_stylebox("panel")
	if parent_stylebox is StyleBoxFlat:
		var shadow_color = Color(color.r, color.g, color.b, 0.3 + pulse_factor)
		parent_stylebox.shadow_color = shadow_color
	
	# Mettre à jour l'ombre de l'enfant
	if child_panel:
		var child_stylebox = child_panel.get_theme_stylebox("panel")
		if child_stylebox is StyleBoxFlat:
			var shadow_color = Color(color.r, color.g, color.b, 0.3 + pulse_factor)
			child_stylebox.shadow_color = shadow_color

func _get_rarity_color(rarity_type: String) -> Color:
	"""Retourne la couleur selon la rareté"""
	match rarity_type:
		"common": return Color(0.8, 0.8, 0.8, 1)
		"uncommon": return Color(0.2, 0.6, 1, 1)
		"rare": return Color(1, 0.8, 0, 1)
		"legendary": return Color(1, 0.4, 0, 1)
		"unique": return Color(0.8, 0, 0, 1)
		_: return Color.WHITE

func _on_hover_start():
	if is_hovered:
		return
	
	is_hovered = true
	_animate_hover(true)

func _on_hover_end():
	if not is_hovered:
		return
	
	is_hovered = false
	_animate_hover(false)

func _animate_hover(entering: bool):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	if entering:
		# HOVER: Décaler le parent (self) à droite
		tween.tween_property(self, "position:x", original_position.x + horizontal_offset, animation_duration)
		
		# Animer le PanelContainer enfant si activé
		if animate_child and child_panel:
			tween.tween_property(child_panel, "rotation_degrees", child_rotation, animation_duration)
			tween.tween_property(child_panel, "scale", Vector2(child_scale, child_scale), animation_duration)
	else:
		# NORMAL: Retour à la position d'origine
		tween.tween_property(self, "position:x", original_position.x, animation_duration)
		
		# Réinitialiser le PanelContainer enfant
		if animate_child and child_panel:
			tween.tween_property(child_panel, "rotation_degrees", 0.0, animation_duration)
			tween.tween_property(child_panel, "scale", Vector2.ONE, animation_duration)

func _notification(what: int):
	# Mettre à jour le pivot de l'enfant si la taille change
	if what == NOTIFICATION_RESIZED and child_panel:
		child_panel.pivot_offset = child_panel.size / 2
