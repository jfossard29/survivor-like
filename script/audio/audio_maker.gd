extends CanvasLayer

## Éditeur de beats interactif avec sélection de musiques
## Place ce script sur un CanvasLayer dans ta scène

@export var music_folder_path: String = "res://sounds/"
@export_file("*.json") var beats_json_path: String = "res://sounds/musique_beats.json"
@export var show_on_start: bool = true

# Nodes UI
var panel: Panel
var audio_player: AudioStreamPlayer
var play_button: Button
var time_slider: HSlider
var time_label: Label
var bpm_label: Label
var beat_count_label: Label
var music_selector: OptionButton
var current_song_label: Label

# Timeline visuelle
var timeline_container: Control
var timeline_canvas: Control
var timeline_scroll: ScrollContainer
var timeline_zoom: float = 50.0
var timeline_offset: float = 0.0
var playhead: ColorRect

# Boutons d'action
var tap_button: Button
var save_button: Button
var load_button: Button
var clear_button: Button
var zoom_in_button: Button
var zoom_out_button: Button

# Indicateur visuel
var beat_indicator: ColorRect

# État
var is_playing: bool = false
var beats: Array[float] = []
var current_beat_index: int = 0
var audio_duration: float = 0.0
var is_seeking: bool = false
var dragging_beat_index: int = -1
var selected_beat_index: int = -1
var hovered_beat_index: int = -1

# Musiques disponibles
var available_songs: Array[String] = []
var current_song_name: String = ""
var all_beats_data: Dictionary = {}  # Format: {"song_name": {"beats": [...], "bpm": 120}}

# Constantes
const BEAT_MARKER_WIDTH = 8
const BEAT_MARKER_HEIGHT = 40
const TIMELINE_HEIGHT = 80
const MIN_ZOOM = 10.0
const MAX_ZOOM = 200.0

func _ready():
	if not show_on_start:
		visible = false
		return
	
	_scan_music_folder()
	_build_ui()
	_setup_audio()
	_load_all_beats_from_json()

