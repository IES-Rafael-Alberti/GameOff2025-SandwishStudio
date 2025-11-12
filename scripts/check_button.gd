extends CheckButton

@export var audio_bus_name: String

var audio_bus_id

func _on_ready() -> void:
	audio_bus_id = AudioServer.get_bus_index(audio_bus_id)

func _on_audio_control_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(audio_bus_id, value)
