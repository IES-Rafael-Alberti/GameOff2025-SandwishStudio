extends CanvasLayer

signal opened
signal closed

@onready var papiro: TextureRect = $Papiro

# --- REFERENCIAS A LOS SLIDERS DE AUDIO ---
@onready var master_slider: HSlider = $Papiro/Sonidos/MasterControl
@onready var music_slider: HSlider = $Papiro/Sonidos/MusicControl
@onready var sfx_slider: HSlider = $Papiro/Sonidos/SfxControl

var _closing: bool = false
var is_pause_menu: bool = false

const BUS_MASTER = "Master"
const BUS_MUSIC = "Music"
const BUS_SFX = "SFX"

func _ready() -> void:
	# Configuración visual
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Configuración de Audio
	_setup_audio()

	# Aseguramos el punto de pivote al centro
	papiro.pivot_offset = papiro.size * 0.5
	papiro.scale = Vector2(0.7, 0.7)
	papiro.modulate.a = 0.0  # invisible al inicio

	# Centramos el papiro en pantalla
	var viewport_size := get_viewport().get_visible_rect().size
	papiro.position = (viewport_size - papiro.size) * 0.5

	# Animación de aparición (de menos a más desde el centro)
	var tween := create_tween()
	tween.tween_property(papiro, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(papiro, "modulate:a", 1.0, 0.45)
	tween.finished.connect(func(): opened.emit())

# --- LÓGICA DE AUDIO ---
func _setup_audio() -> void:
	var master_idx = AudioServer.get_bus_index(BUS_MASTER)
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_idx))
	master_slider.value_changed.connect(_on_master_value_changed)

	var music_idx = AudioServer.get_bus_index(BUS_MUSIC)
	music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_idx))
	music_slider.value_changed.connect(_on_music_value_changed)

	var sfx_idx = AudioServer.get_bus_index(BUS_SFX)
	sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_idx))
	sfx_slider.value_changed.connect(_on_sfx_value_changed)

func _on_master_value_changed(value: float) -> void:
	_update_bus_volume(AudioServer.get_bus_index(BUS_MASTER), value)

func _on_music_value_changed(value: float) -> void:
	_update_bus_volume(AudioServer.get_bus_index(BUS_MUSIC), value)

func _on_sfx_value_changed(value: float) -> void:
	_update_bus_volume(AudioServer.get_bus_index(BUS_SFX), value)

func _update_bus_volume(bus_idx: int, value: float) -> void:
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	AudioServer.set_bus_mute(bus_idx, value < 0.01)

# --- LÓGICA DE APERTURA Y CIERRE ---
func _setup_and_open() -> void:
	var viewport_size := get_viewport().get_visible_rect().size

	if is_pause_menu:
		papiro.position = (viewport_size - papiro.size) * 0.5

	papiro.pivot_offset = papiro.size * 0.5
	papiro.scale = Vector2(0.7, 0.7)
	papiro.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(papiro, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(papiro, "modulate:a", 1.0, 0.45)
	tween.finished.connect(func(): opened.emit())

func set_as_pause_menu(value: bool = true) -> void:
	is_pause_menu = value
	var tree := get_tree()
	if tree:
		tree.paused = value

func close_with_anim() -> void:
	if _closing:
		return
	_closing = true

	var tween := create_tween()
	tween.tween_property(papiro, "scale", Vector2(0.7, 0.7), 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(papiro, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func():
		if is_pause_menu:
			var tree := get_tree()
			if tree:
				tree.paused = false
		closed.emit()
		queue_free()
	)

func _on_back_pressed() -> void:
	close_with_anim()

func _process(delta: float) -> void:
	if is_pause_menu and Input.is_action_just_pressed("pause"):
		close_with_anim()
