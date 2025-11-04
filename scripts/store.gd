extends Control

@export var piece_scene: PackedScene                 
@export var piece_origins: Array[PackedScene] 
@export var passive_origins: Array[PackedScene]        

@onready var piece_zone: HBoxContainer = $VBoxContainer/piece_zone
@onready var passive_zone: HBoxContainer = $VBoxContainer/passive_zone
@onready var reroll_button: TextureButton = $VBoxContainer/HBoxContainer/Reroll

func _ready() -> void:
	generate()

func generate():
	for child in piece_zone.get_children():
		child.queue_free()
	for child in passive_zone.get_children():
		child.queue_free()

	_generate_buttons(piece_origins, piece_zone)
	_generate_buttons(passive_origins, passive_zone)


func _generate_buttons(origin_array: Array[PackedScene], target_zone: HBoxContainer) -> void:
	if origin_array.is_empty():
		return

	var shuffled = origin_array.duplicate()
	shuffled.shuffle()
	var selected = shuffled.slice(0, min(3, shuffled.size()))

	for origin_scene in selected:
		var origin_instance = origin_scene.instantiate()
		var sprite_node = origin_instance.find_child("Sprite2D", true, false)

		if sprite_node and sprite_node.texture:
			var button = TextureButton.new()
			button.texture_normal = sprite_node.texture
			button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			target_zone.add_child(button)

			# Conectar la señal "pressed" para desactivar el botón
			button.pressed.connect(_on_button_pressed.bind(button))

		origin_instance.queue_free()


func _on_button_pressed(button: TextureButton) -> void:
	button.disabled = true  
	button.modulate = Color(0.25, 0.25, 0.25, 1.0)
