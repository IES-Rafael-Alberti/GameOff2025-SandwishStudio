extends Node2D

@export var friction := 0.985
@export var snap_speed := 7.5
@export var bounce_angle := 12.0
@export var bounce_time := 0.08
@export var enemy_manager: Node

enum State { IDLE, DRAGGING, SPINNING, SNAP }
var state := State.IDLE

var last_mouse_angle := 0.0
var inertia := 0.0
var _selected_area: Area2D = null
var bouncing := false

# Nuevo: método útil para que otros nodos verifiquen si la ruleta está "en movimiento"
func is_moving() -> bool:
	# Considera DRAGGING, SPINNING y SNAP como "movimiento" (no permitir modificar piezas)
	return state != State.IDLE

# Mantener compatibilidad: puede usarse donde sea necesario
func can_modify_pieces() -> bool:
	return state == State.IDLE

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
			if abs(inertia) < 0.2:
				inertia = 3.0 * randf_range(0.8, 1.4)
			_selected_area = null

func _drag():
	var mouse = get_global_mouse_position()
	var center = $SpriteRuleta.global_position
	var angle_deg = rad_to_deg((mouse - center).angle())
	var diff = fmod((angle_deg - last_mouse_angle + 540.0), 360.0) - 180.0

	last_mouse_angle = angle_deg
	inertia = diff * 1.2
	$SpriteRuleta.rotation_degrees += inertia

func _spin(delta: float):
	$SpriteRuleta.rotation_degrees += inertia
	inertia *= friction

	if abs(inertia) < 0.05:
		_reset()

func _snap(delta: float):
	if not _selected_area:
		_reset()
		return

	var current_angle = wrapf($SpriteRuleta.rotation_degrees, 0.0, 360.0)
	var target_angle = wrapf(_selected_area.rotation_degrees, 0.0, 360.0)
	var diff = fmod((target_angle - current_angle + 540.0), 360.0) - 180.0

	$SpriteRuleta.rotation_degrees += diff * snap_speed * delta
	inertia *= friction
	$SpriteRuleta.rotation_degrees += inertia * delta

	if abs(diff) < 0.5 and abs(inertia) < 0.05:
		_reward()
		_reset()

func _on_AreaManecilla_area_entered(area: Area2D) -> void:
	if state != State.SPINNING:
		return

	_selected_area = area
	_bounce()

	if $TickSound:
		$TickSound.play()

	$SpriteRuleta.rotation_degrees += randf_range(-2.0, 2.0)

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
	if $Particles:
		$Particles.emitting = true
	if $SoundWin:
		$SoundWin.play()

	if _selected_area and enemy_manager:
		if _selected_area.has_variable("enemy_id"):
			enemy_manager.spawn(_selected_area.enemy_id)

func _reset():
	_selected_area = null
	inertia = 0.0
	bouncing = false
	state = State.IDLE
