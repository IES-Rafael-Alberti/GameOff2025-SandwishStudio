extends HSlider

@export var audio_bus_name: String

var audio_bus_id

func _ready():
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)
	
func _on_value_changed(value: float) -> void:
	# value debería ir de 0.0 a 1.0
	var v : float = clamp(value, 0.0001, 1.0)
	var db : float = linear_to_db(v)
	AudioServer.set_bus_volume_db(audio_bus_id, db)
