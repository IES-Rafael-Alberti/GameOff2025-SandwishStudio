# DeleteArea.gd
extends Panel

@onready var sprite: Sprite2D = $Sprite2D

var normal_color = Color.WHITE
var hover_color = Color(1.0, 1.0, 1.0, 0.7)

# --- ¡NUEVA LÍNEA! ---
# Esta variable rastreará el estado de la ruleta
var _is_roulette_spinning: bool = false


func _ready() -> void:
	# Ya no necesitamos una referencia al 'inventory_manager'.
	# ¡Este script ahora es totalmente independiente!
	
	if not sprite:
		push_warning("DeleteArea: No se encontró el nodo hijo 'Sprite2D'. El efecto de color no funcionará.")
	
	if sprite:
		sprite.modulate = normal_color
	
	self.mouse_exited.connect(_on_mouse_exited)

	# --- ¡NUEVO BLOQUE! ---
	# Nos conectamos a la señal global de la ruleta.
	GlobalSignals.roulette_state_changed.connect(_on_roulette_state_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if sprite:
			sprite.modulate = normal_color


## ------------------------------------------------------------------
## Funciones de Drag-and-Drop
## ------------------------------------------------------------------

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	
	# --- ¡CAMBIO CLAVE! ---
	# Si la ruleta está girando, no permitimos soltar nada.
	if _is_roulette_spinning:
		return false
	# --- FIN CAMBIO ---

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


# --- ¡NUEVA FUNCIÓN! ---
# Se llama cuando GlobalSignals.roulette_state_changed es emitida.
func _on_roulette_state_changed(is_spinning: bool):
	_is_roulette_spinning = is_spinning
	
	# Opcional: Si la ruleta empieza a girar mientras
	# el ratón estaba encima, reseteamos el color.
	if is_spinning and sprite:
		sprite.modulate = normal_color
