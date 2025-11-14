extends CanvasLayer
var options_scene = preload("res://scenes/options.tscn")

func _process(delta):
	if Input.is_action_just_pressed("pause"):
		_on_resume_pressed()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	queue_free()
func _on_options_pressed() -> void:
	var options_instance = options_scene.instantiate()

	add_child(options_instance)
	
	get_tree().paused = true

func _on_quit_pressed() -> void:
	get_tree().quit()
