extends Control

@onready var piece_scene: PackedScene = preload("res://scenes/piece.tscn")
@onready var passive_scene: PackedScene = preload("res://scenes/passive.tscn")

@export_group("Configuración de Items")
@export var piece_origins: Array[PieceData]
@export var passive_origins: Array[PassiveData]
@export var max_copies: int = 3 # Límite para dejar de salir en tienda

@export_group("Economía")
@export_range(0.0, 2.0) var duplicate_piece_mult: float = 0.5 # 50% extra para Piezas
@export_range(0.0, 2.0) var duplicate_passive_mult: float = 0.5 # 50% extra para Pasivas
@export var COLOR_NORMAL_BG = Color(0, 0, 0, 0.6) 
@export var COLOR_UNAFFORD_BG = Color(1.0, 0, 0, 0.6) 

@onready var inventory: Control = $"../inventory"
@onready var piece_zone: HBoxContainer = $VBoxContainer/piece_zone
@onready var passive_zone: HBoxContainer = $VBoxContainer/passive_zone
@onready var reroll_button: TextureButton = $VBoxContainer/HBoxContainer/Reroll

var current_shop_styles: Array = []


func _ready() -> void:
	PlayerData.currency_changed.connect(_update_all_label_colors)


func generate():
	current_shop_styles.clear()
	
	for child in piece_zone.get_children():
		child.queue_free()
	for child in passive_zone.get_children():
		child.queue_free()

	# --- PASO 1: Filtrar items que ya tienen max_copies ---
	var available_pieces = _filter_maxed_items(piece_origins)
	var available_passives = _filter_maxed_items(passive_origins)

	# --- PASO 2: Generar solo con los disponibles ---
	_generate_buttons(available_pieces, piece_zone, piece_scene)
	_generate_buttons(available_passives, passive_zone, passive_scene)
	
	_update_all_label_colors()


# Nueva función auxiliar para filtrar la pool
func _filter_maxed_items(candidates: Array) -> Array:
	var available = []
	for item in candidates:
		if item is PieceData:
			var count = _get_item_count_safe(item)
			if count < max_copies:
				available.append(item)
		else:
			available.append(item)
			
	return available


func _generate_buttons(origin_array: Array, target_zone: HBoxContainer, base_scene: PackedScene) -> void:
	if origin_array.is_empty():
		# Opcional: Mostrar mensaje de "Agotado" si no queda nada
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
				var final_price: int = _calculate_price(origin_data)
				
				var price_label = Label.new()
				price_label.text = str(final_price) + "€"
				price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				
				var style_box = StyleBoxFlat.new()
				
				if PlayerData.has_enough_currency(final_price):
					style_box.bg_color = COLOR_NORMAL_BG
				else:
					style_box.bg_color = COLOR_UNAFFORD_BG

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
				
				current_shop_styles.append({
					"style": style_box, 
					"data": origin_data, 
					"label": price_label
				})

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
		price = _calculate_price(data)
		
	if not PlayerData.has_enough_currency(price):
		print("No tienes suficiente oro. Precio: %d" % price)
		return

	if not inventory.can_add_item(data):
		print("Inventario lleno")
		return

	if PlayerData.spend_currency(price):
		inventory.add_item(data)
		button.disabled = true
		button.modulate = Color(0.25, 0.25, 0.25, 1.0)
		print("Compraste %s por %d oro." % [data.resource_name, price])
		
		# Actualizamos precios por si subieron al comprar copia
		_update_all_label_colors()
	else:
		print("Error al gastar oro.")


func _update_all_label_colors(_new_amount: int = 0) -> void:
	if current_shop_styles.is_empty():
		return

	for item in current_shop_styles:
		var style_box: StyleBoxFlat = item.style
		var data = item.data
		var label: Label = item.label
		
		var current_price: int = _calculate_price(data)
		
		if label:
			label.text = str(current_price) + "€"
		
		if PlayerData.has_enough_currency(current_price):
			style_box.bg_color = COLOR_NORMAL_BG
		else:
			style_box.bg_color = COLOR_UNAFFORD_BG


# --- LÓGICA DE PRECIO MEJORADA ---
func _calculate_price(data) -> int:
	if not "price" in data:
		return 0

	var base_price: int = data.price
	var count: int = _get_item_count_safe(data)
	
	# Seleccionamos el multiplicador correcto según el tipo
	var multiplier_val: float = 0.0
	
	# Detectamos si es pieza o pasiva
	if data is PieceData:
		multiplier_val = duplicate_piece_mult
	elif data is PassiveData:
		multiplier_val = duplicate_passive_mult
	
	var total_mult: float = 1.0 + (multiplier_val * count)
	return int(base_price * total_mult)


# Helper para obtener conteo de forma segura
func _get_item_count_safe(data) -> int:
	var game_manager = null
	if owner and owner.has_method("get_inventory_piece_count"):
		game_manager = owner
	elif get_tree().current_scene and get_tree().current_scene.has_method("get_inventory_piece_count"):
		game_manager = get_tree().current_scene
	
	if game_manager:
		return game_manager.get_inventory_piece_count(data)
	return 0
