extends Control

@onready var piece_scene: PackedScene = preload("res://scenes/piece.tscn")
@onready var passive_scene: PackedScene = preload("res://scenes/passive.tscn")

# Referencia al tooltip (asegúrate de que el nodo Tooltip existe en la escena)
@onready var tooltip: Control = $Tooltip 

@export_group("Configuración de Items")
@export var piece_origins: Array[PieceData]
@export var passive_origins: Array[PassiveData]
@export var max_copies: int = 3 # Límite para dejar de salir en tienda

@export_group("Economía")
@export_range(0.0, 2.0) var duplicate_piece_mult: float = 0.5 
@export_range(0.0, 2.0) var duplicate_passive_mult: float = 0.5 
@export var COLOR_NORMAL_BG: Color = Color(0, 0, 0, 0.6) 
@export var COLOR_UNAFFORD_BG: Color = Color(1.0, 0, 0, 0.6)

@export_group("Economía Reroll")
@export var reroll_base_cost: int = 2      # Costo base (ej: 2 monedas)
@export var reroll_cost_multiplier: float = 1.5 # Cuánto sube el precio (ej: x1.5)

@export_group("Probabilidades de Tienda (%)")
@export_range(0, 100) var prob_comun: int = 70
@export_range(0, 100) var prob_raro: int = 20
@export_range(0, 100) var prob_epico: int = 8
@export_range(0, 100) var prob_legendario: int = 2

var _pieces_by_rarity: Dictionary = {}
var _rerolls_this_round: int = 0
var reroll_label: Label # Variable para guardar la etiqueta de precio del reroll

@onready var inventory: Control = $"../inventory"
@onready var piece_zone: HBoxContainer = $VBoxContainer/piece_zone
@onready var passive_zone: HBoxContainer = $VBoxContainer/passive_zone
@onready var reroll_button: TextureButton = $VBoxContainer/HBoxContainer/Reroll

var current_shop_styles: Array = []

func _ready() -> void:
	PlayerData.currency_changed.connect(_update_all_label_colors)
	
	# --- CREAR VISUALIZADOR DE PRECIO PARA EL REROLL ---
	reroll_label = Label.new()
	reroll_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reroll_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Configuración visual de la etiqueta
	reroll_label.add_theme_color_override("font_outline_color", Color.BLACK)
	reroll_label.add_theme_constant_override("outline_size", 6)
	reroll_label.add_theme_font_size_override("font_size", 24)
	
	# Lo añadimos como hijo del botón Reroll
	reroll_button.add_child(reroll_label)
	
	# Lo posicionamos (Center Bottom para que salga abajo)
	reroll_label.layout_mode = 1 # Anchors
	reroll_label.anchors_preset = Control.PRESET_CENTER_BOTTOM
	reroll_label.position.y += 10 # Ajuste para no tapar icono
	
	# Inicializamos la ronda
	start_new_round()

# --- CONTROL DE RONDA ---

func start_new_round() -> void:
	_rerolls_this_round = 0
	_update_reroll_button_visuals()
	# Refrescamos la tienda gratis al entrar
	_refresh_shop_content() 

# --- LÓGICA DEL BOTÓN REROLL (Generate) ---

func generate():
	var current_cost = _calculate_reroll_cost()
	
	# 1. Verificar si podemos pagar (o si es gratis)
	if current_cost > 0:
		if not PlayerData.has_enough_currency(current_cost):
			print("No tienes suficiente dinero para reroll. Costo: %d" % current_cost)
			_animate_error_shake(reroll_button) # Feedback visual
			return
		
		# Pagar
		PlayerData.spend_currency(current_cost)
		print("Reroll pagado: %d monedas" % current_cost)
	else:
		print("Reroll GRATIS usado.")

	# 2. Ejecutar el Reroll
	_rerolls_this_round += 1
	_refresh_shop_content()
	
	# 3. Actualizar visuales para el SIGUIENTE precio
	_update_reroll_button_visuals()

# --- FUNCIONES VISUALES Y DE CÁLCULO REROLL ---

