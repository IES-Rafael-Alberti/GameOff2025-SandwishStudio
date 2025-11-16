# inventory.gd
extends Control

signal item_sold(refund_amount: int)

## ------------------------------------------------------------------
## Nodos y Exportaciones
## ------------------------------------------------------------------
@onready var piece_inventory: GridContainer = $piece_inventory
@onready var passive_inventory: GridContainer = $passive_inventory
@onready var refund_percent: int = 50
@onready var health_label: Label = $TextureRect3/VBoxContainer/HBoxContainer/Health_container/Label
@onready var damage_label: Label = $TextureRect3/VBoxContainer/HBoxContainer/Damage_container/Label
@onready var speed_label: Label = $TextureRect3/VBoxContainer/HBoxContainer/SpeedCOntainer/Label
@onready var crit_chance_label: Label = $TextureRect3/VBoxContainer/HBoxContainer2/CChance_container/Label
@onready var crit_damage_label: Label = $TextureRect3/VBoxContainer/HBoxContainer2/CDamage_chance/Label
@export var max_pieces: int = 6
@export var max_passives: int = 30
@export var inventory_slot_scene: PackedScene 
@export var piece_scene: PackedScene # Arrastra tu escena piece.tscn aquí

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
	GlobalSignals.item_attached.connect(remove_item_no_money)
	GlobalSignals.item_return_to_inventory_requested.connect(_on_item_return_requested)
	_update_passive_stats_display()
	if not inventory_slot_scene:
		push_error("¡La variable 'Inventory Slot Scene' no está asignada en el script Inventory.gd!")
		return

	# 1. Generar los slots de piezas
	_initialize_slots(piece_inventory, piece_slots, max_pieces, refund_percent)

	# 2. Generar los slots de pasivos
	_initialize_slots(passive_inventory, passive_slots, max_passives, 0) # Pasivos no se venden desde aquí

	# 3. Imprimir la confirmación
	print("Inventory _ready: Generados %d slots de piezas y %d slots de pasivos." % [piece_slots.size(), passive_slots.size()])

## ------------------------------------------------------------------
## Funciones Públicas 
## ------------------------------------------------------------------

func can_add_item(data: Resource) -> bool:
	var context = _get_inventory_context(data)
	if not context:
		return false

	var id: String = _get_item_id(data)
	var can_stack = context.map.has(id)
	var has_empty_slot = _find_empty_slot(context.slots) != null
	
	return can_stack or has_empty_slot


func add_item(data: Resource, amount: int = 1) -> bool:
	if not data:
		push_error("add_item: Se intentó añadir un item NULO.")
		return false
		
	# ¡CAMBIO! Actualizamos el print
	print("--- add_item() llamado con: %s (Cantidad: %d) ---" % [data.resource_name, amount])

	var context = _get_inventory_context(data)

	if not can_add_item(data): # can_add_item no necesita cambiar
		print("... FALLO: can_add_item devolvió false. Inventario probablemente lleno.")
		return false

	var id: String = _get_item_id(data)
	var inventory_map = context.map

	# Lógica de Apilamiento (Stacking)
	if inventory_map.has(id):
		print("... Item ya existe. Apilando.")
		var entry = inventory_map[id]
		entry["count"] += amount # <-- ¡CAMBIO! Sumamos la cantidad recibida
		var slot_node: Node = entry["slot_node"]
		if slot_node and slot_node.has_method("update_count"):
			slot_node.update_count(entry["count"])
		if context.is_passive:
			_update_passive_stats_display()
		return true

	# Lógica de Nuevo Item (en un slot vacío)
	var empty_slot: Node = _find_empty_slot(context.slots)
	
	if empty_slot:
		print("... Item nuevo. Slot vacío encontrado. Asignando item.")
		if empty_slot.has_method("set_item"):
			empty_slot.set_item(data) # set_item lo pone a 1

		# ¡CAMBIO! Pero lo actualizamos a la cantidad correcta
		if empty_slot.has_method("update_count"):
			empty_slot.update_count(amount)

		var new_entry = {
			"count": amount, # <-- ¡CAMBIO! Usamos la cantidad recibida
			"data": data,
			"slot_node": empty_slot 
		}
		inventory_map[id] = new_entry
		if context.is_passive:
			_update_passive_stats_display()
		return true

	print("... FALLO INESPERADO: No se pudo apilar ni encontrar slot vacío.")
	return false

