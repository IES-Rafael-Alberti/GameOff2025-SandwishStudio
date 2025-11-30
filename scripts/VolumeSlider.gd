extends HSlider

# Exportamos el nombre del bus para poder escribir "Master", "Music" o "SFX" 
# directamente desde el inspector de Godot para cada slider.
@export var bus_name: String = "Master"

var _bus_index: int

func _ready() -> void:
	_bus_index = AudioServer.get_bus_index(bus_name)
	
	value = db_to_linear(AudioServer.get_bus_volume_db(_bus_index))
	
	value_changed.connect(_on_value_changed)

func _on_value_changed(new_value: float) -> void:

	AudioServer.set_bus_volume_db(_bus_index, linear_to_db(new_value))
