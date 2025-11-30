extends Control

signal opened
signal closed

@onready var papiro: TextureRect = $Papiro

# --- REFERENCIAS A LOS SLIDERS DE AUDIO ---
# Asegúrate de que estos nodos sean HSlider en el editor
@onready var master_slider: HSlider = $Papiro/Sonidos/MasterControl
@onready var music_slider: HSlider = $Papiro/Sonidos/MusicControl
@onready var sfx_slider: HSlider = $Papiro/Sonidos/SfxControl

var _visible_pos: Vector2
var _hidden_pos: Vector2
var _closing: bool = false
var is_pause_menu: bool = false

# Nombres de los buses en el AudioServer (Tal cual los escribiste en tu solicitud)
const BUS_MASTER = "Master"
const BUS_MUSIC = "Music"
const BUS_SFX = "SFX"

func _ready() -> void:
	# Configuración visual (Tu código original)
	top_level = true
	z_index = 500
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Configuración de Audio (NUEVO)
	_setup_audio()

	# Tu lógica original de posición inicial
	_visible_pos = papiro.position 
	_hidden_pos = Vector2(-papiro.size.x - 350.0, _visible_pos.y)
	papiro.position = _hidden_pos

	# Animación de entrada por defecto
	var tween := create_tween()
	tween.tween_property(papiro, "position", _visible_pos, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		opened.emit()
	)

# --- LÓGICA DE AUDIO (NUEVO) ---
func _setup_audio() -> void:
	# 1. Configurar Master
	var master_idx = AudioServer.get_bus_index(BUS_MASTER)
	# Obtenemos el volumen real actual y lo convertimos a lineal (0 a 1) para el slider
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_idx))
	# Conectamos la señal cuando el jugador mueve el slider
	master_slider.value_changed.connect(_on_master_value_changed)
	
	# 2. Configurar Música
	var music_idx = AudioServer.get_bus_index(BUS_MUSIC)
	music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_idx))
	music_slider.value_changed.connect(_on_music_value_changed)
	
	# 3. Configurar SFX
	var sfx_idx = AudioServer.get_bus_index(BUS_SFX)
	sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_idx))
	sfx_slider.value_changed.connect(_on_sfx_value_changed)

# Funciones que se ejecutan al mover los sliders
func _on_master_value_changed(value: float) -> void:
	var idx = AudioServer.get_bus_index(BUS_MASTER)
	_update_bus_volume(idx, value)

func _on_music_value_changed(value: float) -> void:
	var idx = AudioServer.get_bus_index(BUS_MUSIC)
	_update_bus_volume(idx, value)

func _on_sfx_value_changed(value: float) -> void:
	var idx = AudioServer.get_bus_index(BUS_SFX)
	_update_bus_volume(idx, value)

# Función auxiliar para convertir 0-1 a Decibelios
func _update_bus_volume(bus_idx: int, value: float) -> void:
	# Convertimos valor lineal a DB. 
	# Nota: Si el valor es 0, linear_to_db devuelve -infinito (silencio)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	
	# Opcional: Mutear si el volumen es muy bajo (casi 0)
	AudioServer.set_bus_mute(bus_idx, value < 0.01)

# --- TU CÓDIGO ORIGINAL CONTINÚA AQUÍ ---

func _setup_and_open() -> void:
	var viewport_size := get_viewport_rect().size

	if is_pause_menu:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		position = Vector2.ZERO
		size = viewport_size
		mouse_filter = Control.MOUSE_FILTER_STOP

		_visible_pos = (viewport_size - papiro.size) * 0.5
	else:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

		_visible_pos = papiro.position

	_hidden_pos = _visible_pos + Vector2(0, -papiro.size.y * 1.4)
	papiro.position = _hidden_pos

	# print("OPTIONS _setup_and_open  is_pause_menu =", is_pause_menu,
	#	"  visible_pos =", _visible_pos, "  hidden_pos =", _hidden_pos)

	var tween := create_tween()
	tween.tween_property(papiro, "position", _visible_pos, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		opened.emit()
	)

func set_as_pause_menu(value: bool = true) -> void:
	is_pause_menu = value
	var tree := get_tree()
	if is_pause_menu:
		if tree:
			# print("OPTIONS: set_as_pause_menu(true) -> tree.paused = true")
			tree.paused = true
	else:
		if tree:
			# print("OPTIONS: set_as_pause_menu(false) -> tree.paused = false")
			tree.paused = false

func close_with_anim() -> void:
	if _closing:
		return
	_closing = true

	var tween := create_tween()
	tween.tween_property(papiro, "position", _hidden_pos, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		var tree := get_tree()
		if is_pause_menu and tree:
			tree.paused = false
			# print("OPTIONS: cerrando pausa -> tree.paused = false")
		closed.emit()
		queue_free()
	)

func _on_back_pressed() -> void:
	close_with_anim()

func _process(delta: float) -> void:
	if is_pause_menu and Input.is_action_just_pressed("pause"):
		close_with_anim()
