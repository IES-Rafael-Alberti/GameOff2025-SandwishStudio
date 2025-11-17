# RuletaScene.gd
extends Node2D

signal roulette_spin_started

@export var friction := 0.985
@export var snap_speed := 7.5 # Ya no se usa para el snap, pero se deja por si acaso
@export var bounce_angle := 12.0
@export var bounce_time := 0.08
@export var enemy_manager: Node
@export var min_impulse_force := 10.0
@export var min_impulse_random_range := Vector2(1.5, 4)
@onready var SlotsContainer: Node2D = $SpriteRuleta/SlotsContainer

# --- ¡CAMBIO 1!
# Se elimina el estado 'SNAP' ---
enum State { IDLE, DRAGGING, SPINNING }
var state := State.IDLE
var last_mouse_angle := 0.0
var inertia := 0.0
var _selected_area: Area2D = null
var bouncing := false

var is_interactive := true

# --- ¡NUEVA FUNCIÓN! ---
# Se llama cuando el script _ready() esté disponible
func _ready():
	# Conectamos la señal de borrado de inventario
	GlobalSignals.piece_type_deleted.connect(_on_piece_type_deleted)


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
		# --- ¡CAMBIO 2!
# Se elimina el 'case State.SNAP:' ---
		

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

	# --- ¡CAMBIO 3!
# La ruleta se detiene por fricción ---
	# Ya no cambia a 'State.SNAP'
	if abs(inertia) < 0.05:
		# Si la inercia es casi cero, paramos, damos recompensa y reseteamos estado.
		_reward() 
		_reset()


# --- ¡CAMBIO 4! Se elimina la función _snap() completa ---
# func _snap(delta: float):
#	...
#	...


func _on_AreaManecilla_area_entered(area: Area2D) -> void:
	# Aún necesitamos esto para saber qué área es la seleccionada
	# en el momento en que la ruleta se detiene.
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


func _reward():
	# Esta función es la original
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
		
		var piece = actual_slot_node.current_piece_data 
		
		if piece and piece is PieceData and "piece_origin" in piece:
			
			var combat_resource = piece.piece_origin
			
			if combat_resource and combat_resource is PieceRes:
				print("¡El slot (Índice %d) tiene la pieza: %s!" % [index, piece.resource_name])
				GlobalSignals.emit_signal("combat_requested", combat_resource)
			else:
				print("¡El slot (Índice %d) tiene PieceData pero 'piece_origin' es nulo o no es PieceRes!" % index)
				GlobalSignals.emit_signal("combat_requested", null)
				
		elif piece:
			push_error("Ruleta _reward(): El item '%s' no es un 'PieceData' o no tiene 'piece_origin'." % piece.resource_name)
			GlobalSignals.emit_signal("combat_requested", null)
			
		else:
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
	# ¡Importante!
# No reseteamos la rotación aquí.
	
# --- ¡CAMBIO 5! Nueva función pública ---
# Esta función será llamada por gameManager para reiniciar la
# rotación de la ruleta DESPUÉS del combate.
func reset_rotation_to_zero():
	# Solo reseteamos si la ruleta está en reposo (IDLE)
	if state == State.IDLE:
		$SpriteRuleta.rotation_degrees = 0.0


# --- ¡NUEVA FUNCIÓN DE SEÑAL! ---
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
