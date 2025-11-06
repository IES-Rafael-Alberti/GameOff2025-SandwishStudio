extends Panel

var inventory_manager: Node

@onready var sprite: Sprite2D = $Sprite2D 

var normal_color = Color.WHITE
var hover_color = Color(1.0, 1.0, 1.0, 0.7)

func _ready() -> void:
	inventory_manager = get_parent()
	
	if not inventory_manager:
		push_error("DeleteArea: ¡No se pudo encontrar el nodo padre (Inventory)!")
	elif not inventory_manager.has_method("remove_item"):
		push_error("DeleteArea: El padre 'Inventory' no tiene el método 'remove_item'!")
	
	if not sprite:
		push_warning("DeleteArea: No se encontró el nodo hijo 'Sprite2D'. El efecto de color no funcionará.")
	
	sprite.modulate = normal_color
	
	self.mouse_exited.connect(_on_mouse_exited)


func _notification(what: int) -> void:

	if what == NOTIFICATION_DRAG_END:
		sprite.modulate = normal_color


## ------------------------------------------------------------------
## Funciones de Drag-and-Drop
## ------------------------------------------------------------------

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	sprite.modulate = hover_color
	return data is Resource


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	sprite.modulate = normal_color

	if inventory_manager and inventory_manager.has_method("remove_item"):
		inventory_manager.remove_item(data)
	else:
		push_error("DeleteArea: ¡No se pudo llamar a 'remove_item' en el padre!")


func _on_mouse_exited() -> void:
	sprite.modulate = normal_color
