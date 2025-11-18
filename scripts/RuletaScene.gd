extends Node2D

signal roulette_spin_started

# --- CONFIGURACIÓN DE LA RULETA ---
@export var friction := 0.985
@export var bounce_angle := 12.0
@export var bounce_time := 0.08
@export var min_impulse_force := 45.0 
@export var min_impulse_random_range := Vector2(1.0, 1.4)

# --- CONFIGURACIÓN DE LA PALANCA (FEELING) ---
@export_category("Lever Feel")
@export var lever_max_angle := 55.0    
@export var drag_sensitivity := 0.5    
@export var activation_threshold := 0.8 

# --- REFERENCIAS (OnReady) ---
# Ajustados según tu imagen
@onready var SlotsContainer: Node2D = $SpriteRuleta/SlotsContainer
@onready var lever_sprite: Sprite2D = $Lever
@onready var lever_area: Area2D = $Lever/AreaLever 
@onready var manecilla_area: Area2D = $Manecilla # Asumiendo que el nodo raíz Manecilla es el Area2D
@onready var manecilla_sprite: Sprite2D = $Manecilla/SpriteManecilla

# --- ESTADOS ---
enum State { IDLE, SPINNING }
var state := State.IDLE
var is_interactive := true

# Variables palanca
var is_dragging_lever := false
var drag_start_mouse_y := 0.0
var current_lever_rotation := 0.0

# Variables física
var inertia := 0.0
var _selected_area: Area2D = null
var bouncing := false

# --- INICIO ---
func _ready():
	# Conectar señales globales si existen
	if GlobalSignals:
		GlobalSignals.piece_type_deleted.connect(_on_piece_type_deleted)
	
	# 1. CONEXIÓN PALANCA
	if lever_area:
		# Aseguramos que el área sea detectable
		lever_area.input_pickable = true 
		lever_area.input_event.connect(_on_lever_input_event)
	else:
		printerr("ERROR: No se encontró $Lever/AreaLever")

	# 2. CONEXIÓN MANECILLA (CRÍTICO: Esto faltaba o fallaba)
	if manecilla_area:
		manecilla_area.area_entered.connect(_on_AreaManecilla_area_entered)
	else:
		printerr("ERROR: No se encontró el nodo $Manecilla o no es un Area2D")

# --- INPUT GESTURE (ARRASTRAR PALANCA) ---

func _on_lever_input_event(_viewport, event, _shape_idx):
	# Validaciones iniciales
	if not is_interactive or state != State.IDLE: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			print("DEBUG: Palanca agarrada")
			start_dragging()

func _input(event):
	# Soltar la palanca (Global input para no perder el agarre si el mouse sale del área)
	if is_dragging_lever and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			release_lever()
			
	# Mover la palanca
	if is_dragging_lever and event is InputEventMouseMotion:
		update_lever_drag()

func start_dragging():
	is_dragging_lever = true
	drag_start_mouse_y = get_global_mouse_position().y

func update_lever_drag():
	var current_mouse_y = get_global_mouse_position().y
	var diff = current_mouse_y - drag_start_mouse_y
	
	if diff < 0: diff = 0
	
	var target_angle = diff * drag_sensitivity
	current_lever_rotation = clamp(target_angle, 0.0, lever_max_angle)
	
	lever_sprite.rotation_degrees = current_lever_rotation

