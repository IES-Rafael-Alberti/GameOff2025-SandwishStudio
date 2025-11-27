extends Control

signal item_sold(refund_amount: int)

## ------------------------------------------------------------------
## Nodos y Exportaciones
## ------------------------------------------------------------------
@onready var piece_inventory: GridContainer = $piece_inventory
@onready var passive_inventory: Control = $passive_inventory 
@onready var refund_percent: int = 50
# Asegúrate de que la ruta al Tooltip sea correcta. Si es hijo directo de Inventory: $Tooltip
@onready var tooltip = $passive_inventory/Tooltip 

# Etiquetas de Stats
@onready var health_label: Label = $TextureRect3/Health_container/Label
@onready var damage_label: Label = $TextureRect3/Damage_container/Label
@onready var speed_label: Label = $TextureRect3/SpeedCOntainer/Label
@onready var crit_chance_label: Label = $TextureRect3/CChance_container/Label
@onready var crit_damage_label: Label = $TextureRect3/CDamage_chance/Label

@export var max_pieces: int = 6
# @export var max_passives: int = 30 # YA NO SE USA PARA INSTANCIAR
@export var inventory_slot_scene: PackedScene 
@export var piece_scene: PackedScene

@export var max_piece_copies: int = 3
@export var initial_pieces: Array[PieceData] 

@export_group("Passive Logic")
@export var empty_slot_bonus_per_slot: float = 1.0 

## ------------------------------------------------------------------
## Datos del Inventario
## ------------------------------------------------------------------
var piece_counts: Dictionary = {}
# passive_counts ahora es un espejo de PlayerData.owned_passives para cálculos locales de stats
var passive_counts: Dictionary = {} 

var piece_slots: Array[Node] = []
# var passive_visual_slots: Array[TextureRect] = [] # YA NO SE USA (Son estáticos)
var passive_nodes_map: Dictionary = {}

## ------------------------------------------------------------------
## Funciones de Godot
## ------------------------------------------------------------------

func _ready() -> void:
	GlobalSignals.item_deleted.connect(remove_item)
	GlobalSignals.item_return_to_inventory_requested.connect(_on_item_return_requested)

	# Conexiones para actualizar stats cuando la ruleta cambia
	GlobalSignals.piece_placed_on_roulette.connect(_on_piece_placed)
	GlobalSignals.piece_returned_from_roulette.connect(_on_piece_returned)
	
	if not inventory_slot_scene:
		push_error("¡La variable 'Inventory Slot Scene' no está asignada en el script Inventory.gd!")
		return

	# 1. Inicializar Slots de Piezas (Grid dinámico estándar)
	_initialize_piece_slots(piece_inventory, piece_slots, max_pieces, refund_percent)
	
	# 2. Configurar Pasivas Estáticas (Mapeo y Señales)
	_setup_passive_nodes()
	
	# 3. Restaurar estado visual de pasivas desde PlayerData (Persistencia)
	_sync_passives_from_global()
	
	_update_passive_stats_display()
	
	print("Inventory _ready: Generados %d slots de piezas." % [piece_slots.size()])


## ------------------------------------------------------------------
## Inicialización y Sincronización (MODIFICADO)
## ------------------------------------------------------------------

func _initialize_piece_slots(container: GridContainer, slot_array: Array, count: int, sell_perc: int) -> void:
	for i in range(count):
		var new_slot = inventory_slot_scene.instantiate()
		if sell_perc > 0:
			new_slot.sell_percentage = sell_perc
		container.add_child(new_slot)
		slot_array.append(new_slot) 
		if new_slot.has_signal("item_selected"):
			new_slot.item_selected.connect(_on_item_selected_from_slot)

# --- NUEVO: Configuración de Nodos Estáticos ---
func _setup_passive_nodes() -> void:
	# Vinculamos el Enum con el nodo en la escena
	# NOTA: Asegúrate de que estos nodos existen en tu escena dentro de 'passive_inventory'
	passive_nodes_map = {
		PassiveData.PassiveType.HEALTH_INCREASE: $passive_inventory/health,
		PassiveData.PassiveType.BASE_DAMAGE_INCREASE: $passive_inventory/damage,
		PassiveData.PassiveType.ATTACK_SPEED_INCREASE: $passive_inventory/aspeed,
		PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE: $passive_inventory/cchance,
		PassiveData.PassiveType.CRITICAL_DAMAGE_INCREASE: $passive_inventory/cdamage
	}
	
	# Configuración inicial: Ocultar y conectar Tooltip
	for type in passive_nodes_map:
		var node = passive_nodes_map[type]
		if node:
			node.visible = false # Los ocultamos al inicio
			node.mouse_filter = Control.MOUSE_FILTER_STOP # Asegurar que detecta el ratón
			
			# Conectamos las señales para el Tooltip de resumen
			if not node.mouse_entered.is_connected(_on_passive_inventory_mouse_entered):
				node.mouse_entered.connect(_on_passive_inventory_mouse_entered)
			if not node.mouse_exited.is_connected(_on_passive_inventory_mouse_exited):
				node.mouse_exited.connect(_on_passive_inventory_mouse_exited)

