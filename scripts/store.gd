extends Control

# --- REFERENCIAS ---
@onready var store_slot_scene: PackedScene = preload("res://scenes/store_slot.tscn")
@onready var passive_scene: PackedScene = preload("res://scenes/passive.tscn")

@onready var tooltip: Control = $Tooltip 
@onready var inventory: Control = $"../inventory"
@onready var piece_zone: HBoxContainer = $piece_zone
@onready var passive_zone: HBoxContainer = $passive_zone
@onready var reroll_button: TextureButton = $Reroll
@onready var lock_button: TextureButton = $Lock 

# --- CONFIGURACIÓN ---
@export_group("Configuración de Items")
@export var piece_origins: Array[PieceData]
@export var passive_origins: Array[PassiveData]
@export var max_copies: int = 3 

@export_group("Economía")
@export_range(0.0, 2.0) var duplicate_piece_mult: float = 0.5 
@export_range(0.0, 2.0) var duplicate_passive_mult: float = 0.5 
@export var COLOR_NORMAL_BG: Color = Color(0, 0, 0, 0.6) 
@export var COLOR_UNAFFORD_BG: Color = Color(1.0, 0, 0, 0.6)

@export_group("Economía Reroll")
@export var reroll_base_cost: int = 2
@export var reroll_cost_multiplier: float = 1.5

@export_group("Probabilidades de Tienda (%)")
@export_range(0, 100) var prob_comun: int = 70
@export_range(0, 100) var prob_raro: int = 20
@export_range(0, 100) var prob_epico: int = 8
@export_range(0, 100) var prob_legendario: int = 2

# --- SISTEMA DE BLOQUEO ---
@export_group("Sistema de Bloqueo")
@export var texture_unlocked: Texture2D 
@export var texture_locked: Texture2D   
@export var keep_lock_on_new_day: bool = false 

# --- SHADER & VISUALS ---
const OUTLINE_SHADER = preload("res://shaders/outline_highlight.gdshader")
var highlight_material: ShaderMaterial

var _pieces_by_rarity: Dictionary = {}
var _rerolls_this_round: int = 0
var reroll_label: Label
var current_passive_buttons: Array = []

var is_rerolling: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = OUTLINE_SHADER
	highlight_material.set_shader_parameter("width", 3.0)
	highlight_material.set_shader_parameter("color", Color.WHITE)
	
	if piece_zone.custom_minimum_size.y < 200:
		piece_zone.custom_minimum_size.y = 200
	if passive_zone.custom_minimum_size.y < 100:
		passive_zone.custom_minimum_size.y = 100
	
	PlayerData.currency_changed.connect(_update_shop_visuals)
	
	if reroll_button:
		reroll_button.mouse_entered.connect(func(): if not reroll_button.disabled: reroll_button.material = highlight_material)
		reroll_button.mouse_exited.connect(func(): reroll_button.material = null)
	
	if lock_button:
		_update_lock_visuals()
		lock_button.pressed.connect(_on_lock_pressed)
	
	_setup_reroll_label()
	start_new_round()

# --- LÓGICA DEL CANDADO ---
func _update_lock_visuals() -> void:
	if not lock_button: return
	
	if PlayerData.is_shop_locked:
		if texture_locked: lock_button.texture_normal = texture_locked
	else:
		if texture_unlocked: lock_button.texture_normal = texture_unlocked

func _on_lock_pressed() -> void:
	if is_rerolling: return 
	PlayerData.is_shop_locked = not PlayerData.is_shop_locked
	_update_lock_visuals()
	_update_reroll_button_visuals()
	if PlayerData.is_shop_locked:
		_save_current_shop_state()

# --- CAMBIO DE RONDA ---
func start_new_round() -> void:
	_rerolls_this_round = 0
	_update_reroll_button_visuals()

	if PlayerData.is_shop_locked:
		print("Tienda Bloqueada: Restaurando items guardados...")
		_restore_shop_from_save()
		
		# Lógica de Development: Revisar si mantenemos el candado
		if not keep_lock_on_new_day:
			PlayerData.is_shop_locked = false
			_update_lock_visuals()
			
		_update_shop_visuals()
		return 

	is_rerolling = false 
	_refresh_shop_content() 

