extends Control

@onready var piece_scene: PackedScene = preload("res://scenes/piece.tscn")
@onready var passive_scene: PackedScene = preload("res://scenes/passive.tscn")

@export var piece_origins: Array[PieceData]
@export var passive_origins: Array[PassiveData]

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

	_generate_buttons(piece_origins, piece_zone, piece_scene)
	_generate_buttons(passive_origins, passive_zone, passive_scene)


func _generate_buttons(origin_array: Array, target_zone: HBoxContainer, base_scene: PackedScene) -> void:
	if origin_array.is_empty():
		return

	var shuffled = origin_array.duplicate()
	shuffled.shuffle()
	var selected = shuffled.slice(0, min(3, shuffled.size()))

	for origin_data in selected:
		var origin_instance = base_scene.instantiate()

		var texture_to_use: Texture2D = origin_data.icon
		if texture_to_use == null:
			var sprite_node = origin_instance.find_child("Sprite2D", true, false)
			if sprite_node:
				texture_to_use = sprite_node.texture

		if texture_to_use:
			var button = TextureButton.new()
			button.texture_normal = texture_to_use
			button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			target_zone.add_child(button)
			button.pressed.connect(_on_button_pressed.bind(button))

		origin_instance.queue_free()


func _on_button_pressed(button: TextureButton) -> void:
	button.disabled = true
	button.modulate = Color(0.25, 0.25, 0.25, 1.0)
