extends Control

# Configuration de l'opérateur
@export var operator_name: String = "GHOST RUNNER"
@export var operator_bio: String = "Agent infiltré spécialisé dans les opérations furtives en zone hostile. Maîtrise des systèmes cybernétiques avancés et expertise en combat rapproché."
@export var base_weapon: String = "PLASMA PISTOL"
@export var max_hp: int = 200
@export var xp_multiplier: float = 1.5
@export var damage_multiplier: float = 2.3
@export var harvest_range: float = 12.5
@export_enum("Insignificant", "Surveillance", "Classified") var threat_level: int = 2

# Couleurs cyberpunk
const COLOR_CYAN := Color(0.0, 0.83, 1.0)
const COLOR_MAGENTA := Color(1.0, 0.0, 1.0)
const COLOR_DARK_BG := Color(0.02, 0.02, 0.06, 0.95)
const COLOR_GREEN := Color(0.29, 0.87, 0.5)
const COLOR_YELLOW := Color(0.98, 0.75, 0.14)
const COLOR_RED := Color(0.94, 0.26, 0.26)

# Références aux nodes
@onready var scan_line: ColorRect = $ScanLine
@onready var operator_name_label: Label = $MainContainer/VBoxContainer/Header/MarginContainer/VBoxContainer/OperatorName
@onready var bio_label: Label = $MainContainer/VBoxContainer/Header/MarginContainer/VBoxContainer/Bio
@onready var weapon_value: Label = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/WeaponRow/MarginContainer/HBoxContainer/WeaponValue
@onready var hp_value: Label = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/HPRow/MarginContainer/HBoxContainer/HPBadge/MarginContainer/HPValue
@onready var xp_value: Label = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/XPRow/MarginContainer/HBoxContainer/XPBadge/MarginContainer/XPValue
@onready var dmg_value: Label = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/DMGRow/MarginContainer/HBoxContainer/DMGBadge/MarginContainer/DMGValue
@onready var harvest_progress: ProgressBar = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/HarvestRow/MarginContainer/HBoxContainer/HarvestProgress
@onready var harvest_label: Label = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/HarvestRow/MarginContainer/HBoxContainer/HarvestProgress/HarvestLabel
@onready var threat_label: Label = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/ThreatRow/MarginContainer/HBoxContainer/ThreatBadge/MarginContainer/ThreatLabel
@onready var main_container: PanelContainer = $MainContainer
@onready var header: PanelContainer = $MainContainer/VBoxContainer/Header
@onready var footer: PanelContainer = $MainContainer/VBoxContainer/Footer
@onready var hp_badge: PanelContainer = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/HPRow/MarginContainer/HBoxContainer/HPBadge
@onready var xp_badge: PanelContainer = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/XPRow/MarginContainer/HBoxContainer/XPBadge
@onready var dmg_badge: PanelContainer = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/DMGRow/MarginContainer/HBoxContainer/DMGBadge
@onready var threat_badge: PanelContainer = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/ThreatRow/MarginContainer/HBoxContainer/ThreatBadge

# Rows pour les bordures
@onready var weapon_row: PanelContainer = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/WeaponRow
@onready var hp_row: PanelContainer = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/HPRow
@onready var xp_row: PanelContainer = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/XPRow
@onready var dmg_row: PanelContainer = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/DMGRow
@onready var harvest_row: PanelContainer = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/HarvestRow
@onready var threat_row: PanelContainer = $MainContainer/VBoxContainer/StatsBody/VBoxContainer/ThreatRow

# Animation
var time := 0.0
var glow_intensity := 0.0
var scan_position := 0.0

func _ready():
	apply_styles()
	update_values()
	animate_harvest_bar()

