extends Control

var options_scene: PackedScene = preload("res://scenes/options.tscn")
var options_instance: Control = null
var is_animating: bool = false

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_options_pressed() -> void:
	if is_animating:
		return

	if is_instance_valid(options_instance):
		is_animating = true
		options_instance.close_with_anim()
		return

	options_instance = options_scene.instantiate()

	add_child(options_instance)  # PRIMERO se añade al árbol

	# En el menú principal NO queremos que pause el juego
	if options_instance.has_method("set_as_pause_menu"):
		options_instance.set_as_pause_menu(false)

	options_instance.opened.connect(_on_options_opened)
	options_instance.closed.connect(_on_options_closed)

	is_animating = true

func _on_options_opened() -> void:
	is_animating = false

func _on_options_closed() -> void:
	is_animating = false
	options_instance = null
