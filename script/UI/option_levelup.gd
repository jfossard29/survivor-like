extends PanelContainer

@onready var image_panel: PanelContainer = $Node2D/PanelImage
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var scan_anim_player: AnimationPlayer = $ScanAnimationPlayer
@onready var titre: Label = $MarginContainer/Titre
@onready var description: Label = $MarginContainer/Description
@onready var scan_bar: Panel = $Node2D2/ScanBar

var titre_valeur: String = ""
var description_valeur: String = ""

@export_group("Rarity")
@export_enum("common", "uncommon", "rare", "legendary", "unique")
var rarity: String = "common":
	set(value):
		rarity = value
		if is_inside_tree() and titre != null:
			call_deferred("_apply_rarity_style")

@export var shadow_pulse_intensity: float = 0.3
@export var shadow_pulse_speed: float = 2.0

@export_group("Scan Effect")
@export var scan_enabled: bool = true
@export var scan_width: float = 80.0
@export var scan_min_x: float = 20.0
@export var scan_max_x: float = 420.0
@export var scan_speed: float = 150.0
@export var scan_change_interval: float = 1.5

var is_hovered := false
var pulse_time := 0.0

# Variables pour le scan
var scan_target_x: float = 0.0
var scan_change_timer: float = 0.0
var scan_velocity: float = 0.0

# Variables pour les transitions smooth
var hover_transition_speed: float = 8.0
var current_scale: float = 1.0
var target_scale: float = 1.0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	
	_refresh_node_references()
	_setup_scan_bar()
	call_deferred("_apply_rarity_style")

func _refresh_node_references():
	image_panel = get_node_or_null("Node2D/PanelImage")
	anim_player = get_node_or_null("AnimationPlayer")
	scan_anim_player = get_node_or_null("ScanAnimationPlayer")
	titre = get_node_or_null("MarginContainer/Titre")
	description = get_node_or_null("MarginContainer/Description")
	scan_bar = get_node_or_null("Node2D2/ScanBar")

func _setup_scan_bar():
	if scan_bar and scan_enabled:
		scan_bar.visible = false
		scan_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scan_bar.z_index = 10
		scan_bar.modulate.a = 0.0
		
		# Appliquer la couleur au Panel via StyleBox
		var scan_stylebox = scan_bar.get_theme_stylebox("panel")
		if scan_stylebox:
			scan_stylebox = scan_stylebox.duplicate()
			if scan_stylebox is StyleBoxFlat:
				var scan_color = _get_scan_color_for_rarity()
				scan_stylebox.bg_color = scan_color
			scan_bar.add_theme_stylebox_override("panel", scan_stylebox)
		
		# Position initiale aléatoire
		scan_bar.position.x = randf_range(scan_min_x, scan_max_x)
		_pick_new_scan_target()

func configure(new_titre: String, new_description: String, new_rarity: String):
	titre_valeur = new_titre
	description_valeur = new_description
	rarity = new_rarity
	
	if is_inside_tree():
		_apply_rarity_style()
		if scan_bar:
			var scan_stylebox = scan_bar.get_theme_stylebox("panel")
			if scan_stylebox:
				scan_stylebox = scan_stylebox.duplicate()
				if scan_stylebox is StyleBoxFlat:
					var scan_color = _get_scan_color_for_rarity()
					scan_stylebox.bg_color = scan_color
				scan_bar.add_theme_stylebox_override("panel", scan_stylebox)

func _process(delta):
	pulse_time += delta * shadow_pulse_speed
	_update_shadow_pulse()
	_update_hover_transition(delta)
	
	# Mise à jour du scan si hover
	if is_hovered and scan_bar and scan_enabled:
		_update_scan_movement(delta)

func _update_hover_transition(delta):
	# Transition smooth du scale
	current_scale = lerp(current_scale, target_scale, hover_transition_speed * delta)
	scale = Vector2(current_scale, current_scale)

func _update_scan_movement(delta):
	# Timer pour changer de cible
	scan_change_timer -= delta
	if scan_change_timer <= 0:
		_pick_new_scan_target()
		scan_change_timer = scan_change_interval
	
	# Déplacement vers la cible avec lerp pour un mouvement smooth
	var current_x = scan_bar.position.x
	var direction = sign(scan_target_x - current_x)
	
	# Mouvement avec vitesse variable (plus lent près de la cible)
	var distance = abs(scan_target_x - current_x)
	var speed_factor = clamp(distance / 100.0, 0.3, 1.0)
	
	scan_bar.position.x = lerp(current_x, scan_target_x, delta * 3.0 * speed_factor)
	
	# Fade in/out progressif du scan
	if scan_bar.visible:
		scan_bar.modulate.a = lerp(scan_bar.modulate.a, 1.0, delta * 5.0)

