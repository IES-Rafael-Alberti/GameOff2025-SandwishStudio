# PlayerData.gd
extends Node

signal currency_changed(new_amount: int)

@export var initial_currency: int = 10
var current_currency: int = 0

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
var is_shop_locked: bool = false
var shop_items_saved: Array = [] # Aquí guardaremos qué items había y si estaban comprados
