extends Control

signal item_sold(refund_amount: int)

## ------------------------------------------------------------------
## Nodos y Exportaciones
## ------------------------------------------------------------------
@onready var piece_inventory: GridContainer = $piece_inventory
@onready var passive_inventory: GridContainer = $passive_inventory
@onready var refund_percent: int = 50
@onready var health_label: Label = $TextureRect3/Health_container/Label
@onready var damage_label: Label = $TextureRect3/Damage_container/Label
@onready var speed_label: Label = $TextureRect3/SpeedCOntainer/Label
@onready var crit_chance_label: Label = $TextureRect3/CChance_container/Label
@onready var crit_damage_label: Label = $TextureRect3/CDamage_chance/Label

@export var max_pieces: int = 6
@export var max_passives: int = 30
@export var inventory_slot_scene: PackedScene 
@export var piece_scene: PackedScene

@export var max_piece_copies: int = 3
@export var initial_pieces: Array[PieceData] 

# --- NUEVO: Configuración de Pasivas Graduable ---
@export_group("Passive Logic")
# Cuánto se suma al multiplicador por cada slot vacío.
# 1.0 significa que cada hueco vacío añade un 100% más de stats (x2, x3, etc).
# 0.5 significaría que añade un 50% (x1.5, x2.0, etc).
@export var empty_slot_bonus_per_slot: float = 1.0 

## ------------------------------------------------------------------
## Datos del Inventario
## ------------------------------------------------------------------
var piece_counts: Dictionary = {}
var passive_counts: Dictionary = {}

var piece_slots: Array[Node] = []
var passive_slots: Array[Node] = []

## ------------------------------------------------------------------
## Funciones de Godot
## ------------------------------------------------------------------

func _ready() -> void:
	GlobalSignals.item_deleted.connect(remove_item)
	GlobalSignals.item_return_to_inventory_requested.connect(_on_item_return_requested)

	# Conexiones para actualizar stats cuando la ruleta cambia
	GlobalSignals.piece_placed_on_roulette.connect(_on_piece_placed)
	GlobalSignals.piece_returned_from_roulette.connect(_on_piece_returned)
	
	_update_passive_stats_display()
	if not inventory_slot_scene:
		push_error("¡La variable 'Inventory Slot Scene' no está asignada en el script Inventory.gd!")
		return

	_initialize_slots(piece_inventory, piece_slots, max_pieces, refund_percent)
	_initialize_slots(passive_inventory, passive_slots, max_passives, 0)

	print("Inventory _ready: Generados %d slots de piezas y %d slots de pasivos." % [piece_slots.size(), passive_slots.size()])

## ------------------------------------------------------------------
## Funciones Públicas 
## ------------------------------------------------------------------

func get_random_initial_piece() -> PieceData:
	if initial_pieces.is_empty():
		return null
	
	var shuffled = initial_pieces.duplicate()
	shuffled.shuffle()
	return shuffled[0]

func set_interactive(is_interactive: bool):
	for slot in piece_slots:
		if slot.has_node("TextureButton"):
			slot.get_node("TextureButton").disabled = not is_interactive

func can_add_item(data: Resource) -> bool:
	var context = _get_inventory_context(data)
	if not context:
		return false

	var id: String = _get_item_id(data)
	
	if data is PieceData:
		if context.map.has(id):
			var current_count = context.map[id]["count"]
			if current_count >= max_piece_copies:
				return false

	var can_stack = context.map.has(id)
	var has_empty_slot = _find_empty_slot(context.slots) != null
	
	return can_stack or has_empty_slot