func release_lever():
	is_dragging_lever = false
	print("DEBUG: Palanca soltada. Angulo actual: ", current_lever_rotation)
	
	var percentage_pulled = current_lever_rotation / lever_max_angle
	
	if percentage_pulled >= activation_threshold:
		trigger_spin()
		# Animación retorno elástica
		var t = create_tween()
		t.tween_property(lever_sprite, "rotation_degrees", 0.0, 0.4)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		# Cancelar (volver suave)
		var t = create_tween()
		t.tween_property(lever_sprite, "rotation_degrees", 0.0, 0.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# --- LÓGICA DE GIRO (SPIN) ---

func trigger_spin():
	print("DEBUG: ¡Giro iniciado!")
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

func _spin(_delta: float):
	$SpriteRuleta.rotation_degrees += inertia
	inertia *= friction

	# Detenerse cuando la inercia es muy baja
	if abs(inertia) < 0.05:
		inertia = 0
		_reward() 
		_reset()

# --- SISTEMA DE MANECILLA (TIC-TIC-TIC) ---

func _on_AreaManecilla_area_entered(area: Area2D) -> void:
	# Solo rebotamos si estamos girando
	# Nota: Si quieres que suene al moverla con la mano manualmente, quita el check de State.SPINNING
	if state != State.SPINNING: return
	
	# Guardamos el área actual como la "posible ganadora"
	_selected_area = area 
	_bounce()

func _bounce():
	if bouncing: return
	bouncing = true
	
	var orig_pos = manecilla_sprite.position
	var orig_rot = manecilla_sprite.rotation_degrees
	
	# Golpe visual
	manecilla_sprite.rotation_degrees = -bounce_angle
	manecilla_sprite.position.y -= 4
	
	# Sonido (Opcional, descomentar si tienes el nodo)
	if $Manecilla/AudioStreamPlayer:
		$Manecilla/AudioStreamPlayer.play()
	
	var t = create_tween()
	t.tween_property(manecilla_sprite, "rotation_degrees", orig_rot, bounce_time)
	t.tween_property(manecilla_sprite, "position", orig_pos, bounce_time)
	t.finished.connect(func(): bouncing = false)

# --- RECOMPENSAS ---

func _reward():
	print("DEBUG: Calculando recompensa...")
	if not _selected_area:
		print("RESULTADO: La ruleta se detuvo pero _selected_area es null. (¿No chocó con nada?)")
		GlobalSignals.emit_signal("combat_requested", null)
		return

	# Intentamos obtener el índice del slot
	if not "slot_index" in _selected_area:
		print("RESULTADO: El área detectada no tiene 'slot_index'. Nombre área: ", _selected_area.name)
		GlobalSignals.emit_signal("combat_requested", null)
		return

	var index: int = _selected_area.slot_index
	print("DEBUG: Slot ganador índice: ", index)
	
	if index >= SlotsContainer.get_child_count():
		print("ERROR: Índice fuera de rango.")
		return

	var winning_slot_root = SlotsContainer.get_child(index)
	
	if winning_slot_root and winning_slot_root.has_node("slot"):
		var actual_slot = winning_slot_root.get_node("slot")
		
		if actual_slot and "current_piece_data" in actual_slot:
			var piece = actual_slot.current_piece_data 
			# Verificación de tipo segura
			if piece and piece.get("piece_origin"): # Usamos get para seguridad
				print("¡PREMIO: %s!" % piece.resource_name)
				GlobalSignals.emit_signal("combat_requested", piece.piece_origin)
				return
	
	# Fallback si no hay premio
	print("RESULTADO: Slot vacío o sin datos válidos.")
	GlobalSignals.emit_signal("combat_requested", null)

# --- RESET Y UTILIDADES ---

func _reset():
	_selected_area = null
	inertia = 0.0
	bouncing = false
	state = State.IDLE
	print("DEBUG: Ruleta reseteada a IDLE")

func reset_rotation_to_zero():
	if state == State.IDLE:
		$SpriteRuleta.rotation_degrees = 0.0

func set_interactive(interactive: bool):
	is_interactive = interactive
	if lever_sprite:
		lever_sprite.modulate = Color.WHITE if interactive else Color(0.5, 0.5, 0.5)

func _on_piece_type_deleted(piece_data):
	if not piece_data or not SlotsContainer: return
	for slot_root in SlotsContainer.get_children():
		if slot_root.has_node("slot"):
			var slot = slot_root.get_node("slot")
			if slot and slot.get("current_piece_data") == piece_data:
				if slot.has_method("clear_slot"): slot.clear_slot()
