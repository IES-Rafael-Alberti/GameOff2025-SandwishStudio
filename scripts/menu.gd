extends Control

# Es una buena práctica cargar la escena de opciones una sola vez
# Así no tiene que leerla del disco cada vez que se pulsa el botón
var options_scene = preload("res://scenes/options.tscn")


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_options_pressed() -> void:
	var options_instance = options_scene.instantiate()

	add_child(options_instance)
	
	get_tree().paused = true


func _on_quit_pressed() -> void:
	get_tree().quit()
