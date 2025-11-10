extends PanelContainer

@onready var image_panel: PanelContainer = $MarginContainer/Node2D/PanelImage
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var titre: Label = $MarginContainer/MarginContainer/Titre
@onready var description: Label = $MarginContainer/MarginContainer/Description
@onready var animation : AnimationPlayer = $AnimationPlayer
var titre_valeur: String
var description_valeur: String

@export_group("Rarity")
@export_enum("common", "uncommon", "rare", "legendary", "unique")
var rarity: String = "common":
	set(value):
		rarity = value
		if is_inside_tree():
			_apply_rarity_style()

@export var shadow_pulse_intensity: float = 0.3
@export var shadow_pulse_speed: float = 2.0

var is_hovered := false
var pulse_time := 0.0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	call_deferred("_apply_rarity_style")

func _process(delta):
	pulse_time += delta * shadow_pulse_speed
	_update_shadow_pulse()

func _apply_rarity_style():
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
	description.text = description_valeur

func _update_shadow_pulse():
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

func _on_hover_start():
	if is_hovered or not anim_player:
		return
	is_hovered = true
	shadow_pulse_speed = 10.0
	shadow_pulse_intensity = 1.0
	anim_player.play("hover_enter")

func _on_hover_end():
	if not is_hovered or not anim_player:
		return
	is_hovered = false
	shadow_pulse_speed = 2.0
	shadow_pulse_intensity = 0.3
	anim_player.play("hover_exit")