# --- GUARDAR Y RESTAURAR ---
func _save_current_shop_state() -> void:
	PlayerData.shop_items_saved.clear()
	
	# Guardar Piezas
	for slot in piece_zone.get_children():
		if slot.is_queued_for_deletion(): continue
		
		# Combinación de chequeos de ambas ramas
		if slot is StoreSlot or "item_data" in slot: 
			var data_packet = {
				"type": "piece",
				"data": slot.item_data,
				"price": slot.current_price,
				"purchased": slot.is_purchased
			}
			PlayerData.shop_items_saved.append(data_packet)
	
	# Guardar Pasivas (Lógica V2)
	for wrapper in passive_zone.get_children():
		if wrapper.is_queued_for_deletion(): continue
		var button = _find_texture_button_recursive(wrapper)
		if button:
			var data_packet = {
				"type": "passive",
				"data": button.get_meta("data"),
				"price": button.get_meta("price"),
				"purchased": button.disabled
			}
			PlayerData.shop_items_saved.append(data_packet)

func _find_texture_button_recursive(node: Node) -> TextureButton:
	if node is TextureButton: return node
	for child in node.get_children():
		var res = _find_texture_button_recursive(child)
		if res: return res
	return null

func _restore_shop_from_save() -> void:
	for child in piece_zone.get_children(): child.queue_free()
	for child in passive_zone.get_children(): child.queue_free()
	current_passive_buttons.clear()
	
	for packet in PlayerData.shop_items_saved:
		var type = packet.type
		var data = packet.data
		var price = packet.price
		var purchased = packet.purchased
		
		if type == "piece":
			var slot = store_slot_scene.instantiate()
			piece_zone.add_child(slot)
			
			var can_afford = PlayerData.has_enough_currency(price)
			var current_count = _get_item_count_safe(data)
			if slot.has_method("set_item"):
				slot.set_item(data, price, highlight_material, can_afford, current_count)
				if purchased: slot.disable_interaction()
				elif current_count >= max_copies: slot.set_maxed_state(true)
				slot.slot_pressed.connect(_on_piece_slot_pressed)
				slot.slot_hovered.connect(_on_hover_item)
				slot.slot_exited.connect(_on_exit_item)
			
		elif type == "passive":
			_create_single_passive_button(data, price, purchased)

# --- CREACIÓN DE PASIVAS (V2) ---
func _create_single_passive_button(data, price: int, is_purchased: bool) -> void:
	var item_container = VBoxContainer.new()
	item_container.alignment = VBoxContainer.ALIGNMENT_CENTER
	item_container.add_theme_constant_override("separation", 5) 
	
	var price_label = Label.new()
	price_label.text = str(price) + "€"
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var style_box = StyleBoxFlat.new()
	style_box.content_margin_left = 6
	style_box.content_margin_right = 6
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	
	if PlayerData.has_enough_currency(price):
		style_box.bg_color = COLOR_NORMAL_BG
	else:
		style_box.bg_color = COLOR_UNAFFORD_BG
		
	price_label.add_theme_stylebox_override("normal", style_box)
	item_container.add_child(price_label)

	var tex = data.icon
	if tex == null:
		var instance = passive_scene.instantiate()
		var sprite = instance.find_child("Sprite2D", true, false)
		if sprite: tex = sprite.texture
		instance.queue_free()
	
	var holder = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	if tex:
		holder.custom_minimum_size = tex.get_size()
	else:
		holder.custom_minimum_size = Vector2(64, 64)
	
	var button = TextureButton.new()
	button.texture_normal = tex
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.set_anchors_preset(Control.PRESET_FULL_RECT) 
	button.set_meta("data", data)
	button.set_meta("price", price)
	button.pressed.connect(_on_passive_button_pressed.bind(button))
	button.mouse_entered.connect(_on_hover_item.bind(data))
	button.mouse_entered.connect(func(): if not button.disabled: button.material = highlight_material)
	button.mouse_exited.connect(_on_exit_item)
	button.mouse_exited.connect(func(): button.material = null)
	
	if is_purchased:
		button.disabled = true
		button.modulate = Color(0.25, 0.25, 0.25, 1.0)
	
	holder.add_child(button)
	item_container.add_child(holder)
	passive_zone.add_child(item_container)
	
	if is_rerolling:
		item_container.modulate.a = 0.0
	
	current_passive_buttons.append({
		"button": button, "holder": holder, "container": item_container,
		"label": price_label, "style": style_box, "price": price
	})