func apply_styles():
	# Style du container principal
	var main_style := StyleBoxFlat.new()
	main_style.bg_color = COLOR_DARK_BG
	main_style.border_color = Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.6)
	main_style.border_width_left = 2
	main_style.border_width_right = 2
	main_style.border_width_top = 2
	main_style.border_width_bottom = 2
	main_style.shadow_color = Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.4)
	main_style.shadow_size = 20
	main_container.add_theme_stylebox_override("panel", main_style)
	
	# Style du header
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.1)
	header_style.border_color = Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.6)
	header_style.border_width_bottom = 2
	header.add_theme_stylebox_override("panel", header_style)
	
	# Style du footer
	var footer_style := StyleBoxFlat.new()
	footer_style.bg_color = Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.05)
	footer_style.border_color = Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.3)
	footer_style.border_width_top = 1
	footer.add_theme_stylebox_override("panel", footer_style)
	
	# Style des rows (bordures en bas)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color.TRANSPARENT
	row_style.border_color = Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.2)
	row_style.border_width_bottom = 1
	
	weapon_row.add_theme_stylebox_override("panel", row_style.duplicate())
	hp_row.add_theme_stylebox_override("panel", row_style.duplicate())
	xp_row.add_theme_stylebox_override("panel", row_style.duplicate())
	dmg_row.add_theme_stylebox_override("panel", row_style.duplicate())
	harvest_row.add_theme_stylebox_override("panel", row_style.duplicate())
	threat_row.add_theme_stylebox_override("panel", row_style.duplicate())
	
	# Style des badges
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(COLOR_MAGENTA.r, COLOR_MAGENTA.g, COLOR_MAGENTA.b, 0.2)
	badge_style.border_color = COLOR_MAGENTA
	badge_style.border_width_left = 1
	badge_style.border_width_right = 1
	badge_style.border_width_top = 1
	badge_style.border_width_bottom = 1
	
	hp_badge.add_theme_stylebox_override("panel", badge_style.duplicate())
	xp_badge.add_theme_stylebox_override("panel", badge_style.duplicate())
	dmg_badge.add_theme_stylebox_override("panel", badge_style.duplicate())
	
	# Style de la barre de progression (harvest)
	var harvest_bg := StyleBoxFlat.new()
	harvest_bg.bg_color = Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.1)
	harvest_bg.border_color = Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.4)
	harvest_bg.border_width_left = 1
	harvest_bg.border_width_right = 1
	harvest_bg.border_width_top = 1
	harvest_bg.border_width_bottom = 1
	harvest_progress.add_theme_stylebox_override("background", harvest_bg)
	
	var harvest_fill := StyleBoxFlat.new()
	harvest_fill.bg_color = COLOR_GREEN
	harvest_progress.add_theme_stylebox_override("fill", harvest_fill)
	
	# Style du badge de threat
	apply_threat_style()

func apply_threat_style():
	var threat_style := StyleBoxFlat.new()
	threat_style.bg_color = Color.TRANSPARENT
	
	var threat_color: Color
	var threat_text: String
	
	match threat_level:
		0: # Insignificant
			threat_color = COLOR_GREEN
			threat_text = "INSIGNIFIANT"
		1: # Surveillance
			threat_color = COLOR_YELLOW
			threat_text = "SURVEILLANCE"
		2: # Classified
			threat_color = COLOR_RED
			threat_text = "🔒 CONFIDENTIEL"
	
	threat_style.border_color = threat_color
	threat_style.border_width_left = 2
	threat_style.border_width_right = 2
	threat_style.border_width_top = 2
	threat_style.border_width_bottom = 2
	threat_badge.add_theme_stylebox_override("panel", threat_style)
	
	threat_label.text = threat_text
	threat_label.add_theme_color_override("font_color", threat_color)

func update_values():
	operator_name_label.text = operator_name
	bio_label.text = operator_bio
	weapon_value.text = base_weapon
	hp_value.text = "%d HP" % max_hp
	xp_value.text = "× %.1f" % xp_multiplier
	dmg_value.text = "× %.1f" % damage_multiplier
	harvest_label.text = "%.1fm" % harvest_range
	harvest_progress.max_value = 20.0
	harvest_progress.value = 0

func animate_harvest_bar():
	var tween := create_tween()
	tween.tween_property(harvest_progress, "value", harvest_range, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _process(delta: float):
	time += delta
	
	# Animation scan line
	scan_position += delta * 300
	if scan_position > get_viewport_rect().size.y + 100:
		scan_position = -100
	scan_line.position.y = scan_position
	
	# Ajuster la largeur de la scan line à la fenêtre
	scan_line.size.x = get_viewport_rect().size.x
	
	# Pulse effect for classified threat level
	if threat_level == 2:
		glow_intensity = (sin(time * 3.0) + 1.0) / 2.0
		var pulse_color = COLOR_RED.lerp(Color.WHITE, glow_intensity * 0.3)
		threat_label.add_theme_color_override("font_color", pulse_color)
