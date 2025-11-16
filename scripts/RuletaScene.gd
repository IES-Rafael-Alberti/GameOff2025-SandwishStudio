# RuletaScene.gd
extends Node2D

signal roulette_spin_started

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

var is_interactive := true

func is_moving(): 
	return state != State.IDLE

func set_interactive(interactive: bool):
	is_interactive = interactive
	for slot_root in SlotsContainer.get_children():
		if slot_root.has_node("slot"):
			var slot = slot_root.get_node("slot")
			if slot is Control:
				slot.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
				

func _process(delta: float) -> void:
	match state:
		State.DRAGGING:
			_drag()
		State.SPINNING:
			_spin(delta)
		State.SNAP:
			_snap(delta)

func _input(event):
	if not is_interactive:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		
		if event.pressed and state == State.IDLE:
			state = State.DRAGGING
			last_mouse_angle = rad_to_deg((get_global_mouse_position() - $SpriteRuleta.global_position).angle())
		
		elif not event.pressed and state == State.DRAGGING:
			state = State.SPINNING
			
			var min_boost = min_impulse_force * randf_range(min_impulse_random_range.x, min_impulse_random_range.y)
			inertia += min_boost
			_selected_area = null
			
			roulette_spin_started.emit()


func _drag():
	var mouse = get_global_mouse_position()
	var center = $SpriteRuleta.global_position
	var angle_deg = rad_to_deg((mouse-center).angle())
	var diff = fmod((angle_deg-last_mouse_angle+540),360)-180
	last_mouse_angle = angle_deg
	
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
			_reward() 
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

# --- ¡FUNCIÓN _reward CORREGIDA! ---
func _reward():
	if not _selected_area or not "slot_index" in _selected_area:
		print("¡El giro terminó en un espacio vacío! Saltando combate.")
		GlobalSignals.emit_signal("combat_requested", null)
		return

	var index: int = _selected_area.slot_index

	if index < 0 or index >= SlotsContainer.get_child_count():
		push_error("Ruleta _reward(): El 'slot_index' (%d) está fuera de rango." % index)
		GlobalSignals.emit_signal("combat_requested", null)
		return

	var winning_slot_root = SlotsContainer.get_child(index)
	var actual_slot_node = null

	if winning_slot_root and winning_slot_root.has_node("slot"):
		actual_slot_node = winning_slot_root.get_node("slot")

	if actual_slot_node and "current_piece_data" in actual_slot_node:
		
		# 'piece' es el PieceData que está en el slot
		var piece = actual_slot_node.current_piece_data 
		
		# --- ¡LÓGICA CORREGIDA! ---
		# Verificamos si 'piece' es un PieceData Y si tiene la propiedad 'piece_origin'
		if piece and piece is PieceData and "piece_origin" in piece:
			
			# 'combat_resource' es el PieceRes que está DENTRO del PieceData
			var combat_resource = piece.piece_origin
			
			# Verificamos que el combat_resource sea válido
			if combat_resource and combat_resource is PieceRes:
				print("¡El slot (Índice %d) tiene la pieza: %s!" % [index, piece.resource_name])
				# Enviamos el PieceRes (piece_origin) al combate
				GlobalSignals.emit_signal("combat_requested", combat_resource)
			else:
				# Tenía PieceData, pero el 'piece_origin' estaba vacío o no era un PieceRes
				print("¡El slot (Índice %d) tiene PieceData pero 'piece_origin' es nulo o no es PieceRes!" % index)
				GlobalSignals.emit_signal("combat_requested", null)
				
		elif piece:
			# El slot tenía algo, pero no era un PieceData (quizás un PassiveData?)
			push_error("Ruleta _reward(): El item '%s' no es un 'PieceData' o no tiene 'piece_origin'." % piece.resource_name)
			GlobalSignals.emit_signal("combat_requested", null)
			
		else:
			# El slot estaba vacío
			print("¡El slot ganador (Índice %d) estaba vacío o 'current_piece_data' es nulo!" % index)
			GlobalSignals.emit_signal("combat_requested", null)
	else:
		push_error("Ruleta _reward(): El nodo 'SlotPiece' (índice %d) o su hijo 'slot' no son válidos." % index)
		GlobalSignals.emit_signal("combat_requested", null)

	
func _reset():
	_selected_area = null
	inertia = 0.0
	bouncing = false
	state = State.IDLE
	# No reseteamos la rotación
