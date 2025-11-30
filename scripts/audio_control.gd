extends HSlider

@export var audio_bus_name: String = "Master" 

var audio_bus_id: int

func _ready():
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)
	
	if audio_bus_id == -1:
		printerr("ERROR CRÍTICO: No se encontró el Bus de Audio llamado: ", audio_bus_name)
		set_process_input(false) # Desactivar el slider para que no de errores
		return
	value = db_to_linear(AudioServer.get_bus_volume_db(audio_bus_id))

func _on_value_changed(value: float) -> void:
	if audio_bus_id == -1:
		return

	AudioServer.set_bus_volume_db(audio_bus_id, linear_to_db(value))