func get_item_count(target_res: Resource) -> int:
	if not target_res:
		return 0
	
	var search_res = target_res
	if target_res is PieceData:
		search_res = target_res.piece_origin
	
	if search_res is PieceRes:
		for id in piece_counts:
			var entry = piece_counts[id]
			var data = entry["data"]
			if data is PieceData and data.piece_origin == search_res:
				return entry["count"]

	elif target_res is PassiveData:
		var target_id = _get_item_id(target_res)
		if passive_counts.has(target_id):
			return passive_counts[target_id]["count"]
		
		for id in passive_counts:
			var entry = passive_counts[id]
			var data = entry["data"]
			if data == target_res: 
				return entry["count"]
	
	return 0

func add_item(data: Resource, amount: int = 1) -> bool:
	if not data:
		push_error("add_item: Se intentó añadir un item NULO.")
		return false
		
	print("--- add_item() llamado con: %s (Cantidad: %d) ---" % [data.resource_name, amount])

	var context = _get_inventory_context(data)
	var id: String = _get_item_id(data)
	var inventory_map = context.map
	var final_amount = amount

	# --- LÓGICA DE LÍMITE DE COPIAS ---
	if data is PieceData:
		var current_count = 0
		if inventory_map.has(id):
			current_count = inventory_map[id]["count"]
		
		if current_count >= max_piece_copies:
			print("... FALLO: Límite de %d copias ya alcanzado." % max_piece_copies)
			return false
		
		if (current_count + amount) > max_piece_copies:
			final_amount = max_piece_copies - current_count
			print("... ADVERTENCIA: Se comprarán %d en lugar de %d para no superar el límite." % [final_amount, amount])

	if final_amount <= 0:
		print("... FALLO: No hay nada que añadir (probablemente por el límite).")
		return false
	# ----------------------------------

	var can_stack = inventory_map.has(id)
	var has_empty_slot = _find_empty_slot(context.slots) != null

	if not can_stack and not has_empty_slot:
		print("... FALLO: No hay slot vacío para un item nuevo. Inventario probablemente lleno.")
		return false

	# --- CASO 1: APILAR EN SLOT EXISTENTE ---
	if inventory_map.has(id):
		print("... Item ya existe. Apilando %d." % final_amount)
		var entry = inventory_map[id]
		entry["count"] += final_amount
		var slot_node: Node = entry["slot_node"]
		if slot_node and slot_node.has_method("update_count"):
			slot_node.update_count(entry["count"])
		if context.is_passive:
			_update_passive_stats_display()
			
		# --- ¡NUEVO! Notificar cambio de cantidad (Stack) ---
		if data is PieceData:
			GlobalSignals.piece_count_changed.emit(data, entry["count"])
		# ----------------------------------------------------
			
		return true

	# --- CASO 2: SLOT NUEVO ---
	var empty_slot: Node = _find_empty_slot(context.slots)
	
	if empty_slot:
		print("... Item nuevo. Slot vacío encontrado. Asignando %d." % final_amount)
		
		if data is PieceData:
			# Aseguramos que tenemos la referencia de cuántos usos son el máximo
			if not data.has_meta("max_uses"):
				data.set_meta("max_uses", data.uses)
		
		if empty_slot.has_method("set_item"):
			empty_slot.set_item(data)

		if empty_slot.has_method("update_count"):
			empty_slot.update_count(final_amount)

		var new_entry = {
			"count": final_amount,
			"data": data,
			"slot_node": empty_slot 
		}
		inventory_map[id] = new_entry
		if context.is_passive:
			_update_passive_stats_display()
			
		if data is PieceData:
			GlobalSignals.piece_count_changed.emit(data, new_entry["count"])
			
		return true


	print("... FALLO INESPERADO: No se pudo apilar ni encontrar slot vacío.")
	return false

## ------------------------------------------------------------------
## Funciones de Eliminación de Items
## ------------------------------------------------------------------

