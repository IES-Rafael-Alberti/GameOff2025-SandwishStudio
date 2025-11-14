# Supongamos que este script se llama RouletteSlot.gd
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
var current_piece_count: int = 0 # <-- ¡NUEVA VARIABLE!
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
		piece_texture_rect.visible = false # Empezar oculto
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
	
	if ruleta and ruleta.has_method("is_moving"):
		if ruleta.is_moving():
			return false
	
	if occupied:
		return false
		
	# ¡CAMBIO! Comprobamos si 'data' es nuestro nuevo diccionario
	if data is Dictionary and "data" in data and "count" in data:
		return data.data is PieceData # Comprobamos el 'PieceData' dentro del diccionario

	return false # Si no es el diccionario, lo rechazamos
# En tu script de Slot de Ruleta (slot.gd)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	
	# 1. Marcar como ocupado y guardar los datos
	occupied = true
	current_piece_data = data.data   # <-- ¡CAMBIO! Extraemos los datos
	current_piece_count = data.count # <-- ¡NUEVA LÍNEA! Guardamos la cantidad
	

	if current_piece_data and "icon" in current_piece_data:
		
		if current_piece_data.icon:
			piece_texture_rect.texture = current_piece_data.icon
			piece_texture_rect.visible = true
		else:
			push_warning("RouletteSlot: La propiedad 'icon' está vacía (null).")
			
	else:
		push_warning("RouletteSlot: El Resource soltado no tiene la propiedad 'icon'. No se puede mostrar la imagen.")

	# 3. Emitir la señal para que el Inventario elimine la pieza
	#    Le pasamos solo el 'data.data' (el Resource), que es lo que
	#    'remove_item_no_money' espera recibir.
	GlobalSignals.item_attached.emit(data.data)
func clear_slot():
	occupied = false
	current_piece_data = null
	current_piece_count = 0 # <-- ¡NUEVA LÍNEA!
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

# 4. Crear un "callback" ...
	var callback = Callable(self, "_on_return_attempt_finished")
	
	# 5. ¡CAMBIO CLAVE! Creamos el "paquete de datos" para DEVOLVER
	var return_data_packet = {
		"data": current_piece_data,
		"count": current_piece_count # Usamos la cantidad que guardamos
	}
	
	# 5. Emitir la señal global, pasando el PAQUETE de datos Y el callback
	GlobalSignals.item_return_to_inventory_requested.emit(return_data_packet, callback)




func _on_return_attempt_finished(success: bool):
	if success:
		# 6. Si el inventario la aceptó (no estaba lleno),
		#    limpiamos este slot.
		clear_slot()
	else:
		# 7. Si el inventario falló (está lleno)
		print("No se puede devolver la pieza: ¡El inventario está lleno!")
