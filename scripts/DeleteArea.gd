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
		
	# ¡CAMBIO!
	# Ahora comprobamos si es nuestro 'paquete' (diccionario)
	# y si DENTRO de él hay un Resource válido.
	if data is Dictionary and "data" in data:
		return data.data is Resource # Acepta si tiene datos válidos dentro
	
	# Fallback por si acaso (aunque todo debería usar el paquete)
	return data is Resource


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if sprite:
		sprite.modulate = normal_color

	# ¡CAMBIO CLAVE!
	# Tenemos que decidir qué emitir basado en qué recibimos.
	
	var item_to_delete: Resource = null
	
	if data is Dictionary and "data" in data:
		# Es nuestro nuevo 'paquete'. Extraemos el Resource.
		item_to_delete = data.data
	elif data is Resource:
		# Es un Resource simple (como un pasivo, o un
		# ítem de una fuente que no usa el 'paquete')
		item_to_delete = data
		
	if item_to_delete:
		# Emitimos solo el Resource, que es lo que
		# 'inventory.gd' (remove_item) espera recibir.
		GlobalSignals.item_deleted.emit(item_to_delete)
	else:
		push_warning("DeleteArea: Se soltaron datos en un formato inesperado.")


func _on_mouse_exited() -> void:
	if sprite:
		sprite.modulate = normal_color