func decrement_item(data: Resource):
	var context = _get_inventory_context(data)
	if not context:
		push_warning("decrement_item: Tipo de data no reconocido.")
		return false

	var id: String = _get_item_id(data)
	var inventory_map = context.map

	if not inventory_map.has(id):
		push_error("decrement_item: Se intentó decrementar un item ('%s') que no está en el inventario." % id)
		return false

	var entry = inventory_map[id]
	entry["count"] -= 1
	
	print("... Item encontrado. Reduciendo contador a: %d" % entry["count"])

	var slot_node: Node = entry["slot_node"]

	if entry["count"] > 0:
		if slot_node and slot_node.has_method("update_count"):
			slot_node.update_count(entry["count"])
		else:
			push_error("decrement_item: El slot_node es inválido o no tiene update_count().")
	else:
		if slot_node and slot_node.has_method("clear_slot"):
			slot_node.clear_slot()
		else:
			push_error("decrement_item: El slot_node es inválido o no tiene clear_slot().")
		
		inventory_map.erase(id)
		print("... Contador a cero. Eliminando item del diccionario.")
		
		if context.is_passive:
			_compact_passive_slots()
			_update_passive_stats_display()

	return true

func remove_item(item_data: Resource):
	return _remove_item_stack(item_data, true)

func remove_item_no_money(item_data: Resource):
	push_warning("inventory.gd: remove_item_no_money() fue llamada.")
	return _remove_item_stack(item_data, false)


## ------------------------------------------------------------------
## Funciones Privadas / Auxiliares
## ------------------------------------------------------------------

func _remove_item_stack(item_data: Resource, with_refund: bool) -> bool:
	var context = _get_inventory_context(item_data)
	if not context:
		push_warning("_remove_item_stack: Tipo de data no reconocido.")
		return false

	var id: String = _get_item_id(item_data)
	var inventory_map = context.map

	if not inventory_map.has(id):
		push_error("_remove_item_stack: Se intentó eliminar un item ('%s') que no está en el inventario." % id)
		return false

	var entry = inventory_map[id]
	var total_count = entry["count"]
	
	print("... Item encontrado. Eliminando %d copias." % total_count)

	if with_refund and "price" in item_data and item_data.price > 0:
		var refund_amount = (int(item_data.price * (refund_percent / 100.0)) * total_count)
		item_sold.emit(refund_amount)
		print("... Reembolsados %d de oro (%d%% de %d x %d copias)" % [refund_amount, refund_percent, item_data.price, total_count])
	else:
		print("... Eliminando sin reembolso.")

	var slot_node: Node = entry["slot_node"]

	if slot_node and slot_node.has_method("clear_slot"):
		slot_node.clear_slot()
	else:
		push_error("_remove_item_stack: El slot_node es inválido o no tiene clear_slot().")
	
	inventory_map.erase(id)
	print("... Contador a cero. Eliminando item del diccionario.")
	
	if item_data is PieceData:
		# --- CORRECCIÓN: RESETEAR USOS AL VENDER ---
		if item_data.has_meta("max_uses"):
			item_data.uses = item_data.get_meta("max_uses")
			print("... Usos de la pieza reseteados a %d (Máximo) tras la venta." % item_data.uses)
		# -------------------------------------------
		
		GlobalSignals.piece_type_deleted.emit(item_data)
	
	if context.is_passive:
		_compact_passive_slots()
		_update_passive_stats_display()
	return true

func _get_inventory_context(data: Resource) -> Dictionary:
	if data is PieceData: 
		return { "map": piece_counts, "slots": piece_slots, "is_passive": false }
	elif data is PassiveData:
		return { "map": passive_counts, "slots": passive_slots, "is_passive": true }
	
	return {}

func _initialize_slots(container: GridContainer, slot_array: Array, count: int, sell_perc: int) -> void:
	for i in range(count):
		var new_slot = inventory_slot_scene.instantiate()
		if sell_perc > 0:
			new_slot.sell_percentage = sell_perc
			
		container.add_child(new_slot)
		slot_array.append(new_slot) 
		
		if new_slot.has_signal("item_selected"):
			new_slot.item_selected.connect(_on_item_selected_from_slot)

