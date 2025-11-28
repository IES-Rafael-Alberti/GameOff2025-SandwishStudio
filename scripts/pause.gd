extends CanvasLayer

var options_scene := preload("res://scenes/options.tscn")
var options_instance: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		_on_resume_pressed()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	queue_free()

func _on_options_pressed() -> void:
	if is_instance_valid(options_instance):
		return

	options_instance = options_scene.instantiate()
	add_child(options_instance)
	options_instance.set_as_pause_menu(true)

func _on_quit_pressed() -> void:
	get_tree().quit()