func _sync_passives_from_global() -> void:
	# Copiamos datos de PlayerData
	passive_counts = PlayerData.owned_passives.duplicate(true)
	
	# Reconstruimos visuales
	for id in passive_counts:
		var entry = passive_counts[id]
		var data = entry["data"]
		# Si tenemos al menos 1, activamos su icono correspondiente
		if entry["count"] > 0:
			_activate_passive_visual(data.type)

func _activate_passive_visual(type: int) -> void:
	if passive_nodes_map.has(type):
		var node = passive_nodes_map[type]
		if node:
			node.visible = true

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
	var id: String = _get_item_id(data)
	
	if data is PieceData:
		var context = _get_inventory_context(data)
		if not context: return false
		
		if context.map.has(id):
			var current_count = context.map[id]["count"]
			if current_count >= max_piece_copies:
				return false

		var can_stack = context.map.has(id)
		var has_empty_slot = _find_empty_slot(context.slots) != null
		
		return can_stack or has_empty_slot

	elif data is PassiveData:
		# Lógica Pasivas: Siempre se pueden comprar (se apilan stats)
		return true 
			
	return false

func get_item_count(target_res: Resource) -> int:
	if not target_res: return 0
	
	# 1. Comprobación de PASIVAS
	if target_res is PassiveData:
		return PlayerData.get_passive_count_global(target_res)
	
	# 2. Comprobación de PIEZAS
	var search_res = target_res
	if target_res is PieceData:
		search_res = target_res.piece_origin
	
	if search_res is PieceRes:
		for id in piece_counts:
			var entry = piece_counts[id]
			var data = entry["data"]
			if data is PieceData and data.piece_origin == search_res:
				return entry["count"]
	
	return 0

func add_item(data: Resource, amount: int = 1) -> bool:
	if not data:
		push_error("add_item: Se intentó añadir un item NULO.")
		return false
		
	print("--- add_item() llamado con: %s (Cantidad: %d) ---" % [data.resource_name, amount])

	var id: String = _get_item_id(data)

	# --- LÓGICA DE PASIVAS (MODIFICADA) ---
	if data is PassiveData:
		# 1. Guardar en PlayerData (Base de datos global)
		PlayerData.add_passive_global(data, amount)
		
		# 2. Actualizar espejo local
		if passive_counts.has(id):
			passive_counts[id]["count"] += amount
		else:
			passive_counts[id] = { "data": data, "count": amount }
			# Es nueva, activamos el nodo visual estático
			_activate_passive_visual(data.type)
			
		_update_passive_stats_display()
		
		# Si el ratón ya está encima, actualizamos el tooltip al momento
		if tooltip and tooltip.visible:
			_on_passive_inventory_mouse_entered()
			
		return true

	# --- LÓGICA DE PIEZAS (ORIGINAL) ---
	var context = _get_inventory_context(data)
	if not context: return false
	
	var inventory_map = context.map
	var final_amount = amount

	# Límite de copias
	var current_count = 0
	if inventory_map.has(id):
		current_count = inventory_map[id]["count"]
	
	if current_count >= max_piece_copies:
		print("... FALLO: Límite de %d copias ya alcanzado." % max_piece_copies)
		return false
	
	if (current_count + amount) > max_piece_copies:
		final_amount = max_piece_copies - current_count
		print("... ADVERTENCIA: Se comprarán %d en lugar de %d para no superar el límite." % [final_amount, amount])

	if final_amount <= 0: return false

	# Caso 1: Apilar
	if inventory_map.has(id):
		print("... Item ya existe. Apilando %d." % final_amount)
		var entry = inventory_map[id]
		entry["count"] += final_amount
		var slot_node: Node = entry["slot_node"]
		
		if slot_node and slot_node.has_method("update_count"):
			slot_node.update_count(entry["count"])
			
		GlobalSignals.piece_count_changed.emit(data, entry["count"])
		return true

	# Caso 2: Slot Nuevo
	var empty_slot: Node = _find_empty_slot(context.slots)
	
	if empty_slot:
		print("... Item nuevo. Slot vacío encontrado.")
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
		GlobalSignals.piece_count_changed.emit(data, new_entry["count"])
		return true

	print("... FALLO INESPERADO: No se pudo apilar ni encontrar slot vacío.")
	return false

# --- FUNCIONES DE VISUALES PASIVAS (Ya no usamos _display_passive_visual dinámica) ---
# (Función eliminada porque usamos _activate_passive_visual con el mapa estático)

## ------------------------------------------------------------------
## Funciones de Eliminación de Items (SOLO PIEZAS)
## ------------------------------------------------------------------

func decrement_item(data: Resource):
	if data is PassiveData:
		return false
		
	var context = _get_inventory_context(data)
	if not context: return false

	var id: String = _get_item_id(data)
	var inventory_map = context.map

	if not inventory_map.has(id):
		push_error("decrement_item: Item '%s' no encontrado." % id)
		return false

	var entry = inventory_map[id]
	entry["count"] -= 1
	
	print("... Reduciendo contador a: %d" % entry["count"])
	var slot_node: Node = entry["slot_node"]

	if entry["count"] > 0:
		if slot_node and slot_node.has_method("update_count"):
			slot_node.update_count(entry["count"])
	else:
		if slot_node and slot_node.has_method("clear_slot"):
			slot_node.clear_slot()
		inventory_map.erase(id)
		print("... Contador a cero. Eliminado.")

	return true

