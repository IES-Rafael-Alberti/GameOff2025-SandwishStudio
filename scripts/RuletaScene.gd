extends Node2D
class_name RuletaScene

signal roulette_spin_started

# --- CONFIGURACIÓN DE FÍSICA ---
@export_group("Physics")
@export var friction: float = 0.985
@export var min_impulse_force: float = 60.0 # Ajustado para un mejor "giro"
@export var min_impulse_random_range: Vector2 = Vector2(1.0, 1.4) # Rango de impulso mejorado
@export var bounce_angle: float = 12.0
@export var bounce_time: float = 0.08

# --- CONFIGURACIÓN DE LA PALANCA ---
@export_group("Lever Mechanics")
@export var lever_max_angle: float = 75.0
@export var drag_sensitivity: float = 0.6
@export var activation_threshold: float = 0.75
@export var ratchet_step_angle: float = 10.0 # Cada cuántos grados suena el "clac"

# --- CONFIGURACIÓN DE JUICE (DOPAMINA) ---
@export_group("Visual Juice & FX")
@export var tension_color: Color = Color(1.5, 0.5, 0.5)
@export var speed_glow_color: Color = Color(1.2, 1.2, 1.3) # Brillo azulado
@export var highlight_color: Color = Color.from_hsv(0.1, 0.8, 1.0) # Color base de resalte (ej. naranja/victoria)
@export var flash_color: Color = Color(5.0, 3.0, 1.0) # Color de parpadeo muy brillante (HDR) - ¡NUEVO!
@export var flash_time: float = 0.1 # Duración del parpadeo rápido - ¡NUEVO!
@export var final_highlight_intensity: float = 2.0 # Multiplicador para el resalte del ganador - ¡NUEVO!
@export var shake_intensity_lever: float = 3.0
@export var screen_shake_force: float = 6.0
@export var zoom_strength: float = 0.05

@export_subgroup("Particle References")
@export var lever_release_particles: GPUParticles2D
@export var win_particles: GPUParticles2D

@export_subgroup("Audio & Camera")
@export var game_camera: Camera2D
@export var lever_ratchet_audio: AudioStreamPlayer # ARRASTRA AQUÍ UN SONIDO DE "CLIC" CORTO

# --- REFERENCIAS INTERNAS ---
@onready var slots_container: Node2D = $SpriteRuleta/SlotsContainer
@onready var lever_sprite: Sprite2D = $Lever
@onready var lever_area: Area2D = $Lever/AreaLever
@onready var manecilla_area: Area2D = $Manecilla
@onready var manecilla_sprite: Sprite2D = $Manecilla/SpriteManecilla
@onready var ticker_audio: AudioStreamPlayer = $Manecilla/AudioStreamPlayer

# --- MEMORIA DE POSICIONES ---
@onready var lever_origin_pos: Vector2 = $Lever.position
@onready var roulette_origin_pos: Vector2 = $SpriteRuleta.position
var camera_origin_zoom: Vector2 = Vector2.ONE
var lever_origin_rotation: float = 0.0 # Almacena la rotación inicial inclinada

# --- ESTADOS ---
enum State { IDLE, SPINNING }
var state: State = State.IDLE
var is_interactive: bool = true

# Variables lógica
var is_dragging_lever: bool = false
var drag_start_mouse_y: float = 0.0
var current_lever_rotation: float = 0.0
var inertia: float = 0.0
var _selected_area: Area2D = null
var bouncing: bool = false

# Variables FX
var shake_trauma: float = 0.0
var target_zoom: Vector2 = Vector2.ONE
var last_ratchet_angle: float = 0.0 # Para controlar el sonido de engranaje

# --- INICIO ---
func _ready() -> void:
	lever_origin_pos = lever_sprite.position
	roulette_origin_pos = $SpriteRuleta.position
	lever_origin_rotation = lever_sprite.rotation_degrees # CAPTURA LA INCLINACIÓN INICIAL
	
	if game_camera:
		camera_origin_zoom = game_camera.zoom
		target_zoom = camera_origin_zoom
	
	if GlobalSignals:
		GlobalSignals.piece_type_deleted.connect(_on_piece_type_deleted)
	
	if lever_area:
		lever_area.input_pickable = true
		lever_area.input_event.connect(_on_lever_input_event)
		
	if manecilla_area:
		manecilla_area.area_entered.connect(_on_manecilla_area_entered)

# --- INPUT Y PALANCA ---
func _on_lever_input_event(_viewport, event, _shape_idx):
	if not is_interactive or state != State.IDLE: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			start_dragging()

