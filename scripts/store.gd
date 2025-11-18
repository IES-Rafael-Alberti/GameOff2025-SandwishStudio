extends Control
@export var price_increase: float = 0.5
@onready var piece_scene: PackedScene = preload("res://scenes/piece.tscn")
@onready var passive_scene: PackedScene = preload("res://scenes/passive.tscn")
@export var piece_origins: Array[PieceData]
@export var passive_origins: Array[PassiveData]
@onready var inventory: Control = $"../inventory"
@onready var piece_zone: HBoxContainer = $VBoxContainer/piece_zone
@onready var passive_zone: HBoxContainer = $VBoxContainer/passive_zone
@onready var reroll_button: TextureButton = $VBoxContainer/HBoxContainer/Reroll

# --- NUEVA VARIABLE ---

var current_shop_styles: Array = []
@export var COLOR_NORMAL_BG = Color(0, 0, 0, 0.6) 
@export var COLOR_UNAFFORD_BG = Color(1.0, 0, 0, 0.6) 

func _ready() -> void:
	PlayerData.currency_changed.connect(_update_all_label_colors)

# --- NUEVA FUNCIÓN PARA CALCULAR PRECIO ---
func _calculate_price(data) -> int:
	# Comprobación de seguridad: si el objeto no tiene precio, retornamos 0
	if not "price" in data:
		return 0

	var base_price: int = data.price
	
	# Lógica para buscar al GameManager y contar copias
	var count: int = 0
	
	# Intentamos encontrar el GameManager de forma robusta
	var game_manager = null
	if owner and owner.has_method("get_inventory_piece_count"):
		game_manager = owner
	elif get_tree().current_scene and get_tree().current_scene.has_method("get_inventory_piece_count"):
		game_manager = get_tree().current_scene
	
	if game_manager:
		count = game_manager.get_inventory_piece_count(data)
	
	# Si count es 0, el precio es el base. Si es 1, aumenta según el porcentaje configurado.
	var multiplier: float = 1.0 + (price_increase * count)
	return int(base_price * multiplier)

func generate():
	current_shop_styles.clear()
	
	for child in piece_zone.get_children():
		child.queue_free()
	for child in passive_zone.get_children():
		child.queue_free()

	_generate_buttons(piece_origins, piece_zone, piece_scene)
	_generate_buttons(passive_origins, passive_zone, passive_scene)
	
	_update_all_label_colors()


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
				# --- CAMBIO AQUÍ: Usar precio calculado ---
				var final_price: int = _calculate_price(origin_data)
				
				var price_label = Label.new()
				price_label.text = str(final_price) + "€"
				price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				
				var style_box = StyleBoxFlat.new()
				
				# Lógica de color inicial
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
				
				# --- CAMBIO AQUÍ: Guardamos 'data' y 'label' para recalcular luego si hace falta ---
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
		# --- CAMBIO AQUÍ: Usar precio calculado al momento de comprar ---
		price = _calculate_price(data)
		
	if not PlayerData.has_enough_currency(price):
		print("No tienes suficiente oro para comprar %s. Precio: %d" % [data.resource_name, price])
		return

	if not inventory.can_add_item(data):
		print("Inventario lleno, no se puede comprar")
		return

	if PlayerData.spend_currency(price):
		inventory.add_item(data)
		button.disabled = true
		button.modulate = Color(0.25, 0.25, 0.25, 1.0)
		print("Compraste %s por %d oro." % [data.resource_name, price])
		
		# Opcional: Si quieres que al comprar uno, el precio del OTRO (si hubiera otro igual en tienda) suba inmediatamente:
		# _update_all_label_colors() 
	else:
		print("Error: No se pudo gastar el oro.")


func _update_all_label_colors(_new_amount: int = 0) -> void:
	if current_shop_styles.is_empty():
		return

	for item in current_shop_styles:
		var style_box: StyleBoxFlat = item.style
		var data = item.data
		var label: Label = item.label
		
		# Recalculamos precio por si cambió algo (ej. compraste una unidad y ahora la siguiente es más cara)
		var current_price: int = _calculate_price(data)
		
		# Actualizamos el texto del label por seguridad
		if label:
			label.text = str(current_price) + "€"
		
		if PlayerData.has_enough_currency(current_price):
			style_box.bg_color = COLOR_NORMAL_BG
		else:
			style_box.bg_color = COLOR_UNAFFORD_BG