func _find_empty_slot(slot_array: Array) -> Node:
	for slot in slot_array:
		if slot.has_method("is_empty") and slot.is_empty():
			return slot
	return null 

func _get_item_id(data: Resource) -> String:
	if data.resource_path.is_empty() == false:
		return data.resource_path
	return "%s_%d" % [data.get_class(), data.get_instance_id()]

func _compact_passive_slots() -> void:
	print("--- Compactando slots de pasivos... ---")
	
	for i in range(passive_slots.size() - 1):
		var current_slot: Node = passive_slots[i]
		
		if not current_slot.is_empty():
			continue
			
		var next_item_slot: Node = null
		var next_item_index = -1
		
		for j in range(i + 1, passive_slots.size()):
			if not passive_slots[j].is_empty():
				next_item_slot = passive_slots[j]
				next_item_index = j
				break
		
		if next_item_slot:
			print("... Moviendo item del slot %d al slot %d" % [next_item_index, i])
			
			var item_data_to_move: Resource = next_item_slot.item_data
			var item_count: int = next_item_slot.current_count
			
			current_slot.set_item(item_data_to_move)
			current_slot.update_count(item_count)
			
			next_item_slot.clear_slot()
			
			var id = _get_item_id(item_data_to_move)
			if passive_counts.has(id):
				passive_counts[id]["slot_node"] = current_slot
			else:
				push_warning("Compactar: El item movido no estaba en passive_counts.")
				
		else:
			print("... No se encontraron más items. Compactado finalizado.")
			break

## ------------------------------------------------------------------
## Conexiones de Señales
## ------------------------------------------------------------------

func _on_item_selected_from_slot(data: Resource) -> void:
	if data:
		print("Has seleccionado el item: ", data.resource_name)

func _on_item_return_requested(item_data_packet: Variant, on_complete_callback: Callable):
	if not (item_data_packet is Dictionary and "data" in item_data_packet and "count" in item_data_packet):
		push_error("item_return_requested: Se recibieron datos inválidos.")
		if on_complete_callback.is_valid():
			on_complete_callback.call(false) 
		return

	var item_data: Resource = item_data_packet.data
	var item_count: int = item_data_packet.count
	
	var success: bool = add_item(item_data, item_count)
	
	if on_complete_callback.is_valid():
		on_complete_callback.call(success)


# --- CONTROL DE USOS Y REFRESCO DE STATS ---

func _on_piece_placed(piece_data: PieceData):
	if not piece_data: return
	if not piece_data is PieceData: return

	piece_data.uses = max(0, piece_data.uses - 1)
	print("... Pieza '%s' colocada. Usos restantes: %d" % [piece_data.resource_name, piece_data.uses])

	_update_slot_visuals_for_piece(piece_data)
	
	# Diferimos la actualización para dar tiempo a que la variable 'occupied' del slot cambie
	call_deferred("_update_passive_stats_display")

func _on_piece_returned(piece_data: PieceData):
	if not piece_data: return
	if not piece_data is PieceData: return
		
	piece_data.uses += 1
	print("... Pieza '%s' devuelta. Usos restantes: %d" % [piece_data.resource_name, piece_data.uses])

	_update_slot_visuals_for_piece(piece_data)
	
	var id = _get_item_id(piece_data)
	if piece_counts.has(id):
		var entry = piece_counts[id]
		var target_slot_node = entry["slot_node"]
		
		if target_slot_node:
			var start_pos = get_global_mouse_position()
			_play_arena_return_effect(piece_data, start_pos, target_slot_node)
	# -----------------------------------------
	
	call_deferred("_update_passive_stats_display")


func _update_slot_visuals_for_piece(piece_data: PieceData):
	var id = _get_item_id(piece_data)
	if piece_counts.has(id):
		var entry = piece_counts[id]
		var slot_node: Node = entry["slot_node"]
		
		# Aquí nos aseguramos de llamar a la función del slot que actualiza la imagen (1.png, 2.png...)
		if slot_node and slot_node.has_method("_update_uses"):
			slot_node._update_uses(piece_data)
	else:
		push_error("_update_slot_visuals_for_piece: La pieza no se encontró en piece_counts.")