# Se llama cuando el script _ready() esté disponible
func _ready():
	# Conectamos la señal de borrado de inventario
	GlobalSignals.piece_type_deleted.connect(_on_piece_type_deleted)

func _input(event):
	if is_dragging_lever and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			release_lever()
			
	if is_dragging_lever and event is InputEventMouseMotion:
		update_lever_drag()

func start_dragging():
	is_dragging_lever = true
	drag_start_mouse_y = get_global_mouse_position().y
	last_ratchet_angle = 0.0 # Reset del ratchet
	
	# JUICE: Pop visual
	var t = create_tween()
	t.tween_property(lever_sprite, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_BACK)
func is_moving():
	return state != State.IDLE

func update_lever_drag():
	var current_mouse_y = get_global_mouse_position().y
	var diff = current_mouse_y - drag_start_mouse_y
	if diff < 0: diff = 0
	
	var target_angle_offset = diff * drag_sensitivity
	current_lever_rotation = clamp(target_angle_offset, 0.0, lever_max_angle)
	
	# La rotación es la inclinación inicial + el arrastre.
	lever_sprite.rotation_degrees = lever_origin_rotation + current_lever_rotation
	
	# --- JUICE: RATCHET AUDIO (CARRACA) ---
	# Si hemos pasado el umbral de ángulo desde el último clic, sonamos
	if lever_ratchet_audio and abs(current_lever_rotation - last_ratchet_angle) > ratchet_step_angle:
		last_ratchet_angle = current_lever_rotation
		# Variamos ligeramente el pitch para realismo mecánico
		lever_ratchet_audio.pitch_scale = randf_range(0.9, 1.1)
		lever_ratchet_audio.play()
	
	# JUICE: Feedback visual de tensión
	var progress = current_lever_rotation / lever_max_angle
	lever_sprite.modulate = Color.WHITE.lerp(tension_color, progress)
	
	var stretch = 1.0 + (progress * 0.15)
	var squash = 1.0 - (progress * 0.05)
	lever_sprite.scale = Vector2(squash, stretch)
	
	# JUICE: Jitter (tembleque)
	if progress > 0.9:
		var shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity_lever * (progress - 0.9) * 10
		lever_sprite.position = lever_origin_pos + shake_offset
	else:
		lever_sprite.position = lever_origin_pos

