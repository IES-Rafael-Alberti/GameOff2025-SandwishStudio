extends Panel

# Referencias
@onready var sprite: TextureRect = $Sprite2D
@onready var coin_up: TextureRect = $CoinUp 

# --- CONFIGURACIÓN DE AUDIO (NUEVO) ---
@export_group("Audio")
@export var sfx_sell_item: AudioStream # Asigna aquí tu sonido .wav o .ogg
@export var sfx_bus_name: String = "SFX" # Nombre del bus (por defecto SFX)

# Configuración del efecto de caída (Item)
@export_group("Visual Effects")
@export var fall_duration: float = 0.6
@export var fall_scale: Vector2 = Vector2(0.1, 0.1)
@export var fall_rotation: float = 180.0

# Configuración del efecto CoinUp
@export var coin_float_distance: float = 60.0
@export var coin_anim_duration: float = 0.8

var normal_color = Color.WHITE
var hover_color = Color(1.0, 1.0, 1.0, 0.7)
var _is_roulette_spinning: bool = false

# Variable interna para el reproductor de sonido
var _sfx_player: AudioStreamPlayer

func _ready() -> void:
	if sprite:
		sprite.modulate = normal_color
	
	if coin_up:
		coin_up.visible = false
		coin_up.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# --- SETUP AUDIO ---
	_setup_audio_player()
	
	mouse_exited.connect(_on_mouse_exited)
	
	if GlobalSignals:
		GlobalSignals.roulette_state_changed.connect(_on_roulette_state_changed)

# Crea el reproductor de sonido dinámicamente
func _setup_audio_player() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SellSFXPlayer"
	_sfx_player.bus = sfx_bus_name # Asigna el bus SFX
	add_child(_sfx_player)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if sprite:
			sprite.modulate = normal_color

# --- DRAG & DROP ---

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var game_manager = get_tree().current_scene
	if game_manager and "current_state" in game_manager:
		if game_manager.current_state == 2 or game_manager.current_state == 3:
			return false
			
	if _is_roulette_spinning:
		return false

	var can_drop = false
	if data is Dictionary and "data" in data:
		can_drop = (data.data is Resource)
	
	if can_drop and sprite:
		sprite.modulate = hover_color
		
	return can_drop

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if sprite:
		sprite.modulate = normal_color

	var item = data.data
	if not item: return
	
	# 1. Vender (Lógica inmediata)
	GlobalSignals.item_deleted.emit(item)
	
	# --- REPRODUCIR SONIDO ---
	_play_sell_sound()
	
	# 2. Intentar Animación de Caída
	var animation_started = _play_drop_effect(item)
	
	# 3. Fallback visual
	if not animation_started:
		_play_coin_pop()

# --- FUNCIONES DE AUDIO ---

func _play_sell_sound() -> void:
	if sfx_sell_item and _sfx_player:
		_sfx_player.stream = sfx_sell_item
		# Pequeña variación de tono para "jugosidad" (0.9 a 1.1)
		_sfx_player.pitch_scale = randf_range(0.9, 1.1)
		_sfx_player.play()

# --- EFECTOS VISUALES ---

func _play_drop_effect(item: Resource) -> bool:
	# Verificaciones de seguridad para extraer textura
	if not item or not "piece_origin" in item: return false
	if not item.piece_origin or not "frames" in item.piece_origin: return false
	
	var sprite_frames = item.piece_origin.frames
	if not sprite_frames: return false

	var anim_name = "idle"
	if not sprite_frames.has_animation(anim_name):
		anim_name = "default"
	if not sprite_frames.has_animation(anim_name): return false
		
	var texture = sprite_frames.get_frame_texture(anim_name, 0)
	if not texture: return false
	
	# --- INICIO DE ANIMACIÓN ---
	
	var falling_sprite = Sprite2D.new()
	falling_sprite.texture = texture
	falling_sprite.z_index = 100 
	get_tree().root.add_child(falling_sprite)
	
	falling_sprite.global_position = get_global_mouse_position()
	var target_pos = get_global_rect().get_center()
	
	var t = create_tween()
	t.set_parallel(true)
	t.set_ease(Tween.EASE_IN) 
	t.set_trans(Tween.TRANS_QUAD)
	
	t.tween_property(falling_sprite, "global_position", target_pos, fall_duration)
	t.tween_property(falling_sprite, "scale", fall_scale, fall_duration)
	t.tween_property(falling_sprite, "rotation_degrees", fall_rotation, fall_duration)
	t.tween_property(falling_sprite, "modulate", Color(0.5, 0.5, 0.5, 0.0), fall_duration)

	# --- CADENA DE FINALIZACIÓN ---
	t.chain().tween_callback(falling_sprite.queue_free)
	
	# Y justo después, activamos la moneda
	t.tween_callback(_play_coin_pop)
	
	return true

func _play_coin_pop() -> void:
	if not coin_up: return
	
	# Resetear estado
	coin_up.visible = true
	coin_up.modulate.a = 1.0
	
	# Posicionar
	coin_up.pivot_offset = coin_up.size / 2.0
	coin_up.position = (size - coin_up.size) / 2.0
	coin_up.position.y -= 20.0 
	
	var start_pos_y = coin_up.position.y
	var target_pos_y = start_pos_y - coin_float_distance
	
	# Animar
	var t = create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)
	
	t.tween_property(coin_up, "position:y", target_pos_y, coin_anim_duration)
	t.tween_property(coin_up, "modulate:a", 0.0, coin_anim_duration)
	
	coin_up.scale = Vector2(0.5, 0.5)
	t.tween_property(coin_up, "scale", Vector2(1.2, 1.2), coin_anim_duration * 0.5).set_trans(Tween.TRANS_ELASTIC)
	
	t.chain().tween_callback(coin_up.hide)

# --- SIGNALS ---

func _on_mouse_exited() -> void:
	if sprite:
		sprite.modulate = normal_color

func _on_roulette_state_changed(is_spinning: bool):
	_is_roulette_spinning = is_spinning
	if is_spinning and sprite:
		sprite.modulate = normal_color