# --- MODIFICADO: Cálculo de Stats con Multiplicador Graduable ---
func _update_passive_stats_display() -> void:
	
	var total_health: float = 0.0
	var total_damage: float = 0.0
	var total_speed: float = 0.0
	var total_crit_chance: float = 0.0
	var total_crit_damage: float = 0.0

	# 1. Contar huecos vacíos
	var empty_slots_count = float(_get_empty_roulette_slots())
	
	# 2. Calcular multiplicador
	# Fórmula: Base (1.0) + (Huecos * Bonus)
	var multiplier: float = 1.0 + (empty_slots_count * empty_slot_bonus_per_slot)

	for item_id in passive_counts:
		var entry = passive_counts[item_id]
		var data: PassiveData = entry.data
		var count: int = entry.count
		
		if not data:
			continue
		
		if not data is PassiveData:
			continue
		
		# 3. Aplicar la fórmula: (ValorBase * CantidadItems) * Multiplicador
		var total_value_for_item = (data.value * count) * multiplier
		
		match data.type:
			PassiveData.PassiveType.HEALTH_INCREASE:
				total_health += total_value_for_item
			PassiveData.PassiveType.BASE_DAMAGE_INCREASE:
				total_damage += total_value_for_item
			PassiveData.PassiveType.ATTACK_SPEED_INCREASE:
				total_speed += total_value_for_item
			PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE:
				total_crit_chance += total_value_for_item
			PassiveData.PassiveType.CRITICAL_DAMAGE_INCREASE:
				total_crit_damage += total_value_for_item
			
	health_label.text = "+%s" % str(total_health)
	damage_label.text = "+%s" % str(total_damage)
	speed_label.text = "+%s" % str(total_speed) 
	crit_chance_label.text = "+%s" % str(total_crit_chance)
	crit_damage_label.text = "+%s" % str(total_crit_damage)
	
	var stats_payload := {
		"health": total_health,
		"damage": total_damage,
		"speed": total_speed,
		"crit_chance": total_crit_chance,
		"crit_damage": total_crit_damage
	}
	
	if has_node("/root/GlobalStats"):
		GlobalStats.update_stats(stats_payload)

# --- Función auxiliar para contar slots ---
func _get_empty_roulette_slots() -> int:
	if not has_node("/root/GlobalStats") or not is_instance_valid(GlobalStats.roulette_scene_ref):
		return 0
	
	var ruleta = GlobalStats.roulette_scene_ref
	
	if not "slots_container" in ruleta or not ruleta.slots_container:
		return 0
		
	var container = ruleta.slots_container
	var empty_count = 0
	
	for slot_root in container.get_children():
		if slot_root.has_node("slot"):
			var actual_slot = slot_root.get_node("slot")
			if "occupied" in actual_slot and not actual_slot.occupied:
				empty_count += 1
				
	return empty_count
	
# --- EFECTOS VISUALES (ESTILO ROMA/ARENA) ---

# En GameOff2025-SandwishStudio/scripts/inventory.gd

