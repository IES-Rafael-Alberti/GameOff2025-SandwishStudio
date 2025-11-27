extends Node

signal currency_changed(new_amount: int)

@export var initial_currency: int = 3

var current_currency: int = 0

# --- NUEVO: Persistencia de Pasivas ---
# Diccionario para guardar pasivas compradas: { "id_del_recurso": { "data": Resource, "count": int } }
var owned_passives: Dictionary = {} 
# --------------------------------------

var is_shop_locked: bool = false
var shop_items_saved: Array = [] 

func _ready() -> void:
	current_currency = initial_currency

func has_enough_currency(amount: int) -> bool:
	return current_currency >= amount

func spend_currency(amount: int) -> bool:
	if has_enough_currency(amount):
		current_currency -= amount
		currency_changed.emit(current_currency)
		print("Has gastado %d de oro. Oro restante: %d" % [amount, current_currency])
		return true
	else:
		push_warning("No tienes suficiente oro. Te faltan %d" % [amount - current_currency])
		return false

func add_currency(amount: int) -> void:
	current_currency += amount
	currency_changed.emit(current_currency)
	print("Has ganado %d de oro. Oro total: %d" % [amount, current_currency])

func get_current_currency() -> int:
	return current_currency

# --- FUNCIONES PARA GESTIÓN DE PASIVAS GLOBAL ---
func add_passive_global(data: Resource, amount: int = 1) -> void:
	var id = _get_resource_id(data)
	
	if owned_passives.has(id):
		owned_passives[id]["count"] += amount
	else:
		owned_passives[id] = {
			"data": data,
			"count": amount
		}

func get_passive_count_global(data: Resource) -> int:
	var id = _get_resource_id(data)
	if owned_passives.has(id):
		return owned_passives[id]["count"]
	return 0

func _get_resource_id(data: Resource) -> String:
	if data.resource_path.is_empty() == false:
		return data.resource_path
	return "%s_%d" % [data.get_class(), data.get_instance_id()]