## ------------------------------------------------------------------
## Funciones de Eliminación de Items
## ------------------------------------------------------------------

# Esta función elimina UNA unidad del stack
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

# Esta función elimina el STACK COMPLETO (para vender)
func remove_item(item_data: Resource):
	return _remove_item_stack(item_data, true)

# Esta función elimina el STACK COMPLETO (sin reembolso)
func remove_item_no_money(item_data: Resource):
	return _remove_item_stack(item_data, false)


## ------------------------------------------------------------------
## Funciones Privadas / Auxiliares
## ------------------------------------------------------------------

# FUNCIÓN AUXILIAR (NUEVA)
# Consolida la lógica de eliminación de stacks completos
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

	# --- 💰 LÓGICA DE REEMBOLSO ---
	if with_refund and "price" in item_data and item_data.price > 0:
		var refund_amount = (int(item_data.price * (refund_percent / 100.0)) * total_count)
		item_sold.emit(refund_amount)
		print("... Reembolsados %d de oro (%d%% de %d x %d copias)" % [refund_amount, refund_percent, item_data.price, total_count])
	else:
		print("... Eliminando sin reembolso.")

	# --- LÓGICA DE ELIMINACIÓN ---
	var slot_node: Node = entry["slot_node"]

	if slot_node and slot_node.has_method("clear_slot"):
		slot_node.clear_slot()
	else:
		push_error("_remove_item_stack: El slot_node es inválido o no tiene clear_slot().")
	
	inventory_map.erase(id)
	print("... Contador a cero. Eliminando item del diccionario.")
	
	if context.is_passive:
		_compact_passive_slots()
		_update_passive_stats_display()
	return true

# FUNCIÓN AUXILIAR (NUEVA)
# Devuelve el mapa de inventario y el array de slots correctos para un item
func _get_inventory_context(data: Resource) -> Dictionary:
	if data is PieceData:
		return { "map": piece_counts, "slots": piece_slots, "is_passive": false }
	elif data is PassiveData:
		return { "map": passive_counts, "slots": passive_slots, "is_passive": true }
	
	# Tipo de dato no reconocido
	return {} # Devuelve un diccionario vacío (que fallará como 'null' en las comprobaciones)


# FUNCIÓN AUXILIAR (NUEVA)
# Genera los slots de inventario en el _ready
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

func _update_passive_stats_display() -> void:
	
	var total_health: float = 0.0
	var total_damage: float = 0.0
	var total_speed: float = 0.0
	var total_crit_chance: float = 0.0
	var total_crit_damage: float = 0.0

	for item_id in passive_counts:
		var entry = passive_counts[item_id]
		var data: PassiveData = entry.data
		var count: int = entry.count
		
		if not data:
			print("... ... ERROR DEBUG: Entrada '%s' tiene datos NULOS." % item_id)
			continue
		
		if not data is PassiveData:
			continue
		
		var item_name = data.resource_name
		if "name_passive" in data and not data.name_passive.is_empty():
			item_name = data.name_passive
		match data.type:
			PassiveData.PassiveType.HEALTH_INCREASE:
				total_health += (data.value * count)
			PassiveData.PassiveType.BASE_DAMAGE_INCREASE:
				total_damage += (data.value * count)
			PassiveData.PassiveType.ATTACK_SPEED_INCREASE:
				total_speed += (data.value * count)
			PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE:
				total_crit_chance += (data.value * count)
			PassiveData.PassiveType.CRITICAL_DAMAGE_INCREASE:
				total_crit_damage += (data.value * count)
			
	# 3. Actualizar el texto de las etiquetas
	health_label.text = "+%s" % str(total_health)
	damage_label.text = "+%s" % str(total_damage)
	speed_label.text = "+%s" % str(total_speed) 
	crit_chance_label.text = "+%s" % str(total_crit_chance)
	crit_damage_label.text = "+%s" % str(total_crit_damage)
	
	# --- INICIO DE CÓDIGO NUEVO ---
	# Compilamos un diccionario con los totales
	var stats_payload := {
		"health": total_health,
		"damage": total_damage,
		"speed": total_speed,
		"crit_chance": total_crit_chance,
		"crit_damage": total_crit_damage
	}
	
	# Enviamos los datos al singleton GlobalStats
	# Comprobamos que exista por si acaso
	if has_node("/root/GlobalStats"):
		GlobalStats.update_stats(stats_payload)
	# --- FIN DE CÓDIGO NUEVO ---