func _scan_music_folder():
	var dir = DirAccess.open(music_folder_path)
	if not dir:
		push_error("Impossible d'ouvrir le dossier: %s" % music_folder_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".ogg"):
			available_songs.append(file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	available_songs.sort()
	
	print("🎵 %d musiques trouvées" % available_songs.size())

func _build_ui():
	# Panel principal
	panel = Panel.new()
	panel.position = Vector2(20, 20)
	panel.size = Vector2(1200, 650)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.position = Vector2(20, 20)
	main_vbox.size = Vector2(1160, 610)
	main_vbox.add_theme_constant_override("separation", 15)
	panel.add_child(main_vbox)
	
	# Titre
	var title = Label.new()
	title.text = "🎵 Beat Editor - Multi-Musiques"
	title.add_theme_font_size_override("font_size", 28)
	main_vbox.add_child(title)
	
	# Sélecteur de musique
	var selector_hbox = HBoxContainer.new()
	selector_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(selector_hbox)
	
	var selector_label = Label.new()
	selector_label.text = "Musique:"
	selector_label.add_theme_font_size_override("font_size", 16)
	selector_hbox.add_child(selector_label)
	
	music_selector = OptionButton.new()
	music_selector.custom_minimum_size = Vector2(400, 40)
	music_selector.add_theme_font_size_override("font_size", 14)
	
	for song in available_songs:
		music_selector.add_item(song)
	
	if available_songs.size() > 0:
		music_selector.select(0)
	
	music_selector.item_selected.connect(_on_music_selected)
	selector_hbox.add_child(music_selector)
	
	current_song_label = Label.new()
	current_song_label.text = ""
	current_song_label.add_theme_font_size_override("font_size", 14)
	current_song_label.modulate = Color(0.7, 0.7, 1.0)
	selector_hbox.add_child(current_song_label)
	
	# Indicateur visuel + Infos
	var indicator_row = HBoxContainer.new()
	indicator_row.add_theme_constant_override("separation", 20)
	main_vbox.add_child(indicator_row)
	
	beat_indicator = ColorRect.new()
	beat_indicator.custom_minimum_size = Vector2(60, 60)
	beat_indicator.color = Color.DARK_GRAY
	indicator_row.add_child(beat_indicator)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 5)
	indicator_row.add_child(info_vbox)
	
	time_label = Label.new()
	time_label.text = "Temps: 0:00.0 / 0:00.0"
	time_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(time_label)
	
	beat_count_label = Label.new()
	beat_count_label.text = "Beats: 0"
	beat_count_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(beat_count_label)
	
	bpm_label = Label.new()
	bpm_label.text = "BPM: --"
	bpm_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(bpm_label)
	
	# Contrôles audio
	var controls_hbox = HBoxContainer.new()
	controls_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(controls_hbox)
	
	play_button = Button.new()
	play_button.text = "▶ Play"
	play_button.custom_minimum_size = Vector2(100, 50)
	play_button.add_theme_font_size_override("font_size", 20)
	play_button.pressed.connect(_toggle_playback)
	controls_hbox.add_child(play_button)
	
	var slider_vbox = VBoxContainer.new()
	slider_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_hbox.add_child(slider_vbox)
	
	var slider_label = Label.new()
	slider_label.text = "Position Audio"
	slider_label.add_theme_font_size_override("font_size", 14)
	slider_vbox.add_child(slider_label)
	
	time_slider = HSlider.new()
	time_slider.min_value = 0
	time_slider.max_value = 100
	time_slider.step = 0.01
	time_slider.custom_minimum_size.y = 30
	time_slider.drag_started.connect(_on_slider_drag_start)
	time_slider.drag_ended.connect(_on_slider_drag_end)
	slider_vbox.add_child(time_slider)
	
	# Timeline visuelle
	var timeline_label = Label.new()
	timeline_label.text = "Timeline (cliquez pour ajouter/modifier des beats):"
	timeline_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(timeline_label)
	
	_build_timeline(main_vbox)
	
	# Boutons d'action
	var actions_hbox = HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(actions_hbox)
	
	tap_button = Button.new()
	tap_button.text = "🥁 TAP (Espace)"
	tap_button.custom_minimum_size = Vector2(150, 50)
	tap_button.add_theme_font_size_override("font_size", 16)
	tap_button.pressed.connect(_on_tap_beat)
	actions_hbox.add_child(tap_button)
	
	zoom_in_button = Button.new()
	zoom_in_button.text = "🔍+"
	zoom_in_button.custom_minimum_size = Vector2(60, 50)
	zoom_in_button.pressed.connect(func(): _change_zoom(1.5))
	actions_hbox.add_child(zoom_in_button)
	
	zoom_out_button = Button.new()
	zoom_out_button.text = "🔍-"
	zoom_out_button.custom_minimum_size = Vector2(60, 50)
	zoom_out_button.pressed.connect(func(): _change_zoom(0.667))
	actions_hbox.add_child(zoom_out_button)
	
	save_button = Button.new()
	save_button.text = "💾 Sauvegarder Tout"
	save_button.custom_minimum_size = Vector2(150, 50)
	save_button.add_theme_font_size_override("font_size", 14)
	save_button.pressed.connect(_save_all_beats)
	actions_hbox.add_child(save_button)
	
	load_button = Button.new()
	load_button.text = "📂 Recharger"
	load_button.custom_minimum_size = Vector2(120, 50)
	load_button.add_theme_font_size_override("font_size", 14)
	load_button.pressed.connect(_load_all_beats_from_json)
	actions_hbox.add_child(load_button)
	
	clear_button = Button.new()
	clear_button.text = "🗑️ Effacer"
	clear_button.custom_minimum_size = Vector2(110, 50)
	clear_button.add_theme_font_size_override("font_size", 14)
	clear_button.pressed.connect(_clear_beats)
	actions_hbox.add_child(clear_button)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "💡 Clic: ajouter beat | Clic sur beat: sélectionner | Glisser: déplacer | Clic droit/Suppr: effacer | F3: masquer"
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.modulate = Color(0.7, 0.7, 0.7)
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(instructions)