# ========================================================
# --- SISTEMA DE ANIMACIÓN AVANZADO (GHOST SYSTEM) ---
# ========================================================

func generate():
	if is_rerolling or PlayerData.is_shop_locked:
		_animate_error_shake(reroll_button)
		return

	var current_cost = _calculate_reroll_cost()
	if current_cost > 0:
		if not PlayerData.has_enough_currency(current_cost):
			_animate_error_shake(reroll_button)
			return
	
	is_rerolling = true
	reroll_button.disabled = true 
	
	# ---------------------------------------------------------
	# FASE 1: SALIDA (ANIMAR ITEMS EXISTENTES CAYENDO)
	# ---------------------------------------------------------
	var exit_tween = create_tween().set_parallel(true)
	var items_exiting = false
	
	# PASO CLAVE: Capturar posiciones y nodos ANTES de reparentar
	var exit_snapshots = []
	
	# Capturar Piezas
	for child in piece_zone.get_children():
		if is_instance_valid(child) and child is Control:
			exit_snapshots.append({"node": child, "pos": child.global_position, "size": child.size})
			
	# Capturar Pasivas
	for child in passive_zone.get_children():
		if is_instance_valid(child) and child is Control:
			exit_snapshots.append({"node": child, "pos": child.global_position, "size": child.size})
	
	# Ejecutar animación de salida usando las posiciones capturadas
	for snap in exit_snapshots:
		items_exiting = true
		_detach_and_animate_drop_safe(snap.node, snap.pos, snap.size, exit_tween)
	
	if items_exiting:
		await exit_tween.finished
		await get_tree().create_timer(0.1).timeout 
	
	# ---------------------------------------------------------
	# FASE 2: REFRESCO LÓGICO (CREAR NUEVOS ITEMS INVISIBLES)
	# ---------------------------------------------------------
	if current_cost > 0: PlayerData.spend_currency(current_cost)
	_rerolls_this_round += 1
	_update_reroll_button_visuals()
	
	_refresh_shop_content() # Crea items con modulate.a = 0
	
	# Esperar 2 frames para que el HBoxContainer calcule posiciones
	await get_tree().process_frame
	await get_tree().process_frame 
	
	# ---------------------------------------------------------
	# FASE 3: ENTRADA (FANTASMAS CAEN EN HUECOS RESERVADOS)
	# ---------------------------------------------------------
	var entry_tween = create_tween().set_parallel(true)
	var delay = 0.0
	var drop_height = 150.0 # Más arriba para que se vea bien la caída
	
	# --- PIEZAS ---
	for slot in piece_zone.get_children():
		if not "item_data" in slot: continue
		
		slot.modulate.a = 0.0 
		
		# 1. Crear Fantasma y añadirlo a la raíz (self)
		var ghost = store_slot_scene.instantiate()
		add_child(ghost)
		
		# 2. CRÍTICO: Desactivar Layout/Anclajes para permitir control por posición
		ghost.set_anchors_preset(Control.PRESET_TOP_LEFT) 
		
		# 3. Configurar
		var d = slot.item_data
		ghost.set_item(d, slot.current_price, highlight_material, slot.can_afford_status, _get_item_count_safe(d))
		if slot.is_maxed: ghost.set_maxed_state(true)
		
		# 4. Posicionamiento inicial y final
		var target_pos = slot.global_position
		var start_pos = target_pos - Vector2(0, drop_height)
		
		ghost.global_position = start_pos
		ghost.scale = Vector2(0.8, 0.8)
		ghost.z_index = 10 
		
		# 5. Tween
		entry_tween.tween_property(ghost, "global_position", target_pos, 0.5)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(delay)
		entry_tween.tween_property(ghost, "scale", Vector2.ONE, 0.4).set_delay(delay)
		
		# 6. Al terminar: Mostrar Real y Borrar Fantasma
		entry_tween.parallel().tween_callback(func():
			if is_instance_valid(slot): slot.modulate.a = 1.0
			if is_instance_valid(ghost): ghost.queue_free()
		).set_delay(delay + 0.45)
		
		delay += 0.1
		
	# --- PASIVAS ---
	for container in passive_zone.get_children():
		if not is_instance_valid(container): continue
		container.modulate.a = 0.0
		
		# Clonar para el fantasma
		var ghost = container.duplicate(0)
		add_child(ghost)
		
		# CRÍTICO: Desactivar Layout/Anclajes en el fantasma
		ghost.set_anchors_preset(Control.PRESET_TOP_LEFT)
		
		var target_pos = container.global_position
		var start_pos = target_pos - Vector2(0, drop_height)
		
		ghost.global_position = start_pos
		ghost.scale = Vector2(0.8, 0.8)
		ghost.z_index = 10
		
		entry_tween.tween_property(ghost, "global_position", target_pos, 0.5)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(delay)
		entry_tween.tween_property(ghost, "scale", Vector2.ONE, 0.4).set_delay(delay)
		
		entry_tween.parallel().tween_callback(func():
			if is_instance_valid(container): container.modulate.a = 1.0
			if is_instance_valid(ghost): ghost.queue_free()
		).set_delay(delay + 0.45)
		
		delay += 0.1

	await entry_tween.finished
	is_rerolling = false
	reroll_button.disabled = false
	_save_current_shop_state()

