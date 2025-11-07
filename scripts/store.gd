extends Control

@onready var piece_scene: PackedScene = preload("res://scenes/piece.tscn")
@onready var passive_scene: PackedScene = preload("res://scenes/passive.tscn")
@export var piece_origins: Array[PieceData]
@export var passive_origins: Array[PassiveData]
@onready var inventory: Control = $"../inventory"
@onready var piece_zone: HBoxContainer = $VBoxContainer/piece_zone
@onready var passive_zone: HBoxContainer = $VBoxContainer/passive_zone
@onready var reroll_button: TextureButton = $VBoxContainer/HBoxContainer/Reroll
@onready var game = get_parent()


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
			button.set_meta("data", origin_data)
			target_zone.add_child(button)
			button.pressed.connect(_on_button_pressed.bind(button))

		origin_instance.queue_free()


func _on_button_pressed(button: TextureButton) -> void:
	var data = button.get_meta("data")
	if data == null:
		return

	var price: int = 0
	if "price" in data:
		price = data.price
	# Verificar si el jugador tiene suficiente oro
	if not game.has_enough_currency(price):
		print("No tienes suficiente oro para comprar %s. Precio: %d" % [data.resource_name, price])
		return

	# Verificar si el inventario puede aceptar el ítem
	if not inventory.can_add_item(data):
		print("Inventario lleno, no se puede comprar")
		return

	# Gastar el oro y añadir al inventario
	if game.spend_currency(price):
		inventory.add_item(data)
		button.disabled = true
		button.modulate = Color(0.25, 0.25, 0.25, 1.0)
		print("Compraste %s por %d oro." % [data.resource_name, price])
	else:
		print("Error: No se pudo gastar el oro (verifica el saldo o lógica).")