func release_lever():
	is_dragging_lever = false
	
	var percentage_pulled = current_lever_rotation / lever_max_angle
	
	if percentage_pulled >= activation_threshold:
		# --- DISPARAR ---
		trigger_spin()
		shake_trauma = 0.6
		
		if lever_release_particles:
			lever_release_particles.restart()
			lever_release_particles.emitting = true
		
		var t = create_tween()
		t.set_parallel(true)
		
		# Latigazo más brusco y corto hacia atrás (usando la rotación de origen)
		t.tween_property(lever_sprite, "rotation_degrees", lever_origin_rotation - 25.0, 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		
		# La palanca vuelve a su posición original inclinada (lever_origin_rotation) con rebote elástico.
		t.chain().tween_property(lever_sprite, "rotation_degrees", lever_origin_rotation, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		# CORRECCIÓN PALANCA: Asegura el reset de la posición del sprite después de la animación de rotación.
		t.chain().tween_callback(func(): lever_sprite.position = lever_origin_pos)

		t.parallel().tween_property(lever_sprite, "modulate", Color.WHITE, 0.3)
		# Tween de escala más largo para evitar que se quede "chica" (0.4s)
		t.parallel().tween_property(lever_sprite, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)
		
	else:
		# --- CANCELAR ---
		var t = create_tween()
		t.set_parallel(true)
		# Vuelve a la rotación de origen (inclinada).
		t.tween_property(lever_sprite, "rotation_degrees", lever_origin_rotation, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		t.tween_property(lever_sprite, "modulate", Color.WHITE, 0.2)
		# Tween de escala más largo para evitar que se quede "chica" (0.3s)
		t.tween_property(lever_sprite, "scale", Vector2.ONE, 0.3)

		t.chain().tween_callback(func(): lever_sprite.position = lever_origin_pos)
	  GlobalSignals.emit_signal("roulette_state_changed", true)



# --- LÓGICA CENTRAL ---

func trigger_spin():
	# CORRECCIÓN ILUMINACIÓN (DEFENSIVA): Llamar a _reset() aquí asegura que cualquier luz
	# residual de la ronda anterior se apague ANTES de empezar el nuevo giro.
	_reset()
	
	state = State.SPINNING
	_selected_area = null
	var pull_factor = current_lever_rotation / lever_max_angle
	var base_force = min_impulse_force * pull_factor
	var random_multiplier = randf_range(min_impulse_random_range.x, min_impulse_random_range.y)
	inertia = base_force * random_multiplier
	roulette_spin_started.emit()

func _process(delta: float) -> void:
	if state == State.SPINNING:
		_spin(delta)
		_process_zoom(delta)
		
	if shake_trauma > 0:
		shake_trauma = max(shake_trauma - delta * 2.0, 0)
		if state == State.IDLE:
			shake_trauma = 0
			$SpriteRuleta.position = roulette_origin_pos
			if game_camera: game_camera.zoom = camera_origin_zoom
		else:
			_apply_screen_shake()

func _spin(_delta: float):
	$SpriteRuleta.rotation_degrees += inertia
	
	var glow_amount = remap(clamp(inertia, 0, 50), 0, 50, 0.0, 1.0)
	$SpriteRuleta.modulate = Color.WHITE.lerp(speed_glow_color, glow_amount)
	
	inertia *= friction

	if abs(inertia) < 0.05:
		inertia = 0
		$SpriteRuleta.modulate = Color.WHITE # Asegurar color normal al parar
		_reward()
		_reset()

func _process_zoom(delta: float):
	if not game_camera: return
	if inertia < 10.0 and inertia > 0.1:
		var target = camera_origin_zoom * (1.0 + zoom_strength)
		game_camera.zoom = game_camera.zoom.lerp(target, delta * 2.0)
	else:
		game_camera.zoom = game_camera.zoom.lerp(camera_origin_zoom, delta * 5.0)

func _apply_screen_shake():
	var amount = shake_trauma * shake_trauma
	var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * screen_shake_force * amount
	$SpriteRuleta.position = roulette_origin_pos + offset

# --- MANECILLA ---

func _on_manecilla_area_entered(area: Area2D) -> void:
	if state != State.SPINNING: return
	_selected_area = area
	_bounce()
	_flash_segment(area) # Flash en el segmento al pasar la manecilla

func _bounce():
	if bouncing: return
	bouncing = true
	
	var spr = $Manecilla/SpriteManecilla
	var orig_pos = spr.position
	var orig_rot = spr.rotation_degrees
	
	spr.rotation_degrees = -bounce_angle
	spr.position.y -= 4
	spr.modulate = Color(1.5, 1.5, 1.5)
	
	if ticker_audio:
		# Audio turbina
		var pitch = remap(clamp(inertia, 0, 50), 0, 50, 0.7, 1.3)
		ticker_audio.pitch_scale = pitch
		ticker_audio.play()
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(spr, "rotation_degrees", orig_rot, bounce_time)
	t.tween_property(spr, "position", orig_pos, bounce_time)
	t.tween_property(spr, "modulate", Color.WHITE, 0.1)
	t.chain().tween_callback(func(): bouncing = false)

# --- RECOMPENSAS ---

func _flash_segment(area: Area2D) -> void:
	if not "slot_index" in area: return
	var slot_index: int = area.slot_index
	
	var count = slots_container.get_child_count()
	var safe_index = wrapi(slot_index, 0, count)
	var slot_root = slots_container.get_child(safe_index)
	
	if slot_root and slot_root.has_node("slot"):
		var actual_slot = slot_root.get_node("slot")
		if actual_slot is CanvasItem:
			# Resalte rápido al pasar (flash)
			var t = create_tween()
			t.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			t.tween_property(actual_slot, "modulate", flash_color, flash_time)
			# Vuelve a blanco más lentamente (APAGARSE)
			t.chain().tween_property(actual_slot, "modulate", Color.WHITE, flash_time * 2.0)


func _reward(): 
	# Primero, emitimos partículas de victoria
	if win_particles:
		win_particles.restart()
		win_particles.emitting = true

	if not _selected_area or not "slot_index" in _selected_area:
		GlobalSignals.emit_signal("combat_requested", null)
		return
	
	var index: int = _selected_area.slot_index
	if index >= slots_container.get_child_count():
		GlobalSignals.emit_signal("combat_requested", null)
		return

	var winning_slot_root = SlotsContainer.get_child(index)
	var actual_slot_node = null

	if winning_slot_root and winning_slot_root.has_node("slot"):
		actual_slot_node = winning_slot_root.get_node("slot")

	# Usamos 'current_piece_data' del script slot.gd
	if actual_slot_node and "current_piece_data" in actual_slot_node:
		
		var piece = actual_slot_node.current_piece_data
		
	var winning_slot_root = slots_container.get_child(index)
	
	# Resalte TEMPORAL de la victoria (ya no es permanente)
	if winning_slot_root and winning_slot_root.has_node("slot"):
		var actual_slot = winning_slot_root.get_node("slot")
		if actual_slot is CanvasItem:
			var final_highlight_color = highlight_color * final_highlight_intensity
			
			# Animación de entrada con efecto elástico
			var t = create_tween()
			t.set_trans(Tween.TRANS_ELASTIC)
			t.tween_property(actual_slot, "modulate", final_highlight_color, 0.3)
			
			# Vuelve a blanco para APAGARSE (requerimiento del usuario)
			t.chain().tween_property(actual_slot, "modulate", Color.WHITE, 0.5) 

			# La lógica de highlight permanente y su loop se ha eliminado.
			
			# Aseguramos el reset forzoso en _reset()
			if winning_slot_root.has_method("kill_highlight_tween"):
				winning_slot_root.kill_highlight_tween()

		# Lógica de recompensa
		if actual_slot and "current_piece_data" in actual_slot:
			var piece = actual_slot.current_piece_data
			if piece and piece.get("piece_origin"):
				print("¡Pieza obtenida: %s!" % piece.resource_name)
				GlobalSignals.emit_signal("combat_requested", piece.piece_origin)
				return
	
	GlobalSignals.emit_signal("combat_requested", null)

func _reset():
	_selected_area = null
	inertia = 0.0
	bouncing = false
	state = State.IDLE
	shake_trauma = 0.0
	$SpriteRuleta.position = roulette_origin_pos
	
	# CORRECCIÓN PALANCA (FORZOSO): Reset forzoso de la posición y ROTACIÓN del lever
	lever_sprite.position = lever_origin_pos
	lever_sprite.rotation_degrees = lever_origin_rotation # Fuerza la rotación a la posición inclinada
	
	# Asegurar que todos los slots vuelven a blanco/color normal
	for slot_root in slots_container.get_children():
		if slot_root.has_node("slot"):
			var actual_slot = slot_root.get_node("slot")
			if actual_slot is CanvasItem:
				
				# Detener cualquier Tween de parpadeo que pudiera existir
				if slot_root.has_method("kill_highlight_tween"):
					slot_root.kill_highlight_tween()

				# Resetear el color a la normalidad (Color.WHITE)
				actual_slot.modulate = Color.WHITE
	
	# Detener las partículas de victoria
	if win_particles:
		win_particles.emitting = false
	
	if game_camera:
		var t = create_tween()
		t.tween_property(game_camera, "zoom", camera_origin_zoom, 0.5).set_trans(Tween.TRANS_CUBIC)

# --- UTILIDADES ---


	GlobalSignals.emit_signal("roulette_state_changed", false)


func reset_rotation_to_zero():
	if state == State.IDLE:
		$SpriteRuleta.rotation_degrees = 0.0
		$SpriteRuleta.position = roulette_origin_pos

func set_interactive(interactive: bool):
	is_interactive = interactive
	if lever_sprite:
		lever_sprite.modulate = Color.WHITE if interactive else Color(0.5, 0.5, 0.5)


# --- ¡NUEVA FUNCIÓN DE SEÑAL!
# Se llama cuando GlobalSignals.piece_type_deleted se emite desde inventory.gd
func _on_piece_type_deleted(piece_data: PieceData):
	if not piece_data:
		return
		
	print("... Ruleta ha recibido orden de borrado para: %s" % piece_data.resource_name)
	
	# Recorremos todos los slots de la ruleta
	for slot_root in SlotsContainer.get_children():
		if not slot_root.has_node("slot"):
			continue
			
		var slot = slot_root.get_node("slot")
		
		# Usamos la variable 'current_piece_data' de tu script slot.gd
		if slot and "current_piece_data" in slot:
			
			# Si la pieza en este slot es la que se borró
			if slot.current_piece_data == piece_data:
				
				# Usamos el método 'clear_slot()' de tu script slot.gd
				if slot.has_method("clear_slot"):
					print("... ... Limpiando slot %s" % slot.name)
					slot.clear_slot()
				else:
					push_warning("Ruleta: El slot %s no tiene método clear_slot()" % slot.name)