func _calculate_reroll_cost() -> int:
	if _rerolls_this_round == 0:
		return 0 # Gratis
	
	# Fórmula exponencial: Base * (Multi ^ (usos_pagados))
	# (_rerolls_this_round - 1) porque el primero no cuenta para el exponente
	var paid_uses = _rerolls_this_round 
	var multiplier = pow(reroll_cost_multiplier, paid_uses - 1)
	
	if paid_uses == 1: 
		multiplier = 1.0
	
	return int(reroll_base_cost * multiplier)

func _update_reroll_button_visuals():
	if not reroll_label: return
	
	var cost = _calculate_reroll_cost()
	
	if cost == 0:
		reroll_label.text = "GRATIS"
		reroll_label.modulate = Color(0.2, 1.0, 0.2) # Verde brillante
		reroll_button.modulate = Color.WHITE
		reroll_button.tooltip_text = "¡Reroll GRATIS!"
	else:
		reroll_label.text = "-%d €" % cost
		reroll_button.tooltip_text = "Costo: %d" % cost
		
		if PlayerData.has_enough_currency(cost):
			reroll_label.modulate = Color(1.0, 0.9, 0.4) # Dorado/Normal
			reroll_button.modulate = Color.WHITE
		else:
			reroll_label.modulate = Color(1.0, 0.2, 0.2) # Rojo
			reroll_button.modulate = Color(0.6, 0.6, 0.6) # Botón oscurecido

func _animate_error_shake(node: Control):
	var tween = create_tween()
	var original_pos = node.position.x
	# Pequeña animación de sacudida derecha-izquierda
	tween.tween_property(node, "position:x", original_pos + 10, 0.05)
	tween.tween_property(node, "position:x", original_pos - 10, 0.05)
	tween.tween_property(node, "position:x", original_pos, 0.05)

# --- LÓGICA DE GENERACIÓN DE TIENDA (Original) ---

func _refresh_shop_content():
	current_shop_styles.clear()
	
	for child in piece_zone.get_children():
		child.queue_free()
	for child in passive_zone.get_children():
		child.queue_free()

	# 1. Piezas
	var available_pieces = _filter_maxed_items(piece_origins)
	_organize_pieces_by_rarity(available_pieces)
	
	var selected_pieces: Array = []
	for i in range(3):
		var piece = _get_random_weighted_piece()
		if piece:
			selected_pieces.append(piece)

	_generate_buttons(selected_pieces, piece_zone, piece_scene)
	
	# 2. Pasivas
	var available_passives = _filter_maxed_items(passive_origins)
	if not available_passives.is_empty():
		var shuffled_passives = available_passives.duplicate()
		shuffled_passives.shuffle()
		var selected_passives = shuffled_passives.slice(0, min(3, shuffled_passives.size()))
		_generate_buttons(selected_passives, passive_zone, passive_scene)
	
	_update_all_label_colors()

# --- GENERACIÓN DE BOTONES Y TOOLTIPS ---

func _generate_buttons(origin_array: Array, target_zone: HBoxContainer, base_scene: PackedScene) -> void:
	if origin_array.is_empty():
		return

	var shuffled = origin_array.duplicate()
	shuffled.shuffle()
	var selected = shuffled.slice(0, min(3, shuffled.size()))

	for origin_data in selected:
		var origin_instance = base_scene.instantiate()

		# Obtener textura (icon o sprite)
		var texture_to_use: Texture2D = origin_data.icon
		if texture_to_use == null:
			var sprite_node = origin_instance.find_child("Sprite2D", true, false)
			if sprite_node:
				texture_to_use = sprite_node.texture

		if texture_to_use:
			var item_container = VBoxContainer.new()
			item_container.alignment = VBoxContainer.ALIGNMENT_CENTER

			# Etiqueta de precio del Item
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

				style_box.content_margin_left = 6; style_box.content_margin_right = 6
				style_box.content_margin_top = 2; style_box.content_margin_bottom = 2
				style_box.corner_radius_top_left = 4; style_box.corner_radius_top_right = 4
				style_box.corner_radius_bottom_left = 4; style_box.corner_radius_bottom_right = 4
				
				price_label.add_theme_stylebox_override("normal", style_box)
				item_container.add_child(price_label)
				
				current_shop_styles.append({
					"style": style_box, 
					"data": origin_data, 
					"label": price_label
				})

			# Botón del Item
			var button = TextureButton.new()
			button.texture_normal = texture_to_use
			button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			button.set_meta("data", origin_data)
			
			button.pressed.connect(_on_button_pressed.bind(button))
			
			# Tooltips
			button.mouse_entered.connect(_on_button_mouse_entered.bind(origin_data))
			button.mouse_exited.connect(_on_button_mouse_exited)
			
			item_container.add_child(button)
			target_zone.add_child(item_container)

		origin_instance.queue_free()

