# DeleteArea.gd
extends Panel

@onready var sprite: Sprite2D = $Sprite2D 

var normal_color = Color.WHITE
var hover_color = Color(1.0, 1.0, 1.0, 0.7)

func _ready() -> void:
	# Ya no necesitamos una referencia al 'inventory_manager'.
	# ¡Este script ahora es totalmente independiente!
	
	if not sprite:
		push_warning("DeleteArea: No se encontró el nodo hijo 'Sprite2D'. El efecto de color no funcionará.")
	
	if sprite:
		sprite.modulate = normal_color
	
	self.mouse_exited.connect(_on_mouse_exited)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if sprite:
			sprite.modulate = normal_color


## ------------------------------------------------------------------
## Funciones de Drag-and-Drop
## ------------------------------------------------------------------

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if sprite:
		sprite.modulate = hover_color
	# Seguimos comprobando que 'data' sea un Recurso,
	# como lo hace DraggableItem.gd
	return data is Resource


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if sprite:
		sprite.modulate = normal_color

	# ¡Aquí está la magia!
	# En lugar de llamar a un método del padre, emitimos la señal global.
	# El InventoryManager (o quien sea) estará escuchando.
	GlobalSignals.item_deleted.emit(data)


func _on_mouse_exited() -> void:
	if sprite:
		sprite.modulate = normal_color
