# Tooltip.gd
extends PanelContainer

# Referencias a los labels que creamos en la escena
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var description_label: Label = $VBoxContainer/DescriptionLabel
@onready var sell_price_label: Label = $VBoxContainer/SellPriceLabel

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:

	global_position = get_global_mouse_position() + Vector2(15, 15)

## Muestra y actualiza el tooltip con la información de un item
func show_tooltip(item_data: Resource, sell_percentage: int) -> void:
	if not item_data:
		return

	# 1. Poner el nombre
	name_label.text = item_data.resource_name
	name_label.visible = true

	# 2. Poner la descripción (si existe)
	if "description" in item_data and not item_data.description.is_empty():
		description_label.text = item_data.description
		description_label.visible = true
	else:
		description_label.visible = false

	# 3. Calcular y poner el precio de venta (si existe)
	if "price" in item_data and item_data.price > 0:
		var sell_price = int(item_data.price * (sell_percentage / 100.0))
		sell_price_label.text = "Valor de venta: %d€" % sell_price
		sell_price_label.visible = true
	else:
		sell_price_label.visible = false

	# Mostrar el tooltip
	show()

## Oculta el tooltip
func hide_tooltip() -> void:
	hide()
