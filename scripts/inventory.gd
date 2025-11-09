extends Control

## ------------------------------------------------------------------
## Nodos y Exportaciones
## ------------------------------------------------------------------
@onready var piece_inventory: GridContainer = $piece_inventory
@onready var passive_inventory: GridContainer = $passive_inventory
@onready var refund_percent: int = 50
@export var max_pieces: int = 6
@export var max_passives: int = 30
@onready var game = get_parent()
@export var inventory_slot_scene: PackedScene 

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
	
	# 1. Asegurarnos de que la escena del slot fue asignada
	if not inventory_slot_scene:
		push_error("¡La variable 'Inventory Slot Scene' no está asignada en el script Inventory.gd!")
		return

	# 2. Generar los slots de piezas
	for i in range(max_pieces):
		var new_slot = inventory_slot_scene.instantiate()
		piece_inventory.add_child(new_slot) # Añadirlo al GridContainer
		
		piece_slots.append(new_slot) 
		if new_slot.has_signal("item_selected"):
			new_slot.item_selected.connect(_on_item_selected_from_slot)


	# 3. Generar los slots de pasivos
	for i in range(max_passives):
		var new_slot = inventory_slot_scene.instantiate()
		passive_inventory.add_child(new_slot)
		
		passive_slots.append(new_slot)
		if new_slot.has_signal("item_selected"):
			new_slot.item_selected.connect(_on_item_selected_from_slot)

	# 4. Imprimir la confirmación (el "Chivato" de antes)
	print("Inventory _ready: Generados %d slots de piezas y %d slots de pasivos." % [piece_slots.size(), passive_slots.size()])


## ------------------------------------------------------------------
## Funciones Públicas 
## ------------------------------------------------------------------

"""
Comprueba si se puede añadir un item al inventario correspondiente.
"""
func can_add_item(data: Resource) -> bool:
	var inventory_map: Dictionary
	var slot_array: Array
	var id: String = _get_item_id(data)

	if data is PieceData:
		inventory_map = piece_counts
		slot_array = piece_slots
	elif data is PassiveData:
		inventory_map = passive_counts
		slot_array = passive_slots
	else:
		return false 

	var can_stack = inventory_map.has(id)
	var has_empty_slot = _find_empty_slot(slot_array) != null
	
	return can_stack or has_empty_slot


"""
Añade un item (Pieza o Pasivo) al inventario.
"""
func add_item(data: Resource) -> bool:
	if not data:
		push_error("add_item: Se intentó añadir un item NULO.")
		return false
		
	print("--- add_item() llamado con: %s ---" % data.resource_name)

	if not can_add_item(data):
		print("... FALLO: can_add_item devolvió false. Inventario probablemente lleno.")
		return false

	var inventory_map: Dictionary
	var slot_array: Array
	var id: String = _get_item_id(data)

	if data is PieceData:
		inventory_map = piece_counts
		slot_array = piece_slots
	elif data is PassiveData:
		inventory_map = passive_counts
		slot_array = passive_slots
	else:
		return false

	# Lógica de Apilamiento (Stacking)
	if inventory_map.has(id):
		print("... Item ya existe. Apilando.")
		var entry = inventory_map[id]
		entry["count"] += 1
		var slot_node: Node = entry["slot_node"]
		if slot_node and slot_node.has_method("update_count"):
			slot_node.update_count(entry["count"])
		return true

	# Lógica de Nuevo Item (en un slot vacío)
	var empty_slot: Node = _find_empty_slot(slot_array)
	
	if empty_slot:
		print("... Item nuevo. Slot vacío encontrado. Asignando item.")
		if empty_slot.has_method("set_item"):
			empty_slot.set_item(data)

		var new_entry = {
			"count": 1,
			"data": data,
			"slot_node": empty_slot 
		}
		inventory_map[id] = new_entry
		return true

	print("... FALLO INESPERADO: No se pudo apilar ni encontrar slot vacío.")
	return false 


## ------------------------------------------------------------------
## Funciones Privadas 
## ------------------------------------------------------------------

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
		

"""
Elimina UNA unidad de un item (Pieza o Pasivo) del inventario.
"""

## ------------------------------------------------------------------
## Funciones Privadas (Nueva función de compactado)
## ------------------------------------------------------------------

"""
Compacta los slots de pasivos.
Busca el primer slot vacío y mueve el siguiente item disponible
a ese hueco. Repite hasta que no queden huecos.
"""
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


func remove_item(data: Resource) -> bool:
	
	var inventory_map: Dictionary
	var id: String = _get_item_id(data)
	
	var is_passive_item: bool = false
	# --------------------

	if data is PieceData:
		inventory_map = piece_counts
	elif data is PassiveData:
		inventory_map = passive_counts
		is_passive_item = true
	else:
		push_warning("remove_item: Tipo de data no reconocido.")
		return false # Item no es ni Pieza ni Pasivo

	# Comprobar si realmente tenemos ese item antes de intentar restarlo
	if not inventory_map.has(id):
		push_error("remove_item: Se intentó eliminar un item ('%s') que no está en el inventario." % id)
		return false

	var entry = inventory_map[id]
	entry["count"] -= 1
	
	print("... Item encontrado. Reduciendo contador a: %d" % entry["count"])

	if "price" in data and data.price > 0:
		var refund_amount = int(data.price * (refund_percent / 100.0))
		
		if game:
			game.add_currency(refund_amount)
			print("... Reembolsados %d de oro (%d%% de %d)" % [refund_amount, refund_percent, data.price])
		else:
			push_error("Inventory.gd: No se encontró el nodo 'game' para dar el reembolso.")

	var slot_node: Node = entry["slot_node"]

	if entry["count"] > 0:
		if slot_node and slot_node.has_method("update_count"):
			slot_node.update_count(entry["count"])
		else:
			push_error("remove_item: El slot_node es inválido o no tiene update_count().")
	else:
		if slot_node and slot_node.has_method("clear_slot"):
			slot_node.clear_slot()
		else:
			push_error("remove_item: El slot_node es inválido o no tiene clear_slot().")
		
		inventory_map.erase(id)
		print("... Contador a cero. Eliminando item del diccionario.")
		if is_passive_item:
			_compact_passive_slots()
		# -----------------------------------

	return true
