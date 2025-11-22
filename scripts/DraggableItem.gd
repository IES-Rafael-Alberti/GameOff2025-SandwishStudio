extends TextureButton

var item_data: Resource
var item_count: int = 1
"""
Esta función se llama automáticamente cuando Godot detecta
que un arrastre comienza sobre este botón.
"""
func _get_drag_data(_at_position: Vector2) -> Variant:
	
	if item_data == null:
		return null
		
	var preview = TextureRect.new()
	preview.z_index = 4096
	preview.texture = self.texture_normal
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(75, 75) 
	set_drag_preview(preview)
	
	self.modulate = Color(0.5, 0.5, 0.5) 

	# ¡CAMBIO CLAVE! Creamos un "paquete" (diccionario) con los datos Y la cantidad
	var drag_data_packet = {
		"data": item_data,
		"count": item_count 
	}
	
	return drag_data_packet # <-- Devolvemos el paquete
"""
Esta función virtual recibe notificaciones del motor.
Detecta cuándo termina el arrastre.
"""
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		self.modulate = Color(1.0, 1.0, 1.0)
