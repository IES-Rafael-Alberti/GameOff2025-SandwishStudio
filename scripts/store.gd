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
var current_shop_styles: Array = []
@export var COLOR_NORMAL_BG = Color(0, 0, 0, 0.6) # Negro translúcido
@export var COLOR_UNAFFORD_BG = Color(1.0, 0, 0, 0.6) # Rojo translúcido
func _ready() -> void:
	pass

func generate():
	current_shop_styles.clear()
	_update_all_label_colors()
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
			
			var item_container = VBoxContainer.new()
			item_container.alignment = VBoxContainer.ALIGNMENT_CENTER

			if "price" in origin_data:
				var price: int = origin_data.price # Obtenemos el precio
				var price_label = Label.new()
				price_label.text = str(price) + "€"
				price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				
				var style_box = StyleBoxFlat.new()
				
				# --- LÓGICA DE COLOR INICIAL (MODIFICADO) ---
				if game.has_enough_currency(price):
					style_box.bg_color = COLOR_NORMAL_BG
				else:
					style_box.bg_color = COLOR_UNAFFORD_BG
				# --- FIN LÓGICA DE COLOR ---

				style_box.content_margin_left = 6
				style_box.content_margin_right = 6
				style_box.content_margin_top = 2
				style_box.content_margin_bottom = 2
				style_box.corner_radius_top_left = 4
				style_box.corner_radius_top_right = 4
				style_box.corner_radius_bottom_left = 4
				style_box.corner_radius_bottom_right = 4
				
				price_label.add_theme_stylebox_override("normal", style_box)
				
				item_container.add_child(price_label)
				
				# --- NUEVA LÍNEA ---
				# Guardamos el estilo y su precio para actualizarlo después
				current_shop_styles.append({"style": style_box, "price": price})

			var button = TextureButton.new()
			button.texture_normal = texture_to_use
			button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			button.set_meta("data", origin_data)
			
			button.pressed.connect(_on_button_pressed.bind(button))
			
			item_container.add_child(button)

			target_zone.add_child(item_container)

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
		_update_all_label_colors()
		inventory.add_item(data)
		button.disabled = true
		button.modulate = Color(0.25, 0.25, 0.25, 1.0)
		print("Compraste %s por %d oro." % [data.resource_name, price])
	else:
		print("Error: No se pudo gastar el oro (verifica el saldo o lógica).")
func _update_all_label_colors() -> void:
	print("Actualizando colores de la tienda...")
	for item in current_shop_styles:
		var style_box: StyleBoxFlat = item.style
		var price: int = item.price
		
		if game.has_enough_currency(price):
			style_box.bg_color = COLOR_NORMAL_BG
		else:
			style_box.bg_color = COLOR_UNAFFORD_BG
