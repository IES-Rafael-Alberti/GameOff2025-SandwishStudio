extends Panel

@onready var sprite: Sprite2D = $Sprite2D

var normal_color = Color.WHITE
var hover_color = Color(1.0, 1.0, 1.0, 0.7)

# Esta variable se puede mantener por seguridad, o confiar solo en el GameManager
var _is_roulette_spinning: bool = false

func _ready() -> void:
	if not sprite:
		push_warning("DeleteArea: No se encontró el nodo hijo 'Sprite2D'.")
	
	if sprite:
		sprite.modulate = normal_color
	
	self.mouse_exited.connect(_on_mouse_exited)
	GlobalSignals.roulette_state_changed.connect(_on_roulette_state_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if sprite:
			sprite.modulate = normal_color

## ------------------------------------------------------------------
## Funciones de Drag-and-Drop (MODIFICADA)
## ------------------------------------------------------------------

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	
	# --- INICIO NUEVA LÓGICA DE BLOQUEO ---
	# Intentamos obtener el GameManager (normalmente es la escena raíz actual)
	var game_manager = get_tree().current_scene
	
	if game_manager and "current_state" in game_manager:
		# Basado en tu GameManager:
		# GameState.SHOP = 0
		# GameState.ROULETTE = 1
		# GameState.SPINNING = 2  <-- Bloquear
		# GameState.COMBAT = 3    <-- Bloquear
		
		if game_manager.current_state == 2 or game_manager.current_state == 3:
			return false
	# --- FIN NUEVA LÓGICA DE BLOQUEO ---
	
	# Fallback: Si no encuentra el GameManager, usa tu variable local anterior
	if _is_roulette_spinning:
		return false

	# Lógica visual normal
	if sprite:
		sprite.modulate = hover_color
		
	if data is Dictionary and "data" in data:
		return data.data is Resource 
	
	return data is Resource

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if sprite:
		sprite.modulate = normal_color

	var item_to_delete: Resource = null
	
	if data is Dictionary and "data" in data:
		item_to_delete = data.data
	elif data is Resource:
		item_to_delete = data
		
	if item_to_delete:
		# Al soltar, se emite la señal y el inventario lo borra (y vende)
		GlobalSignals.item_deleted.emit(item_to_delete)
	else:
		push_warning("DeleteArea: Se soltaron datos en un formato inesperado.")


func _on_mouse_exited() -> void:
	if sprite:
		sprite.modulate = normal_color

func _on_roulette_state_changed(is_spinning: bool):
	_is_roulette_spinning = is_spinning
	if is_spinning and sprite:
		sprite.modulate = normal_color
