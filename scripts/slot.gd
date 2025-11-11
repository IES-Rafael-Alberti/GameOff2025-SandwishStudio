# Supongamos que este script se llama RouletteSlot.gd
extends Panel

@export var max_glow_alpha := 0.7
@export var max_scale := 1.0
@export var min_scale := 0.6
@export var attraction_radius := 120.0
@export var highlight_speed := 10.0
@export var ruleta: Node
var glow_sprite: Sprite2D
var particles: CPUParticles2D
var piece_over: Node = null
var occupied := false
var current_piece_data: Resource = null # Para guardar los datos de la pieza

# ¡NUEVO! Necesitamos un nodo para mostrar la imagen de la pieza
@onready var piece_texture_rect: TextureRect = $PieceTextureRect

# La instancia de inventario aquí parece un poco extraña,
# pero la dejaremos como está ya que no afecta al drag-and-drop.


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

	# ¡NUEVO! Asegurarnos de que el nodo TextureRect existe
	if not piece_texture_rect:
		push_error("RouletteSlot: ¡No se encontró el nodo hijo 'PieceTextureRect'!")
	else:
		piece_texture_rect.visible = false # Empezar oculto
	self.gui_input.connect(_on_gui_input)

func _process(delta):
	# ... (tu código de _process para el brillo no cambia) ...
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
	# 1. Rechazar si el slot ya está ocupado
	if occupied:
		return false
		
	return data is PieceData


# En tu script de Slot de Ruleta (slot.gd)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	
	# 1. Marcar como ocupado y guardar los datos
	occupied = true
	current_piece_data = data
	
	# 2. Mostrar la imagen
	
	# -----------------------------------------------------------------
	# ✅ LÍNEAS CORREGIDAS:
	#    Usamos "icon" (el nombre de tu variable en PieceData.gd)
	#    en lugar de "texture".
	# -----------------------------------------------------------------
	if current_piece_data and "icon" in current_piece_data:
		
		# Asegurarnos de que la textura no sea nula
		if current_piece_data.icon:
			piece_texture_rect.texture = current_piece_data.icon
			piece_texture_rect.visible = true
		else:
			push_warning("RouletteSlot: La propiedad 'icon' está vacía (null).")
			
	else:
		# Este mensaje de advertencia también lo actualizamos
		push_warning("RouletteSlot: El Resource soltado no tiene la propiedad 'icon'. No se puede mostrar la imagen.")

	# 3. Emitir la señal para que el Inventario elimine la pieza
	GlobalSignals.item_attached.emit(data)

# ¡NUEVO! Una función para limpiar el slot
func clear_slot():
	occupied = false
	current_piece_data = null
	if piece_texture_rect:
		piece_texture_rect.visible = false
func _on_gui_input(event: InputEvent) -> void:
	# 1. Salir si no es un clic izquierdo
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	# 2. Salir si el slot está vacío
	if not occupied:
		return
		
	# 3. Comprobar que la ruleta no esté girando
	if ruleta and ruleta.has_method("is_moving") and ruleta.is_moving():
		print("No se puede devolver la pieza: ¡La ruleta está girando!")
		return

	# 4. Crear un "callback" (una Callable) que apunte
	#    a nuestra nueva función local "_on_return_attempt_finished"
	var callback = Callable(self, "_on_return_attempt_finished")
	
	# 5. Emitir la señal global, pasando los datos Y el callback
	GlobalSignals.item_return_to_inventory_requested.emit(current_piece_data, callback)



func _on_return_attempt_finished(success: bool):
	if success:
		# 6. Si el inventario la aceptó (no estaba lleno),
		#    limpiamos este slot.
		clear_slot()
	else:
		# 7. Si el inventario falló (está lleno)
		print("No se puede devolver la pieza: ¡El inventario está lleno!")
