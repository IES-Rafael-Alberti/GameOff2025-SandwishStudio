extends Node2D

@export var initial_currency: int = 1000
var current_currency: int
@onready var gold_label: Label = $gold_label

func _ready():
	current_currency = initial_currency
	_update_gold_label()

# --------------------------------------------------
# 🔹 Funciones públicas de manejo de oro
# --------------------------------------------------

func has_enough_currency(amount: int) -> bool:
	return current_currency >= amount

func spend_currency(amount: int) -> bool:
	if has_enough_currency(amount):
		current_currency -= amount
		print("Has gastado %d de oro. Oro restante: %d" % [amount, current_currency])
		_update_gold_label()
		return true
	else:
		push_warning("No tienes suficiente oro. Te faltan %d" % [amount - current_currency])
		return false

func add_currency(amount: int) -> void:
	current_currency += amount
	print("Has ganado %d de oro. Oro total: %d" % [amount, current_currency])
	_update_gold_label()

func _update_gold_label() -> void:
	if gold_label:
		gold_label.text = str(current_currency) + "€"