# --- EVENTOS DEL MOUSE (Tooltips) ---

func _on_button_mouse_entered(data: Resource) -> void:
	if tooltip and data:
		var count = _get_item_count_safe(data)
		tooltip.show_tooltip(data, 0, count) # Asumiendo que tu tooltip acepta (data, nivel, cantidad)
		
func _on_button_mouse_exited() -> void:
	if tooltip:
		tooltip.hide_tooltip()

func _on_button_pressed(button: TextureButton) -> void:
	var data = button.get_meta("data")
	if data == null: return

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
		_update_all_label_colors()
	else:
		print("Error al gastar oro.")

# --- ACTUALIZACIÓN DE COLORES Y PRECIOS ---

func _update_all_label_colors(_new_amount: int = 0) -> void:
	# 1. Actualizar botón de reroll
	_update_reroll_button_visuals()

	# 2. Actualizar items de la tienda
	if current_shop_styles.is_empty(): return
	
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

# --- PROBABILIDAD Y HELPERS ---

func _calculate_price(data) -> int:
	if not "price" in data: return 0
	var base_price: int = data.price
	var count: int = _get_item_count_safe(data)
	var multiplier_val: float = 0.0
	
	if data is PieceData:
		multiplier_val = duplicate_piece_mult
	elif data is PassiveData:
		multiplier_val = duplicate_passive_mult
	
	var total_mult: float = 1.0 + (multiplier_val * count)
	return int(base_price * total_mult)

func _get_item_count_safe(data) -> int:
	var game_manager = null
	if owner and owner.has_method("get_inventory_piece_count"):
		game_manager = owner
	elif get_tree().current_scene and get_tree().current_scene.has_method("get_inventory_piece_count"):
		game_manager = get_tree().current_scene
	
	if game_manager:
		return game_manager.get_inventory_piece_count(data)
	return 0

func _organize_pieces_by_rarity(pieces: Array):
	_pieces_by_rarity.clear()
	_pieces_by_rarity[PieceRes.PieceRarity.COMUN] = []
	_pieces_by_rarity[PieceRes.PieceRarity.RARO] = []
	_pieces_by_rarity[PieceRes.PieceRarity.EPICO] = []
	_pieces_by_rarity[PieceRes.PieceRarity.LEGENDARIO] = []
	
	for p in pieces:
		if p is PieceData and p.piece_origin:
			var rarity = p.piece_origin.rarity
			if _pieces_by_rarity.has(rarity):
				_pieces_by_rarity[rarity].append(p)

func _get_random_weighted_piece() -> Resource:
	var roll = randi() % 100 + 1 
	var selected_rarity = -1
	
	if roll <= prob_comun: selected_rarity = PieceRes.PieceRarity.COMUN
	elif roll <= prob_comun + prob_raro: selected_rarity = PieceRes.PieceRarity.RARO
	elif roll <= prob_comun + prob_raro + prob_epico: selected_rarity = PieceRes.PieceRarity.EPICO
	else: selected_rarity = PieceRes.PieceRarity.LEGENDARIO
	
	var piece = _pick_from_rarity_pool(selected_rarity)
	if piece == null: piece = _pick_from_rarity_pool(PieceRes.PieceRarity.COMUN) 
	if piece == null:
		var all_pools = _pieces_by_rarity.values()
		for pool in all_pools:
			if not pool.is_empty(): return pool.pick_random()
	return piece

func _pick_from_rarity_pool(rarity: int) -> Resource:
	if _pieces_by_rarity.has(rarity):
		var pool = _pieces_by_rarity[rarity]
		if not pool.is_empty(): return pool.pick_random()
	return null

func _filter_maxed_items(candidates: Array) -> Array:
	var available = []
	for item in candidates:
		if item is PieceData:
			var count = _get_item_count_safe(item)
			if count < max_copies: available.append(item)
		else:
			available.append(item)
	return available