func _play_arena_return_effect(item_data: Resource, start_pos: Vector2, target_slot: Node):
	if not item_data or not "icon" in item_data: return
	
	# --- CORRECCIÓN DE PUNTERÍA ---
	var target_pos = Vector2.ZERO
	
	# 1. Intentamos buscar el icono específico dentro del slot para ser precisos
	if "item_icon" in target_slot and target_slot.item_icon and target_slot.item_icon.visible:
		# Obtenemos el centro EXACTO de la imagen en pantalla
		target_pos = target_slot.item_icon.get_global_rect().get_center()
	else:
		# Fallback: Si no encontramos el icono, vamos al centro del slot
		target_pos = target_slot.get_global_rect().get_center()
	# -----------------------------

	var effect_root = Node2D.new()
	effect_root.z_index = 4096 
	get_tree().root.add_child(effect_root)
	
	# 2. Sprite de la pieza
	var sprite = Sprite2D.new()
	sprite.texture = item_data.icon
	# Ajustamos la escala inicial para que coincida con el tamaño del icono en el inventario
	# (Un poco más grande al principio para que se note)
	sprite.scale = Vector2(0.9, 0.9) 
	sprite.position = Vector2.ZERO 
	effect_root.add_child(sprite)
	
	# 3. Partículas (Igual que antes)
	var particles = CPUParticles2D.new()
	particles.amount = 25
	particles.lifetime = 0.5
	particles.local_coords = false 
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 15.0
	particles.direction = Vector2(-1, 0)
	particles.spread = 180.0
	particles.gravity = Vector2(0, 50)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.95, 0.8, 0.3) 
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.95, 0.8, 0.3, 1.0))
	gradient.set_color(1, Color(0.95, 0.8, 0.3, 0.0))
	particles.color_ramp = gradient
	effect_root.add_child(particles)
	particles.emitting = true

	# 4. Cálculo de la Curva (Trayectoria)
	var p0 = start_pos
	var p2 = target_pos
	
	# Calculamos la altura del arco basándonos en la distancia
	var distance = p0.distance_to(p2)
	var arc_height = min(distance * 0.5, 300.0) * -1.0 # Negativo es hacia arriba
	
	# Punto de control P1
	var center_x = (p0.x + p2.x) / 2.0
	# Usamos el punto más alto entre los dos y sumamos la altura del arco
	var base_y = min(p0.y, p2.y) 
	var p1 = Vector2(center_x, base_y + arc_height)
	
	# 5. Animación
	var t = create_tween()
	t.set_parallel(true)
	
	# Movimiento curvo
	t.tween_method(func(val): 
		effect_root.global_position = _bezier_quadratic(p0, p1, p2, val), 
		0.0, 1.0, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	
	# Rotación
	t.tween_property(sprite, "rotation", deg_to_rad(360), 0.55).set_ease(Tween.EASE_OUT)
	
	# Escala: Hace un "zoom" hacia la cámara y luego se ajusta al tamaño final
	var t_scale = create_tween()
	t_scale.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.25).set_ease(Tween.EASE_OUT)
	# Al final se encoge para "entrar" en el slot (un poco más pequeño que 1.0 para que no tape el borde)
	t_scale.chain().tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.3).set_ease(Tween.EASE_IN)

	# 6. Finalización
	t.chain().tween_callback(func():
		particles.emitting = false
		sprite.visible = false # Ocultamos el sprite inmediatamente al llegar
		
		# Limpieza diferida para dejar terminar las partículas
		var cleanup = create_tween()
		cleanup.tween_interval(0.6)
		cleanup.tween_callback(effect_root.queue_free)
		
		_play_slot_impact(target_slot)
	)
	
# --- FUNCIONES AUXILIARES (Añadir al final de inventory.gd) ---

# Función matemática para calcular la curva suave
func _bezier_quadratic(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)

# Efecto de golpe visual en el slot cuando recibe la pieza
func _play_slot_impact(slot_node: Node):
	if not slot_node: return
	
	# 1. Flash blanco
	var original_modulate = slot_node.modulate
	slot_node.modulate = Color(2.0, 2.0, 1.5) # Brillo intenso
	
	var t = create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_ELASTIC)
	t.set_ease(Tween.EASE_OUT)
	
	# 2. Temblor / Aplastamiento
	# Usamos scale para que no rompa el layout del grid
	slot_node.scale = Vector2(1.3, 0.7) 
	t.tween_property(slot_node, "scale", Vector2.ONE, 0.4)
	
	# Recuperar color normal
	t.tween_property(slot_node, "modulate", original_modulate, 0.3)
