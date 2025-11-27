extends Panel

# Referencia al icono visual del pozo (asegúrate de que existe como hijo)
@onready var sprite: TextureRect = $Sprite2D

# Configuración del efecto de caída
@export var fall_duration: float = 0.6
@export var fall_scale: Vector2 = Vector2(0.1, 0.1)
@export var fall_rotation: float = 180.0

var normal_color = Color.WHITE
var hover_color = Color(1.0, 1.0, 1.0, 0.7)
var _is_roulette_spinning: bool = false

func _ready() -> void:
	if sprite:
		sprite.modulate = normal_color
	
	# Detectar si el ratón sale para quitar el brillo
	mouse_exited.connect(_on_mouse_exited)
	
	if GlobalSignals:
		GlobalSignals.roulette_state_changed.connect(_on_roulette_state_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if sprite:
			sprite.modulate = normal_color

# --- DRAG & DROP ---

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# 1. Validaciones de estado del juego (Ruleta girando, etc.)
	var game_manager = get_tree().current_scene
	if game_manager and "current_state" in game_manager:
		# Bloquear si estamos en combate (2) o recompensa (3)
		if game_manager.current_state == 2 or game_manager.current_state == 3:
			return false
			
	if _is_roulette_spinning:
		return false

	# 2. Validación del objeto
	var can_drop = false
	if data is Dictionary and "data" in data:
		can_drop = (data.data is Resource)
	
	# 3. Feedback visual (brillo del pozo)
	if can_drop and sprite:
		sprite.modulate = hover_color
		
	return can_drop

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# Restaurar color del pozo
	if sprite:
		sprite.modulate = normal_color

	var item = data.data
	if not item: return
	
	# 1. VENDER: Emitimos la señal original que tu sistema ya conoce
	GlobalSignals.item_deleted.emit(item)
	
	# 2. EFECTO VISUAL: Reproducimos la animación de caída
	_play_drop_effect(item)

# --- LÓGICA DEL EFECTO VISUAL (La parte nueva) ---

func _play_drop_effect(item: Resource) -> void:
	# Intentamos sacar la textura del PieceData
	if not item or not "piece_origin" in item: return
	if not item.piece_origin or not "frames" in item.piece_origin: return
	
	var sprite_frames = item.piece_origin.frames
	if not sprite_frames: return

	# Buscar frame: intentamos "idle", si no "default"
	var anim_name = "idle"
	if not sprite_frames.has_animation(anim_name):
		anim_name = "default"
	
	if not sprite_frames.has_animation(anim_name): return
		
	var texture = sprite_frames.get_frame_texture(anim_name, 0)
	if not texture: return
	
	# Crear sprite temporal "cayendo"
	var falling_sprite = Sprite2D.new()
	falling_sprite.texture = texture
	falling_sprite.z_index = 100 # Encima de todo
	
	# Añadirlo a la raíz para que sea independiente de la UI
	get_tree().root.add_child(falling_sprite)
	
	# Posición inicial: Donde está el ratón
	falling_sprite.global_position = get_global_mouse_position()
	
	# Posición final: Centro del pozo (DeleteArea)
	var target_pos = get_global_rect().get_center()
	
	# Animación
	var t = create_tween()
	t.set_parallel(true)
	t.set_ease(Tween.EASE_IN) # Acelera al caer
	t.set_trans(Tween.TRANS_QUAD)
	
	# Se mueve al centro, se encoge y gira
	t.tween_property(falling_sprite, "global_position", target_pos, fall_duration)
	t.tween_property(falling_sprite, "scale", fall_scale, fall_duration)
	t.tween_property(falling_sprite, "rotation_degrees", fall_rotation, fall_duration)
	
	# Se oscurece/desvanece un poco al final
	t.tween_property(falling_sprite, "modulate", Color(0.5, 0.5, 0.5, 0.0), fall_duration)

	# Borrar al terminar
	t.chain().tween_callback(falling_sprite.queue_free)

# --- SIGNALS AUXILIARES ---

func _on_mouse_exited() -> void:
	if sprite:
		sprite.modulate = normal_color

func _on_roulette_state_changed(is_spinning: bool):
	_is_roulette_spinning = is_spinning
	if is_spinning and sprite:
		sprite.modulate = normal_color