func _build_timeline(parent: VBoxContainer):
	var timeline_panel = Panel.new()
	var timeline_style = StyleBoxFlat.new()
	timeline_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	timeline_style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	timeline_style.border_width_left = 2
	timeline_style.border_width_right = 2
	timeline_style.border_width_top = 2
	timeline_style.border_width_bottom = 2
	timeline_panel.add_theme_stylebox_override("panel", timeline_style)
	timeline_panel.custom_minimum_size.y = TIMELINE_HEIGHT + 20
	parent.add_child(timeline_panel)
	
	timeline_scroll = ScrollContainer.new()
	timeline_scroll.position = Vector2(10, 10)
	timeline_scroll.size = Vector2(1140, TIMELINE_HEIGHT)
	timeline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	timeline_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	timeline_panel.add_child(timeline_scroll)
	
	timeline_container = Control.new()
	timeline_container.custom_minimum_size = Vector2(1000, TIMELINE_HEIGHT)
	timeline_scroll.add_child(timeline_container)
	
	timeline_canvas = Control.new()
	timeline_canvas.custom_minimum_size = Vector2(1000, TIMELINE_HEIGHT)
	timeline_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	timeline_canvas.draw.connect(_draw_timeline)
	timeline_canvas.gui_input.connect(_on_timeline_input)
	timeline_container.add_child(timeline_canvas)
	
	playhead = ColorRect.new()
	playhead.color = Color(1.0, 0.3, 0.3, 0.8)
	playhead.custom_minimum_size = Vector2(2, TIMELINE_HEIGHT)
	playhead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timeline_container.add_child(playhead)

func _on_music_selected(index: int):
	if index < 0 or index >= available_songs.size():
		return
	
	# Sauvegarder les beats actuels avant de changer
	if not current_song_name.is_empty():
		_save_current_song_beats()
	
	# Charger la nouvelle musique
	var song_name = available_songs[index]
	_load_song(song_name)

func _load_song(song_name: String):
	current_song_name = song_name
	var audio_path = music_folder_path.path_join(song_name)
	
	var audio_stream = load(audio_path)
	if not audio_stream:
		push_error("Impossible de charger: %s" % audio_path)
		return
	
	# Arrêter la lecture en cours
	if is_playing:
		_toggle_playback()
	
	audio_player.stream = audio_stream
	audio_duration = audio_stream.get_length()
	time_slider.max_value = audio_duration
	time_slider.value = 0
	
	# Charger les beats de cette musique
	if all_beats_data.has(song_name):
		var song_data = all_beats_data[song_name]
		beats = song_data.get("beats", []).duplicate()
	else:
		beats.clear()
	
	current_beat_index = 0
	selected_beat_index = -1
	
	_update_timeline_size()
	_update_display()
	timeline_canvas.queue_redraw()
	
	current_song_label.text = "✓ Chargé (%d beats)" % beats.size()
	
	print("✅ Musique chargée: %s (%.2fs, %d beats)" % [song_name, audio_duration, beats.size()])

func _setup_audio():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	# Charger la première musique si disponible
	if available_songs.size() > 0:
		_load_song(available_songs[0])

func _save_current_song_beats():
	if current_song_name.is_empty():
		return
	
	var intervals: Array[float] = []
	for i in range(1, beats.size()):
		var interval = beats[i] - beats[i - 1]
		intervals.append(snapped(interval, 0.001))  # 3 décimales
	
	var avg_bpm = 0
	if intervals.size() > 0:
		var avg_interval = intervals.reduce(func(a, b): return a + b, 0.0) / intervals.size()
		avg_bpm = int(60.0 / avg_interval)
	
	all_beats_data[current_song_name] = {
		"bpm": avg_bpm,
		"beat_count": beats.size(),
		"duration": snapped(beats[-1] if beats.size() > 0 else 0.0, 0.001),
		"first_beat_offset": snapped(beats[0] if beats.size() > 0 else 0.0, 0.001),
		"intervals": intervals,
		"beats": beats.duplicate()
	}

