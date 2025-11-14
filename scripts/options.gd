extends Control

func _on_back_pressed() -> void:
	get_tree().paused = false
	queue_free()

func _on_exit_pressed() -> void:
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("pause"):
		_on_back_pressed()