func _pick_new_scan_target():
	# Choisir une nouvelle position aléatoire
	scan_target_x = randf_range(scan_min_x, scan_max_x)

func _apply_rarity_style():
	if not titre or not description:
		_refresh_node_references()
		if not titre or not description:
			return
	
	var color = _get_rarity_color(rarity)
	var parent_stylebox = get_theme_stylebox("panel").duplicate()
	if parent_stylebox is StyleBoxFlat:
		parent_stylebox.border_color = color
		parent_stylebox.shadow_size = 8
		parent_stylebox.shadow_color = Color(color.r, color.g, color.b, 0.5)
	add_theme_stylebox_override("panel", parent_stylebox)
	
	if image_panel:
		var child_stylebox = image_panel.get_theme_stylebox("panel").duplicate()
		if child_stylebox is StyleBoxFlat:
			child_stylebox.border_color = color
			child_stylebox.shadow_size = 6
			child_stylebox.shadow_color = Color(color.r, color.g, color.b, 0.5)
		image_panel.add_theme_stylebox_override("panel", child_stylebox)
	
	if titre:
		var font_title := titre.label_settings.duplicate() if titre.label_settings else LabelSettings.new()
		font_title.outline_color = Color(color.r, color.g, color.b, 0.5)
		titre.label_settings = font_title
		titre.text = titre_valeur
	
	if description:
		description.text = description_valeur

func _update_shadow_pulse():
	if not image_panel:
		return
		
	var pulse_factor = (sin(pulse_time) * 0.5 + 0.5) * shadow_pulse_intensity
	var color = _get_rarity_color(rarity)
	
	var parent_stylebox = get_theme_stylebox("panel")
	if parent_stylebox is StyleBoxFlat:
		parent_stylebox.shadow_color = Color(color.r, color.g, color.b, 0.3 + pulse_factor)
	
	if image_panel:
		var child_stylebox = image_panel.get_theme_stylebox("panel")
		if child_stylebox is StyleBoxFlat:
			child_stylebox.shadow_color = Color(color.r, color.g, color.b, 0.3 + pulse_factor)

func _get_rarity_color(rarity_type: String) -> Color:
	match rarity_type:
		"common": return Color(0.8, 0.8, 0.8, 1)
		"uncommon": return Color(0.2, 0.6, 1, 1)
		"rare": return Color(1, 0.8, 0, 1)
		"legendary": return Color(1, 0.4, 0, 1)
		"unique": return Color(0.8, 0, 0, 1)
		_: return Color.WHITE

func _get_scan_color_for_rarity() -> Color:
	var base_color = _get_rarity_color(rarity)
	return Color(base_color.r, base_color.g, base_color.b, 0.5)

func _on_hover_start():
	if is_hovered:
		return
	is_hovered = true
	shadow_pulse_speed = 10.0
	shadow_pulse_intensity = 1.0
	target_scale = 1.05
	
	# Activer la barre de scan
	if scan_bar and scan_enabled:
		scan_bar.visible = true
		# Appliquer la couleur
		var scan_stylebox = scan_bar.get_theme_stylebox("panel")
		if scan_stylebox:
			scan_stylebox = scan_stylebox.duplicate()
			if scan_stylebox is StyleBoxFlat:
				var scan_color = _get_scan_color_for_rarity()
				scan_stylebox.bg_color = scan_color
			scan_bar.add_theme_stylebox_override("panel", scan_stylebox)
		
		scan_bar.modulate.a = 0.0
		_pick_new_scan_target()
		scan_change_timer = scan_change_interval
	
	# Animation de hover
	if anim_player and anim_player.has_animation("hover_enter"):
		if anim_player.is_playing():
			anim_player.stop(false)
		anim_player.play("hover_enter")

func _on_hover_end():
	if not is_hovered:
		return
	is_hovered = false
	shadow_pulse_speed = 2.0
	shadow_pulse_intensity = 0.3
	target_scale = 1.0
	
	# Fade out du scan
	if scan_bar:
		var tween = create_tween()
		tween.tween_property(scan_bar, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): scan_bar.visible = false)
	
	if anim_player and anim_player.has_animation("hover_exit"):
		if anim_player.is_playing():
			anim_player.stop(false)
		anim_player.play("hover_exit")
