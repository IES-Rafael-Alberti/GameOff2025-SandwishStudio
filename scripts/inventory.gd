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
@export var piece_scene: PackedScene

# --- ¡NUEVA VARIABLE! ---
# Límite de cuántas copias de una misma pieza se pueden tener.
@export var max_piece_copies: int = 3

# --- ¡CORREGIDO!
# Vuelve a ser un Array[PieceData]
@export var initial_pieces: Array[PieceData] 

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
	
	# --- ¡LÓGICA MODIFICADA! ---
	# Ya no conectamos 'item_attached', porque la pieza no se
	# elimina del inventario, solo gasta un uso.
	#GlobalSignals.item_attached.connect(remove_item_no_money)
	
	GlobalSignals.item_return_to_inventory_requested.connect(_on_item_return_requested)
	
	# --- ¡NUEVAS SEÑALES DE USOS! ---
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

# --- ¡CORREGIDO!
# Devuelve PieceData
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

# --- ¡FUNCIÓN MODIFICADA! ---
# Comprueba si el jugador puede añadir un item (incluyendo el límite de copias)
func can_add_item(data: Resource) -> bool:
	var context = _get_inventory_context(data)
	if not context:
		return false

	var id: String = _get_item_id(data)
	
	# --- ¡NUEVA LÓGICA DE LÍMITE! ---
	if data is PieceData:
		if context.map.has(id):
			var current_count = context.map[id]["count"]
			if current_count >= max_piece_copies:
				# Ya estamos en el límite, no se puede añadir ni 1 más.
				return false
	# --- FIN DE LA NUEVA LÓGICA ---

	# Comprobación original:
	# ¿Podemos apilarlo (porque ya existe) o tenemos un slot vacío?
	var can_stack = context.map.has(id)
	var has_empty_slot = _find_empty_slot(context.slots) != null
	
	return can_stack or has_empty_slot


# --- ¡FUNCIÓN MODIFICADA! ---
# Añade un item, respetando el límite de copias
# En /scripts/inventory.gd
func get_item_count(target_res: Resource) -> int:
	if not target_res:
		return 0
	
	# CASO 1: Nos pasan una Pieza (PieceData o PieceRes)
	# Si es PieceData, extraemos el origen para buscar todas las variantes
	var search_res = target_res
	if target_res is PieceData:
		search_res = target_res.piece_origin
	
	# Buscamos en el inventario de PIEZAS
	if search_res is PieceRes:
		for id in piece_counts:
			var entry = piece_counts[id]
			var data = entry["data"]
			# Comparamos el PieceRes original (identidad de la unidad)
			if data is PieceData and data.piece_origin == search_res:
				return entry["count"]

	# CASO 2: Nos pasan una Pasiva (PassiveData)
	# Buscamos en el inventario de PASIVAS
	elif target_res is PassiveData:
		# Intento 1: Buscar por ID de recurso (más rápido y exacto)
		var target_id = _get_item_id(target_res)
		if passive_counts.has(target_id):
			return passive_counts[target_id]["count"]
		
		# Intento 2: Búsqueda manual (por si acaso las instancias son diferentes pero el recurso es igual)
		for id in passive_counts:
			var entry = passive_counts[id]
			var data = entry["data"]
			if data == target_res: # Comparación de puntero/recurso
				return entry["count"]
	
	return 0

