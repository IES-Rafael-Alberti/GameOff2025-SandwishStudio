# slot.gd (RouletteSlot.gd)
extends Panel

@export var max_glow_alpha := 0.7
@export var max_scale := 1.0
@export var min_scale := 0.6
@export var attraction_radius := 120.0
@export var highlight_speed := 10.0
var glow_sprite: Sprite2D
var particles: CPUParticles2D
var piece_over: Node = null
var occupied := false
var current_piece_data: Resource = null 
var current_piece_count: int = 0
@onready var ruleta: Node = get_parent().get_parent().get_parent().get_parent()
@onready var piece_texture_rect: TextureRect = $PieceTextureRect

func _ready():
	if not has_node("Highlight"):
		var h = Node2D.new()
		h.name = "Highlight"
		add_child(h)
		h.z_index = 10
		glow_sprite = Sprite2D.new()
		glow_sprite.centered = true
		glow_sprite.modulate = Color(1,1,0,0)
		glow_sprite.scale = Vector2(min_scale,min_scale)
		h.add_child(glow_sprite)
		particles = CPUParticles2D.new()
		particles.amount = 6
		particles.one_shot = false
		particles.emitting = false
		h.add_child(particles)
	else:
		glow_sprite = get_node("Highlight/Glow")
		particles = get_node("Highlight/Particles")

	if not piece_texture_rect:
		push_error("RouletteSlot: ¡No se encontró el nodo hijo 'PieceTextureRect'!")
	else:
		piece_texture_rect.visible = false
	self.gui_input.connect(_on_gui_input)

func _process(delta):
	if piece_over:
		var dist = piece_over.global_position.distance_to(global_position)
		var factor = clamp(1.0 - float(dist) / float(attraction_radius), 0.0, 1.0)
		glow_sprite.modulate.a = lerp(float(glow_sprite.modulate.a), max_glow_alpha * factor, delta * highlight_speed)
		var target_scale = lerp(float(min_scale), float(max_scale), factor)
		glow_sprite.scale = glow_sprite.scale.lerp(Vector2(target_scale, target_scale), delta * highlight_speed)
		particles.emitting = factor > 0.3
	else:
		glow_sprite.modulate.a = lerp(float(glow_sprite.modulate.a), 0.0, delta * highlight_speed)
		glow_sprite.scale = glow_sprite.scale.lerp(Vector2(min_scale, min_scale), delta * highlight_speed)
		particles.emitting = false

		
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	
	# --- MODIFICADO ---
	# Usamos la variable 'is_interactive' de la ruleta, controlada por la FSM
	if ruleta and ruleta.has_method("is_moving"):
		if ruleta.is_moving() or not ruleta.is_interactive:
			return false
	
	if occupied:
		return false
		
	if data is Dictionary and "data" in data and "count" in data:
		# --- ¡LÓGICA DE USOS AÑADIDA! ---
		# Comprobamos que es una pieza Y que le quedan usos.
		if data.data is PieceData:
			return data.data.uses > 0
		
		# Si es otro tipo de item (ej: pasivo), lo rechazamos
		return false

	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	
	occupied = true
	current_piece_data = data.data
	current_piece_count = 1 # Solo se coloca 1, aunque la pila tenga más
	
	if current_piece_data and "icon" in current_piece_data:
		
		if current_piece_data.icon:
			piece_texture_rect.texture = current_piece_data.icon
			piece_texture_rect.visible = true
		else:
			push_warning("RouletteSlot: La propiedad 'icon' está vacía (null).")
			
	else:
		push_warning("RouletteSlot: El Resource soltado no tiene la propiedad 'icon'. No se puede mostrar la imagen.")

	# --- ¡LÓGICA MODIFICADA! ---
	# Ya NO emitimos 'item_attached' (que borraba la pila).
	# En su lugar, emitimos la nueva señal para que 'inventory.gd' reste 1 uso.
	GlobalSignals.piece_placed_on_roulette.emit(current_piece_data)


func clear_slot():
	occupied = false
	current_piece_data = null
	current_piece_count = 0
	if piece_texture_rect:
		piece_texture_rect.visible = false

# --- ¡FUNCIÓN MODIFICADA! ---
# Ahora, hacer clic en la pieza la "devuelve", sumando 1 uso
# al inventario y limpiando este slot.
func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	if not occupied:
		return
		
	# --- MODIFICADO ---
	# Comprobamos si la ruleta está interactiva (controlado por la FSM)
	if ruleta and ruleta.has_method("is_moving"):
		# Comprobamos si está girando O si la FSM la ha bloqueado
		if ruleta.is_moving() or not ruleta.is_interactive:
			print("No se puede devolver la pieza: ¡La ruleta está girando o el juego está en combate!")
			return

	# --- ¡LÓGICA MODIFICADA! ---
	# Ya no pedimos devolver el item al inventario (lo que duplicaría).
	# Ahora emitimos una señal para "devolver" 1 uso al contador
	# de la pieza que está en el inventario.
	GlobalSignals.piece_returned_from_roulette.emit(current_piece_data)
	
	# Y simplemente limpiamos este slot.
	clear_slot()


# Esta función ya no es necesaria con la nueva lógica,
# pero la dejamos por si se usa en otro sitio.
func _on_return_attempt_finished(success: bool):
	if success:
		# Esta línea ya no se ejecutará si _on_gui_input no la llama.
		clear_slot()
	else:
		print("No se puede devolver la pieza: ¡El inventario está lleno!")