func remove_item(item_data: Resource):
	if item_data is PassiveData:
		print("remove_item: Ignorado para pasiva.")
		return false
	return _remove_item_stack(item_data, true)

func remove_item_no_money(item_data: Resource):
	if item_data is PassiveData:
		return false
	return _remove_item_stack(item_data, false)

## ------------------------------------------------------------------
## Funciones Privadas / Auxiliares
## ------------------------------------------------------------------

func _remove_item_stack(item_data: Resource, with_refund: bool) -> bool:
	if not (item_data is PieceData): return false

	var context = _get_inventory_context(item_data)
	if not context: return false

	var id: String = _get_item_id(item_data)
	var inventory_map = context.map

	if not inventory_map.has(id):
		push_error("_remove_item_stack: Item no encontrado.")
		return false

	var entry = inventory_map[id]
	var total_count = entry["count"]
	
	print("... Eliminando %d copias." % total_count)

	if with_refund and "price" in item_data and item_data.price > 0:
		var refund_amount = (int(item_data.price * (refund_percent / 100.0)) * total_count)
		item_sold.emit(refund_amount)
		print("... Reembolsados %d de oro." % refund_amount)

	var slot_node: Node = entry["slot_node"]
	if slot_node and slot_node.has_method("clear_slot"):
		slot_node.clear_slot()
	
	inventory_map.erase(id)
	
	# Resetear usos al vender/eliminar
	if item_data.has_meta("max_uses"):
		item_data.uses = item_data.get_meta("max_uses")
		
	GlobalSignals.piece_type_deleted.emit(item_data)
	return true

func _get_inventory_context(data: Resource) -> Dictionary:
	if data is PieceData: 
		return { "map": piece_counts, "slots": piece_slots }
	return {}

func _find_empty_slot(slot_array: Array) -> Node:
	for slot in slot_array:
		if slot.has_method("is_empty") and slot.is_empty():
			return slot
	return null 

func _get_item_id(data: Resource) -> String:
	if data.resource_path.is_empty() == false:
		return data.resource_path
	return "%s_%d" % [data.get_class(), data.get_instance_id()]

## ------------------------------------------------------------------
## Conexiones de Señales
## ------------------------------------------------------------------

func _on_item_selected_from_slot(data: Resource) -> void:
	if data:
		print("Has seleccionado el item: ", data.resource_name)

func _on_item_return_requested(item_data_packet: Variant, on_complete_callback: Callable):
	if not (item_data_packet is Dictionary and "data" in item_data_packet and "count" in item_data_packet):
		if on_complete_callback.is_valid(): on_complete_callback.call(false) 
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
	print("... Pieza colocada. Usos restantes: %d" % piece_data.uses)

	_update_slot_visuals_for_piece(piece_data)
	call_deferred("_update_passive_stats_display")

func _on_piece_returned(piece_data: PieceData):
	if not piece_data: return
	if not piece_data is PieceData: return
		
	piece_data.uses += 1
	print("... Pieza devuelta. Usos restantes: %d" % piece_data.uses)

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
		
		if slot_node and slot_node.has_method("_update_uses"):
			slot_node._update_uses(piece_data)

# --- CÁLCULO DE STATS ---
func _update_passive_stats_display() -> void:
	
	var total_health: float = 0.0
	var total_damage: float = 0.0
	var total_speed: float = 0.0
	var total_crit_chance: float = 0.0
	var total_crit_damage: float = 0.0

	var empty_slots_count = float(_get_empty_roulette_slots())
	var multiplier: float = 1.0 + (empty_slots_count * empty_slot_bonus_per_slot)

	for item_id in passive_counts:
		var entry = passive_counts[item_id]
		var data: PassiveData = entry.data
		var count: int = entry.count
		
		if not data: continue
		
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

func _play_arena_return_effect(item_data: Resource, start_pos: Vector2, target_slot: Node):
	if not item_data or not "icon" in item_data: return

	var target_pos = Vector2.ZERO
	
	if "item_icon" in target_slot and target_slot.item_icon and target_slot.item_icon.visible:

		target_pos = target_slot.item_icon.get_global_rect().get_center()
	else:
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

# --- HANDLERS DEL TOOLTIP (CONECTADOS EN _setup_passive_nodes) ---
func _on_passive_inventory_mouse_entered() -> void:
	if not tooltip: return
	
	# 1. Recalcular el multiplicador actual al vuelo
	var empty_slots_count = float(_get_empty_roulette_slots())
	var multiplier: float = 1.0 + (empty_slots_count * empty_slot_bonus_per_slot)
	
	# 2. Llamar a la nueva función del Tooltip pasando todos los datos
	tooltip.show_passive_summary(passive_counts, multiplier)

func _on_passive_inventory_mouse_exited() -> void:
	if tooltip:
		tooltip.hide_tooltip()