# Helper para "robar" un nodo de su HBox y animarlo cayendo
func _detach_and_animate_drop_safe(node: Control, old_global_pos: Vector2, old_size: Vector2, tween: Tween):
	# 1. Reparentar al root para sacarlo del HBox
	node.reparent(self)
	
	# 2. CRÍTICO: Desactivar el layout para permitir la animación libre
	node.set_anchors_preset(Control.PRESET_TOP_LEFT) 
	
	# 3. Restaurar la posición global y tamaño guardados
	node.size = old_size
	node.global_position = old_global_pos
	node.z_index = 5 
	
	# 4. Animar caída: Corregido el easing para que se vea como una caída acelerada.
	var drop_duration = 0.4
	var drop_distance = 250.0 
	
	tween.tween_property(node, "position:y", drop_distance, drop_duration).as_relative()\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN) # Transición más adecuada para una caída
	
	# Desvanecer al mismo tiempo
	tween.tween_property(node, "modulate:a", 0.0, 0.2).set_delay(0.1) 
	
	# 5. Borrar al terminar
	tween.tween_callback(node.queue_free).set_delay(drop_duration)

# ========================================================

func _refresh_shop_content():
	for child in piece_zone.get_children(): child.queue_free()
	for child in passive_zone.get_children(): child.queue_free()
	current_passive_buttons.clear()

	# 1. PIEZAS
	var available_pieces = _filter_maxed_items(piece_origins)
	_organize_pieces_by_rarity(available_pieces)
	var selected_pieces: Array = []
	for i in range(3):
		var piece = _get_random_weighted_piece()
		if piece: selected_pieces.append(piece)
	_generate_piece_slots(selected_pieces)
	
	# 2. GENERAR PASIVAS
	# Nota: Combinamos la lógica. En Development no se filtraba por maxed (son acumulables),
	# pero mantenemos la generación de botones de v2.
	var available_passives = passive_origins 
	if not available_passives.is_empty():
		var shuffled = available_passives.duplicate()
		shuffled.shuffle()
		var selected = shuffled.slice(0, min(2, shuffled.size()))
		_generate_passive_buttons(selected)
	
	if not is_rerolling:
		_save_current_shop_state()