func _load_all_beats_from_json():
	if beats_json_path.is_empty():
		print("⚠️ Aucun fichier JSON spécifié")
		return
	
	var file = FileAccess.open(beats_json_path, FileAccess.READ)
	if not file:
		print("⚠️ Fichier JSON introuvable, création d'un nouveau: %s" % beats_json_path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("Erreur JSON: %s" % json.get_error_message())
		return
	
	var data = json.data
	all_beats_data.clear()
	
	# Le JSON doit être un tableau d'objets avec des IDs
	if data is Array:
		for song_data in data:
			if not song_data is Dictionary:
				continue
			
			var song_id = song_data.get("id", "")
			if song_id.is_empty():
				continue
			
			# Reconstruire les beats depuis les intervalles
			var song_beats: Array[float] = []
			if song_data.has("intervals"):
				var first_beat = song_data.get("first_beat_offset", 0.0)
				song_beats.append(first_beat)
				
				var current_time = first_beat
				for interval in song_data.intervals:
					current_time += float(interval)
					song_beats.append(current_time)
			
			all_beats_data[song_id] = {
				"bpm": song_data.get("bpm", 0),
				"beat_count": song_data.get("beat_count", 0),
				"duration": song_data.get("duration", 0.0),
				"first_beat_offset": song_data.get("first_beat_offset", 0.0),
				"intervals": song_data.get("intervals", []),
				"beats": song_beats
			}
		
		print("✅ %d musiques chargées depuis JSON" % all_beats_data.size())
	
	# Recharger la musique actuelle si elle existe
	if not current_song_name.is_empty() and all_beats_data.has(current_song_name):
		beats = all_beats_data[current_song_name]["beats"].duplicate()
		_update_display()
		timeline_canvas.queue_redraw()

func _save_all_beats():
	# Sauvegarder les beats de la musique actuelle
	if not current_song_name.is_empty():
		_save_current_song_beats()
	
	if all_beats_data.is_empty():
		print("⚠️ Aucune donnée à sauvegarder")
		return
	
	var json_array: Array = []
	
	for song_name in all_beats_data.keys():
		var song_data = all_beats_data[song_name]
		
		json_array.append({
			"id": song_name,
			"song_name": song_name,
			"bpm": song_data.get("bpm", 0),
			"beat_count": song_data.get("beat_count", 0),
			"duration": song_data.get("duration", 0.0),
			"first_beat_offset": song_data.get("first_beat_offset", 0.0),
			"intervals": song_data.get("intervals", [])
		})
	
	var json_string = JSON.stringify(json_array, "\t")
	
	var file = FileAccess.open(beats_json_path, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()
		print("✅ Toutes les musiques sauvegardées: %s" % ProjectSettings.globalize_path(beats_json_path))
		print("📊 %d musiques enregistrées" % json_array.size())
		
		DisplayServer.clipboard_set(json_string)
		print("📋 JSON copié dans le presse-papier")
	else:
		push_error("❌ Erreur lors de la sauvegarde")

func _update_timeline_size():
	if audio_duration > 0:
		var total_width = audio_duration * timeline_zoom
		timeline_canvas.custom_minimum_size.x = max(total_width, 1000)
		timeline_container.custom_minimum_size.x = timeline_canvas.custom_minimum_size.x

func _change_zoom(factor: float):
	timeline_zoom = clamp(timeline_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	_update_timeline_size()
	timeline_canvas.queue_redraw()
	print("🔍 Zoom: %.1f px/s" % timeline_zoom)

func _draw_timeline():
	if not timeline_canvas:
		return
	
	var canvas = timeline_canvas
	var width = canvas.size.x
	var height = TIMELINE_HEIGHT
	
	canvas.draw_rect(Rect2(0, 0, width, height), Color(0.2, 0.2, 0.25, 1.0))
	
	var interval = 1.0
	if timeline_zoom < 30:
		interval = 5.0
	elif timeline_zoom > 100:
		interval = 0.5
	
	var current_time = 0.0
	while current_time <= audio_duration:
		var x = current_time * timeline_zoom
		var is_major = int(current_time) % 5 == 0
		var line_height = height if is_major else height * 0.5
		var color = Color(0.4, 0.4, 0.5, 1.0) if is_major else Color(0.3, 0.3, 0.35, 0.5)
		
		canvas.draw_line(Vector2(x, height - line_height), Vector2(x, height), color, 1.0)
		
		if is_major:
			canvas.draw_string(ThemeDB.fallback_font, Vector2(x + 3, 15), 
				"%d:%02d" % [int(current_time / 60), int(current_time) % 60], 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.6, 0.7))
		
		current_time += interval
	
	for i in range(beats.size()):
		var beat_time = beats[i]
		var x = beat_time * timeline_zoom
		
		var color = Color.CYAN
		if i == selected_beat_index:
			color = Color.GREEN
		elif i == hovered_beat_index:
			color = Color.YELLOW
		elif i == dragging_beat_index:
			color = Color.ORANGE
		
		var triangle_height = BEAT_MARKER_HEIGHT
		var half_width = BEAT_MARKER_WIDTH / 2.0
		
		var points = PackedVector2Array([
			Vector2(x, 0),
			Vector2(x - half_width, triangle_height),
			Vector2(x + half_width, triangle_height)
		])
		canvas.draw_colored_polygon(points, color)
		
		canvas.draw_line(Vector2(x, triangle_height), Vector2(x, height), color, 2.0)
		
		canvas.draw_string(ThemeDB.fallback_font, Vector2(x - 8, triangle_height + 15), 
			str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func _on_timeline_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var click_x = event.position.x
				var click_time = click_x / timeline_zoom
				
				var clicked_beat = _find_beat_at_position(click_time)
				
				if clicked_beat >= 0:
					selected_beat_index = clicked_beat
					dragging_beat_index = clicked_beat
					print("✓ Beat #%d sélectionné" % (clicked_beat + 1))
				else:
					_add_beat_at_time(click_time)
				
				timeline_canvas.queue_redraw()
			else:
				if dragging_beat_index >= 0:
					beats.sort()
					_update_display()
				dragging_beat_index = -1
				timeline_canvas.queue_redraw()
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var click_x = event.position.x
			var click_time = click_x / timeline_zoom
			var clicked_beat = _find_beat_at_position(click_time)
			
			if clicked_beat >= 0:
				_delete_beat(clicked_beat)
	
	elif event is InputEventMouseMotion:
		var mouse_x = event.position.x
		var mouse_time = mouse_x / timeline_zoom
		
		var old_hovered = hovered_beat_index
		hovered_beat_index = _find_beat_at_position(mouse_time)
		
		if old_hovered != hovered_beat_index:
			timeline_canvas.queue_redraw()
		
		if dragging_beat_index >= 0:
			var new_time = clamp(mouse_time, 0.0, audio_duration)
			beats[dragging_beat_index] = new_time
			timeline_canvas.queue_redraw()

func _find_beat_at_position(time: float) -> int:
	var tolerance = 0.1
	
	for i in range(beats.size()):
		if abs(beats[i] - time) < tolerance:
			return i
	
	return -1

func _add_beat_at_time(time: float):
	var clamped_time = clamp(time, 0.0, audio_duration)
	
	for beat in beats:
		if abs(beat - clamped_time) < 0.05:
			print("⚠️ Beat trop proche d'un beat existant")
			return
	
	beats.append(clamped_time)
	beats.sort()
	
	beat_indicator.color = Color.GREEN
	
	print("➕ Beat ajouté à %.3fs" % clamped_time)
	_update_display()
	timeline_canvas.queue_redraw()

func _toggle_playback():
	if not audio_player or not audio_player.stream:
		print("⚠️ Aucun audio chargé")
		return
	
	is_playing = !is_playing
	
	if is_playing:
		audio_player.play(time_slider.value)
		play_button.text = "⏸ Pause"
	else:
		audio_player.stop()
		play_button.text = "▶ Play"

func _on_slider_drag_start():
	is_seeking = true
	if is_playing:
		audio_player.stream_paused = true

func _on_slider_drag_end(value_changed: bool):
	is_seeking = false
	
	if not audio_player or not audio_player.stream:
		return
	
	var target_pos = time_slider.value
	
	if is_playing:
		audio_player.stop()
		audio_player.play(target_pos)
		audio_player.stream_paused = false
	
	current_beat_index = 0
	for i in range(beats.size()):
		if beats[i] <= target_pos:
			current_beat_index = i + 1

func _on_tap_beat():
	if not audio_player or not audio_player.stream:
		return
	
	var current_time = audio_player.get_playback_position() if is_playing else time_slider.value
	_add_beat_at_time(current_time)

func _clear_beats():
	beats.clear()
	current_beat_index = 0
	selected_beat_index = -1
	print("🗑️ Tous les beats effacés pour: %s" % current_song_name)
	_update_display()
	timeline_canvas.queue_redraw()

func _delete_beat(index: int):
	if index < 0 or index >= beats.size():
		return
	
	var beat_time = beats[index]
	beats.remove_at(index)
	
	if selected_beat_index == index:
		selected_beat_index = -1
	elif selected_beat_index > index:
		selected_beat_index -= 1
	
	print("🗑️ Beat #%d supprimé (%.3fs)" % [index + 1, beat_time])
	_update_display()
	timeline_canvas.queue_redraw()

func _update_display():
	beat_count_label.text = "Beats: %d" % beats.size()
	
	if beats.size() >= 2:
		var intervals: Array[float] = []
		for i in range(1, beats.size()):
			intervals.append(beats[i] - beats[i - 1])
		
		var avg_interval = intervals.reduce(func(a, b): return a + b, 0.0) / intervals.size()
		var bpm = int(60.0 / avg_interval)
		bpm_label.text = "BPM: %d (moy)" % bpm
	else:
		bpm_label.text = "BPM: --"

func _process(delta: float):
	if not audio_player or not audio_player.stream:
		return
	
	# Mise à jour du temps
	if is_playing and not is_seeking:
		var pos = audio_player.get_playback_position()
		time_slider.set_value_no_signal(pos)
		
		# Mettre à jour la position du playhead
		playhead.position.x = pos * timeline_zoom
		
		# Auto-scroll pour suivre la lecture
		var scroll_pos = timeline_scroll.scroll_horizontal
		var visible_width = timeline_scroll.size.x
		var playhead_screen_pos = playhead.position.x - scroll_pos
		
		# Garder le playhead dans la zone visible (avec marge)
		if playhead_screen_pos > visible_width - 100:
			timeline_scroll.scroll_horizontal = playhead.position.x - visible_width + 100
		elif playhead_screen_pos < 100 and scroll_pos > 0:
			timeline_scroll.scroll_horizontal = max(0, playhead.position.x - 100)
		
		# Vérifier les beats
		if current_beat_index < beats.size() and pos >= beats[current_beat_index] - 0.02:
			beat_indicator.color = Color.YELLOW
			current_beat_index += 1
	else:
		# Mettre à jour le playhead même en pause
		playhead.position.x = time_slider.value * timeline_zoom
	
	var current_time = time_slider.value
	time_label.text = "Temps: %s / %s" % [_format_time(current_time), _format_time(audio_duration)]
	
	# Fade de l'indicateur
	if beat_indicator.color != Color.DARK_GRAY:
		beat_indicator.color = beat_indicator.color.lerp(Color.DARK_GRAY, delta * 5)

func _format_time(seconds: float) -> String:
	var mins = int(seconds / 60)
	var secs = int(seconds) % 60
	var millis = int((seconds - int(seconds)) * 10)
	return "%d:%02d.%d" % [mins, secs, millis]

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			_on_tap_beat()
		elif event.keycode == KEY_F3:
			visible = !visible
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			if selected_beat_index >= 0:
				_delete_beat(selected_beat_index)