# --- ¡FUNCIÓN MODIFICADA! ---
# Añade un item, respetando el límite de copias
func add_item(data: Resource, amount: int = 1) -> bool:
	if not data:
		push_error("add_item: Se intentó añadir un item NULO.")
		return false
		
	print("--- add_item() llamado con: %s (Cantidad: %d) ---" % [data.resource_name, amount])

	var context = _get_inventory_context(data)
	var id: String = _get_item_id(data)
	var inventory_map = context.map
	var final_amount = amount

	# --- LÓGICA DE LÍMITE DE COPIAS (Esto está bien) ---
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
	# --- FIN DE LA LÓGICA DE LÍMITE ---


	var can_stack = inventory_map.has(id)
	var has_empty_slot = _find_empty_slot(context.slots) != null

	if not can_stack and not has_empty_slot:
		print("... FALLO: No hay slot vacío para un item nuevo. Inventario probablemente lleno.")
		return false

	# Lógica de apilar (Esto está bien)
	if inventory_map.has(id):
		print("... Item ya existe. Apilando %d." % final_amount)
		var entry = inventory_map[id]
		entry["count"] += final_amount
		var slot_node: Node = entry["slot_node"]
		if slot_node and slot_node.has_method("update_count"):
			slot_node.update_count(entry["count"])
		if context.is_passive:
			_update_passive_stats_display()
		return true

	# Lógica de añadir a slot nuevo
	var empty_slot: Node = _find_empty_slot(context.slots)
	
	if empty_slot:
		print("... Item nuevo. Slot vacío encontrado. Asignando %d." % final_amount)
		
		# --- ¡¡AQUÍ ESTÁ EL FIX!! ---
		# Si es una pieza, reiniciamos sus usos al valor por defecto
		# antes de asignarla al slot.
		if data is PieceData:
			# Si tienes un valor de "usos por defecto" en tu recurso, úsalo.
			# data.uses = data.default_uses 
			# Si no, pon el valor a mano (como 3):
			data.uses = 3
			print("... ¡FIX APLICADO! Reseteando usos a 3.")
		# --- ¡¡FIN DEL FIX!! ---
		
		if empty_slot.has_method("set_item"):
			empty_slot.set_item(data) # 'data' ahora tiene los usos reseteados

		if empty_slot.has_method("update_count"):
			empty_slot.update_count(final_amount) # <-- Usamos final_amount

		var new_entry = {
			"count": final_amount, # <-- Usamos final_amount
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

func decrement_item(data: Resource):
	var context = _get_inventory_context(data)
	if not context:
		push_warning("decrement_item: Tipo de data no reconocido.")
		return false

	var id: String = _get_item_id(data)
	var inventory_map = context.map

	if not inventory_map.has(id):
		push_error("decrement_item: Se intentó decrementar un item 
('%s') que no está en el inventario." % id)
		return false

	var entry = inventory_map[id]
	entry["count"] -= 1
	
	print("... Item encontrado.
Reduciendo contador a: %d" % entry["count"])

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
	# Esta función probablemente ya no se use si 'slot.gd' deja
	# de emitir 'item_attached', pero la dejamos por seguridad.
	push_warning("inventory.gd: remove_item_no_money() fue llamada. Esto puede ser un error bajo la nueva lógica de 'usos'.")
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
	
	# --- ¡NUEVA LÍNEA! ---
	# Avisamos al resto del juego (a la Ruleta) que este TIPO de
	# pieza ha sido eliminado por completo.
	if item_data is PieceData:
		GlobalSignals.piece_type_deleted.emit(item_data)
	
	if context.is_passive:
		_compact_passive_slots()
		_update_passive_stats_display()
	return true

# --- ¡CORREGIDO! ---
# Vuelve a comprobar 'PieceData'
func _get_inventory_context(data: Resource) -> Dictionary:
	if data is PieceData: # <-- CAMBIADO
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
			print("... Moviendo item del slot 
%d al slot %d" % [next_item_index, i])
			
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
			print("... No se encontraron más items.
Compactado finalizado.")
			break

## ------------------------------------------------------------------
## Conexiones de Señales
## ------------------------------------------------------------------

func _on_item_selected_from_slot(data: Resource) -> void:
	if data:
		print("Has seleccionado el item: ", data.resource_name)

# Esta función ahora solo se usará si algo (que no sea slot.gd)
# pide devolver un item. La lógica de 'slot.gd' ya no la usa.
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


# --- ¡NUEVAS FUNCIONES DE SEÑALES DE USOS! ---

# Se llama cuando GlobalSignals.piece_placed_on_roulette se emite
func _on_piece_placed(piece_data: PieceData):
	if not piece_data: return
	if not piece_data is PieceData: return

	# 1. Restamos un uso
	piece_data.uses = max(0, piece_data.uses - 1)
	print("... Pieza '%s' colocada. Usos restantes: %d" % [piece_data.resource_name, piece_data.uses])

	# 2. Buscamos el slot de inventario y actualizamos su UI
	_update_slot_visuals_for_piece(piece_data)


# Se llama cuando GlobalSignals.piece_returned_from_roulette se emite
func _on_piece_returned(piece_data: PieceData):
	if not piece_data: return
	if not piece_data is PieceData: return
		
	# 1. Sumamos un uso
	piece_data.uses += 1
	print("... Pieza '%s' devuelta. Usos restantes: %d" % [piece_data.resource_name, piece_data.uses])

	# 2. Buscamos el slot de inventario y actualizamos su UI
	_update_slot_visuals_for_piece(piece_data)


# Función auxiliar para encontrar el slot de una pieza y refrescarlo
func _update_slot_visuals_for_piece(piece_data: PieceData):
	var id = _get_item_id(piece_data)
	if piece_counts.has(id):
		var entry = piece_counts[id]
		var slot_node: Node = entry["slot_node"]
		
		# 3. Le decimos al slot que refresque su UI (para mostrar usos y ponerse gris)
		if slot_node and slot_node.has_method("_update_uses"):
			slot_node._update_uses(piece_data)
	else:
		push_error("_update_slot_visuals_for_piece: La pieza no se encontró en piece_counts.")


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
			print("... ... ERROR DEBUG: Entrada '%s' tiene datos NULOS." 
% item_id)
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