func _generate_piece_slots(items: Array) -> void:
	for data in items:
		var slot = store_slot_scene.instantiate()
		piece_zone.add_child(slot)
		
		var price = _calculate_price(data)
		var can_afford = PlayerData.has_enough_currency(price)
		var current_count = _get_item_count_safe(data)
		
		if slot.has_method("set_item"):
			slot.set_item(data, price, highlight_material, can_afford, current_count)
			slot.slot_pressed.connect(_on_piece_slot_pressed)
			slot.slot_hovered.connect(_on_hover_item)
			slot.slot_exited.connect(_on_exit_item)
			if current_count >= max_copies: slot.set_maxed_state(true)
		
		if is_rerolling:
			slot.modulate.a = 0.0

# --- INTERACCIÓN ---

func _on_piece_slot_pressed(slot) -> void:
	if is_rerolling: return 
	var data = slot.item_data
	var price = slot.current_price
	
	if slot.is_purchased:
		_animate_error_shake(slot.get_node("TextureButton"))
		return
	var current_count = _get_item_count_safe(data)
	if current_count >= max_copies:
		_animate_error_shake(slot.get_node("TextureButton"))
		return
	if not PlayerData.has_enough_currency(price):
		_animate_error_shake(slot.get_node("TextureButton"))
		return
	if not inventory.can_add_item(data):
		_animate_error_shake(slot.get_node("TextureButton"))
		return

	if PlayerData.spend_currency(price):
		inventory.add_item(data)
		slot.disable_interaction() 
		_update_shop_visuals()
		_save_current_shop_state()
	else:
		_animate_error_shake(slot.get_node("TextureButton"))

# --- FUNCIONES AUXILIARES (UI y Lógica) ---

func _setup_reroll_label():
	reroll_label = Label.new()
	reroll_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reroll_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reroll_label.add_theme_color_override("font_outline_color", Color.BLACK)
	reroll_label.add_theme_constant_override("outline_size", 6)
	reroll_label.add_theme_font_size_override("font_size", 24)
	reroll_button.add_child(reroll_label)
	reroll_label.layout_mode = 1
	reroll_label.anchors_preset = Control.PRESET_CENTER_BOTTOM
	reroll_label.position.y += 10 

func _calculate_reroll_cost() -> int:
	if _rerolls_this_round == 0: return 0 
	var paid_uses = _rerolls_this_round 
	var multiplier = pow(reroll_cost_multiplier, paid_uses - 1)
	if paid_uses == 1: multiplier = 1.0
	return int(reroll_base_cost * multiplier)

func _update_reroll_button_visuals():
	if not reroll_label: return
	if PlayerData.is_shop_locked:
		reroll_label.text = "BLOQ."
		reroll_label.modulate = Color(0.5, 0.5, 0.5)
		reroll_button.modulate = Color(0.7, 0.7, 0.7)
		return
	var cost = _calculate_reroll_cost()
	if cost == 0:
		reroll_label.text = "GRATIS"
		reroll_label.modulate = Color(0.2, 1.0, 0.2) 
		reroll_button.modulate = Color.WHITE
	else:
		reroll_label.text = "-%d €" % cost
		if PlayerData.has_enough_currency(cost):
			reroll_label.modulate = Color(1.0, 0.9, 0.4) 
			reroll_button.modulate = Color.WHITE
		else:
			reroll_label.modulate = Color(1.0, 0.2, 0.2) 
			reroll_button.modulate = Color(0.6, 0.6, 0.6) 

func _animate_error_shake(node: Control):
	if not node: return
	var tween = create_tween()
	node.pivot_offset = node.size / 2
	tween.tween_property(node, "rotation_degrees", 5, 0.05)
	tween.tween_property(node, "rotation_degrees", -5, 0.05)
	tween.tween_property(node, "rotation_degrees", 0, 0.05)

func _generate_passive_buttons(items: Array) -> void:
	for data in items:
		var final_price = _calculate_price(data)
		_create_single_passive_button(data, final_price, false)

func _on_passive_button_pressed(button: TextureButton) -> void:
	if is_rerolling: return
	var data = button.get_meta("data")
	var price = button.get_meta("price")
	if not PlayerData.has_enough_currency(price):
		_animate_error_shake(button)
		return
		
	# Verificación de hueco visual para pasivas (Development)
	if not inventory.can_add_item(data):
		_animate_error_shake(button)
		return

	if PlayerData.spend_currency(price):
		inventory.add_item(data)
		button.disabled = true
		button.modulate = Color(0.25, 0.25, 0.25, 1.0)
		button.material = null
		_update_shop_visuals()
		_save_current_shop_state()

