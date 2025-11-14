extends Node2D
@export var friction := 0.985
@export var snap_speed := 7.5
@export var bounce_angle := 12.0
@export var bounce_time := 0.08
@export var enemy_manager: Node
@export var min_impulse_force := 10.0
@export var min_impulse_random_range := Vector2(1.5, 4)
@onready var SlotsContainer: Node2D = $SpriteRuleta/SlotsContainer

enum State { IDLE, DRAGGING, SPINNING, SNAP}
var state := State.IDLE
var last_mouse_angle := 0.0
var inertia := 0.0
var _selected_area: Area2D = null
var bouncing := false
func is_moving(): return state != State.IDLE


func _process(delta: float) -> void:
	match state:
		State.DRAGGING:
			_drag()
		State.SPINNING:
			_spin(delta)
		State.SNAP:
			_snap(delta)


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		
		if event.pressed and state == State.IDLE:
			state = State.DRAGGING
			last_mouse_angle = rad_to_deg((get_global_mouse_position() - $SpriteRuleta.global_position).angle())
		
		
		elif not event.pressed and state == State.DRAGGING:
			state = State.SPINNING
			
			# Calculamos el impulso mínimo aleatorio
			var min_boost = min_impulse_force * randf_range(min_impulse_random_range.x, min_impulse_random_range.y)
			
			# --- CAMBIO PRINCIPAL ---
			# Ahora, SIEMPRE sumamos el impulso mínimo a la inercia
			# que se generó con el arrastre (sea grande o pequeña).
			inertia += min_boost
			
			_selected_area = null
		# ---------------------------------

func _drag():
	var mouse = get_global_mouse_position()
	var center = $SpriteRuleta.global_position
	var angle_deg = rad_to_deg((mouse-center).angle())
	var diff = fmod((angle_deg-last_mouse_angle+540),360)-180
	last_mouse_angle = angle_deg
	
	# --- CAMBIO AQUÍ: Invertida la condición > por < ---
	# Esto solo permite que la 'diff' (diferencia) sea positiva,
	# invirtiendo la dirección del giro.
	if diff < 0.0:
		diff = 0.0
	
	inertia = diff*1.2
	$SpriteRuleta.rotation_degrees += inertia


func _spin(delta: float):
	$SpriteRuleta.rotation_degrees += inertia
	inertia *= friction

	if abs(inertia) < 0.05:
		
		if _selected_area:
			state = State.SNAP
		else:

			_reset()


func _snap(delta: float):
	if not _selected_area:
		_reset()
		return

	var current_angle = wrapf($SpriteRuleta.rotation_degrees, 0.0, 360.0)
	var target_angle = wrapf(_selected_area.rotation_degrees, 0.0, 360.0)
	var diff = fmod((target_angle - current_angle + 540.0), 360.0) - 180.0


	inertia *= friction

	$SpriteRuleta.rotation_degrees += diff * snap_speed * delta

	if abs(diff) < 0.5 and abs(inertia) < 0.05:
		
		$SpriteRuleta.rotation_degrees = target_angle
		_reward()
		_reset()

func _on_AreaManecilla_area_entered(area: Area2D) -> void:
	if state != State.SPINNING:
		return
	_selected_area = area
	_bounce()
	#if $TickSound:
	#	$TickSound.play()
	#$SpriteRuleta.rotation_degrees += randf_range(-2.0, 2.0)


func _bounce():
	if bouncing:
		return
	bouncing = true
	var spr = $Manecilla/SpriteManecilla
	var orig_pos = spr.position
	var orig_rot = spr.rotation_degrees
	spr.rotation_degrees = -bounce_angle
	spr.position.y -= 4
	var t = create_tween()
	t.tween_property(spr, "rotation_degrees", orig_rot, bounce_time)
	t.tween_property(spr, "position", orig_pos, bounce_time)
	t.connect("finished", Callable(self, "_bounce_end"))
	t.play()


func _bounce_end():
	bouncing = false

func _reward():
	#if $Particles:
	#	$Particles.emitting = true
	#if $SoundWin:
	#	$SoundWin.play()

	if not _selected_area or not "slot_index" in _selected_area:
		push_error("Ruleta _reward(): El Area2D ganadora ('%s') no tiene la variable 'slot_index'." % _selected_area.name)
		_reset()
		return

	var index: int = _selected_area.slot_index

	if index < 0 or index >= SlotsContainer.get_child_count():
		push_error("Ruleta _reward(): El 'slot_index' (%d) del área '%s' está fuera del rango de hijos de 'SlotsContainer' (cantidad %d)." % [index, _selected_area.name, SlotsContainer.get_child_count()])
		_reset()
		return

	var winning_slot_root = SlotsContainer.get_child(index)
	var actual_slot_node = null

	if winning_slot_root and winning_slot_root.has_node("slot"):
		actual_slot_node = winning_slot_root.get_node("slot")

	if actual_slot_node and "current_piece_data" in actual_slot_node:
		
		var piece = actual_slot_node.current_piece_data 
		
		# Asumiendo que piece.piece_origin es un PieceRes
		if piece and piece.piece_origin:
			print("¡El slot (Índice %d) tiene la pieza: %s!" % [index, piece.piece_name])
			
			# --- ¡CAMBIO CLAVE! ---
			# Emitimos la señal a través del Autoload GlobalSignals
			GlobalSignals.emit_signal("combat_requested", piece.piece_origin)
			
		else:
			print("¡El slot ganador (Índice %d) estaba vacío o 'piece_origin' es nulo!" % index)
	else:
		push_error("Ruleta _reward(): El nodo 'SlotPiece' (índice %d) o su hijo 'slot' no son válidos o no tienen el script." % index)

	_reset()
func _reset():
	_selected_area = null
	inertia = 0.0
	bouncing = false
	state = State.IDLE
