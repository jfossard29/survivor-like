extends CanvasLayer

@export var single_bar_margin: float = 70.0  # Marge de chaque côté pour un seul boss
@export var single_bar_height: float = 25.0  # Hauteur de base pour un seul boss
@export var single_font_size: int = 32  # Taille de police pour un seul boss
@export var bar_spacing: float = 20.0
@export var vertical_offset: float = 30.0  # Distance depuis le haut de l'écran

var boss_bars: Dictionary = {}  # boss_instance -> {container, bar, label}
var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size

func register_boss(boss: Node, max_health: int) -> void:
	if boss in boss_bars:
		return  # Déjà enregistré
	
	# Créer un container pour cette barre
	var container = Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	
	# Label avec le nom du boss
	var label = Label.new()
	label.text = "Sentinelle"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(label)
	
	# Créer la ProgressBar
	var bar = ProgressBar.new()
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	
	# Style de la barre
	var stylebox_bg = StyleBoxFlat.new()
	stylebox_bg.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	stylebox_bg.set_border_width_all(3)
	stylebox_bg.border_color = Color(0.8, 0.4, 0.2, 1.0)  # Bordure dorée
	stylebox_bg.corner_radius_top_left = 2
	stylebox_bg.corner_radius_top_right = 2
	stylebox_bg.corner_radius_bottom_left = 2
	stylebox_bg.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", stylebox_bg)
	
	var stylebox_fill = StyleBoxFlat.new()
	stylebox_fill.bg_color = Color(0.8, 0.2, 0.2)
	stylebox_fill.corner_radius_top_left = 5
	stylebox_fill.corner_radius_top_right = 5
	stylebox_fill.corner_radius_bottom_left = 5
	stylebox_fill.corner_radius_bottom_right = 5
	bar.add_theme_stylebox_override("fill", stylebox_fill)
	
	container.add_child(bar)
	
	# Enregistrer
	boss_bars[boss] = {
		"container": container,
		"bar": bar,
		"label": label
	}
	
	# Réorganiser toutes les barres
	_reorganize_all_bars()
	
	print("Boss enregistré dans l'UI: ", label.text)

func update_boss_health(boss: Node, current_health: int, max_health: int) -> void:
	if not boss in boss_bars:
		return
	
	var bar = boss_bars[boss]["bar"]
	var ratio = float(current_health) / float(max_health)
	
	# Animer la barre
	var tween = create_tween()
	tween.tween_property(bar, "value", ratio * 100.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Flash rouge
	var stylebox = bar.get_theme_stylebox("fill") as StyleBoxFlat
	if stylebox:
		var color_tween = create_tween()
		color_tween.tween_property(stylebox, "bg_color", Color(1, 0.4, 0.4), 0.1)
		color_tween.tween_property(stylebox, "bg_color", Color(0.8, 0.2, 0.2), 0.3)

func unregister_boss(boss: Node) -> void:
	if not boss in boss_bars:
		return
	
	var data = boss_bars[boss]
	data["container"].queue_free()
	boss_bars.erase(boss)
	
	# Réorganiser les barres restantes
	_reorganize_all_bars()

func _reorganize_all_bars() -> void:
	screen_size = get_viewport().get_visible_rect().size
	var boss_count = boss_bars.size()
	
	if boss_count == 0:
		return
	
	# Calculer le facteur de division
	var scale_factor = 1.0 / float(boss_count)
	
	# Calculer les dimensions basées sur le nombre de boss
	var bar_height = single_bar_height * scale_factor
	var font_size = max(12, int(single_font_size * scale_factor))  # Min 12px
	var label_height = font_size + 10
	
	if boss_count == 1:
		# Un seul boss : barre presque pleine largeur, centrée
		var bar_width = screen_size.x - (single_bar_margin * 2)
		var x_position = single_bar_margin
		
		for boss in boss_bars:
			var container = boss_bars[boss]["container"]
			var bar = boss_bars[boss]["bar"]
			var label = boss_bars[boss]["label"]
			
			# Mettre à jour le label
			label.text = "Esprit Tutélaire"
			label.add_theme_font_size_override("font_size", font_size)
			label.position = Vector2(0, 0)
			label.size = Vector2(bar_width, label_height)
			
			# Positionner la barre
			bar.position = Vector2(0, label_height + 5)
			bar.size = Vector2(bar_width, bar_height)
			
			# Positionner le container
			container.position = Vector2(x_position, vertical_offset)
			container.size = Vector2(bar_width, label_height + bar_height + 5)
			
			# Animation douce
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(container, "position", Vector2(x_position, vertical_offset), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(container, "size", Vector2(bar_width, label_height + bar_height + 5), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(bar, "size", Vector2(bar_width, bar_height), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(label, "size", Vector2(bar_width, label_height), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	else:
		# Plusieurs boss : diviser l'espace équitablement
		var total_spacing = bar_spacing * (boss_count - 1)
		var available_width = screen_size.x - (single_bar_margin * 2) - total_spacing
		var bar_width = available_width / boss_count
		
		var current_x = single_bar_margin
		var boss_index = 0
		
		for boss in boss_bars:
			var container = boss_bars[boss]["container"]
			var bar = boss_bars[boss]["bar"]
			var label = boss_bars[boss]["label"]
			
			# Mettre à jour le label
			label.text = "Esprit Tutélaire #" + str(boss_index + 1)
			label.add_theme_font_size_override("font_size", font_size)
			label.position = Vector2(0, 0)
			label.size = Vector2(bar_width, label_height)
			
			# Positionner la barre
			bar.position = Vector2(0, label_height + 5)
			bar.size = Vector2(bar_width, bar_height)
			
			# Positionner le container
			var target_pos = Vector2(current_x, vertical_offset)
			var target_size = Vector2(bar_width, label_height + bar_height + 5)
			
			container.position = target_pos
			container.size = target_size
			
			# Animation douce
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(container, "position", target_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(container, "size", target_size, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(bar, "size", Vector2(bar_width, bar_height), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(label, "size", Vector2(bar_width, label_height), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			
			current_x += bar_width + bar_spacing
			boss_index += 1

func _process(_delta: float) -> void:
	# Réagir aux changements de taille d'écran
	var new_size = get_viewport().get_visible_rect().size
	if new_size != screen_size:
		screen_size = new_size
		_reorganize_all_bars()
