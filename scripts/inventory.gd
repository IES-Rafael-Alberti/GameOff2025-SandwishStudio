extends Control

signal item_sold(refund_amount: int)

## ------------------------------------------------------------------
## Nodos y Exportaciones
## ------------------------------------------------------------------
@onready var piece_inventory: GridContainer = $piece_inventory
@onready var passive_inventory: Control = $passive_inventory 
@onready var refund_percent: int = 50

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
var passive_visual_slots: Array[TextureRect] = [] # Aquí guardaremos referencias a los 5 TextureRect fijos

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
	
	# 2. Inicializar Slots de Pasivas (Referencias a los nodos visuales fijos)
	_initialize_passive_visuals()
	
	# 3. Restaurar estado visual de pasivas desde PlayerData (Persistencia)
	_sync_passives_from_global()
	
	_update_passive_stats_display()
	
	print("Inventory _ready: Generados %d slots de piezas. Pasivas gestionadas visualmente." % [piece_slots.size()])


## ------------------------------------------------------------------
## Inicialización y Sincronización (NUEVO)
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

func _initialize_passive_visuals() -> void:
	# Recogemos los TextureRect que ya existen en la escena dentro de passive_inventory
	# Suponemos que son hijos directos y son de tipo TextureRect
	for child in passive_inventory.get_children():
		if child is TextureRect:
			passive_visual_slots.append(child)
			# Los ocultamos o limpiamos inicialmente
			child.texture = null
			child.visible = false 

func _sync_passives_from_global() -> void:
	# Copiamos datos de PlayerData
	passive_counts = PlayerData.owned_passives.duplicate(true)
	
	# Reconstruimos visuales
	for id in passive_counts:
		var entry = passive_counts[id]
		var data = entry["data"]
		# Mostramos visualmente la pasiva si tenemos al menos 1
		if entry["count"] > 0:
			_display_passive_visual(data)

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
		# Lógica Pasivas: Siempre se pueden comprar para stats, 
		# pero visualmente solo si ya la tenemos O si hay hueco visual libre.
		if passive_counts.has(id):
			return true # Ya la tenemos, solo sube stack
		else:
			return _has_empty_visual_passive_slot()
			
	return false

func get_item_count(target_res: Resource) -> int:
	if not target_res: return 0
	
	# 1. Comprobación de PASIVAS
	if target_res is PassiveData:
		return PlayerData.get_passive_count_global(target_res)
	
	# 2. Comprobación de PIEZAS
	# Recuperamos la lógica original que permite buscar tanto por PieceData como por PieceRes
	var search_res = target_res
	if target_res is PieceData:
		search_res = target_res.piece_origin
	
	if search_res is PieceRes:
		for id in piece_counts:
			var entry = piece_counts[id]
			var data = entry["data"]
			# Comparamos el origen (definition) para encontrar coincidencias
			if data is PieceData and data.piece_origin == search_res:
				return entry["count"]
	
	return 0

func add_item(data: Resource, amount: int = 1) -> bool:
	if not data:
		push_error("add_item: Se intentó añadir un item NULO.")
		return false
		
	print("--- add_item() llamado con: %s (Cantidad: %d) ---" % [data.resource_name, amount])

	var id: String = _get_item_id(data)

	# --- LÓGICA DE PASIVAS (NUEVA) ---
	if data is PassiveData:
		# 1. Guardar en PlayerData (Base de datos global)
		PlayerData.add_passive_global(data, amount)
		
		# 2. Actualizar espejo local
		if passive_counts.has(id):
			passive_counts[id]["count"] += amount
		else:
			passive_counts[id] = { "data": data, "count": amount }
			# Es nueva, activamos visual
			_display_passive_visual(data)
			
		_update_passive_stats_display()
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

# --- VISUALES DE PASIVAS (NUEVO) ---
func _has_empty_visual_passive_slot() -> bool:
	for slot in passive_visual_slots:
		if not slot.visible or slot.texture == null:
			return true
	return false

func _display_passive_visual(data: PassiveData) -> void:
	# 1. Chequear si ya está mostrada
	for slot in passive_visual_slots:
		if slot.visible and slot.texture == data.icon:
			return # Ya está, no hacer nada

	# 2. Buscar hueco libre
	for slot in passive_visual_slots:
		if not slot.visible or slot.texture == null:
			slot.texture = data.icon
			slot.visible = true
			return

## ------------------------------------------------------------------
## Funciones de Eliminación de Items (SOLO PIEZAS)
## ------------------------------------------------------------------

func decrement_item(data: Resource):
	# PROTECCIÓN: No decrementar pasivas
	if data is PassiveData:
		print("decrement_item: Ignorado para pasiva.")
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
	call_deferred("_update_passive_stats_display")


func _update_slot_visuals_for_piece(piece_data: PieceData):
	var id = _get_item_id(piece_data)
	if piece_counts.has(id):
		var entry = piece_counts[id]
		var slot_node: Node = entry["slot_node"]
		
		if slot_node and slot_node.has_method("_update_uses"):
			slot_node._update_uses(piece_data)

# --- CÁLCULO DE STATS (MODIFICADO para leer de PlayerData/Espejo) ---
func _update_passive_stats_display() -> void:
	
	var total_health: float = 0.0
	var total_damage: float = 0.0
	var total_speed: float = 0.0
	var total_crit_chance: float = 0.0
	var total_crit_damage: float = 0.0

	# 1. Contar huecos vacíos
	var empty_slots_count = float(_get_empty_roulette_slots())
	
	# 2. Calcular multiplicador
	var multiplier: float = 1.0 + (empty_slots_count * empty_slot_bonus_per_slot)

	# 3. Iteramos sobre passive_counts (que sincronizamos con PlayerData)
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
