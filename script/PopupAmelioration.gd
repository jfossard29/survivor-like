extends CanvasLayer

signal amelioration_choisie(name: String)

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/Label
@onready var container: VBoxContainer = $Panel/ChoixContainer

func _ready():
	hide()

func afficher(ameliorations: Array[Amelioration]):
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

	label.text = "Choisissez une amélioration :"
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

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
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