func _update_shop_visuals(_new_amount: int = 0) -> void:
	_update_reroll_button_visuals()
	for slot in piece_zone.get_children():
		if slot.has_method("update_count_visuals"):
			var current_count = _get_item_count_safe(slot.item_data)
			slot.update_count_visuals(slot.item_data, current_count)
			if slot.is_purchased: continue
			if slot.item_data is PieceData and current_count >= max_copies:
				slot.set_maxed_state(true)
			else:
				slot.set_maxed_state(false)
				var can = PlayerData.has_enough_currency(slot.current_price)
				slot.update_affordability(can)
	for item_info in current_passive_buttons:
		var btn = item_info.button
		if btn.disabled: continue
		var price = item_info.price
		var style = item_info.style
		if PlayerData.has_enough_currency(price):
			style.bg_color = COLOR_NORMAL_BG
		else:
			style.bg_color = COLOR_UNAFFORD_BG

func _on_hover_item(data: Resource) -> void:
	if tooltip and data:
		var count = _get_item_count_safe(data)
		tooltip.show_tooltip(data, 0, count)

func _on_exit_item() -> void:
	if tooltip: tooltip.hide_tooltip()

func _calculate_price(data) -> int:
	if not "price" in data: return 0
	var base = data.price
	var count = _get_item_count_safe(data)
	var mult = 0.0
	if data is PieceData: mult = duplicate_piece_mult
	elif data is PassiveData: mult = duplicate_passive_mult
	return int(base * (1.0 + (mult * count)))

func _get_item_count_safe(data) -> int:
	# Si es Pasiva, preguntamos a PlayerData
	if data is PassiveData:
		return PlayerData.get_passive_count_global(data)
		
	# Si es Pieza, preguntamos al inventario de la escena
	var gm = null
	if owner and owner.has_method("get_inventory_piece_count"): gm = owner
	elif get_tree().current_scene and get_tree().current_scene.has_method("get_inventory_piece_count"): gm = get_tree().current_scene
	if gm: return gm.get_inventory_piece_count(data)
	return 0

func _filter_maxed_items(candidates: Array) -> Array:
	var available = []
	for item in candidates:
		if item is PieceData:
			if _get_item_count_safe(item) < max_copies: available.append(item)
		else:
			available.append(item)
	return available

func _organize_pieces_by_rarity(pieces: Array):
	_pieces_by_rarity.clear()
	_pieces_by_rarity[PieceRes.PieceRarity.COMUN] = []
	_pieces_by_rarity[PieceRes.PieceRarity.RARO] = []
	_pieces_by_rarity[PieceRes.PieceRarity.EPICO] = []
	_pieces_by_rarity[PieceRes.PieceRarity.LEGENDARIO] = []
	for p in pieces:
		if p is PieceData and p.piece_origin:
			var r = p.piece_origin.rarity
			if _pieces_by_rarity.has(r): _pieces_by_rarity[r].append(p)

func _get_random_weighted_piece() -> Resource:
	var roll = randi() % 100 + 1 
	var sel = PieceRes.PieceRarity.COMUN
	if roll <= prob_comun: sel = PieceRes.PieceRarity.COMUN
	elif roll <= prob_comun + prob_raro: sel = PieceRes.PieceRarity.RARO
	elif roll <= prob_comun + prob_raro + prob_epico: sel = PieceRes.PieceRarity.EPICO
	else: sel = PieceRes.PieceRarity.LEGENDARIO
	
	var p = _pick_from_pool(sel)
	if not p: p = _pick_from_pool(PieceRes.PieceRarity.COMUN)
	if not p:
		for pool in _pieces_by_rarity.values():
			if not pool.is_empty(): return pool.pick_random()
	return p

func _pick_from_pool(rarity: int) -> Resource:
	if _pieces_by_rarity.has(rarity) and not _pieces_by_rarity[rarity].is_empty():
		return _pieces_by_rarity[rarity].pick_random()
	return null